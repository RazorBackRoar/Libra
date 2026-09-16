import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PhotoSweepState: ObservableObject {
    @Published var photos: [VideoInfo] = []
    @Published var results: [OperationResult] = []
    @Published var running = false
    @Published var recap: String?
    @Published var dryRun = true
    @Published var progress: (done: Int, total: Int) = (0, 0)
    @Published var undoRecords: [UndoRecord] = []

    var canUndo: Bool { !undoRecords.isEmpty && !running }

    var confirmDiscover: (@Sendable (Int) async -> Bool)?
    private var task: Task<Void, Never>?

    func startScan(paths: [String], settings: AppSettings) {
        guard !running else { return }
        running = true
        recap = "Finding photos…"
        photos = []
        results = []
        undoRecords = []
        AppState.shared.rememberLastFolder(from: paths)
        let confirm = confirmDiscover
        task = Task { [weak self] in
            guard let self else { return }
            let outcome = await ScannerService.scan(
                paths: paths,
                extensions: settings.imageExtensions,
                progress: { done, total in
                    await MainActor.run { self.progress = (done, total) }
                },
                confirmDiscover: confirm
            )
            self.photos = outcome.supported
            self.results = outcome.unsupported
            if outcome.terminal == .cancelled {
                self.recap = "Cancelled."
            } else if self.photos.isEmpty {
                self.recap = "No photos in that drop."
            } else {
                self.recap =
                    "Found \(self.photos.count) photo\(self.photos.count == 1 ? "" : "s"). Move them out of the video folders."
            }
            self.running = false
            self.task = nil
            self.confirmDiscover = nil
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
        guard panel.runModal() == .OK, let dest = panel.url?.path else { return }
        if ScanSafety.destinationIsInsideSource(
            dest: dest, sourceRoot: SettingsStore.shared.settings.lastFolder)
        {
            recap = "Choose a folder outside the scanned video folder."
            return
        }
        if SettingsStore.shared.settings.requireConfirmToWrite, !dryRun {
            let alert = NSAlert()
            alert.messageText = "Move \(photos.count) photo\(photos.count == 1 ? "" : "s")?"
            alert.informativeText = dest
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Move Photos")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        running = true
        let dry = dryRun
        let toMove = photos
        Task {
            let moved = await Task.detached {
                PhotoMover.move(toMove, to: dest, dryRun: dry)
            }.value
            results = moved
            for result in moved where result.status == .failed {
                let name = (result.path as NSString).lastPathComponent
                Log.shared.warn("\(name): \(result.reason ?? "unknown error")", scope: "run")
            }
            let ok = moved.filter { $0.status == .success }.count
            if dry {
                recap = "Preview: \(ok) photo\(ok == 1 ? "" : "s") would move to \(dest)."
                if let reportURL = DryRunReport.write(tool: .photoSweep, results: moved) {
                    recap? += " Report: \(reportURL.lastPathComponent)"
                }
            } else {
                recap = "Moved \(ok) photo\(ok == 1 ? "" : "s") to \(dest)."
                photos = photos.filter { photo in
                    !moved.contains { $0.path == photo.path && $0.status == .success }
                }
                undoRecords = moved.compactMap { result in
                    guard result.status == .success, let output = result.outputPath,
                        output != result.path
                    else { return nil }
                    return UndoRecord(kind: .moved, originalPath: result.path, resultPath: output)
                }
            }
            running = false
        }
    }

    func undoLastRun() {
        guard canUndo else { return }
        running = true
        let records = undoRecords
        undoRecords = []
        Task {
            let outcome = await Task.detached { UndoApply.apply(records) }.value
            running = false
            recap =
                outcome.failed == 0
                ? "Undid \(outcome.restored) photo move\(outcome.restored == 1 ? "" : "s")."
                : "Undo finished: \(outcome.restored) restored, \(outcome.failed) failed."
        }
    }
}

struct PhotoSweepView: View {
    let onBack: () -> Void
    @StateObject private var state = PhotoSweepState()
    @ObservedObject private var settingsStore = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button("Back") { onBack() }
                    .buttonStyle(LibraSecondaryButtonStyle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(Tool.photoSweep.title)
                        .font(.system(size: 20, weight: .bold))
                    Text("Move stills out of mixed video folders.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
            }

            DropZone(
                title: "Drop photos here",
                subtitle: state.photos.isEmpty
                    ? "Folders or stills. We’ll list JPG, HEIC, PNG so you can move them out."
                    : "Drop more, or use Open Folder / Select Photos.",
                compact: !state.photos.isEmpty,
                selectTitle: "Select Photos…",
                onDrop: { paths in
                    beginScan(paths)
                },
                onBrowse: { browse(files: false) },
                onSelectFiles: { browse(files: true) }
            )
            .disabled(state.running)

            if state.running {
                ProgressView(
                    value: Double(state.progress.done), total: Double(max(state.progress.total, 1)))
            }

            if state.photos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.yellow.opacity(0.7))
                    Text(state.recap ?? "No photos yet")
                        .font(.system(size: 14, weight: .semibold))
                    if state.recap == nil {
                        Text("Drop a mixed folder above to pull stills out of the video library.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.vertical, 8)
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
                                    Text(file.identificationLine)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .help(file.identificationLine)
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
                    Text("Preview only")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.yellow)
                }
                .toggleStyle(.switch)
                .tint(.yellow)
                .disabled(state.running)

                Text(
                    state.dryRun
                        ? "Preview only — nothing will be changed." : "Live — photos will move."
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(state.dryRun ? .yellow : .orange)
                .lineLimit(2)

                Spacer()

                if state.canUndo {
                    Button("Undo last run") {
                        state.undoLastRun()
                    }
                }

                Button("Move photos out…") {
                    state.moveOut()
                }
                .buttonStyle(LibraPrimaryButtonStyle())
                .disabled(state.photos.isEmpty || state.running)
                .accessibilityLabel("Move photos out")
            }

            if let recap = state.recap, !state.photos.isEmpty {
                Text(recap)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.ignoresSafeArea())
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
        state.startScan(paths: paths, settings: settingsStore.settings)
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

    private func browse(files: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = files
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if files {
            panel.allowedContentTypes = [.image, .data]
        }
        if panel.runModal() == .OK {
            beginScan(panel.urls.map(\.path))
        }
    }
}
