import Foundation

enum FfmpegOps {
    static func timeout(durationSec: Double, factor: Double = 1) -> TimeInterval {
        let safeFactor = max(factor, 0.01)
        return min(3600, max(30, 30 + durationSec * 4 / safeFactor))
    }

    static func sloMo(
        filePath: String,
        outputPath: String,
        factor: Double,
        ffmpegPath: String,
        durationSec: Double = 0,
        withinRoot: String? = nil
    ) async -> OperationResult {
        let multiplier = 1.0 / factor
        let setpts = "PTS*\(multiplier)"
        return await runToUniqueOutput(
            filePath: filePath,
            outputPath: outputPath,
            ffmpegPath: ffmpegPath,
            timeout: timeout(durationSec: durationSec, factor: factor),
            withinRoot: withinRoot,
            arguments: { tmp in
                [
                    "-i", filePath,
                    "-vf", setpts,
                    "-an",
                    "-c:v", "libx264",
                    "-y", tmp
                ]
            }
        )
    }

    static func adjustTimestamp(
        filePath: String,
        outputPath: String,
        creationTime: Date,
        ffmpegPath: String,
        durationSec: Double = 0,
        withinRoot: String? = nil
    ) async -> OperationResult {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeString = formatter.string(from: creationTime)
        let result = await runToUniqueOutput(
            filePath: filePath,
            outputPath: outputPath,
            ffmpegPath: ffmpegPath,
            timeout: timeout(durationSec: durationSec, factor: 1),
            withinRoot: withinRoot,
            arguments: { tmp in
                [
                    "-i", filePath,
                    "-metadata", "creation_time=\(timeString)",
                    "-c", "copy",
                    "-y", tmp
                ]
            }
        )
        if result.status == .success, let dest = result.outputPath {
            try? FileManager.default.setAttributes([.creationDate: creationTime], ofItemAtPath: dest)
        }
        return result
    }

    private static func runToUniqueOutput(
        filePath: String,
        outputPath: String,
        ffmpegPath: String,
        timeout: TimeInterval,
        withinRoot: String? = nil,
        arguments: (String) -> [String]
    ) async -> OperationResult {
        if let withinRoot, !FileOps.destinationIsSafe(outputPath, within: withinRoot) {
            return OperationResult(
                path: filePath,
                status: .failed,
                reason: "Destination is outside the selected folder (symlink)"
            )
        }
        let dir = (outputPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let tmp = FileOps.uniquePath(for: outputPath + ".libra-tmp")
        if let withinRoot, !FileOps.destinationIsSafe(tmp, within: withinRoot) {
            return OperationResult(
                path: filePath,
                status: .failed,
                reason: "Destination is outside the selected folder (symlink)"
            )
        }
        do {
            let output = try await ProcessRunner.run(
                executablePath: ffmpegPath,
                arguments: arguments(tmp),
                timeout: timeout
            )
            if output.exitCode == 0 {
                do {
                    if FileManager.default.fileExists(atPath: outputPath) {
                        try FileManager.default.removeItem(atPath: outputPath)
                    }
                    try FileManager.default.moveItem(atPath: tmp, toPath: outputPath)
                    return OperationResult(path: filePath, status: .success, outputPath: outputPath)
                } catch {
                    try? FileManager.default.removeItem(atPath: tmp)
                    return OperationResult(
                        path: filePath,
                        status: .failed,
                        reason: error.localizedDescription
                    )
                }
            } else {
                try? FileManager.default.removeItem(atPath: tmp)
                return OperationResult(
                    path: filePath,
                    status: .failed,
                    reason: ffmpegFailureReason(output.stderr)
                )
            }
        } catch ProcessRunnerError.cancelled {
            try? FileManager.default.removeItem(atPath: tmp)
            return OperationResult(path: filePath, status: .cancelled, reason: "Cancelled")
        } catch ProcessRunnerError.timeout {
            try? FileManager.default.removeItem(atPath: tmp)
            return OperationResult(path: filePath, status: .failed, reason: "Processing timed out")
        } catch is CancellationError {
            try? FileManager.default.removeItem(atPath: tmp)
            return OperationResult(path: filePath, status: .cancelled, reason: "Cancelled")
        } catch {
            try? FileManager.default.removeItem(atPath: tmp)
            return OperationResult(path: filePath, status: .failed, reason: "Processing failed")
        }
    }

    private static func ffmpegFailureReason(_ stderr: String) -> String {
        let lines = stderr
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let last = lines.suffix(2).last, !last.isEmpty {
            return String(last)
        }
        return "Processing failed"
    }
}
