import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var settings = SettingsStore.shared.settings
    @Published var ffmpegPath: String?
    @Published var ffprobePath: String?
    @Published var missingFfmpeg = false
    @Published var missingFfprobe = false
    @Published var depMessage: String? = nil

    private init() {
        resolveDependencies()
    }

    func resolveDependencies() {
        ffmpegPath = resolve(command: "ffmpeg", override: settings.ffmpegPath)
        ffprobePath = resolve(command: "ffprobe", override: settings.ffprobePath)
        missingFfmpeg = ffmpegPath == nil
        missingFfprobe = ffprobePath == nil
        depMessage = missingFfmpeg
            ? "Needs ffmpeg to create transformed media."
            : nil
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
        let alert = NSAlert()
        alert.messageText = "Install ffmpeg?"
        alert.informativeText = """
        Libra will run Homebrew:

        brew install ffmpeg

        ffmpeg is only needed for Slo-Mo and 1-Min-Adjuster. Organize tools do not require it.
        """
        alert.addButton(withTitle: "Install ffmpeg…")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

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
