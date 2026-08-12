import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var settings = SettingsStore.shared.settings
    @Published var ffmpegPath: String?
    @Published var ffprobePath: String?
    @Published var missingFfmpeg = false
    @Published var missingFfprobe = false
    @Published var depMessage: String? = nil

    var missingScanTools: Bool { missingFfprobe }

    private init() {
        resolveDependencies()
    }

    func resolveDependencies() {
        ffmpegPath = resolve(command: "ffmpeg", override: settings.ffmpegPath)
        ffprobePath = resolve(command: "ffprobe", override: settings.ffprobePath)
        missingFfmpeg = ffmpegPath == nil
        missingFfprobe = ffprobePath == nil
        if missingFfprobe {
            depMessage = "ffprobe is required to scan media. Install with: brew install ffmpeg"
        } else if missingFfmpeg {
            depMessage = "ffmpeg is required for Slo-Mo and 1MinVid. Install with: brew install ffmpeg"
        } else {
            depMessage = nil
        }
    }

    private func resolve(command: String, override: String?) -> String? {
        if let override = override, FileManager.default.isExecutableFile(atPath: override) {
            return override
        }
        let candidates = [
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
            "/usr/bin/\(command)"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    func installDependencies() {
        Task {
            let brewPath = resolve(command: "brew", override: nil) ?? "/opt/homebrew/bin/brew"
            _ = try? await ProcessRunner.run(executablePath: brewPath, arguments: ["install", "ffmpeg"], timeout: 600)
            resolveDependencies()
        }
    }

    func rememberLastFolder(from paths: [String]) {
        guard let first = paths.first else { return }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: first, isDirectory: &isDir)
        let folder = isDir.boolValue ? first : (first as NSString).deletingLastPathComponent
        SettingsStore.shared.update { $0.lastFolder = folder }
        settings.lastFolder = folder
    }

    var settingsStore: SettingsStore { SettingsStore.shared }
}
