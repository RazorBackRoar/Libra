import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var settings = SettingsStore.shared.settings
    @Published var ffmpegPath: String?
    @Published var missingFfmpeg = false
    @Published var depMessage: String? = nil

    private init() {
        resolveDependencies()
    }

    func resolveDependencies() {
        ffmpegPath = resolve(command: "ffmpeg", override: settings.ffmpegPath)
        missingFfmpeg = ffmpegPath == nil
        depMessage =
            missingFfmpeg
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
            "/usr/bin/\(command)",
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

        guard let brewPath = resolve(command: "brew", override: nil) else {
            let alert = NSAlert()
            alert.messageText = "Homebrew not found"
            alert.informativeText = "Install Homebrew from brew.sh first, then try again."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        depMessage = "Installing ffmpeg with Homebrew…"

        Task {
            do {
                let output = try await ProcessRunner.run(
                    executablePath: brewPath,
                    arguments: ["install", "ffmpeg"],
                    timeout: 600
                )
                resolveDependencies()
                if output.exitCode != 0 {
                    let detail =
                        output.stderr
                        .split(whereSeparator: \.isNewline)
                        .last
                        .map(String.init) ?? ""
                    depMessage =
                        "brew install ffmpeg failed (exit \(output.exitCode))"
                        + (detail.isEmpty ? "." : ": \(detail)")
                }
            } catch {
                depMessage = "brew install ffmpeg failed: \(error.localizedDescription)"
            }
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
