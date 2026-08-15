import Foundation

enum DuplicateDetector {
    /// Same size, duration, pixel size, frame rate, and codec — not a byte hash.
    static func key(for file: VideoInfo) -> String {
        let duration = Int(file.durationSec.rounded())
        let fps = Int(file.fps.rounded())
        let codec = file.codec.lowercased()
        return "\(file.sizeBytes)|\(duration)|\(file.width)x\(file.height)|\(fps)|\(codec)"
    }

    /// Paths that are extras in a duplicate group (everything after the first, sorted by path).
    static func extraPaths(in files: [VideoInfo]) -> Set<String> {
        var groups: [String: [VideoInfo]] = [:]
        for file in files where file.error == nil {
            groups[key(for: file), default: []].append(file)
        }
        var extras = Set<String>()
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted { $0.path < $1.path }
            for file in ordered.dropFirst() {
                extras.insert(file.path)
            }
        }
        return extras
    }

    static func extraCount(in files: [VideoInfo]) -> Int {
        extraPaths(in: files).count
    }
}
