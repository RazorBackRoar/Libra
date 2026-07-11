import Foundation

/// Compatibility shim — probing lives in `MediaProbe`.
@MainActor
enum FfprobeService {
    static func probe(filePath: String, ffprobePath: String) async -> VideoInfo {
        await MediaProbe.probe(filePath: filePath, ffprobePath: ffprobePath)
    }
}
