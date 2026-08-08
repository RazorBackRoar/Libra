import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ToolPage: View {
    let tool: Tool
    @StateObject private var state: ToolState
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    @State private var browserFilter: MediaBrowserFilter?

    init(tool: Tool) {
        self.tool = tool
        _state = StateObject(wrappedValue: ToolState(tool: tool))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button("← Back") { dismiss() }
                    Spacer()
                    Text(tool.title)
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                }

                Text(tool.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                if appState.missingDeps {
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
                        state.startScan(
                            paths: paths,
                            settings: appState.settings,
                            ffmpegPath: appState.ffmpegPath ?? "",
                            ffprobePath: appState.ffprobePath ?? ""
                        )
                    },
                    onBrowse: { browse() },
                    onSelectFiles: { selectFiles() }
                )
                .disabled(state.running)
                .opacity(state.running ? 0.6 : 1)

                CountPills(files: state.filteredFiles, tool: tool) { filter in
                    browserFilter = filter
                }

                if tool == .provid || tool == .vidres || tool == .promax || tool == .maxvid {
                    TextField(tool == .provid ? "Prefix" : "Prefix (optional)", text: $state.prefix)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .disabled(state.running)
                }

                if tool == .slomo {
                    Picker("Factor", selection: $state.slomoFactor) {
                        Text("0.5x").tag(0.5)
                        Text("0.25x").tag(0.25)
                    }
                    .pickerStyle(.segmented)
                    .disabled(state.running)
                }

                if tool == .oneMin {
                    Picker("Mode", selection: $state.oneMinMode) {
                        Text("Copies").tag("copies")
                        Text("In place").tag("inplace")
                    }
                    .pickerStyle(.segmented)
                    .disabled(state.running)
                    DatePicker("Start time", selection: $state.oneMinStart)
                        .disabled(state.running)
                }

                if state.running {
                    ProgressView(value: Double(state.progress.done), total: Double(max(state.progress.total, 1)))
                    Text("\(state.progress.done) / \(state.progress.total)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if let message = state.message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                ResultsTable(files: state.filteredFiles, results: state.results)

                HStack {
                    Button(action: { run() }) {
                        Text("Run \(tool.title)")
                    }
                    .buttonStyle(LibraPrimaryButtonStyle())
                    .disabled(state.files.isEmpty || state.running)

                    Toggle("Dry Run", isOn: $state.dryRun)
                        .toggleStyle(.switch)
                        .disabled(state.running)

                    if state.running {
                        Button(state.cancelling ? "Cancelling…" : "Cancel") {
                            state.cancelActiveWork()
                        }
                        .disabled(state.cancelling)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(tool.title)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(item: $browserFilter) { filter in
            CategoryBrowserView(
                title: filter.title,
                files: state.filteredFiles.filter { filter.matches($0) }
            )
        }
    }

    private func browse() {
        guard !state.running else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = []
        if panel.runModal() == .OK {
            let paths = panel.urls.map { $0.path }
            state.startScan(
                paths: paths,
                settings: appState.settings,
                ffmpegPath: appState.ffmpegPath ?? "",
                ffprobePath: appState.ffprobePath ?? ""
            )
        }
    }

    private func selectFiles() {
        guard !state.running else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if tool.acceptsImages {
            panel.allowedContentTypes = [.image, .movie, .video, .data]
        } else {
            panel.allowedContentTypes = [UTType.movie, UTType.video, UTType.data]
        }
        if panel.runModal() == .OK {
            let paths = panel.urls.map { $0.path }
            state.startScan(
                paths: paths,
                settings: appState.settings,
                ffmpegPath: appState.ffmpegPath ?? "",
                ffprobePath: appState.ffprobePath ?? ""
            )
        }
    }

    private func run() {
        state.startRun(
            settings: appState.settings,
            ffmpegPath: appState.ffmpegPath,
            ffprobePath: appState.ffprobePath
        )
    }
}
