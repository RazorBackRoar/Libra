import Foundation
import SwiftUI

@MainActor
final class ToolState: ObservableObject {
    let tool: Tool

    @Published var files: [VideoInfo] = []
    @Published var selected: Set<String> = []
    @Published var results: [OperationResult] = []
    @Published var progress: (done: Int, total: Int) = (0, 0)
    @Published var running = false
    @Published var cancelling = false
    @Published var message: String?
    @Published var recap: String?
    @Published var needsWriteConfirm = false
    @Published var undoRecords: [UndoRecord] = []

    @Published var prefix: String = ""
    @Published var dryRun: Bool = true
    @Published var slomoFactor: Double = 0.5
    @Published var oneMinStart: Date = Date()
    @Published var oneMinMode: String = "copies"

    private var activeTask: Task<Void, Never>?
    private var rerunTask: Task<Void, Never>?
    private var pendingUndo: [UndoRecord] = []

    var canUndo: Bool { !undoRecords.isEmpty && !running }

    init(tool: Tool) {
        self.tool = tool
        let settings = SettingsStore.shared.settings
        self.dryRun = settings.dryRunDefault
        if usesPrefixField {
            self.prefix = settings.defaultPrefix
        }
    }

    var filteredFiles: [VideoInfo] { files }

    func startScan(paths: [String], settings: AppSettings, ffmpegPath: String, ffprobePath: String) {
        guard !running else { return }
        rerunTask?.cancel()
        needsWriteConfirm = false
        running = true
        cancelling = false
        progress = (0, 0)
        files = []
        results = []
        recap = nil
        message = "Finding supported files…"
        AppState.shared.rememberLastFolder(from: paths)

        activeTask = Task { [weak self] in
            guard let self else { return }
            let shouldContinue = await self.performScan(paths: paths, settings: settings, ffprobePath: ffprobePath)
            guard shouldContinue else {
                self.finishIdle()
                return
            }
            await self.continueAfterScan()
        }
    }

    func confirmLiveRun() {
        needsWriteConfirm = false
        dryRun = false
        startRun(
            settings: AppState.shared.settings,
            ffmpegPath: AppState.shared.ffmpegPath,
            ffprobePath: AppState.shared.ffprobePath
        )
    }

    func cancelLiveConfirm() {
        needsWriteConfirm = false
        dryRun = true
        scheduleRerunAfterOptionsChange()
    }

    func startRun(settings: AppSettings, ffmpegPath: String?, ffprobePath: String?) {
        guard !running else { return }
        guard AppState.shared.ffprobePath != nil || ffprobePath != nil else {
            message = "ffprobe is required to scan media."
            return
        }
        if tool.needsFfmpeg, (ffmpegPath ?? AppState.shared.ffmpegPath) == nil {
            message = "ffmpeg is required for \(tool.title)."
            return
        }

        running = true
        cancelling = false
        let priorSkips = results.filter { $0.status == .skipped }
        results = priorSkips
        recap = nil
        message = dryRun ? "Previewing…" : "Writing…"

        let resolvedFfmpeg = ffmpegPath ?? AppState.shared.ffmpegPath ?? ""
        activeTask = Task { [weak self] in
            await self?.performRun(ffmpegPath: resolvedFfmpeg)
        }
    }

    /// Re-process after Prefix / Dry Run / tool options change (debounced).
    /// Live writes never auto-start — they need a confirm.
    func scheduleRerunAfterOptionsChange() {
        guard !files.isEmpty, !running else { return }
        rerunTask?.cancel()
        rerunTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard let self, !Task.isCancelled else { return }
            if self.dryRun {
                self.startRun(
                    settings: AppState.shared.settings,
                    ffmpegPath: AppState.shared.ffmpegPath,
                    ffprobePath: AppState.shared.ffprobePath
                )
            } else if SettingsStore.shared.settings.requireConfirmToWrite {
                self.needsWriteConfirm = true
            } else {
                self.startRun(
                    settings: AppState.shared.settings,
                    ffmpegPath: AppState.shared.ffmpegPath,
                    ffprobePath: AppState.shared.ffprobePath
                )
            }
        }
    }

    func cancelActiveWork() {
        guard running, !cancelling else { return }
        cancelling = true
        message = "Cancelling…"
        rerunTask?.cancel()
        activeTask?.cancel()
    }

    func undoLastRun() {
        guard canUndo else { return }
        running = true
        message = "Undoing last run…"
        let records = undoRecords
        undoRecords = []
        var restored = 0
        var failed = 0
        for record in records.reversed() {
            switch record.kind {
            case .moved:
                let result = FileOps.moveFile(from: record.resultPath, to: record.originalPath, dryRun: false)
                if result.status == .success { restored += 1 } else { failed += 1 }
            case .createdCopy:
                let result = FileOps.deleteFile(record.resultPath, dryRun: false)
                if result.status == .success { restored += 1 } else { failed += 1 }
            }
        }
        running = false
        recap = failed == 0
            ? "Undid \(restored) change\(restored == 1 ? "" : "s")."
            : "Undo finished: \(restored) restored, \(failed) failed."
        message = recap
    }

    private func continueAfterScan() async {
        if tool.needsFfmpeg, AppState.shared.ffmpegPath == nil {
            message = "ffmpeg is required for \(tool.title)."
            finishIdle()
            return
        }
        if dryRun {
            let priorSkips = results.filter { $0.status == .skipped }
            results = priorSkips
            await performRun(ffmpegPath: AppState.shared.ffmpegPath ?? "")
            return
        }
        if SettingsStore.shared.settings.requireConfirmToWrite {
            needsWriteConfirm = true
            recap = "Scanned \(files.count) files. Confirm to write for real."
            message = recap
            finishIdle()
            return
        }
        let priorSkips = results.filter { $0.status == .skipped }
        results = priorSkips
        await performRun(ffmpegPath: AppState.shared.ffmpegPath ?? "")
    }

    private func finishIdle() {
        running = false
        cancelling = false
        activeTask = nil
    }

    /// Returns `true` when the tool should auto-process after this scan.
    private func performScan(paths: [String], settings: AppSettings, ffprobePath: String) async -> Bool {
        var exts = settings.videoExtensions
        if tool.acceptsImages {
            exts = Array(Set(exts + settings.imageExtensions))
        }

        let outcome = await ScannerService.scan(
            paths: paths,
            extensions: exts,
            ffprobePath: ffprobePath,
            progress: { done, total in
                await MainActor.run {
                    self.progress = (done, total)
                    if total > 0, self.message == "Finding supported files…" {
                        self.message = nil
                    }
                }
            }
        )

        files = outcome.supported
        results = outcome.unsupported
        applyScanSummary(outcome)

        return outcome.terminal == .completed
            && !outcome.supported.isEmpty
            && !Task.isCancelled
            && !cancelling
    }

    private func applyScanSummary(_ outcome: ScanOutcome) {
        let failures = outcome.supported.filter { $0.error != nil }.count
        let warnings = outcome.supported.filter { $0.warning != nil }.count
        let unsupportedCount = outcome.unsupported.count
        let dupes = DuplicateDetector.extraCount(in: outcome.supported)

        switch outcome.terminal {
        case .cancelled:
            recap = "Cancelled after \(outcome.completedCount) of \(outcome.discoveredTotal)."
        case .completed:
            var parts: [String] = ["Scanned \(outcome.supported.count) files"]
            if failures > 0 {
                parts.append("\(failures) metadata failure\(failures == 1 ? "" : "s")")
            }
            if warnings > 0 {
                parts.append("\(warnings) metadata warning\(warnings == 1 ? "" : "s")")
            }
            if unsupportedCount > 0 {
                parts.append("\(unsupportedCount) unsupported skipped")
            }
            if dupes > 0 {
                parts.append("\(dupes) likely duplicate\(dupes == 1 ? "" : "s")")
            }
            recap = parts.joined(separator: " · ") + "."
        }
        message = recap
    }

    private func performRun(ffmpegPath: String) async {
        defer { finishIdle() }

        pendingUndo = []
        let priorCount = results.count
        let target = files
        progress = (0, target.count)

        switch tool {
        case .vidres, .promax, .maxvid, .keepName:
            await sort(target: target)
        case .provid:
            await rename(target: target, prefix: prefix)
        case .gps:
            await gpsSort(target: target)
        case .iphoneSorter:
            await iphoneSort(target: target)
        case .oneMin:
            await oneMinAdjust(target: target, start: oneMinStart, mode: oneMinMode, ffmpegPath: ffmpegPath)
        case .slomo:
            await sloMo(target: target, factor: slomoFactor, ffmpegPath: ffmpegPath)
        }

        let runResults = Array(results.dropFirst(priorCount))
        applyRunRecap(runResults)
        if !dryRun {
            undoRecords = pendingUndo
        }
        pendingUndo = []
    }

    private func applyRunRecap(_ runResults: [OperationResult]) {
        let success = runResults.filter { $0.status == .success }.count
        let failed = runResults.filter { $0.status == .failed }.count
        let skipped = runResults.filter { $0.status == .skipped }.count
        var summary: String
        if Task.isCancelled || cancelling {
            summary = "Cancelled after \(progress.done) of \(progress.total)."
        } else if dryRun {
            summary = "Preview: \(success) would change"
            if failed > 0 { summary += ", \(failed) failed" }
            if skipped > 0 { summary += ", \(skipped) skipped" }
            summary += "."
        } else {
            summary = "Wrote \(success) of \(progress.total)"
            if failed > 0 { summary += ", \(failed) failed" }
            if skipped > 0 { summary += ", \(skipped) skipped" }
            summary += "."
        }
        if dryRun, let reportURL = DryRunReport.write(tool: tool, results: runResults) {
            summary += " Report: \(reportURL.lastPathComponent)"
        }
        recap = summary
        message = summary
    }

    private var usesPrefixField: Bool {
        switch tool {
        case .provid, .vidres, .promax, .maxvid:
            return true
        case .keepName, .iphoneSorter, .oneMin, .slomo, .gps:
            return false
        }
    }

    private func namingPrefix() -> String {
        usesPrefixField ? prefix : ""
    }

    private func shouldStop() -> Bool {
        Task.isCancelled || cancelling
    }

    private func advanceProgress() {
        progress = (min(progress.done + 1, progress.total), progress.total)
    }

    private func noteUndo(kind: UndoRecord.Kind, from: String, result: OperationResult) {
        guard !dryRun, result.status == .success, let output = result.outputPath, output != from else { return }
        pendingUndo.append(UndoRecord(kind: kind, originalPath: from, resultPath: output))
    }

    private func keepNameFileName(for file: VideoInfo) -> String {
        let stem = FileOps.sanitizeFileName(file.name)
        return "\(stem).\(file.ext.lowercased())"
    }

    private func sort(target: [VideoInfo]) async {
        let extras = DuplicateDetector.extraPaths(in: target)
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var reserved = Set<String>()
        var index = 0
        for file in target {
            if shouldStop() { return }
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            let folder = destinationFolder(for: file, duplicateExtra: extras.contains(file.path))
            let filename = tool == .keepName
                ? keepNameFileName(for: file)
                : FileNaming.standardFileName(
                    for: file,
                    prefix: namingPrefix(),
                    index: index,
                    padWidth: padWidth
                )
            let dest = FileOps.uniquePath(
                for: (folder as NSString).appendingPathComponent(filename),
                reserved: reserved
            )
            reserved.insert(dest)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun, reserved: reserved)
            if let output = result.outputPath { reserved.insert(output) }
            noteUndo(kind: .moved, from: file.path, result: result)
            results.append(result)
            advanceProgress()
        }
    }

    private func rename(target: [VideoInfo], prefix: String) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var reserved = Set<String>()
        var index = 0
        for file in target {
            if shouldStop() { return }
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            let filename = FileNaming.standardFileName(
                for: file,
                prefix: prefix,
                index: index,
                padWidth: padWidth
            )
            let dest = FileOps.uniquePath(
                for: (file.dir as NSString).appendingPathComponent(filename),
                reserved: reserved
            )
            reserved.insert(dest)
            let result = FileOps.renameFile(from: file.path, to: dest, dryRun: dryRun, reserved: reserved)
            if let output = result.outputPath { reserved.insert(output) }
            noteUndo(kind: .moved, from: file.path, result: result)
            results.append(result)
            advanceProgress()
        }
    }

    private func gpsSort(target: [VideoInfo]) async {
        let extras = DuplicateDetector.extraPaths(in: target)
        var clusters = GPSMapClustering.cluster(files: target)
        for index in clusters.indices {
            if shouldStop() { return }
            let name = await GPSGeocoder.reverseGeocode(
                latitude: clusters[index].latitude,
                longitude: clusters[index].longitude
            )
            clusters[index].placeName = name
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        clusters = GPSMapClustering.mergeByPlaceName(clusters)

        var cityByPath: [String: String] = [:]
        for cluster in clusters {
            let folder = GPSGeocoder.folderName(for: cluster.placeName)
            for file in cluster.files {
                cityByPath[file.path] = folder
            }
        }

        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var reserved = Set<String>()
        var index = 0
        for file in target {
            if shouldStop() { return }
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            let city: String
            if let named = cityByPath[file.path] {
                city = named
            } else if file.hasGPS {
                city = "GPS"
            } else {
                city = "No-GPS"
            }
            let folder = destinationFolder(for: file, duplicateExtra: extras.contains(file.path), gpsCity: city)
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let dest = FileOps.uniquePath(
                for: (folder as NSString).appendingPathComponent(filename),
                reserved: reserved
            )
            reserved.insert(dest)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun, reserved: reserved)
            if let output = result.outputPath { reserved.insert(output) }
            noteUndo(kind: .moved, from: file.path, result: result)
            results.append(result)
            advanceProgress()
        }
    }

    private func iphoneSort(target: [VideoInfo]) async {
        let extras = DuplicateDetector.extraPaths(in: target)
        let ordered = target.sorted { $0.path < $1.path }
        typealias ClassifiedFile = (file: VideoInfo, classification: IPhoneSortLogic.Classification)
        var iphoneFiles: [ClassifiedFile] = []
        var otherFiles: [ClassifiedFile] = []

        for file in ordered {
            if shouldStop() { return }
            if let error = file.error {
                results.append(OperationResult(
                    path: file.path,
                    status: .failed,
                    reason: "Metadata read failed: \(error)"
                ))
                advanceProgress()
                continue
            }
            let classification = IPhoneSortLogic.classify(
                hasAppleMake: file.hasAppleMake,
                hasiPhoneModel: file.hasiPhoneModel,
                make: file.make,
                model: file.model
            )
            if classification.isIPhoneFolder {
                iphoneFiles.append((file, classification))
            } else {
                otherFiles.append((file, classification))
            }
        }

        let totalNamed = iphoneFiles.count + otherFiles.count
        let padWidth = FileNaming.paddingWidth(forCount: totalNamed)
        var reserved = Set<String>()
        var index = 0

        for item in iphoneFiles + otherFiles {
            if shouldStop() { return }
            let file = item.file
            let classification = item.classification
            index += 1
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let bucket = classification.isIPhoneFolder ? "iPhone" : "Not iPhone"
            var parts = extras.contains(file.path) ? ["Duplicates", bucket] : [bucket]
            parts.append(contentsOf: extraFolderParts(for: file))
            let folder = parts.reduce(file.dir) { ($0 as NSString).appendingPathComponent($1) }
            let dest = FileOps.uniquePath(
                for: (folder as NSString).appendingPathComponent(filename),
                reserved: reserved
            )
            reserved.insert(dest)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun, reserved: reserved)
            if let output = result.outputPath { reserved.insert(output) }
            noteUndo(kind: .moved, from: file.path, result: result)
            results.append(OperationResult(
                path: file.path,
                status: result.status,
                reason: result.reason ?? classification.note,
                outputPath: result.outputPath
            ))
            advanceProgress()
        }
    }

    private func oneMinAdjust(target: [VideoInfo], start: Date, mode: String, ffmpegPath: String) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var reserved = Set<String>()
        var current = start
        var index = 0
        for file in target {
            if shouldStop() { return }
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let planned: String
            if mode == "copies" {
                let dir = (file.dir as NSString).appendingPathComponent("Adjusted")
                planned = (dir as NSString).appendingPathComponent(filename)
            } else {
                planned = (file.dir as NSString).appendingPathComponent(filename)
            }
            let output = FileOps.uniquePath(for: planned, reserved: reserved)
            reserved.insert(output)
            if !dryRun {
                try? FileManager.default.createDirectory(
                    atPath: (output as NSString).deletingLastPathComponent,
                    withIntermediateDirectories: true
                )
            }
            let result: OperationResult
            if dryRun {
                result = OperationResult(
                    path: file.path,
                    status: .success,
                    reason: "Dry-run timestamp → \(output)",
                    outputPath: output
                )
            } else {
                result = await FfmpegOps.adjustTimestamp(
                    filePath: file.path,
                    outputPath: output,
                    creationTime: current,
                    ffmpegPath: ffmpegPath
                )
                if mode != "copies",
                   result.status == .success,
                   output != file.path {
                    try? FileManager.default.removeItem(atPath: file.path)
                }
            }
            if let out = result.outputPath { reserved.insert(out) }
            noteUndo(kind: mode == "copies" ? .createdCopy : .moved, from: file.path, result: result)
            results.append(result)
            advanceProgress()
            if result.status == .cancelled { return }
            current = current.addingTimeInterval(60)
        }
    }

    private func sloMo(target: [VideoInfo], factor: Double, ffmpegPath: String) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var reserved = Set<String>()
        var index = 0
        for file in target {
            if shouldStop() { return }
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            let dir = (file.dir as NSString).appendingPathComponent("SloMo")
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let output = FileOps.uniquePath(
                for: (dir as NSString).appendingPathComponent(filename),
                reserved: reserved
            )
            reserved.insert(output)
            let result: OperationResult
            if dryRun {
                result = OperationResult(
                    path: file.path,
                    status: .success,
                    reason: "Dry-run slo-mo → \(output)",
                    outputPath: output
                )
            } else {
                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                result = await FfmpegOps.sloMo(
                    filePath: file.path,
                    outputPath: output,
                    factor: factor,
                    ffmpegPath: ffmpegPath
                )
            }
            if let out = result.outputPath { reserved.insert(out) }
            noteUndo(kind: .createdCopy, from: file.path, result: result)
            results.append(result)
            advanceProgress()
            if result.status == .cancelled { return }
        }
    }

    private func extraFolderParts(for file: VideoInfo) -> [String] {
        let settings = SettingsStore.shared.settings
        var parts: [String] = []
        if settings.sortByDate, let date = file.creationTime {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            parts.append(formatter.string(from: date))
        }
        if settings.sortByCamera {
            let camera = FileOps.sanitizeFileName(
                [file.make, file.model].filter { !$0.isEmpty }.joined(separator: " ")
            )
            if camera != "file" {
                parts.append(camera)
            }
        }
        return parts
    }

    private func destinationFolder(for file: VideoInfo, duplicateExtra: Bool, gpsCity: String? = nil) -> String {
        var parts: [String] = []
        if duplicateExtra {
            parts.append("Duplicates")
        }
        if let gpsCity {
            parts.append(gpsCity)
        } else {
            switch tool {
            case .vidres, .keepName:
                parts.append(file.resolutionClass)
            case .promax:
                parts.append(file.resolutionClass)
                parts.append(file.orientation.capitalized)
            case .maxvid:
                parts.append(file.resolutionClass)
                parts.append(file.orientation.capitalized)
                parts.append("\(FileNaming.fpsBucket(file.fps))fps")
            case .iphoneSorter, .provid, .oneMin, .slomo, .gps:
                break
            }
        }
        if tool.supportsExtraFolders {
            parts.append(contentsOf: extraFolderParts(for: file))
        }
        return parts.reduce(file.dir) { ($0 as NSString).appendingPathComponent($1) }
    }
}
