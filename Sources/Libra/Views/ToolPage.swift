import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum ToolWorkspace: String, CaseIterable {
    case video = "Video"
    case photos = "Photos"
}

struct ToolPage: View {
    let tool: Tool
    let onBack: () -> Void
    @StateObject private var state: ToolState
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var settingsStore = SettingsStore.shared
    @State private var browserFilter: MediaBrowserFilter?
    @State private var workspace: ToolWorkspace = .video

    init(tool: Tool, onBack: @escaping () -> Void) {
        self.tool = tool
        self.onBack = onBack
        _state = StateObject(wrappedValue: ToolState(tool: tool))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                header

                if appState.missingFfprobe || (tool.needsFfmpeg && appState.missingFfmpeg) {
                    HStack {
                        Text(appState.depMessage ?? "Dependencies missing.")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Button("Install") { appState.installDependencies() }
                            .buttonStyle(LibraPrimaryButtonStyle())
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                DropZone(
                    title: "Drop videos here",
                    subtitle: "Folders or video files. Photos are set aside in the Photos tab.",
                    onDrop: { paths in
                        guard !state.running else { return }
                        beginScan(paths)
                    },
                    onBrowse: { browse() },
                    onSelectFiles: { selectFiles() }
                )
                .disabled(state.running)
                .opacity(state.running ? 0.6 : 1)

                workspaceTabs

                if workspace == .video {
                    videoWorkspace
                } else {
                    photosWorkspace
                }

                footer
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black.ignoresSafeArea())

            if let filter = browserFilter {
                let extras = DuplicateDetector.extraPaths(in: state.filteredFiles)
                CategoryBrowserView(
                    title: filter.title,
                    files: state.filteredFiles.filter { filter.matches($0, duplicateExtras: extras) },
                    onBack: { browserFilter = nil }
                )
                .background(Color.black)
            }
        }
        .onChange(of: state.photos.count) { _, count in
            if count == 0, workspace == .photos, !state.filteredFiles.isEmpty {
                workspace = .video
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button("Back") { onBack() }
                .buttonStyle(LibraSecondaryButtonStyle())
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title)
                    .font(.system(size: 20, weight: .bold))
                Text(tool.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private var workspaceTabs: some View {
        HStack(spacing: 0) {
            tab(.video, label: "Video")
            tab(.photos, label: state.photos.isEmpty ? "Photos" : "Photos \(state.photos.count)")
            Spacer()
        }
    }

    private func tab(_ item: ToolWorkspace, label: String) -> some View {
        Button {
            workspace = item
        } label: {
            VStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(workspace == item ? .yellow : .secondary)
                Rectangle()
                    .fill(workspace == item ? Color.yellow : Color.clear)
                    .frame(height: 2)
            }
            .padding(.trailing, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var videoWorkspace: some View {
        CountPills(files: state.filteredFiles, tool: tool) { filter in
            browserFilter = filter
        }

        if state.filteredFiles.contains(where: \.hasCoordinates) {
            GPSMapPanel(files: state.filteredFiles)
        }

        if tool == .provid || tool == .vidres || tool == .promax || tool == .maxvid {
            TextField(tool == .provid ? "Prefix" : "Prefix (optional)", text: $state.prefix)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
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
    }

    @ViewBuilder
    private var photosWorkspace: some View {
        if state.photos.isEmpty {
            Text("No photos in this drop. L!bra is video-only — if stills are mixed in, they show up here so you can move them out.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text("\(state.photos.count) photo\(state.photos.count == 1 ? "" : "s") found in this folder. Move them out of the video library.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            List {
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
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack {
                Spacer()
                Button("Move photos out…") { movePhotosOut() }
                    .buttonStyle(LibraPrimaryButtonStyle())
                    .disabled(state.running)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let recap = state.recap ?? state.message {
                Text(recap)
                    .font(.system(size: 13, weight: .medium))
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
                .onChange(of: state.dryRun) { _, _ in
                    state.scheduleRerunAfterOptionsChange()
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

    private func movePhotosOut() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Move photos here"
        panel.message = "Choose a folder outside your video library."
        if let last = settingsStore.settings.lastFolder {
            panel.directoryURL = URL(fileURLWithPath: last)
        }
        guard panel.runModal() == .OK, let dest = panel.url?.path else { return }
        state.movePhotosOut(to: dest)
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
        panel.allowedContentTypes = [UTType.movie, UTType.video, UTType.data]
        if panel.runModal() == .OK {
            beginScan(panel.urls.map(\.path))
        }
    }
}
