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

    // controls
    @Published var sortMode: SortMode = .maxvid
    @Published var prefix: String = ""
    @Published var dryRun: Bool = true
    @Published var filter4K = true
    @Published var filter1080 = true
    @Published var filter720 = true
    @Published var filterSD = true
    @Published var filterGPS = true
    @Published var filteriPhone = true
    @Published var filterDuplicates = true
    @Published var slomoFactor: Double = 0.5
    @Published var oneMinStart: Date = Date()
    @Published var oneMinMode: String = "copies"

    init(tool: Tool) {
        self.tool = tool
    }

    var filteredFiles: [VideoInfo] {
        files.filter { file in
            if !filter4K && file.resolutionClass == "4K" { return false }
            if !filter1080 && file.resolutionClass == "1080p" { return false }
            if !filter720 && file.resolutionClass == "720p" { return false }
            if !filterSD && file.resolutionClass == "SD" { return false }
            if !filterGPS && file.hasGPS { return false }
            if !filteriPhone && file.isApple { return false }
            return true
        }
    }

    var duplicateGroups: [DuplicateGroup] = []

    func scan(paths: [String], settings: AppSettings, ffmpegPath: String, ffprobePath: String) async {
        running = true
        progress = (0, 0)
        files = []
        results = []
        duplicateGroups = []
        let exts = settings.videoExtensions
        let scanned = await ScannerService.scan(paths: paths, extensions: exts, ffprobePath: ffprobePath) { done, total in
            self.progress = (done, total)
        }
        files = scanned
        message = "Scanned \(scanned.count) files."
        running = false
    }

    func run(settings: AppSettings, ffmpegPath: String?, ffprobePath: String?) async {
        guard let ffmpegPath = ffmpegPath, let _ = ffprobePath else {
            message = "ffmpeg and ffprobe are required."
            return
        }
        running = true
        results = []
        defer { running = false }

        let target = files
        switch tool {
        case .organizer, .vidres, .promax, .maxvid, .keepName:
            await sort(target: target, mode: sortMode, prefix: prefix, keepName: tool == .keepName)
        case .provid:
            await rename(target: target, prefix: prefix)
        case .reencode:
            results = target.filter { $0.isReencodeCandidate }.map {
                OperationResult(path: $0.path, status: .success, reason: "Re-encode candidate (\($0.codec) / \($0.container))", outputPath: nil)
            }
        case .duplicates:
            let groups = await Hashing.findDuplicates(files: target) { done, total in
                self.progress = (done, total)
            }
            duplicateGroups = groups
            results = groups.flatMap { group in
                group.files.map { OperationResult(path: $0.path, status: .success, reason: "MD5 \(group.hash)", outputPath: nil) }
            }
        case .gps:
            await gpsSort(target: target)
        case .codec:
            results = target.map {
                OperationResult(path: $0.path, status: .success, reason: "\($0.codec) / \($0.container) / \($0.resolutionClass) / \($0.fps) fps", outputPath: nil)
            }
        case .oneMin:
            await oneMinAdjust(target: target, start: oneMinStart, mode: oneMinMode, ffmpegPath: ffmpegPath)
        case .slomo:
            await sloMo(target: target, factor: slomoFactor, ffmpegPath: ffmpegPath)
        }
    }

    private func sort(target: [VideoInfo], mode: SortMode, prefix: String, keepName: Bool) async {
        for file in target {
            let folder = destinationFolder(for: file, mode: mode, prefix: prefix)
            let filename = keepName ? file.name + "." + file.ext : folderNamePrefix(prefix: prefix, file: file) + "." + file.ext
            let dest = (folder as NSString).appendingPathComponent(filename)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun)
            results.append(result)
        }
    }

    private func rename(target: [VideoInfo], prefix: String) async {
        for file in target {
            let newName = prefix.isEmpty ? file.name : "\(prefix) \(file.name)"
            let dest = (file.dir as NSString).appendingPathComponent(newName + "." + file.ext)
            let result = FileOps.renameFile(from: file.path, to: dest, dryRun: dryRun)
            results.append(result)
        }
    }

    private func gpsSort(target: [VideoInfo]) async {
        for file in target {
            let folder = (file.dir as NSString).appendingPathComponent(file.hasGPS ? "GPS" : "No-GPS")
            let dest = (folder as NSString).appendingPathComponent(file.name + "." + file.ext)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun)
            results.append(result)
        }
    }

    private func oneMinAdjust(target: [VideoInfo], start: Date, mode: String, ffmpegPath: String) async {
        var current = start
        for file in target {
            let output: String
            if mode == "copies" {
                let dir = (file.dir as NSString).appendingPathComponent("Adjusted")
                output = (dir as NSString).appendingPathComponent(file.name + "_adjusted." + file.ext)
            } else {
                output = file.path
            }
            let result = await FfmpegOps.adjustTimestamp(filePath: file.path, outputPath: output, creationTime: current, ffmpegPath: ffmpegPath)
            results.append(result)
            current = current.addingTimeInterval(60)
        }
    }

    private func sloMo(target: [VideoInfo], factor: Double, ffmpegPath: String) async {
        for file in target {
            let dir = (file.dir as NSString).appendingPathComponent("SloMo")
            let output = (dir as NSString).appendingPathComponent(file.name + "_slow." + file.ext)
            let result = await FfmpegOps.sloMo(filePath: file.path, outputPath: output, factor: factor, ffmpegPath: ffmpegPath)
            results.append(result)
        }
    }

    private func destinationFolder(for file: VideoInfo, mode: SortMode, prefix: String) -> String {
        var parts: [String] = []
        switch mode {
        case .provid:
            parts = [file.dir]
        case .vidres:
            parts = [file.resolutionClass]
        case .promax:
            parts = [file.resolutionClass, file.orientation.capitalized]
        case .maxvid:
            parts = [file.resolutionClass, file.orientation.capitalized, "\(Int(file.fps))fps"]
        case .keepName:
            parts = [file.resolutionClass]
        }
        let tail = parts.joined(separator: "/")
        return (file.dir as NSString).appendingPathComponent(tail)
    }

    private func folderNamePrefix(prefix: String, file: VideoInfo) -> String {
        if prefix.isEmpty { return file.name }
        return "\(prefix) \(file.name)"
    }
}
