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
    @Published var message: String?

    @Published var prefix: String = ""
    @Published var dryRun: Bool = true
    @Published var slomoFactor: Double = 0.5
    @Published var oneMinStart: Date = Date()
    @Published var oneMinMode: String = "copies"

    init(tool: Tool) {
        self.tool = tool
        self.dryRun = AppState.shared.settings.dryRunDefault
    }

    var filteredFiles: [VideoInfo] { files }

    func scan(paths: [String], settings: AppSettings, ffmpegPath: String, ffprobePath: String) async {
        running = true
        progress = (0, 0)
        files = []
        results = []
        var exts = settings.videoExtensions
        if tool.acceptsImages {
            exts = Array(Set(exts + settings.imageExtensions))
        }
        let scanned = await ScannerService.scan(paths: paths, extensions: exts, ffprobePath: ffprobePath) { done, total in
            self.progress = (done, total)
        }
        files = scanned.supported
        results = scanned.unsupported
        let unsupportedCount = scanned.unsupported.count
        if unsupportedCount > 0 {
            message = "Scanned \(scanned.supported.count) files · \(unsupportedCount) unsupported skipped."
        } else {
            message = "Scanned \(scanned.supported.count) files."
        }
        running = false
    }

    func run(settings: AppSettings, ffmpegPath: String?, ffprobePath: String?) async {
        guard let ffmpegPath = ffmpegPath, let _ = ffprobePath else {
            message = "ffmpeg and ffprobe are required."
            return
        }
        running = true
        // Keep any prior unsupported skip results; replace operation results for this run
        let priorSkips = results.filter { $0.status == .skipped }
        results = priorSkips
        defer { running = false }

        let target = files
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

    private func sort(target: [VideoInfo]) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var index = 0
        for file in target {
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
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
        }
    }

    private func rename(target: [VideoInfo], prefix: String) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var index = 0
        for file in target {
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
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
        }
    }

    private func gpsSort(target: [VideoInfo]) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var index = 0
        for file in target {
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                continue
            }
            index += 1
            let folder = (file.dir as NSString).appendingPathComponent(file.hasGPS ? "GPS" : "No-GPS")
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let dest = (folder as NSString).appendingPathComponent(filename)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun)
            results.append(result)
        }
    }

    private func iphoneSort(target: [VideoInfo]) async {
        let ordered = target.sorted { $0.path < $1.path }
        var iphoneFiles: [VideoInfo] = []
        var otherFiles: [VideoInfo] = []

        for file in ordered {
            if let error = file.error {
                results.append(OperationResult(
                    path: file.path,
                    status: .failed,
                    reason: "Metadata read failed: \(error)"
                ))
                continue
            }
            let classification = IPhoneSortLogic.classify(
                hasAppleMake: file.hasAppleMake,
                hasiPhoneModel: file.hasiPhoneModel,
                make: file.make,
                model: file.model
            )
            if classification.isIPhoneFolder {
                iphoneFiles.append(file)
            } else {
                otherFiles.append(file)
            }
        }

        let allNamed = iphoneFiles + otherFiles
        let padWidth = FileNaming.paddingWidth(forCount: allNamed.count)
        var reserved = Set<String>()
        var index = 0

        for file in iphoneFiles {
            let classification = IPhoneSortLogic.classify(
                hasAppleMake: file.hasAppleMake,
                hasiPhoneModel: file.hasiPhoneModel,
                make: file.make,
                model: file.model
            )
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
        }

        for file in otherFiles {
            let classification = IPhoneSortLogic.classify(
                hasAppleMake: file.hasAppleMake,
                hasiPhoneModel: file.hasiPhoneModel,
                make: file.make,
                model: file.model
            )
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
        var reserved = Set<String>()
        for file in target {
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
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
            let safeOutput = uniqueReservedPath(output, reserved: &reserved)
            let result = await FfmpegOps.adjustTimestamp(filePath: file.path, outputPath: safeOutput, creationTime: current, ffmpegPath: ffmpegPath)
            if mode != "copies",
               result.status == .success,
               safeOutput != file.path,
               !dryRun {
                try? FileManager.default.removeItem(atPath: file.path)
            }
            results.append(result)
            current = current.addingTimeInterval(60)
        }
    }

    private func sloMo(target: [VideoInfo], factor: Double, ffmpegPath: String) async {
        let eligible = target.filter { $0.error == nil }
        let padWidth = FileNaming.paddingWidth(forCount: eligible.count)
        var index = 0
        var reserved = Set<String>()
        for file in target {
            if let error = file.error {
                results.append(OperationResult(path: file.path, status: .failed, reason: "Metadata read failed: \(error)"))
                continue
            }
            index += 1
            let dir = (file.dir as NSString).appendingPathComponent("SloMo")
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let filename = FileNaming.standardFileName(for: file, index: index, padWidth: padWidth)
            let output = uniqueReservedPath(
                (dir as NSString).appendingPathComponent(filename),
                reserved: &reserved
            )
            let result = await FfmpegOps.sloMo(filePath: file.path, outputPath: output, factor: factor, ffmpegPath: ffmpegPath)
            results.append(result)
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
