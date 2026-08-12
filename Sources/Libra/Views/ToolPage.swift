import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ToolPage: View {
    let tool: Tool
    @StateObject private var state: ToolState
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var settingsStore = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var browserFilter: MediaBrowserFilter?

    init(tool: Tool) {
        self.tool = tool
        _state = StateObject(wrappedValue: ToolState(tool: tool))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 6) {
                    Text(tool.title)
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text(tool.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                Button("← Back") { dismiss() }
            }

            if appState.missingFfprobe || (tool.needsFfmpeg && appState.missingFfmpeg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.depMessage ?? "Dependencies missing.")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                    Button("Install ffmpeg with Homebrew") {
                        appState.installDependencies()
                    }
                    .buttonStyle(LibraPrimaryButtonStyle())
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            DropZone(
                title: "Drop files here",
                subtitle: tool.acceptsImages
                    ? "Drop folders, photos, or video files to start."
                    : "Drop folders or video files to start.",
                onDrop: { paths in
                    guard !state.running else { return }
                    beginScan(paths)
                },
                onBrowse: { browse() },
                onSelectFiles: { selectFiles() }
            )
            .disabled(state.running)
            .opacity(state.running ? 0.6 : 1)

            CountPills(files: state.filteredFiles, tool: tool) { filter in
                browserFilter = filter
            }

            if state.filteredFiles.contains(where: \.hasCoordinates) {
                GPSMapPanel(files: state.filteredFiles)
            }

            if tool == .provid || tool == .vidres || tool == .promax || tool == .maxvid {
                TextField(tool == .provid ? "Prefix" : "Prefix (optional)", text: $state.prefix)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                    .disabled(state.running)
                    .onChange(of: state.prefix) { _, _ in
                        state.scheduleRerunAfterOptionsChange()
                    }
            }

            if tool.supportsExtraFolders {
                HStack(spacing: 16) {
                    Toggle("Date folders", isOn: $settingsStore.settings.sortByDate)
                    Toggle("Camera folders", isOn: $settingsStore.settings.sortByCamera)
                }
                .toggleStyle(.checkbox)
                .disabled(state.running)
                .onChange(of: settingsStore.settings.sortByDate) { _, _ in
                    settingsStore.save()
                    state.scheduleRerunAfterOptionsChange()
                }
                .onChange(of: settingsStore.settings.sortByCamera) { _, _ in
                    settingsStore.save()
                    state.scheduleRerunAfterOptionsChange()
                }
            }

            if tool == .slomo {
                Picker("Factor", selection: $state.slomoFactor) {
                    Text("0.5x").tag(0.5)
                    Text("0.25x").tag(0.25)
                }
                .pickerStyle(.segmented)
                .disabled(state.running)
                .onChange(of: state.slomoFactor) { _, _ in
                    state.scheduleRerunAfterOptionsChange()
                }
            }

            if tool == .oneMin {
                Picker("Mode", selection: $state.oneMinMode) {
                    Text("Copies").tag("copies")
                    Text("In place").tag("inplace")
                }
                .pickerStyle(.segmented)
                .disabled(state.running)
                .onChange(of: state.oneMinMode) { _, _ in
                    state.scheduleRerunAfterOptionsChange()
                }
                DatePicker("Start time", selection: $state.oneMinStart)
                    .disabled(state.running)
                    .onChange(of: state.oneMinStart) { _, _ in
                        state.scheduleRerunAfterOptionsChange()
                    }
            }

            if state.running {
                ProgressView(value: Double(state.progress.done), total: Double(max(state.progress.total, 1)))
                Text("\(state.progress.done) / \(state.progress.total)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            ResultsTable(files: state.filteredFiles, results: state.results)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 8) {
                if let recap = state.recap ?? state.message {
                    Text(recap)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
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
                    .onChange(of: state.dryRun) { _, isOn in
                        if isOn {
                            state.scheduleRerunAfterOptionsChange()
                        } else if !state.files.isEmpty {
                            state.needsWriteConfirm = true
                        }
                    }

                    Text(state.dryRun ? "Preview only — nothing will be moved." : "Live — files will be renamed or moved.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(state.dryRun ? .yellow : .orange)

                    Spacer()

                    if state.canUndo {
                        Button("Undo last run") {
                            state.undoLastRun()
                        }
                    }

                    if state.running {
                        Button(state.cancelling ? "Cancelling…" : "Cancel") {
                            state.cancelActiveWork()
                        }
                        .disabled(state.cancelling)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(tool.title)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(item: $browserFilter) { filter in
            let extras = DuplicateDetector.extraPaths(in: state.filteredFiles)
            CategoryBrowserView(
                title: filter.title,
                files: state.filteredFiles.filter { filter.matches($0, duplicateExtras: extras) }
            )
        }
        .alert("Write files for real?", isPresented: $state.needsWriteConfirm) {
            Button("Stay on Dry Run", role: .cancel) {
                state.cancelLiveConfirm()
            }
            Button("Write files") {
                state.confirmLiveRun()
            }
        } message: {
            Text("Dry Run is off. \(tool.title) will rename or move files on disk. You can Undo last run after it finishes.")
        }
    }

    private func beginScan(_ paths: [String]) {
        state.startScan(
            paths: paths,
            settings: settingsStore.settings,
            ffmpegPath: appState.ffmpegPath ?? "",
            ffprobePath: appState.ffprobePath ?? ""
        )
    }

    private func configuredPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        if let last = settingsStore.settings.lastFolder {
            panel.directoryURL = URL(fileURLWithPath: last)
        }
        return panel
    }

    private func browse() {
        guard !state.running else { return }
        let panel = configuredPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = []
        if panel.runModal() == .OK {
            beginScan(panel.urls.map(\.path))
        }
    }

    private func selectFiles() {
        guard !state.running else { return }
        let panel = configuredPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if tool.acceptsImages {
            panel.allowedContentTypes = [.image, .movie, .video, .data]
        } else {
            panel.allowedContentTypes = [UTType.movie, UTType.video, UTType.data]
        }
        if panel.runModal() == .OK {
            beginScan(panel.urls.map(\.path))
        }
    }
}
