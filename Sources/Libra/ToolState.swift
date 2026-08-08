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

    @Published var prefix: String = ""
    @Published var dryRun: Bool = true
    @Published var slomoFactor: Double = 0.5
    @Published var oneMinStart: Date = Date()
    @Published var oneMinMode: String = "copies"

    private var activeTask: Task<Void, Never>?

    init(tool: Tool) {
        self.tool = tool
        self.dryRun = AppState.shared.settings.dryRunDefault
    }

    var filteredFiles: [VideoInfo] { files }

    func startScan(paths: [String], settings: AppSettings, ffmpegPath: String, ffprobePath: String) {
        guard !running else { return }
        running = true
        cancelling = false
        progress = (0, 0)
        files = []
        results = []
        message = "Finding supported files…"

        activeTask = Task { [weak self] in
            await self?.performScan(paths: paths, settings: settings, ffprobePath: ffprobePath)
        }
    }

    func startRun(settings: AppSettings, ffmpegPath: String?, ffprobePath: String?) {
        guard !running else { return }
        guard let ffmpegPath = ffmpegPath, ffprobePath != nil else {
            message = "ffmpeg and ffprobe are required."
            return
        }

        running = true
        cancelling = false
        let priorSkips = results.filter { $0.status == .skipped }
        results = priorSkips
        message = nil

        activeTask = Task { [weak self] in
            await self?.performRun(ffmpegPath: ffmpegPath)
        }
    }

    func cancelActiveWork() {
        guard running, !cancelling else { return }
        cancelling = true
        message = "Cancelling…"
        activeTask?.cancel()
    }

    private func performScan(paths: [String], settings: AppSettings, ffprobePath: String) async {
        defer {
            running = false
            cancelling = false
            activeTask = nil
        }

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
                }
            }
        )

        files = outcome.supported
        results = outcome.unsupported
        applyScanSummary(outcome)
    }

    private func applyScanSummary(_ outcome: ScanOutcome) {
        let failures = outcome.supported.filter { $0.error != nil }.count
        let warnings = outcome.supported.filter { $0.warning != nil }.count
        let unsupportedCount = outcome.unsupported.count

        switch outcome.terminal {
        case .cancelled:
            message = "Cancelled after \(outcome.completedCount) of \(outcome.discoveredTotal)."
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
            message = parts.joined(separator: " · ") + "."
        }
    }

    private func performRun(ffmpegPath: String) async {
        defer {
            running = false
            cancelling = false
            activeTask = nil
        }

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

        if Task.isCancelled || cancelling {
            message = "Cancelled after \(progress.done) of \(progress.total)."
        } else {
            message = "Finished \(progress.done) of \(progress.total)."
        }
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

    private func sort(target: [VideoInfo]) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var index = 0
        for file in target {
            if shouldStop() { return }
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            let folder = destinationFolder(for: file)
            let filename = FileNaming.standardFileName(
                for: file,
                prefix: namingPrefix(),
                index: index,
                padWidth: padWidth
            )
            let dest = (folder as NSString).appendingPathComponent(filename)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun)
            results.append(result)
            advanceProgress()
        }
    }

    private func rename(target: [VideoInfo], prefix: String) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
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
            let dest = (file.dir as NSString).appendingPathComponent(filename)
            let result = FileOps.renameFile(from: file.path, to: dest, dryRun: dryRun)
            results.append(result)
            advanceProgress()
        }
    }

    private func gpsSort(target: [VideoInfo]) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var index = 0
        for file in target {
            if shouldStop() { return }
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                advanceProgress()
                continue
            }
            index += 1
            let folder = (file.dir as NSString).appendingPathComponent(file.hasGPS ? "GPS" : "No-GPS")
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let dest = (folder as NSString).appendingPathComponent(filename)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun)
            results.append(result)
            advanceProgress()
        }
    }

    private func iphoneSort(target: [VideoInfo]) async {
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

        for item in iphoneFiles {
            if shouldStop() { return }
            let file = item.file
            let classification = item.classification
            index += 1
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let folder = (file.dir as NSString).appendingPathComponent("iPhone")
            var dest = (folder as NSString).appendingPathComponent(filename)
            dest = uniqueReservedPath(dest, reserved: &reserved)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun)
            if let output = result.outputPath {
                reserved.insert(output)
            }
            results.append(OperationResult(
                path: file.path,
                status: result.status,
                reason: result.reason ?? classification.note,
                outputPath: result.outputPath
            ))
            advanceProgress()
        }

        for item in otherFiles {
            if shouldStop() { return }
            let file = item.file
            let classification = item.classification
            index += 1
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let folder = (file.dir as NSString).appendingPathComponent("Not iPhone")
            var dest = (folder as NSString).appendingPathComponent(filename)
            dest = uniqueReservedPath(dest, reserved: &reserved)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun)
            if let output = result.outputPath {
                reserved.insert(output)
            }
            results.append(OperationResult(
                path: file.path,
                status: result.status,
                reason: result.reason ?? classification.note,
                outputPath: result.outputPath
            ))
            advanceProgress()
        }
    }

    private func uniqueReservedPath(_ path: String, reserved: inout Set<String>) -> String {
        var candidate = path
        var counter = 1
        let ext = (path as NSString).pathExtension
        let base = (path as NSString).deletingPathExtension
        while reserved.contains(candidate) || FileManager.default.fileExists(atPath: candidate) {
            if ext.isEmpty {
                candidate = "\(base) (\(counter))"
            } else {
                candidate = "\(base) (\(counter)).\(ext)"
            }
            counter += 1
        }
        reserved.insert(candidate)
        return candidate
    }

    private func oneMinAdjust(target: [VideoInfo], start: Date, mode: String, ffmpegPath: String) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
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
            let output: String
            if mode == "copies" {
                let dir = (file.dir as NSString).appendingPathComponent("Adjusted")
                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                output = (dir as NSString).appendingPathComponent(filename)
            } else {
                output = (file.dir as NSString).appendingPathComponent(filename)
            }
            let result = await FfmpegOps.adjustTimestamp(
                filePath: file.path,
                outputPath: output,
                creationTime: current,
                ffmpegPath: ffmpegPath
            )
            // Never delete the source for cancelled/failed transforms.
            if mode != "copies",
               result.status == .success,
               output != file.path,
               !dryRun {
                try? FileManager.default.removeItem(atPath: file.path)
            }
            results.append(result)
            advanceProgress()
            if result.status == .cancelled { return }
            current = current.addingTimeInterval(60)
        }
    }

    private func sloMo(target: [VideoInfo], factor: Double, ffmpegPath: String) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
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
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let output = (dir as NSString).appendingPathComponent(filename)
            let result = await FfmpegOps.sloMo(
                filePath: file.path,
                outputPath: output,
                factor: factor,
                ffmpegPath: ffmpegPath
            )
            results.append(result)
            advanceProgress()
            if result.status == .cancelled { return }
        }
    }

    private func destinationFolder(for file: VideoInfo) -> String {
        let parts: [String]
        switch tool {
        case .vidres:
            parts = [file.resolutionClass]
        case .promax:
            parts = [file.resolutionClass, file.orientation.capitalized]
        case .maxvid:
            parts = [file.resolutionClass, file.orientation.capitalized, "\(FileNaming.fpsBucket(file.fps))fps"]
        case .keepName:
            parts = [file.resolutionClass]
        case .iphoneSorter, .provid, .oneMin, .slomo, .gps:
            parts = []
        }
        let tail = parts.joined(separator: "/")
        if tail.isEmpty { return file.dir }
        return (file.dir as NSString).appendingPathComponent(tail)
    }
}
