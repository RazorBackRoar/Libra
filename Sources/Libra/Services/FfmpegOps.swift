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
        withinRoot: String? = nil,
        keepAudio: Bool = false,
        hasAudio: Bool = false
    ) async -> OperationResult {
        return await runToUniqueOutput(
            filePath: filePath,
            outputPath: outputPath,
            ffmpegPath: ffmpegPath,
            timeout: timeout(durationSec: durationSec, factor: factor),
            withinRoot: withinRoot,
            arguments: { tmp in
                sloMoArguments(
                    input: filePath, output: tmp, factor: factor,
                    keepAudio: keepAudio, hasAudio: hasAudio)
            }
        )
    }

    static func sloMoArguments(
        input: String, output: String, factor: Double,
        keepAudio: Bool = false, hasAudio: Bool = false
    ) -> [String] {
        // The output keeps the input's container. H.264 cannot live in WebM,
        // so WebM outputs get VP9; every other supported container takes
        // libx264. (h264_videotoolbox was evaluated and stays unused — it is
        // faster but measurably lower quality per bit, and slo-mo output is
        // archival content where quality wins over encode speed.)
        let ext = (output as NSString).pathExtension.lowercased()
        let videoCodec = ext == "webm" ? "libvpx-vp9" : "libx264"
        var args = [
            "-i", input,
            "-vf", "setpts=PTS*\(1.0 / factor)",
        ]
        if keepAudio && hasAudio {
            // Audio is tempo-matched to the slowed video. WebM can't hold AAC.
            args += ["-af", atempoFilter(factor: factor)]
            args += ["-c:a", ext == "webm" ? "libopus" : "aac"]
        } else {
            args.append("-an")
        }
        args += ["-c:v", videoCodec, "-y", output]
        return args
    }

    /// atempo accepts 0.5…100 per stage — chain 0.5 steps for slower factors
    /// (0.25 → "atempo=0.5,atempo=0.5").
    private static func atempoFilter(factor: Double) -> String {
        var tempo = max(factor, 0.01)
        var parts: [String] = []
        while tempo < 0.5 {
            parts.append("atempo=0.5")
            tempo /= 0.5
        }
        parts.append("atempo=\(tempo)")
        return parts.joined(separator: ",")
    }

    static func adjustTimestamp(
        filePath: String,
        outputPath: String,
        creationTime: Date,
        ffmpegPath: String,
        durationSec: Double = 0,
        withinRoot: String? = nil
    ) async -> OperationResult {
        let result = await runToUniqueOutput(
            filePath: filePath,
            outputPath: outputPath,
            ffmpegPath: ffmpegPath,
            timeout: timeout(durationSec: durationSec, factor: 1),
            withinRoot: withinRoot,
            arguments: { tmp in
                adjustTimestampArguments(input: filePath, output: tmp, creationTime: creationTime)
            }
        )
        if result.status == .success, let dest = result.outputPath {
            try? FileManager.default.setAttributes(
                [.creationDate: creationTime], ofItemAtPath: dest)
        }
        return result
    }

    static func adjustTimestampArguments(input: String, output: String, creationTime: Date)
        -> [String]
    {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return [
            "-i", input,
            "-metadata", "creation_time=\(formatter.string(from: creationTime))",
            "-c", "copy",
            "-y", output,
        ]
    }

    /// ffmpeg selects its muxer from the output extension, so the temp name
    /// keeps the real container extension last: `name.libra-tmp.mp4`.
    static func temporaryOutputPath(for outputPath: String) -> String {
        let ns = outputPath as NSString
        let ext = ns.pathExtension
        let stem = (ns.lastPathComponent as NSString).deletingPathExtension
        let name = ext.isEmpty ? "\(stem).libra-tmp" : "\(stem).libra-tmp.\(ext)"
        return (ns.deletingLastPathComponent as NSString).appendingPathComponent(name)
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
        let tmp = FileOps.uniquePath(for: temporaryOutputPath(for: outputPath))
        if let withinRoot, !FileOps.destinationIsSafe(tmp, within: withinRoot) {
            return OperationResult(
                path: filePath,
                status: .failed,
                reason: "Destination is outside the selected folder (symlink)"
            )
        }
        var movedToOutput = false
        defer {
            if !movedToOutput {
                try? FileManager.default.removeItem(atPath: tmp)
            }
        }
        do {
            let output = try await ProcessRunner.run(
                executablePath: ffmpegPath,
                arguments: arguments(tmp),
                timeout: timeout
            )
            if output.exitCode == 0 {
                do {
                    var dest = outputPath
                    if FileManager.default.fileExists(atPath: dest) {
                        dest = FileOps.uniquePath(for: dest)
                    }
                    if let withinRoot, !FileOps.destinationIsSafe(dest, within: withinRoot) {
                        return OperationResult(
                            path: filePath,
                            status: .failed,
                            reason: "Destination is outside the selected folder (symlink)"
                        )
                    }
                    try FileManager.default.moveItem(atPath: tmp, toPath: dest)
                    movedToOutput = true
                    return OperationResult(path: filePath, status: .success, outputPath: dest)
                } catch {
                    return OperationResult(
                        path: filePath,
                        status: .failed,
                        reason: error.localizedDescription
                    )
                }
            } else {
                return OperationResult(
                    path: filePath,
                    status: .failed,
                    reason: ffmpegFailureReason(output.stderr)
                )
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

    private static func ffmpegFailureReason(_ stderr: String) -> String {
        let lines =
            stderr
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let last = lines.suffix(2).last, !last.isEmpty {
            return String(last)
        }
        return "Processing failed"
    }
}
