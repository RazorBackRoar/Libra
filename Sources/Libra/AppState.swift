import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var settings = SettingsStore.shared.settings
    @Published var ffmpegPath: String?
    @Published var ffprobePath: String?
    @Published var missingDeps = false
    @Published var depMessage: String? = nil

    private init() {
        resolveDependencies()
    }

    func resolveDependencies() {
        ffmpegPath = resolve(command: "ffmpeg", override: settings.ffmpegPath)
        ffprobePath = resolve(command: "ffprobe", override: settings.ffprobePath)
        missingDeps = (ffmpegPath == nil || ffprobePath == nil)
        if missingDeps {
            depMessage = "ffmpeg and ffprobe are required. Install with: brew install ffmpeg"
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
            _ = try? await ProcessRunner.run(executablePath: "/usr/bin/env", arguments: ["bash", "-c", "brew install ffmpeg"], timeout: 600)
            resolveDependencies()
        }
    }

    var settingsStore: SettingsStore { SettingsStore.shared }
}
