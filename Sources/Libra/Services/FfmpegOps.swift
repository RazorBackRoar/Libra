import Foundation

@MainActor
enum FfmpegOps {
    static func sloMo(filePath: String, outputPath: String, factor: Double, ffmpegPath: String) async -> OperationResult {
        let multiplier = 1.0 / factor
        let setpts = "PTS*\(multiplier)"
        let args = [
            "-i", filePath,
            "-vf", setpts,
            "-an",
            "-c:v", "libx264",
            "-y", outputPath
        ]
        do {
            let output = try await ProcessRunner.run(executablePath: ffmpegPath, arguments: args, timeout: 300)
            if output.exitCode == 0 {
                return OperationResult(path: filePath, status: .success, outputPath: outputPath)
            } else {
                return OperationResult(path: filePath, status: .failed, reason: "Processing failed")
            }
        } catch ProcessRunnerError.cancelled {
            return OperationResult(path: filePath, status: .cancelled, reason: "Cancelled")
        } catch ProcessRunnerError.timeout {
            return OperationResult(path: filePath, status: .failed, reason: "Processing timed out")
        } catch is CancellationError {
            return OperationResult(path: filePath, status: .cancelled, reason: "Cancelled")
        } catch {
            return OperationResult(path: filePath, status: .failed, reason: "Processing failed")
        }
    }

    static func adjustTimestamp(filePath: String, outputPath: String, creationTime: Date, ffmpegPath: String) async -> OperationResult {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeString = formatter.string(from: creationTime)
        let args = [
            "-i", filePath,
            "-metadata", "creation_time=\(timeString)",
            "-c", "copy",
            "-y", outputPath
        ]
        do {
            let output = try await ProcessRunner.run(executablePath: ffmpegPath, arguments: args, timeout: 300)
            if output.exitCode == 0 {
                try? FileManager.default.setAttributes([.creationDate: creationTime], ofItemAtPath: outputPath)
                return OperationResult(path: filePath, status: .success, outputPath: outputPath)
            } else {
                return OperationResult(path: filePath, status: .failed, reason: "Processing failed")
            }
        } catch ProcessRunnerError.cancelled {
            return OperationResult(path: filePath, status: .cancelled, reason: "Cancelled")
        } catch ProcessRunnerError.timeout {
            return OperationResult(path: filePath, status: .failed, reason: "Processing timed out")
        } catch is CancellationError {
            return OperationResult(path: filePath, status: .cancelled, reason: "Cancelled")
        } catch {
            return OperationResult(path: filePath, status: .failed, reason: "Processing failed")
        }
    }
}
