import Foundation
import Darwin

struct ProcessOutput {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum ProcessRunnerError: Error, LocalizedError {
    case timeout
    case launchFailure(Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "The process did not finish in time."
        case .cancelled:
            return "The operation was cancelled."
        case .launchFailure(let error):
            return "Failed to launch process: \(error.localizedDescription)"
        }
    }
}

final class ProcessRunner {
    private init() {}

    /// Grace period after SIGTERM before force-killing the child.
    private static let gracePeriodNanoseconds: UInt64 = 2_000_000_000

    static func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval = 60
    ) async throws -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutReader = Reader(handle: stdoutPipe.fileHandleForReading)
        let stderrReader = Reader(handle: stderrPipe.fileHandleForReading)
        let box = RunBox(process: process, stdoutReader: stdoutReader, stderrReader: stderrReader)

        stdoutReader.start()
        stderrReader.start()
        process.terminationHandler = { [weak box] _ in
            Task { [weak box] in
                await box?.finishFromTermination()
            }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessOutput, Error>) in
                box.setContinuation(continuation)
                guard !box.hasResumed else { return }
                do {
                    try process.run()
                    box.startTimeout(after: timeout)
                } catch {
                    box.finishWithError(ProcessRunnerError.launchFailure(error))
                }
            }
        } onCancel: {
            box.cancel()
        }
    }

    private final class Reader {
        let handle: FileHandle
        private var task: Task<Data, Never>?

        init(handle: FileHandle) {
            self.handle = handle
        }

        func start() {
            task = Task { [handle] in
                await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let data = handle.readDataToEndOfFile()
                        handle.closeFile()
                        continuation.resume(returning: data)
                    }
                }
            }
        }

        func data() async -> Data {
            await (task?.value ?? Data())
        }
    }

    private final class RunBox {
        private let process: Process
        private let stdoutReader: Reader
        private let stderrReader: Reader
        private let lock = NSLock()
        private var continuation: CheckedContinuation<ProcessOutput, Error>?
        private var outcome: Outcome = .normal
        private var timeoutTask: Task<Void, Error>?
        private var cancelledBeforeStart = false
        private(set) var hasResumed = false

        init(process: Process, stdoutReader: Reader, stderrReader: Reader) {
            self.process = process
            self.stdoutReader = stdoutReader
            self.stderrReader = stderrReader
        }

        func setContinuation(_ continuation: CheckedContinuation<ProcessOutput, Error>) {
            lock.lock()
            self.continuation = continuation
            let shouldFinish = cancelledBeforeStart
            lock.unlock()
            if shouldFinish {
                Task { [weak self] in
                    await self?.finishAfterShutdown()
                }
            }
        }

        func startTimeout(after: TimeInterval) {
            timeoutTask = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: UInt64(after * 1_000_000_000))
                    guard let self = self else { return }
                    self.setOutcome(.timedOut)
                    await self.shutDownProcess()
                } catch {
                    // Sleep cancelled when the process finishes or the parent cancels.
                }
            }
        }

        func cancel() {
            lock.lock()
            if continuation == nil {
                cancelledBeforeStart = true
                lock.unlock()
                return
            }
            lock.unlock()
            timeoutTask?.cancel()
            setOutcome(.cancelled)
            Task { [weak self] in
                await self?.shutDownProcess()
            }
        }

        func finishWithError(_ error: Error) {
            lock.lock()
            guard let continuation = continuation, !hasResumed else {
                lock.unlock()
                return
            }
            hasResumed = true
            lock.unlock()
            timeoutTask?.cancel()
            continuation.resume(throwing: error)
        }

        func finishFromTermination() async {
            await finishAfterShutdown()
        }

        private func shutDownProcess() async {
            if process.isRunning {
                process.terminate()
                try? await Task.sleep(nanoseconds: ProcessRunner.gracePeriodNanoseconds)
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }
            await finishAfterShutdown()
        }

        private func finishAfterShutdown() async {
            let stdoutData = await stdoutReader.data()
            let stderrData = await stderrReader.data()
            finish(stdoutData: stdoutData, stderrData: stderrData)
        }

        private func finish(stdoutData: Data, stderrData: Data) {
            lock.lock()
            guard let continuation = continuation, !hasResumed else {
                lock.unlock()
                return
            }
            hasResumed = true
            let outcome = self.outcome
            lock.unlock()
            timeoutTask?.cancel()
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            switch outcome {
            case .normal:
                continuation.resume(
                    returning: ProcessOutput(
                        stdout: stdout,
                        stderr: stderr,
                        exitCode: process.terminationStatus
                    )
                )
            case .timedOut:
                continuation.resume(throwing: ProcessRunnerError.timeout)
            case .cancelled:
                continuation.resume(throwing: ProcessRunnerError.cancelled)
            }
        }

        private func setOutcome(_ outcome: Outcome) {
            lock.lock()
            if self.outcome == .normal {
                self.outcome = outcome
            }
            lock.unlock()
        }

        private enum Outcome {
            case normal
            case timedOut
            case cancelled
        }
    }
}
