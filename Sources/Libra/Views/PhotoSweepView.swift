import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class PhotoSweepState: ObservableObject {
    @Published var photos: [VideoInfo] = []
    @Published var results: [OperationResult] = []
    @Published var running = false
    @Published var recap: String?
    @Published var dryRun = true
    @Published var progress: (done: Int, total: Int) = (0, 0)

    private var task: Task<Void, Never>?

    func startScan(paths: [String], ffprobePath: String, settings: AppSettings) {
        guard !running else { return }
        running = true
        recap = "Finding photos…"
        photos = []
        results = []
        AppState.shared.rememberLastFolder(from: paths)
        task = Task { [weak self] in
            guard let self else { return }
            let outcome = await ScannerService.scan(
                paths: paths,
                extensions: settings.imageExtensions,
                ffprobePath: ffprobePath,
                progress: { done, total in
                    await MainActor.run { self.progress = (done, total) }
                }
            )
            self.photos = outcome.supported
            self.results = outcome.unsupported
            if outcome.terminal == .cancelled {
                self.recap = "Cancelled."
            } else if self.photos.isEmpty {
                self.recap = "No photos in that drop."
            } else {
                self.recap = "Found \(self.photos.count) photo\(self.photos.count == 1 ? "" : "s"). Move them out of the video folders."
            }
            self.running = false
            self.task = nil
        }
    }

    func moveOut() {
        guard !photos.isEmpty, !running else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Move photos here"
        panel.message = "Choose a folder outside your video library."
        if let last = SettingsStore.shared.settings.lastFolder {
            panel.directoryURL = URL(fileURLWithPath: last)
        }
        guard panel.runModal() == .OK, let dest = panel.url?.path else { return }

        running = true
        let moved = PhotoMover.move(photos, to: dest, dryRun: dryRun)
        results = moved
        let ok = moved.filter { $0.status == .success }.count
        if dryRun {
            recap = "Preview: \(ok) photo\(ok == 1 ? "" : "s") would move to \(dest)."
        } else {
            recap = "Moved \(ok) photo\(ok == 1 ? "" : "s") to \(dest)."
            photos = photos.filter { photo in
                !moved.contains { $0.path == photo.path && $0.status == .success }
            }
        }
        running = false
    }
}

struct PhotoSweepView: View {
    @StateObject private var state = PhotoSweepState()
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var settingsStore = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pull stills out of a folder so they don’t sit with your videos.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            DropZone(
                title: "Drop a folder",
                subtitle: "We’ll list photos (JPG, HEIC, PNG, …) so you can move them out.",
                onDrop: { paths in
                    guard let probe = appState.ffprobePath else { return }
                    state.startScan(paths: paths, ffprobePath: probe, settings: settingsStore.settings)
                },
                onBrowse: { browse(files: false) },
                onSelectFiles: { browse(files: true) },
                lastFolderTitle: lastFolderButtonTitle,
                onLastFolder: lastFolderButtonTitle == nil ? nil : { scanLastFolder() }
            )
            .disabled(state.running)

            if state.running {
                ProgressView(value: Double(state.progress.done), total: Double(max(state.progress.total, 1)))
            }

            if state.photos.isEmpty {
                Text(state.recap ?? "No photos yet.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List {
                    Section("\(state.photos.count) photos") {
                        ForEach(Array(state.photos.enumerated()), id: \.element.id) { index, file in
                            HStack(spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.yellow)
                                    .frame(width: 36, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(file.name).\(file.ext)")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(file.dir)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { MediaOpen.open(file.path) }
                            .contextMenu {
                                Button("Open") { MediaOpen.open(file.path) }
                                Button("Reveal in Finder") { MediaOpen.reveal(file.path) }
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Toggle(isOn: $state.dryRun) {
                    Text("Dry Run")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.yellow)
                }
                .toggleStyle(.switch)
                .tint(.yellow)
                .disabled(state.running)

                Text(state.dryRun ? "Preview only." : "Live — photos will move.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(state.dryRun ? .yellow : .orange)

                Spacer()

                Button("Move photos out…") {
                    state.moveOut()
                }
                .buttonStyle(LibraPrimaryButtonStyle())
                .disabled(state.photos.isEmpty || state.running)
            }

            if let recap = state.recap {
                Text(recap)
                    .font(.system(size: 13, weight: .medium))
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var lastFolderButtonTitle: String? {
        guard let last = settingsStore.settings.lastFolder, FileManager.default.fileExists(atPath: last) else {
            return nil
        }
        return (last as NSString).lastPathComponent
    }

    private func scanLastFolder() {
        guard let last = settingsStore.settings.lastFolder, let probe = appState.ffprobePath else { return }
        state.startScan(paths: [last], ffprobePath: probe, settings: settingsStore.settings)
    }

    private func browse(files: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = files
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if files {
            panel.allowedContentTypes = [.image, .data]
        }
        if let last = settingsStore.settings.lastFolder {
            panel.directoryURL = URL(fileURLWithPath: last)
        }
        if panel.runModal() == .OK, let probe = appState.ffprobePath {
            state.startScan(
                paths: panel.urls.map(\.path),
                ffprobePath: probe,
                settings: settingsStore.settings
            )
        }
    }
}
