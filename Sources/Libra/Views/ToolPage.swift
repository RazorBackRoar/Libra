import AppKit
import SwiftUI
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
    /// GPS map-only pin filter — never affects Preview/Write scope.
    @State private var gpsMapFilter: MediaBrowserFilter = .all
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

                // GPS is map-first — the map itself is the drop surface.
                if tool != .gps {
                    DropZone(
                        title: "Drop videos here",
                        subtitle: hasMedia
                            ? "Drop more, or use Open Folder / Select Videos."
                            : "Folders or videos. Mixed photos get a Photos tab.",
                        compact: hasMedia,
                        selectTitle: "Select Videos…",
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
                }

                if !state.photos.isEmpty || workspace == .photos {
                    workspaceTabs
                }

                if workspace == .photos {
                    photosWorkspace
                } else {
                    videoWorkspace
                }

                footer
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(LibraTheme.bg.ignoresSafeArea())

            if let filter = browserFilter {
                CategoryBrowserView(
                    title: filter.title,
                    files: state.filteredFiles.filter { filter.matches($0) },
                    onBack: { browserFilter = nil }
                )
                .background(LibraTheme.bg)
            }
        }
        .onChange(of: state.photos.count) { _, count in
            if count == 0, workspace == .photos, !state.filteredFiles.isEmpty {
                workspace = .video
            }
        }
        .onChange(of: state.files.map(\.path)) { _, _ in
            gpsMapFilter = .all
        }
    }

    private var hasMedia: Bool {
        !state.files.isEmpty || !state.photos.isEmpty
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
                if tool != .gps {
                    Text(tool.ruleSummary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(LibraTheme.gold)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if tool == .gps {
                GPSStateStrip(
                    files: state.files,
                    resolvedNames: state.gpsPlaceByPath
                )
            }
            if usesPrefixField {
                TextField("Prefix", text: $state.prefix)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .disabled(state.running)
                    .help("Replaces the original name")
                    .onChange(of: state.prefix) { _, _ in
                        state.scheduleRerunAfterOptionsChange()
                    }
            }
        }
    }

    private var workspaceTabs: some View {
        HStack(spacing: 0) {
            tab(.video, label: "Videos")
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
                    .foregroundColor(workspace == item ? LibraTheme.yellow : .secondary)
                Rectangle()
                    .fill(workspace == item ? LibraTheme.yellow : Color.clear)
                    .frame(height: 2)
            }
            .padding(.trailing, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var videoWorkspace: some View {
        if tool == .gps {
            gpsWorkspace
        } else {
            standardVideoWorkspace
        }
    }

    /// GPS is map-first: the map fills the workspace, is itself the drop
    /// surface, and hosts floating chips (stats, filter pills, Add menu).
    /// No drop zone, results table, or media browser lives here.
    /// Preview/Write scope is untouched — filters are visual only.
    @ViewBuilder
    private var gpsWorkspace: some View {
        GPSMapPanel(
            files: state.filteredFiles,
            resolvedNames: state.gpsPlaceByPath,
            filter: $gpsMapFilter,
            presentation: .primary,
            onDrop: { paths in
                guard !state.running else { return }
                beginScan(paths)
            },
            onBrowse: { browse() },
            onSelectFiles: { selectFiles() }
        )
        .frame(maxHeight: .infinity)
        .layoutPriority(1)

        if state.filteredFiles.contains(where: \.hasCoordinates) {
            HStack(spacing: 12) {
                Button(state.gpsCitiesResolved ? "City names resolved" : "Resolve city names…") {
                    state.resolveGPSCityNames()
                }
                .buttonStyle(LibraSecondaryButtonStyle())
                .disabled(state.running || state.gpsCitiesResolved)
                .accessibilityLabel("Resolve city names")
                Text(
                    state.gpsCitiesResolved
                        ? "Preview shows the exact destination folders."
                        : "Required before organizing — preview shows GPS/ until cities resolve."
                )
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
        }

        if state.running {
            ProgressView(
                value: Double(state.progress.done), total: Double(max(state.progress.total, 1)))
            Text(progressCaption)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .accessibilityLabel(progressCaption)
        }
    }

    @ViewBuilder
    private var standardVideoWorkspace: some View {
        if !state.filteredFiles.isEmpty {
            CountPills(files: state.filteredFiles, tool: tool) { filter in
                browserFilter = filter
            }
        }

        GPSMapPanel(files: state.filteredFiles)

        if tool.isSortRenameFamily {
            sortRenameControls
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
            Toggle("Keep audio — slowed to match the video", isOn: $settingsStore.settings.sloMoKeepAudio)
                .toggleStyle(.checkbox)
                .disabled(state.running)
                .onChange(of: settingsStore.settings.sloMoKeepAudio) { _, _ in
                    settingsStore.save()
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
            ProgressView(
                value: Double(state.progress.done), total: Double(max(state.progress.total, 1)))
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

        Text(state.folderDepth.detail)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var photosWorkspace: some View {
        if state.photos.isEmpty {
            Text(
                "No photos in this drop. Libra is video-only — if stills are mixed in, they show up here so you can move them out."
            )
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text(
                "\(state.photos.count) photo\(state.photos.count == 1 ? "" : "s") found in this folder. Move them out of the video library."
            )
            .font(.system(size: 13))
            .foregroundColor(.secondary)

            List {
                ForEach(Array(state.photos.enumerated()), id: \.element.id) { index, file in
                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(LibraTheme.gold)
                            .frame(width: 36, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(file.name).\(file.ext)")
                                .font(.system(size: 13, weight: .semibold))
                            Text(file.identificationLine)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .help(file.identificationLine)
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
            .libraPanel()

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
            if let reason = state.gpsWriteBlockReason, !state.dryRun {
                Text(reason)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(LibraTheme.gold)
            }
            if let recap = state.recap ?? state.message {
                Text(recap)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            HStack {
                Toggle(isOn: $state.dryRun) {
                    Text(state.dryRun ? "Preview only" : "Live")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(state.dryRun ? LibraTheme.yellow : .orange)
                }
                .toggleStyle(PreviewModeToggleStyle())
                .disabled(state.running)
                .accessibilityLabel("Preview only")
                .accessibilityHint(
                    state.dryRun
                        ? "Preview is on — nothing will be changed. Turn off to enable the action."
                        : "Live — the action button applies changes.")
                .onChange(of: state.dryRun) { _, _ in
                    state.scheduleRerunAfterOptionsChange()
                }

                Text(state.previewLiveCaption)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(state.dryRun ? LibraTheme.yellow : .orange)
                    .lineLimit(2)

                if tool == .gps, !state.files.isEmpty {
                    gpsFooterCounts
                }

                Spacer()

                if state.canUndo {
                    Button("Undo last run") {
                        state.undoLastRun()
                    }
                    .buttonStyle(LibraSecondaryButtonStyle(compact: true))
                    .accessibilityLabel("Undo last run")
                }

                if state.running {
                    Button(state.cancelling ? "Cancelling…" : "Cancel") {
                        state.cancelActiveWork()
                    }
                    .buttonStyle(LibraSecondaryButtonStyle(compact: true))
                    .disabled(state.cancelling)
                    .accessibilityLabel("Cancel")
                } else {
                    Button(state.writeButtonTitle) {
                        confirmAndWrite()
                    }
                    .buttonStyle(LibraPrimaryButtonStyle())
                    .disabled(!state.canWrite)
                    .help(state.gpsWriteBlockReason ?? "")
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

    /// GPS footer strip — GPS / No GPS / iPhone / Unknown counts as the
    /// same gold capsule filters the map pills use. Visual filter only;
    /// Preview/Write scope never narrows.
    private var gpsFooterCounts: some View {
        HStack(spacing: 8) {
            gpsCountPill(
                "GPS",
                value: state.files.filter(\.hasCoordinates).count,
                filter: .gps)
            gpsCountPill(
                "No GPS",
                value: state.files.filter { !$0.hasCoordinates }.count,
                filter: .noGps)
            gpsCountPill(
                "iPhone",
                value: state.files.filter(\.hasiPhoneModel).count,
                filter: .iPhoneModel)
            gpsCountPill(
                "Unknown",
                value: state.files.filter {
                    !$0.isApple && $0.make.isEmpty && $0.model.isEmpty
                }.count,
                filter: .unknown)
        }
    }

    private func gpsCountPill(
        _ label: String, value: Int, filter: MediaBrowserFilter
    ) -> some View {
        CountPill(
            label: label,
            value: value,
            helpText: filter == .gps || filter == .noGps
                ? "Show only \(label.lowercased()) pins"
                : "Show only \(label.lowercased()) on the map",
            isSelected: gpsMapFilter == filter
        ) {
            gpsMapFilter = gpsMapFilter == filter ? .all : filter
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
            alert.messageText =
                "Move \(state.photos.count) photo\(state.photos.count == 1 ? "" : "s")?"
            alert.informativeText = "From the scanned folder to:\n\(dest)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Move Photos")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        Task {
            if let refused = await state.movePhotosOut(to: dest) {
                let alert = NSAlert()
                alert.messageText = "Choose another folder"
                alert.informativeText = refused
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
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
            alert.addButton(withTitle: state.writeActionVerb)
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
        state.confirmDiscover = { [paths] count in
            await MainActor.run {
                Self.confirmFileCount(count, paths: paths)
            }
        }
        state.startScan(
            paths: paths,
            settings: settingsStore.settings
        )
    }

    private static func confirmFileCount(_ count: Int, paths: [String]) -> Bool {
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
