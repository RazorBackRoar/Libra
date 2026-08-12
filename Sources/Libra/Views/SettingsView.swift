import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var ffmpegPath: String = ""
    @State private var ffprobePath: String = ""
    @State private var extensions: String = ""
    @State private var defaultPrefix: String = ""

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
                TextField("Default prefix", text: $defaultPrefix)
                Toggle("Date folders", isOn: $store.settings.sortByDate)
                Toggle("Camera folders", isOn: $store.settings.sortByCamera)
            }
            Section("Last folder") {
                Text(store.settings.lastFolder ?? "None yet")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460, height: 420)
        .onAppear {
            ffmpegPath = store.settings.ffmpegPath ?? ""
            ffprobePath = store.settings.ffprobePath ?? ""
            extensions = store.settings.videoExtensions.joined(separator: ", ")
            defaultPrefix = store.settings.defaultPrefix
        }
        .onChange(of: ffmpegPath) { update() }
        .onChange(of: ffprobePath) { update() }
        .onChange(of: extensions) { update() }
        .onChange(of: defaultPrefix) { update() }
        .onChange(of: store.settings.dryRunDefault) { store.save() }
        .onChange(of: store.settings.sortByDate) { store.save() }
        .onChange(of: store.settings.sortByCamera) { store.save() }
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
            settings.defaultPrefix = defaultPrefix
        }
        AppState.shared.settings = store.settings
        AppState.shared.resolveDependencies()
    }
}
