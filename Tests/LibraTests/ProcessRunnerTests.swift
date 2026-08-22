import XCTest
@testable import Libra

final class ProcessRunnerTests: XCTestCase {
    func testRunDrainsStandardErrorBeforeItsPipeFills() async throws {
        let output = try await ProcessRunner.run(
            executablePath: "/bin/sh",
            arguments: [
                "-c",
                "i=0; while [ \"$i\" -lt 20000 ]; do printf 'x\\n' >&2; i=$((i + 1)); done; printf 'done\\n'"
            ],
            timeout: 5
        )

        XCTAssertEqual(output.exitCode, 0)
        XCTAssertEqual(output.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "done")
        XCTAssertGreaterThanOrEqual(output.stderr.split(separator: "\n").count, 20000)
    }

    func testRunThrowsTimeoutAndStopsChild() async {
        let started = Date()
        do {
            _ = try await ProcessRunner.run(
                executablePath: "/bin/sh",
                arguments: ["-c", "sleep 30"],
                timeout: 0.4
            )
            XCTFail("Expected timeout")
        } catch ProcessRunnerError.timeout {
            let elapsed = Date().timeIntervalSince(started)
            XCTAssertLessThan(elapsed, 5.0, "Timeout should not wait indefinitely")
            XCTAssertGreaterThanOrEqual(elapsed, 0.3)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRunThrowsCancellationAndStopsChild() async {
        let started = Date()
        let task = Task {
            try await ProcessRunner.run(
                executablePath: "/bin/sh",
                arguments: ["-c", "sleep 30"],
                timeout: 30
            )
        }

        try? await Task.sleep(nanoseconds: 150_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch ProcessRunnerError.cancelled {
            let elapsed = Date().timeIntervalSince(started)
            XCTAssertLessThan(elapsed, 5.0, "Cancellation should not wait indefinitely")
        } catch is CancellationError {
            let elapsed = Date().timeIntervalSince(started)
            XCTAssertLessThan(elapsed, 5.0, "Cancellation should not wait indefinitely")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFfmpegOpsTimeoutCalculations() {
        XCTAssertEqual(FfmpegOps.timeout(durationSec: 0, factor: 1), 30)
        XCTAssertEqual(FfmpegOps.timeout(durationSec: 10, factor: 1), 70)
        XCTAssertEqual(FfmpegOps.timeout(durationSec: 10, factor: 2), 50)
        XCTAssertEqual(FfmpegOps.timeout(durationSec: 2000, factor: 1), 3600, "Should cap at 3600")
        XCTAssertEqual(FfmpegOps.timeout(durationSec: 10, factor: 0), 3600, "Zero factor clamped to 0.01")
    }
}
