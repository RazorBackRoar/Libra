import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var ffmpegPath: String = ""
    @State private var ffprobePath: String = ""
    @State private var extensions: String = ""

    var body: some View {
        Form {
            Section("ffmpeg / ffprobe") {
                TextField("ffmpeg path", text: $ffmpegPath)
                TextField("ffprobe path", text: $ffprobePath)
                Button("Auto-detect from Homebrew") {
                    detect()
                }
            }
            Section("File Extensions") {
                TextField("mp4, mov, m4v, …", text: $extensions)
            }
            Section("Defaults") {
                Toggle("Dry-run by default", isOn: $store.settings.dryRunDefault)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 260)
        .onAppear {
            ffmpegPath = store.settings.ffmpegPath ?? ""
            ffprobePath = store.settings.ffprobePath ?? ""
            extensions = store.settings.videoExtensions.joined(separator: ", ")
        }
        .onChange(of: ffmpegPath) { update() }
        .onChange(of: ffprobePath) { update() }
        .onChange(of: extensions) { update() }
        .onChange(of: store.settings.dryRunDefault) { store.save() }
    }

    private func detect() {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffprobe",
            "/usr/local/bin/ffprobe"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                if path.contains("ffmpeg") { ffmpegPath = path }
                if path.contains("ffprobe") { ffprobePath = path }
            }
        }
    }

    private func update() {
        store.update { settings in
            settings.ffmpegPath = ffmpegPath.isEmpty ? nil : ffmpegPath
            settings.ffprobePath = ffprobePath.isEmpty ? nil : ffprobePath
            settings.videoExtensions = extensions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        }
    }
}
