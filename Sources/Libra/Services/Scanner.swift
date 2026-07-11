import Foundation

@MainActor
final class ScannerService {
    private init() {}

    static func scan(
        paths: [String],
        extensions: [String],
        ffprobePath: String,
        progress: @MainActor @escaping (Int, Int) -> Void
    ) async -> (supported: [VideoInfo], unsupported: [OperationResult]) {
        var files: [String] = []
        var unsupported: [OperationResult] = []
        let allowed = Set(extensions.map { $0.lowercased() })

        for path in paths {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                let walked = walkDirectory(path, extensions: Array(allowed))
                files.append(contentsOf: walked.supported)
                unsupported.append(contentsOf: walked.unsupported)
            } else {
                let ext = (path as NSString).pathExtension.lowercased()
                if allowed.contains(ext) {
                    files.append(path)
                } else {
                    unsupported.append(OperationResult(
                        path: path,
                        status: .skipped,
                        reason: "Unsupported file type (.\(ext.isEmpty ? "?" : ext))"
                    ))
                }
            }
        }

        let deduped = Array(Set(files)).sorted()
        var results: [VideoInfo] = []
        let total = deduped.count
        for (index, file) in deduped.enumerated() {
            let info = await MediaProbe.probe(filePath: file, ffprobePath: ffprobePath)
            results.append(info)
            progress(index + 1, total)
        }
        return (results, unsupported)
    }

    private static func walkDirectory(_ path: String, extensions: [String]) -> (supported: [String], unsupported: [OperationResult]) {
        var found: [String] = []
        let unsupported: [OperationResult] = []
        let allowed = Set(extensions)
        let enumerator = FileManager.default.enumerator(atPath: path)
        while let item = enumerator?.nextObject() as? String {
            let full = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue {
                let ext = (full as NSString).pathExtension.lowercased()
                if allowed.contains(ext) {
                    found.append(full)
                } else if !ext.isEmpty {
                    // Only report files that look like media attempts when walking; skip hidden/system noise
                    continue
                }
            }
        }
        return (found, unsupported)
    }
}
