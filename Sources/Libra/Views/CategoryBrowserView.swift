import SwiftUI
import AVKit
import AppKit

struct CategoryBrowserView: View {
    let title: String
    let files: [VideoInfo]

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var player: AVPlayer?
    @StateObject private var keys = ArrowKeyMonitor()
    @FocusState private var focused: Bool

    private var current: VideoInfo? {
        guard files.indices.contains(index) else { return nil }
        return files[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                HStack {
                    Button("← Back") { dismiss() }
                    Spacer()
                    if !files.isEmpty {
                        Text("\(index + 1) / \(files.count)")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }

            if files.isEmpty {
                Spacer()
                Text("No files in this category.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                HStack(alignment: .top, spacing: 12) {
                    fileList
                        .frame(width: 280)

                    VStack(alignment: .leading, spacing: 8) {
                        if let file = current {
                            mediaPane(for: file)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemGray).opacity(0.15))
                                .cornerRadius(10)

                            Text("\(file.name).\(file.ext)")
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)

                            Text(file.path)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .focusable()
        .focused($focused)
        .onAppear {
            focused = true
            loadPlayer()
            keys.onLeft = { move(-1) }
            keys.onRight = { move(1) }
            keys.start()
        }
        .onChange(of: index) { _, _ in
            loadPlayer()
        }
        .onDisappear {
            keys.stop()
            tearDownPlayer()
        }
        .onKeyPress(.leftArrow) {
            move(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            move(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            move(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            move(1)
            return .handled
        }
        .navigationBarBackButtonHidden(true)
    }

    private var fileList: some View {
        List(selection: Binding(
            get: { files.indices.contains(index) ? files[index].id : nil },
            set: { newID in
                if let newID, let i = files.firstIndex(where: { $0.id == newID }) {
                    index = i
                }
            }
        )) {
            Section("\(title) · \(files.count)") {
                ForEach(Array(files.enumerated()), id: \.element.id) { offset, file in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(offset + 1).")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.yellow)
                            .frame(width: 36, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(file.name).\(file.ext)")
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            if let error = file.error {
                                Text(error)
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                            } else {
                                Text(file.resolutionClass)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tag(file.id)
                    .padding(.vertical, 1)
                }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func mediaPane(for file: VideoInfo) -> some View {
        let imageExts = Set(AppSettings.default.imageExtensions)
        if imageExts.contains(file.ext.lowercased()) {
            if let nsImage = NSImage(contentsOfFile: file.path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                placeholder("Could not load image")
            }
        } else if let player {
            // Use AppKit AVPlayerView — SwiftUI VideoPlayer crashes on some macOS builds
            // (_AVKit_SwiftUI metadata fatalError) when opening category browsers.
            AppKitPlayerView(player: player)
                .cornerRadius(8)
        } else {
            placeholder(file.error ?? "Preview unavailable")
        }
    }

    private func placeholder(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func move(_ delta: Int) {
        guard !files.isEmpty else { return }
        let next = index + delta
        guard files.indices.contains(next) else { return }
        index = next
    }

    private func loadPlayer() {
        tearDownPlayer()
        guard let file = current else { return }
        let imageExts = Set(AppSettings.default.imageExtensions)
        guard !imageExts.contains(file.ext.lowercased()) else { return }
        guard file.error == nil else { return }
        guard FileManager.default.fileExists(atPath: file.path) else { return }

        let url = URL(fileURLWithPath: file.path)
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = true
        player = newPlayer
        // Do not autoplay — listing + path are the primary goal; play is user-controlled.
    }

    private func tearDownPlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}

/// AppKit-backed player avoids SwiftUI `VideoPlayer` / `_AVKit_SwiftUI` crashes.
private struct AppKitPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = true
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player?.pause()
        nsView.player = nil
    }
}

/// Keeps arrow keys working when the player view steals key focus.
@MainActor
private final class ArrowKeyMonitor: ObservableObject {
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?
    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            switch event.keyCode {
            case 123, 126: // left, up
                DispatchQueue.main.async { self?.onLeft?() }
                return nil
            case 124, 125: // right, down
                DispatchQueue.main.async { self?.onRight?() }
                return nil
            default:
                return event
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        onLeft = nil
        onRight = nil
    }
}
