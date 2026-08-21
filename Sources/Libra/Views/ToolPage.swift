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
            VStack(alignment: .leading, spacing: 12) {
                header

                if tool.needsFfmpeg && appState.missingFfmpeg {
                    HStack {
                        Text(appState.depMessage ?? "Needs ffmpeg to create transformed media.")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Button("Install ffmpeg…") { appState.installDependencies() }
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
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Drop videos here")

                workspaceTabs

                if workspace == .video {
                    videoWorkspace
                } else {
                    photosWorkspace
                }

                footer
            }
            .padding(18)
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

    private var usesPrefixField: Bool {
        tool.isSortRenameFamily && state.filenameStyle == .libraFormat
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
            Spacer(minLength: 8)
            if usesPrefixField {
                TextField("Prefix", text: $state.prefix)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .disabled(state.running)
                    .help("Replaces the original name: katie 720p W30 002.mp4")
                    .onChange(of: state.prefix) { _, _ in
                        state.scheduleRerunAfterOptionsChange()
                    }
            }
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
            GPSMapPanel(files: state.filteredFiles, startsExpanded: true)
        }

        if tool.isSortRenameFamily {
            sortRenameControls
        }

        if state.showsExtraFolderToggles || tool == .iphoneSorter {
            HStack(spacing: 16) {
                Toggle("Also sort by date", isOn: $settingsStore.settings.sortByDate)
                Toggle("Also sort by camera", isOn: $settingsStore.settings.sortByCamera)
                Toggle("Put extras in Duplicates", isOn: $settingsStore.settings.sortDuplicatesIntoFolder)
                    .help("Same size, duration, and video format — not a byte-for-byte match")
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
            .onChange(of: settingsStore.settings.sortDuplicatesIntoFolder) { _, _ in
                settingsStore.save()
                state.scheduleRerunAfterOptionsChange()
            }
        }

        if tool == .slomo {
            Picker("Slow-down speed", selection: $state.slomoFactor) {
                Text("Half speed (0.5x)").tag(0.5)
                Text("Quarter speed (0.25x)").tag(0.25)
            }
            .pickerStyle(.segmented)
            .disabled(state.running)
            .onChange(of: state.slomoFactor) { _, _ in
                state.scheduleRerunAfterOptionsChange()
            }
        }

        if tool == .oneMin {
            Picker("Output", selection: $state.oneMinMode) {
                Text("New copies").tag("copies")
                Text("Change originals").tag("inplace")
            }
            .pickerStyle(.segmented)
            .disabled(state.running)
            .onChange(of: state.oneMinMode) { _, _ in
                state.scheduleRerunAfterOptionsChange()
            }
            DatePicker("First timestamp", selection: $state.oneMinStart)
                .disabled(state.running)
                .onChange(of: state.oneMinStart) { _, _ in
                    state.scheduleRerunAfterOptionsChange()
                }
        }

        if state.running {
            ProgressView(value: Double(state.progress.done), total: Double(max(state.progress.total, 1)))
            Text(progressCaption)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .accessibilityLabel(progressCaption)
        }

        ResultsTable(files: state.filteredFiles, results: state.results)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var sortRenameControls: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Picker("Filename", selection: $state.filenameStyle) {
                ForEach(FilenameStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 280)
            .disabled(state.running)
            .onChange(of: state.filenameStyle) { _, _ in
                state.scheduleRerunAfterOptionsChange()
            }

            Picker("Folders", selection: $state.folderDepth) {
                ForEach(FolderDepth.allCases) { depth in
                    Text(depth.label).tag(depth)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 320)
            .disabled(state.running)
            .onChange(of: state.folderDepth) { _, _ in
                state.scheduleRerunAfterOptionsChange()
            }
        }

        if state.filenameStyle == .libraFormat {
            Text("Example: \(libraFormatExample)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        Text(state.folderDepth.detail)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
    }

    private var libraFormatExample: String {
        let prefix = state.prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = prefix.isEmpty ? "katie" : prefix
        return "\(stem) 720p W30 002.mp4"
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
                    .onTapGesture { MediaOpen.open(file.path) }
                    .contextMenu {
                        Button("Open") { MediaOpen.open(file.path) }
                        Button("Reveal in Finder") { MediaOpen.reveal(file.path) }
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
                    .accessibilityLabel("Move photos out")
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
                    Text("Preview only")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.yellow)
                }
                .toggleStyle(.switch)
                .tint(.yellow)
                .disabled(state.running)
                .accessibilityLabel("Preview only")
                .onChange(of: state.dryRun) { _, _ in
                    state.scheduleRerunAfterOptionsChange()
                }

                Text(state.previewLiveCaption)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(state.dryRun ? .yellow : .orange)

                Spacer()

                if state.canUndo {
                    Button("Undo last run") {
                        state.undoLastRun()
                    }
                    .accessibilityLabel("Undo last run")
                }

                if state.running {
                    Button(state.cancelling ? "Cancelling…" : "Cancel") {
                        state.cancelActiveWork()
                    }
                    .disabled(state.cancelling)
                    .accessibilityLabel("Cancel")
                } else {
                    Button(state.writeButtonTitle) {
                        confirmAndWrite()
                    }
                    .buttonStyle(LibraPrimaryButtonStyle())
                    .disabled(!state.canWrite)
                    .accessibilityLabel(state.writeButtonTitle)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: LibraCommands.openFolder)) { _ in
            browse()
        }
        .onReceive(NotificationCenter.default.publisher(for: LibraCommands.selectFiles)) { _ in
            selectFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: LibraCommands.undoLastRun)) { _ in
            state.undoLastRun()
        }
        .onReceive(NotificationCenter.default.publisher(for: LibraCommands.cancelWork)) { _ in
            state.cancelActiveWork()
        }
        .onExitCommand {
            if state.running {
                state.cancelActiveWork()
            }
        }
    }

    private var progressCaption: String {
        let counts = "\(state.progress.done) of \(state.progress.total) videos"
        if state.progressName.isEmpty { return counts }
        return "\(counts) — \(state.progressName)"
    }

    private func movePhotosOut() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Move photos here"
        panel.message = "Choose a folder outside your video library."
        guard panel.runModal() == .OK, let dest = panel.url?.path else { return }
        if settingsStore.settings.requireConfirmToWrite, !state.dryRun {
            let alert = NSAlert()
            alert.messageText = "Move \(state.photos.count) photo\(state.photos.count == 1 ? "" : "s")?"
            alert.informativeText = "From the scanned folder to:\n\(dest)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Move Photos")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        if let refused = state.movePhotosOut(to: dest) {
            let alert = NSAlert()
            alert.messageText = "Choose another folder"
            alert.informativeText = refused
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func confirmAndWrite() {
        guard state.canWrite else { return }
        if settingsStore.settings.requireConfirmToWrite {
            let alert = NSAlert()
            alert.messageText = state.writeButtonTitle + "?"
            alert.informativeText = """
            Source: \(settingsStore.settings.lastFolder ?? "dropped items")
            \(state.previewLiveCaption)
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Write")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        state.startWrite(
            settings: settingsStore.settings,
            ffmpegPath: appState.ffmpegPath
        )
    }

    private func beginScan(_ paths: [String]) {
        if let warning = ScanSafety.warning(for: paths) {
            let alert = NSAlert()
            alert.messageText = "Scan this location?"
            alert.informativeText = warning
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Scan")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        state.confirmDiscover = { count in
            await MainActor.run {
                confirmFileCount(count, paths: paths)
            }
        }
        state.startScan(
            paths: paths,
            settings: settingsStore.settings
        )
    }

    private func confirmFileCount(_ count: Int, paths: [String]) -> Bool {
        guard let warning = ScanSafety.fileCountWarning(count: count, paths: paths) else {
            return true
        }
        let alert = NSAlert()
        alert.messageText = "Scan this many items?"
        alert.informativeText = warning
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Scan")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func browse() {
        guard !state.running else { return }
        let panel = NSOpenPanel()
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
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType.movie, UTType.video, UTType.data]
        if panel.runModal() == .OK {
            beginScan(panel.urls.map(\.path))
        }
    }
}
