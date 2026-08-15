import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var ffmpegPath: String = ""
    @State private var extensions: String = ""
    @State private var imageExtensions: String = ""
    @State private var defaultPrefix: String = ""

    var body: some View {
        Form {
            Section("Media tools (ffmpeg)") {
                Text("Needed only for Slow motion and 1-minute stamps. Organize tools scan with built-in macOS media APIs.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("ffmpeg path", text: $ffmpegPath)
                Button("Find Homebrew installs") {
                    detect()
                }
            }
            Section("Video extensions") {
                TextField("mp4, mov, m4v, …", text: $extensions)
            }
            Section("Photo extensions") {
                TextField("jpg, heic, png, …", text: $imageExtensions)
            }
            Section("Defaults") {
                Toggle("Preview only by default", isOn: $store.settings.dryRunDefault)
                Toggle("Confirm before Write", isOn: $store.settings.requireConfirmToWrite)
                TextField("Default prefix", text: $defaultPrefix)
                Toggle("Also sort by date", isOn: $store.settings.sortByDate)
                Toggle("Also sort by camera", isOn: $store.settings.sortByCamera)
                Toggle("Put extras in Duplicates", isOn: $store.settings.sortDuplicatesIntoFolder)
                Text("Duplicates match size, duration, and video format — not a byte-for-byte hash.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460, height: 560)
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
        .onChange(of: store.settings.sortByDate) { store.save() }
        .onChange(of: store.settings.sortByCamera) { store.save() }
        .onChange(of: store.settings.sortDuplicatesIntoFolder) { store.save() }
    }

    private func detect() {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                ffmpegPath = path
            }
        }
    }

    private func update() {
        store.update { settings in
            settings.ffmpegPath = ffmpegPath.isEmpty ? nil : ffmpegPath
            settings.videoExtensions = extensions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            settings.imageExtensions = imageExtensions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            settings.defaultPrefix = defaultPrefix
        }
        AppState.shared.settings = store.settings
        AppState.shared.resolveDependencies()
    }
}
