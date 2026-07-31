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
        let total = deduped.count

        let unorderedResults = await withTaskGroup(of: (Int, VideoInfo).self) { group in
            for (index, file) in deduped.enumerated() {
                group.addTask {
                    let info = await MediaProbe.probe(filePath: file, ffprobePath: ffprobePath)
                    return (index, info)
                }
            }

            var completed = 0
            var collected: [(Int, VideoInfo)] = []
            for await result in group {
                collected.append(result)
                completed += 1
                progress(completed, total)
            }
            return collected
        }

        let results = unorderedResults.sorted { $0.0 < $1.0 }.map { $1 }
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
