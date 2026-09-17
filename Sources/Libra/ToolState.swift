import Foundation
import SwiftUI

@MainActor
final class ToolState: ObservableObject {
    let tool: Tool

    @Published var files: [VideoInfo] = []
    @Published var results: [OperationResult] = []
    @Published var progress: (done: Int, total: Int) = (0, 0)
    @Published var progressName: String = ""
    @Published var running = false
    @Published var cancelling = false
    @Published var message: String?
    @Published var recap: String?
    @Published var undoRecords: [UndoRecord] = []
    @Published var photos: [VideoInfo] = []

    @Published var prefix: String = ""
    @Published var dryRun: Bool = true
    @Published var slomoFactor: Double = 0.5
    @Published var oneMinStart: Date = Date()
    @Published var oneMinMode: String = "copies"
    @Published var filenameStyle: FilenameStyle
    @Published var folderDepth: FolderDepth

    private var activeTask: Task<Void, Never>?
    private var rerunTask: Task<Void, Never>?
    private var pendingUndo: [UndoRecord] = []
    private var previewPass = true
    private var reportThisPass = true
    private var unresolvedLocationCount = 0
    /// file.path → resolved city folder, filled by `resolveGPSCityNames` and
    /// reused by Write so Preview and Write can't disagree.
    private var gpsCityByPath: [String: String] = [:]
    /// cluster id → place name, persisted across scans — same spot never
    /// geocodes twice in one session.
    private var gpsPlaceCache: [String: String] = [:]
    /// file.path → place name for map labels, filled by the explicit
    /// "Resolve city names" action. Read-only to views; empty until resolved.
    @Published private(set) var gpsPlaceByPath: [String: String] = [:]
    @Published private(set) var gpsCitiesResolved = false

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    var confirmDiscover: (@Sendable (Int) async -> Bool)?

    var canUndo: Bool { !undoRecords.isEmpty && !running }

    var canWrite: Bool {
        !running && !files.isEmpty && !dryRun
            && (!tool.needsFfmpeg || AppState.shared.ffmpegPath != nil)
            && gpsWriteBlockReason == nil
    }

    /// When set, the action button stays disabled — coordinate-bearing files
    /// must be resolved to city folders by the explicit action first. Batches
    /// with no coordinates at all write straight to No-GPS/ and never need it.
    var gpsWriteBlockReason: String? {
        guard tool == .gps, files.contains(where: \.hasCoordinates), !gpsCitiesResolved
        else { return nil }
        return "Resolve city names first — organizing stays off until locations are named."
    }

    /// The verb the action button performs for this tool — "Write" means
    /// nothing; the button names the operation itself.
    var writeActionVerb: String {
        switch tool {
        case .slomo: return "Make"
        case .oneMin: return "Adjust"
        case .gps: return "Organize"
        case .iphoneSorter: return "Sort"
        case .photoSweep: return "Move"
        default: return "Rename"
        }
    }

    var writeButtonTitle: String {
        let count = files.filter { $0.error == nil }.count
        let plural = count == 1 ? "" : "s"
        switch tool {
        case .slomo: return "Make \(count) Slo-Mo"
        case .oneMin: return "Adjust \(count) Timestamp\(plural)"
        case .gps: return "Organize \(count) Video\(plural)"
        case .iphoneSorter: return "Sort \(count) Video\(plural)"
        case .photoSweep: return "Move \(count) Photo\(plural)"
        default: return "Rename \(count) Video\(plural)"
        }
    }

    var showsExtraFolderToggles: Bool {
        if tool == .gps || tool == .iphoneSorter { return true }
        return tool.isSortRenameFamily && folderDepth != .none
    }

    var previewLiveCaption: String {
        if dryRun { return "Preview only — nothing will be changed." }
        switch tool {
        case .slomo:
            return "Live — Make Slo-Mo will create slowed copies."
        case .oneMin:
            return oneMinMode == "copies"
                ? "Live — Adjust will create timestamped copies."
                : "Live — Adjust will change originals."
        default:
            return "Live — the action button renames, moves, or copies files."
        }
    }

    init(tool: Tool) {
        self.tool = tool
        self.filenameStyle = OrganizeLayout.filenameStyle(for: tool)
        self.folderDepth = OrganizeLayout.folderDepth(for: tool)
        let settings = SettingsStore.shared.settings
        self.dryRun = settings.dryRunDefault
        if tool.isSortRenameFamily, filenameStyle == .libraFormat {
            self.prefix = settings.defaultPrefix
        }
    }

    var filteredFiles: [VideoInfo] { files }

    func startScan(paths: [String], settings: AppSettings) {
        guard !running else { return }
        rerunTask?.cancel()
        running = true
        cancelling = false
        progress = (0, 0)
        progressName = ""
        files = []
        photos = []
        results = []
        recap = nil
        undoRecords = []
        gpsCityByPath = [:]
        gpsPlaceByPath = [:]
        gpsCitiesResolved = false
        unresolvedLocationCount = 0
        message = "Finding supported videos…"
        AppState.shared.rememberLastFolder(from: paths)

        activeTask = Task { [weak self] in
            guard let self else { return }
            let shouldContinue = await self.performScan(paths: paths, settings: settings)
            guard shouldContinue else {
                self.finishIdle()
                return
            }
            await self.continueAfterScan()
        }
    }

    func startPreview(writeReport: Bool = true) {
        guard !files.isEmpty, !running else { return }
        running = true
        cancelling = false
        let priorSkips = results.filter { $0.status == .skipped }
        results = priorSkips
        recap = nil
        message = "Previewing…"
        previewPass = true
        reportThisPass = writeReport
        activeTask = Task { [weak self] in
            await self?.performRun(ffmpegPath: AppState.shared.ffmpegPath ?? "")
        }
    }

    func startWrite(settings: AppSettings, ffmpegPath: String?) {
        guard !running, !files.isEmpty else { return }
        if dryRun {
            message = "Turn off Preview only to enable the action."
            return
        }
        if tool.needsFfmpeg, (ffmpegPath ?? AppState.shared.ffmpegPath) == nil {
            message = "Needs ffmpeg to create transformed media."
            return
        }
        if let blocked = gpsWriteBlockReason {
            message = blocked
            return
        }

        running = true
        cancelling = false
        let priorSkips = results.filter { $0.status == .skipped }
        results = priorSkips
        recap = nil
        message = "Writing…"
        previewPass = false
        let resolvedFfmpeg = ffmpegPath ?? AppState.shared.ffmpegPath ?? ""
        activeTask = Task { [weak self] in
            await self?.performRun(ffmpegPath: resolvedFfmpeg)
        }
    }

    /// Re-preview after Prefix / Preview / tool options change (debounced).
    /// Never writes — even when Preview only is off.
    func scheduleRerunAfterOptionsChange() {
        guard !files.isEmpty, !running else { return }
        rerunTask?.cancel()
        rerunTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard let self, !Task.isCancelled else { return }
            self.startPreview(writeReport: false)
        }
    }

    func cancelActiveWork() {
        guard running, !cancelling else { return }
        cancelling = true
        message = "Cancelling…"
        rerunTask?.cancel()
        activeTask?.cancel()
    }

    func movePhotosOut(to destDir: String) async -> String? {
        guard !photos.isEmpty, !running else { return nil }
        if ScanSafety.destinationIsInsideSource(
            dest: destDir, sourceRoot: SettingsStore.shared.settings.lastFolder)
        {
            let reason = "Choose a folder outside the scanned video folder."
            recap = reason
            message = reason
            return reason
        }
        running = true
        let dry = dryRun
        let toMove = photos
        let moved = await Task.detached {
            PhotoMover.move(toMove, to: destDir, dryRun: dry)
        }.value
        running = false
        results.append(contentsOf: moved)
        for result in moved { logFailure(result) }
        let ok = moved.filter { $0.status == .success }.count
        if dry {
            recap = "Preview: \(ok) photo\(ok == 1 ? "" : "s") would move out."
        } else {
            recap = "Moved \(ok) photo\(ok == 1 ? "" : "s") out of the video folders."
            let movedPaths = Set(moved.filter { $0.status == .success }.map(\.path))
            photos.removeAll { movedPaths.contains($0.path) }
            let records = moved.compactMap { result -> UndoRecord? in
                guard result.status == .success, let output = result.outputPath,
                    output != result.path
                else { return nil }
                return UndoRecord(kind: .moved, originalPath: result.path, resultPath: output)
            }
            if !records.isEmpty {
                undoRecords = records
            }
        }
        message = recap
        return nil
    }

    func undoLastRun() {
        guard canUndo else { return }
        running = true
        message = "Undoing last run…"
        let records = undoRecords
        undoRecords = []
        Task {
            let outcome = await Task.detached { UndoApply.apply(records) }.value
            running = false
            recap =
                outcome.failed == 0
                ? "Undid \(outcome.restored) change\(outcome.restored == 1 ? "" : "s")."
                : "Undo finished: \(outcome.restored) restored, \(outcome.failed) failed."
            message = recap
            Log.shared.info(recap ?? "Undo finished", scope: "run")
        }
    }

    private func continueAfterScan() async {
        if files.isEmpty {
            recap =
                photos.isEmpty
                ? "No videos found."
                : "No videos. \(photos.count) photo\(photos.count == 1 ? "" : "s") are in the Photos tab — move them out."
            message = recap
            finishIdle()
            return
        }
        if tool.needsFfmpeg, AppState.shared.ffmpegPath == nil {
            message = "Needs ffmpeg to create transformed media."
            finishIdle()
            return
        }
        let priorSkips = results.filter { $0.status == .skipped }
        results = priorSkips
        previewPass = true
        reportThisPass = true
        message = "Previewing…"
        await performRun(ffmpegPath: AppState.shared.ffmpegPath ?? "")
    }

    private func finishIdle() {
        running = false
        cancelling = false
        progressName = ""
        activeTask = nil
        confirmDiscover = nil
    }

    /// Returns `true` when the tool should auto-preview after this scan.
    private func performScan(paths: [String], settings: AppSettings) async -> Bool {
        let imageExts = Set(settings.imageExtensions.map { $0.lowercased() })
        let exts = Array(Set(settings.videoExtensions + settings.imageExtensions))

        let progressGate = ProgressGate()
        let outcome = await ScannerService.scan(
            paths: paths,
            extensions: exts,
            progress: { done, total in
                guard progressGate.shouldFire(done: done, total: total) else { return }
                await MainActor.run {
                    self.progress = (done, total)
                    if total > 0, self.message == "Finding supported videos…" {
                        self.message = nil
                    }
                }
            },
            confirmDiscover: confirmDiscover
        )

        let videos = outcome.supported.filter { !imageExts.contains($0.ext.lowercased()) }
        photos = outcome.supported.filter { imageExts.contains($0.ext.lowercased()) }
        files = videos
        results = outcome.unsupported
        applyScanSummary(outcome)

        return outcome.terminal == .completed
            && (!videos.isEmpty || !photos.isEmpty)
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
            var parts: [String] = ["Scanned \(files.count) video\(files.count == 1 ? "" : "s")"]
            if !photos.isEmpty {
                parts.append("\(photos.count) photo\(photos.count == 1 ? "" : "s") set aside")
            }
            if failures > 0 {
                parts.append("\(failures) metadata failure\(failures == 1 ? "" : "s")")
                Log.shared.warn(
                    "Scan: \(failures) metadata failure(s), e.g. \(outcome.supported.first { $0.error != nil }?.error ?? "unknown")",
                    scope: "scan")
            }
            if warnings > 0 {
                parts.append("\(warnings) metadata warning\(warnings == 1 ? "" : "s")")
            }
            if unsupportedCount > 0 {
                parts.append("\(unsupportedCount) unsupported skipped")
            }
            if dupes > 0 {
                parts.append(
                    "\(dupes) likely duplicate\(dupes == 1 ? "" : "s") (same size, duration, format)"
                )
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
        progressName = ""
        if !previewPass {
            Log.shared.info("Write \(tool.rawValue) — \(target.count) videos", scope: "run")
        }

        switch tool {
        case .provid, .vidres, .promax, .maxvid, .keepName:
            if folderDepth == .none {
                await rename(target: target, prefix: namingPrefix())
            } else {
                await sort(target: target)
            }
        case .gps:
            await gpsSort(target: target)
        case .iphoneSorter:
            await iphoneSort(target: target)
        case .oneMin:
            await oneMinAdjust(
                target: target, start: oneMinStart, mode: oneMinMode, ffmpegPath: ffmpegPath)
        case .slomo:
            await sloMo(target: target, factor: slomoFactor, ffmpegPath: ffmpegPath)
        case .photoSweep:
            break
        }

        let runResults = Array(results.dropFirst(priorCount))
        applyRunRecap(runResults)
        if !previewPass, !pendingUndo.isEmpty {
            undoRecords = pendingUndo
        }
        pendingUndo = []
    }

    private func applyRunRecap(_ runResults: [OperationResult]) {
        let success = runResults.filter { $0.status == .success }.count
        let failed = runResults.filter { $0.status == .failed }.count
        let skipped = runResults.filter { $0.status == .skipped }.count
        var summary = RunRecap.summary(
            previewPass: previewPass,
            cancelled: Task.isCancelled || cancelling,
            success: success,
            failed: failed,
            skipped: skipped,
            done: progress.done,
            total: progress.total
        )
        if previewPass, tool == .gps {
            if gpsCitiesResolved, unresolvedLocationCount > 0 {
                summary +=
                    " \(unresolvedLocationCount) location\(unresolvedLocationCount == 1 ? "" : "s") could not be named — filed under GPS."
            } else if !gpsCitiesResolved {
                summary += " Preview shows GPS/ — “Resolve city names” shows exact folders."
            }
        }
        if !previewPass, tool == .gps, unresolvedLocationCount > 0 {
            summary +=
                " \(unresolvedLocationCount) location\(unresolvedLocationCount == 1 ? "" : "s") could not be named — filed under GPS."
            Log.shared.warn(
                "Geocode unresolved for \(unresolvedLocationCount) cluster(s)", scope: "run")
        }
        if previewPass, reportThisPass,
            let reportURL = DryRunReport.write(tool: tool, results: runResults)
        {
            summary += " Report: \(reportURL.lastPathComponent)"
        }
        recap = summary
        message = summary
        if !previewPass {
            Log.shared.info(summary, scope: "run")
        }
    }

    private var usesPrefixField: Bool {
        tool.isSortRenameFamily && filenameStyle == .libraFormat
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
        guard !previewPass, result.status == .success, let output = result.outputPath,
            output != from
        else { return }
        pendingUndo.append(UndoRecord(kind: kind, originalPath: from, resultPath: output))
    }

    private func keepNameFileName(for file: VideoInfo) -> String {
        let stem = FileOps.sanitizeFileName(file.name)
        return "\(stem).\(file.ext.lowercased())"
    }

    private func commitMove(
        from: String,
        planned: String,
        reserved: inout Set<String>,
        kind: UndoRecord.Kind = .moved
    ) async -> OperationResult {
        progressName = (from as NSString).lastPathComponent
        let dry = previewPass
        let root =
            SettingsStore.shared.settings.lastFolder ?? (from as NSString).deletingLastPathComponent
        // [reserved] keeps the set alive only for the task's duration, so the
        // insert below mutates in place instead of copy-on-writing per file.
        let result = await Task.detached { [reserved] in
            FileOps.moveFile(
                from: from, to: planned, dryRun: dry, reserved: reserved, withinRoot: root)
        }.value
        if let output = result.outputPath { reserved.insert(output) }
        noteUndo(kind: kind, from: from, result: result)
        logFailure(result)
        return result
    }

    private func logFailure(_ result: OperationResult) {
        guard result.status == .failed else { return }
        let name = (result.path as NSString).lastPathComponent
        Log.shared.warn("\(name): \(result.reason ?? "unknown error")", scope: "run")
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
                results.append(
                    OperationResult(
                        path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            let folder = destinationFolder(for: file, duplicateExtra: extras.contains(file.path))
            let filename =
                filenameStyle == .keepOriginal
                ? keepNameFileName(for: file)
                : FileNaming.standardFileName(
                    for: file,
                    prefix: namingPrefix(),
                    index: index,
                    padWidth: padWidth
                )
            let planned = (folder as NSString).appendingPathComponent(filename)
            let result = await commitMove(from: file.path, planned: planned, reserved: &reserved)
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
                results.append(
                    OperationResult(
                        path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            let filename =
                filenameStyle == .keepOriginal
                ? keepNameFileName(for: file)
                : FileNaming.standardFileName(
                    for: file,
                    prefix: prefix,
                    index: index,
                    padWidth: padWidth
                )
            let planned = (file.dir as NSString).appendingPathComponent(filename)
            let result = await commitMove(from: file.path, planned: planned, reserved: &reserved)
            results.append(result)
            advanceProgress()
        }
    }

    /// One geocode pass over the coordinate clusters in `files`. Returns a
    /// file.path → city-folder map for Preview/Write, a file.path → place-name
    /// map for map labels, and how many files' locations could not be named.
    /// Internal (not private) so tests can drive it with a stubbed
    /// `GPSGeocoder.resolver`.
    @discardableResult
    func geocodeGPSClusters(files: [VideoInfo]) async
        -> (byPath: [String: String], names: [String: String], unresolved: Int)
    {
        var clusters = GPSMapClustering.cluster(files: files)
        for index in clusters.indices {
            if Task.isCancelled || cancelling { return ([:], [:], 0) }
            if let cached = gpsPlaceCache[clusters[index].id] {
                clusters[index].placeName = cached
                continue
            }
            clusters[index].placeName = await GPSGeocoder.reverseGeocode(
                latitude: clusters[index].latitude,
                longitude: clusters[index].longitude
            )
            if let name = clusters[index].placeName {
                gpsPlaceCache[clusters[index].id] = name
            }
            // Be gentle with Apple's geocoder.
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        guard !Task.isCancelled, !cancelling else { return ([:], [:], 0) }
        clusters = GPSMapClustering.mergeByPlaceName(clusters)
        var byPath: [String: String] = [:]
        var names: [String: String] = [:]
        var unresolved = 0
        for cluster in clusters {
            if cluster.placeName == nil { unresolved += cluster.files.count }
            let folder = GPSGeocoder.folderName(for: cluster.placeName)
            for file in cluster.files {
                byPath[file.path] = folder
                if let place = cluster.placeName {
                    names[file.path] = place
                }
            }
        }
        return (byPath, names, unresolved)
    }

    /// Explicit user action: geocode now so Preview shows the exact city
    /// folders Write will use. Cached — Write never re-geocodes.
    func resolveGPSCityNames() {
        guard tool == .gps, !running, !files.isEmpty, !gpsCitiesResolved else { return }
        running = true
        cancelling = false
        message = "Resolving city names…"
        activeTask = Task { [weak self] in
            guard let self else { return }
            let outcome = await self.geocodeGPSClusters(files: self.files)
            guard !Task.isCancelled, !self.cancelling else {
                self.finishIdle()
                return
            }
            self.gpsCityByPath = outcome.byPath
            self.gpsPlaceByPath = outcome.names
            self.unresolvedLocationCount = outcome.unresolved
            self.gpsCitiesResolved = true
            // Re-run the preview so rows show the resolved folders.
            self.previewPass = true
            self.reportThisPass = false
            await self.performRun(ffmpegPath: "")
        }
    }

    private func gpsSort(target: [VideoInfo]) async {
        let extras = DuplicateDetector.extraPaths(in: target)
        // Only the explicit "Resolve city names" cache feeds destinations —
        // Write never geocodes inline (gpsWriteBlockReason gates it).
        let cityByPath = gpsCityByPath

        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var reserved = Set<String>()
        var index = 0
        for file in target {
            if shouldStop() { return }
            if let error = file.error {
                results.append(
                    OperationResult(
                        path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
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
            let folder = destinationFolder(
                for: file, duplicateExtra: extras.contains(file.path), gpsCity: city)
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let planned = (folder as NSString).appendingPathComponent(filename)
            let result = await commitMove(from: file.path, planned: planned, reserved: &reserved)
            results.append(result)
            advanceProgress()
        }
    }

    private func iphoneSort(target: [VideoInfo]) async {
        let extras = DuplicateDetector.extraPaths(in: target)
        let ordered = target.sorted { $0.path < $1.path }
        typealias ClassifiedFile = (file: VideoInfo, classification: IPhoneSortLogic.Classification)
        var iphoneFiles: [ClassifiedFile] = []
        var otherAppleFiles: [ClassifiedFile] = []
        var notAppleFiles: [ClassifiedFile] = []

        for file in ordered {
            if shouldStop() { return }
            if let error = file.error {
                results.append(
                    OperationResult(
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
            switch classification.folder {
            case .iPhone:
                iphoneFiles.append((file, classification))
            case .otherApple:
                otherAppleFiles.append((file, classification))
            case .notApple:
                notAppleFiles.append((file, classification))
            }
        }

        let totalNamed = iphoneFiles.count + otherAppleFiles.count + notAppleFiles.count
        let padWidth = FileNaming.paddingWidth(forCount: totalNamed)
        var reserved = Set<String>()
        var index = 0

        for item in iphoneFiles + otherAppleFiles + notAppleFiles {
            if shouldStop() { return }
            let file = item.file
            let classification = item.classification
            index += 1
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            var parts: [String] = []
            if SettingsStore.shared.settings.sortDuplicatesIntoFolder, extras.contains(file.path) {
                parts.append("Duplicates")
            }
            parts.append(classification.folder.rawValue)
            if showsExtraFolderToggles {
                parts.append(contentsOf: extraFolderParts(for: file))
            }
            let folder = parts.reduce(file.dir) { ($0 as NSString).appendingPathComponent($1) }
            let planned = (folder as NSString).appendingPathComponent(filename)
            let result = await commitMove(from: file.path, planned: planned, reserved: &reserved)
            results.append(
                OperationResult(
                    path: file.path,
                    status: result.status,
                    reason: result.reason ?? classification.note,
                    outputPath: result.outputPath
                ))
            advanceProgress()
        }
    }

    private func oneMinAdjust(target: [VideoInfo], start: Date, mode: String, ffmpegPath: String)
        async
    {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var reserved = Set<String>()
        var current = start
        var index = 0
        for file in target {
            if shouldStop() { return }
            if let error = file.error {
                results.append(
                    OperationResult(
                        path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            progressName = "\(file.name).\(file.ext)"
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
            let result: OperationResult
            if previewPass {
                result = OperationResult(
                    path: file.path,
                    status: .success,
                    reason: "Dry-run timestamp → \(output)",
                    outputPath: output
                )
            } else {
                var written = await FfmpegOps.adjustTimestamp(
                    filePath: file.path,
                    outputPath: output,
                    creationTime: current,
                    ffmpegPath: ffmpegPath,
                    durationSec: file.durationSec,
                    withinRoot: SettingsStore.shared.settings.lastFolder ?? file.dir
                )
                if mode != "copies",
                    written.status == .success,
                    output != file.path
                {
                    let removed = FileOps.trashFile(file.path, dryRun: false)
                    if removed.status != .success {
                        written = OperationResult(
                            path: file.path,
                            status: .failed,
                            reason:
                                "Wrote \(output) but could not move original to Trash: \(removed.reason ?? "unknown error")",
                            outputPath: output
                        )
                    } else if let trashPath = removed.outputPath {
                        // In-place runs record two halves: restore the original
                        // from its Trash location, and remove the adjusted copy.
                        pendingUndo.append(
                            UndoRecord(
                                kind: .trashedOriginal,
                                originalPath: file.path,
                                resultPath: trashPath))
                    }
                }
                result = written
            }
            if let out = result.outputPath { reserved.insert(out) }
            // Both modes produce a new output file — undo removes it via Trash.
            noteUndo(kind: .createdCopy, from: file.path, result: result)
            logFailure(result)
            results.append(result)
            advanceProgress()
            if result.status == .cancelled { return }
            current = current.addingTimeInterval(60)
        }
    }

    private func sloMo(target: [VideoInfo], factor: Double, ffmpegPath: String) async {
        let keepAudio = SettingsStore.shared.settings.sloMoKeepAudio
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var reserved = Set<String>()
        var index = 0
        for file in target {
            if shouldStop() { return }
            if let error = file.error {
                results.append(
                    OperationResult(
                        path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            progressName = "Slowing \(file.name).\(file.ext)…"
            let dir = (file.dir as NSString).appendingPathComponent("SloMo")
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let output = FileOps.uniquePath(
                for: (dir as NSString).appendingPathComponent(filename),
                reserved: reserved
            )
            reserved.insert(output)
            let result: OperationResult
            if previewPass {
                result = OperationResult(
                    path: file.path,
                    status: .success,
                    reason: "Dry-run slo-mo → \(output)",
                    outputPath: output
                )
            } else {
                result = await FfmpegOps.sloMo(
                    filePath: file.path,
                    outputPath: output,
                    factor: factor,
                    ffmpegPath: ffmpegPath,
                    durationSec: file.durationSec,
                    withinRoot: SettingsStore.shared.settings.lastFolder ?? file.dir,
                    keepAudio: keepAudio,
                    hasAudio: file.audioCodec != nil
                )
            }
            if let out = result.outputPath { reserved.insert(out) }
            noteUndo(kind: .createdCopy, from: file.path, result: result)
            logFailure(result)
            results.append(result)
            advanceProgress()
            if result.status == .cancelled { return }
        }
    }

    private func extraFolderParts(for file: VideoInfo) -> [String] {
        let settings = SettingsStore.shared.settings
        var parts: [String] = []
        if settings.sortByDate, let date = file.creationTime {
            parts.append(Self.dayFormatter.string(from: date))
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

    private func destinationFolder(
        for file: VideoInfo, duplicateExtra: Bool, gpsCity: String? = nil
    ) -> String {
        var parts: [String] = []
        if SettingsStore.shared.settings.sortDuplicatesIntoFolder, duplicateExtra {
            parts.append("Duplicates")
        }
        if let gpsCity {
            parts.append(gpsCity)
        } else if tool.isSortRenameFamily {
            parts.append(
                contentsOf: OrganizeLayout.folderComponents(
                    depth: folderDepth,
                    resolutionClass: file.resolutionClass,
                    orientation: file.orientation,
                    fpsBucket: FileNaming.fpsBucket(file.fps)
                ))
        }
        if showsExtraFolderToggles {
            parts.append(contentsOf: extraFolderParts(for: file))
        }
        return parts.reduce(file.dir) { ($0 as NSString).appendingPathComponent($1) }
    }
}

/// Throttles scan progress hops to ~10 Hz; the final update always passes.
/// Scan progress arrives serially on the dequeue loop, so no locking is needed.
private final class ProgressGate: @unchecked Sendable {
    private var lastFire: CFAbsoluteTime = 0

    func shouldFire(done: Int, total: Int) -> Bool {
        if done >= total { return true }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFire >= 0.1 else { return false }
        lastFire = now
        return true
    }
}
