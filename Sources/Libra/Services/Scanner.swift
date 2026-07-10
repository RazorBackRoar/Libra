import Foundation

@MainActor
final class ScannerService {
    private init() {}

    static func scan(
        paths: [String],
        extensions: [String],
        ffprobePath: String,
        progress: @MainActor @escaping (Int, Int) -> Void
    ) async -> [VideoInfo] {
        var files: [String] = []
        for path in paths {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                files.append(contentsOf: walkDirectory(path, extensions: extensions))
            } else {
                files.append(path)
            }
        }

        let deduped = Array(Set(files)).sorted()
        var results: [VideoInfo] = []
        let total = deduped.count
        for (index, file) in deduped.enumerated() {
            let info = await FfprobeService.probe(filePath: file, ffprobePath: ffprobePath)
            results.append(info)
            progress(index + 1, total)
        }
        return results
    }

    private static func walkDirectory(_ path: String, extensions: [String]) -> [String] {
        var found: [String] = []
        let enumerator = FileManager.default.enumerator(atPath: path)
        while let item = enumerator?.nextObject() as? String {
            let full = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue {
                let ext = (full as NSString).pathExtension.lowercased()
                if extensions.contains(ext) {
                    found.append(full)
                }
            }
        }
        return found
    }
}
