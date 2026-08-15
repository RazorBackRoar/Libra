import Foundation

enum ScannerService {
    typealias ProbeHandler = @Sendable (String) async throws -> VideoInfo
    typealias ProgressHandler = @Sendable (Int, Int) async -> Void

    /// macOS bundle-like directories that are apps/frameworks, not media folders.
    private static let bundleExtensions: Set<String> = [
        "app", "bundle", "framework", "xpc", "plugin", "kext", "driver", "appex", "qlgenerator"
    ]

    static func scan(
        paths: [String],
        extensions: [String],
        probe: ProbeHandler? = nil,
        progress: ProgressHandler? = nil,
        confirmDiscover: (@Sendable (Int) async -> Bool)? = nil
    ) async -> ScanOutcome {
        let probeHandler = probe ?? { filePath in
            try await MediaProbe.probe(filePath: filePath)
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

            if FileOps.isSymlinkOrAlias(path) {
                unsupported.append(OperationResult(
                    path: path,
                    status: .skipped,
                    reason: "Skipped symlink or alias"
                ))
                continue
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
                    unsupported.append(OperationResult(
                        path: path,
                        status: .skipped,
                        reason: "Could not read folder: \(error.localizedDescription)"
                    ))
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
        if let confirmDiscover, !(await confirmDiscover(total)) {
            return cancelledOutcome(
                supported: [],
                unsupported: unsupported,
                discoveredTotal: total,
                completedCount: 0
            )
        }
        await progress?(0, total)

        var slotResults: [Int: VideoInfo] = [:]
        let workerCount = min(4, max(total, 0))

        if total > 0 {
            await withTaskGroup(of: (Int, Result<VideoInfo, Error>).self) { group in
                var submitted = 0
                func enqueue(_ index: Int) {
                    let file = deduped[index]
                    group.addTask {
                        do {
                            let info = try await probeHandler(file)
                            return (index, .success(info))
                        } catch {
                            return (index, .failure(error))
                        }
                    }
                }

                while submitted < workerCount {
                    enqueue(submitted)
                    submitted += 1
                }

                var completed = 0
                while let (index, result) = await group.next() {
                    if Task.isCancelled {
                        group.cancelAll()
                        break
                    }
                    switch result {
                    case .success(let info):
                        slotResults[index] = info
                    case .failure(let error):
                        if error is CancellationError {
                            group.cancelAll()
                            break
                        }
                        if let runner = error as? ProcessRunnerError, case .cancelled = runner {
                            group.cancelAll()
                            break
                        }
                        slotResults[index] = failedProbeInfo(filePath: deduped[index])
                    }
                    completed += 1
                    await progress?(completed, total)
                    if submitted < total {
                        enqueue(submitted)
                        submitted += 1
                    }
                }
            }
        }

        let results = slotResults.keys.sorted().compactMap { slotResults[$0] }
        if Task.isCancelled || results.count < total {
            return cancelledOutcome(
                supported: results,
                unsupported: unsupported,
                discoveredTotal: total,
                completedCount: results.count
            )
        }

        return ScanOutcome(
            supported: results,
            unsupported: unsupported,
            discoveredTotal: total,
            completedCount: results.count,
            terminal: .completed
        )
    }

    private static func failedProbeInfo(filePath: String) -> VideoInfo {
        VideoInfo(
            path: filePath,
            name: URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent,
            dir: URL(fileURLWithPath: filePath).deletingLastPathComponent().path,
            ext: (filePath as NSString).pathExtension.lowercased(),
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

            if FileOps.isSymlinkOrAlias(full) {
                if isDir.boolValue {
                    enumerator?.skipDescendants()
                }
                unsupported.append(OperationResult(
                    path: full,
                    status: .skipped,
                    reason: "Skipped symlink or alias"
                ))
                continue
            }

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
