import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var ffmpegPath: String = ""
    @State private var extensions: String = ""
    @State private var imageExtensions: String = ""
    @State private var defaultPrefix: String = ""
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section("Media tools (ffmpeg)") {
                Text(
                    "Needed only for Slo-Mo and 1-Min-Adjuster. Organize tools scan with built-in macOS media APIs."
                )
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                TextField("ffmpeg path", text: $ffmpegPath)
                Button("Find Homebrew installs") {
                    detect()
                }
            }
            Section("Video extensions") {
                TextField("mp4, mov, m4v, …", text: $extensions)
                Text(
                    "Scanning uses macOS media APIs — containers they can't read (mkv, avi, webm) report “metadata unreadable” and are skipped."
                )
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            Section("Photo extensions") {
                TextField("jpg, heic, png, …", text: $imageExtensions)
            }
            Section("Defaults") {
                Toggle("Preview only by default", isOn: $store.settings.dryRunDefault)
                Toggle("Confirm before applying", isOn: $store.settings.requireConfirmToWrite)
                TextField("Default prefix", text: $defaultPrefix)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
        .frame(width: 460, height: 560)
        .background(LibraTheme.bg.ignoresSafeArea())
        .tint(LibraTheme.yellow)
        .onAppear {
            ffmpegPath = store.settings.ffmpegPath ?? ""
            extensions = store.settings.videoExtensions.joined(separator: ", ")
            imageExtensions = store.settings.imageExtensions.joined(separator: ", ")
            defaultPrefix = store.settings.defaultPrefix
        }
        .onChange(of: ffmpegPath) { update() }
        .onChange(of: extensions) { update() }
        .onChange(of: imageExtensions) { update() }
        .onChange(of: defaultPrefix) { update() }
        .onChange(of: store.settings.dryRunDefault) { store.save() }
        .onChange(of: store.settings.requireConfirmToWrite) { store.save() }
    }

    private func detect() {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                ffmpegPath = path
                break
            }
        }
    }

    /// Debounced ~500ms so a keystroke burst costs one disk write, not one per key.
    private func update() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let vids = extensions.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            }
            let imgs = imageExtensions.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            }
            store.update { settings in
                settings.ffmpegPath = ffmpegPath.isEmpty ? nil : ffmpegPath
                // Never empty a list mid-edit — an empty set would scan nothing.
                if !vids.isEmpty { settings.videoExtensions = vids }
                if !imgs.isEmpty { settings.imageExtensions = imgs }
                settings.defaultPrefix = defaultPrefix
            }
            AppState.shared.settings = store.settings
            AppState.shared.resolveDependencies()
        }
    }
}
