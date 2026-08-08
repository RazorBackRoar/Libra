import Foundation

enum ScannerService {
    typealias ProbeHandler = @Sendable (String, String) async throws -> VideoInfo
    typealias ProgressHandler = @Sendable (Int, Int) async -> Void

    /// macOS bundle-like directories that are apps/frameworks, not media folders.
    private static let bundleExtensions: Set<String> = [
        "app", "bundle", "framework", "xpc", "plugin", "kext", "driver", "appex", "qlgenerator"
    ]

    static func scan(
        paths: [String],
        extensions: [String],
        ffprobePath: String,
        probe: ProbeHandler? = nil,
        progress: ProgressHandler? = nil
    ) async -> ScanOutcome {
        let probeHandler = probe ?? { filePath, probePath in
            try await MediaProbe.probe(filePath: filePath, ffprobePath: probePath)
        }

        var files: [String] = []
        var unsupported: [OperationResult] = []
        let allowed = Set(extensions.map { $0.lowercased() })

        for path in paths {
            if Task.isCancelled {
                return cancelledOutcome(
                    supported: [],
                    unsupported: unsupported,
                    discoveredTotal: 0,
                    completedCount: 0
                )
            }

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
                do {
                    let walked = try walkDirectory(path, extensions: Array(allowed))
                    files.append(contentsOf: walked.supported)
                    unsupported.append(contentsOf: walked.unsupported)
                } catch is CancellationError {
                    let deduped = Array(Set(files)).sorted()
                    return cancelledOutcome(
                        supported: [],
                        unsupported: unsupported,
                        discoveredTotal: deduped.count,
                        completedCount: 0
                    )
                } catch {
                    continue
                }
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
        await progress?(0, total)

        var results: [VideoInfo] = []
        for (index, file) in deduped.enumerated() {
            if Task.isCancelled {
                return cancelledOutcome(
                    supported: results,
                    unsupported: unsupported,
                    discoveredTotal: total,
                    completedCount: results.count
                )
            }

            do {
                let info = try await probeHandler(file, ffprobePath)
                results.append(info)
            } catch is CancellationError {
                return cancelledOutcome(
                    supported: results,
                    unsupported: unsupported,
                    discoveredTotal: total,
                    completedCount: results.count
                )
            } catch ProcessRunnerError.cancelled {
                return cancelledOutcome(
                    supported: results,
                    unsupported: unsupported,
                    discoveredTotal: total,
                    completedCount: results.count
                )
            } catch {
                results.append(
                    VideoInfo(
                        path: file,
                        name: URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent,
                        dir: URL(fileURLWithPath: file).deletingLastPathComponent().path,
                        ext: (file as NSString).pathExtension.lowercased(),
                        sizeBytes: 0,
                        width: 0,
                        height: 0,
                        resolutionClass: "Unknown",
                        orientation: "Unknown",
                        fps: 0,
                        durationSec: 0,
                        codec: "",
                        container: "",
                        make: "",
                        model: "",
                        hasAppleMake: false,
                        hasiPhoneModel: false,
                        hasGPS: false,
                        creationTime: nil,
                        error: "Could not read video metadata",
                        warning: nil
                    )
                )
            }

            await progress?(index + 1, total)
        }

        return ScanOutcome(
            supported: results,
            unsupported: unsupported,
            discoveredTotal: total,
            completedCount: results.count,
            terminal: .completed
        )
    }

    private static func cancelledOutcome(
        supported: [VideoInfo],
        unsupported: [OperationResult],
        discoveredTotal: Int,
        completedCount: Int
    ) -> ScanOutcome {
        ScanOutcome(
            supported: supported,
            unsupported: unsupported,
            discoveredTotal: discoveredTotal,
            completedCount: completedCount,
            terminal: .cancelled
        )
    }

    private static func walkDirectory(
        _ path: String,
        extensions: [String]
    ) throws -> (supported: [String], unsupported: [OperationResult]) {
        var found: [String] = []
        var unsupported: [OperationResult] = []
        let allowed = Set(extensions)
        let enumerator = FileManager.default.enumerator(atPath: path)
        while let item = enumerator?.nextObject() as? String {
            if Task.isCancelled {
                throw CancellationError()
            }

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
