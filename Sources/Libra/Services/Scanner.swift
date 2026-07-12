import Foundation

@MainActor
final class ScannerService {
    private init() {}

    /// macOS bundle-like directories that are apps/frameworks, not media folders.
    private static let bundleExtensions: Set<String> = [
        "app", "bundle", "framework", "xpc", "plugin", "kext", "driver", "appex", "qlgenerator"
    ]

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
                if isBundleDirectory(path) {
                    unsupported.append(OperationResult(
                        path: path,
                        status: .skipped,
                        reason: "Skipped app/bundle directory"
                    ))
                    continue
                }
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
        var unsupported: [OperationResult] = []
        let allowed = Set(extensions)
        let enumerator = FileManager.default.enumerator(atPath: path)
        while let item = enumerator?.nextObject() as? String {
            let full = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: full, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                if isBundleDirectory(full) {
                    enumerator?.skipDescendants()
                    unsupported.append(OperationResult(
                        path: full,
                        status: .skipped,
                        reason: "Skipped app/bundle directory"
                    ))
                }
                continue
            }

            let ext = (full as NSString).pathExtension.lowercased()
            if allowed.contains(ext) {
                found.append(full)
            }
        }
        return (found, unsupported)
    }

    private static func isBundleDirectory(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return bundleExtensions.contains(ext)
    }
}
