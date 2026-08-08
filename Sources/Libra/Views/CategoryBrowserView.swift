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
                    if files.count > 1 {
                        HStack(spacing: 8) {
                            Button("←") { move(-1) }
                                .disabled(index <= 0)
                            Text("\(index + 1) / \(files.count)")
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 56)
                            Button("→") { move(1) }
                                .disabled(index >= files.count - 1)
                        }
                    } else if !files.isEmpty {
                        Text("1 / 1")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }

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
                    .padding(.top, 2)
            } else {
                Spacer()
                Text("No files in this category.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
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
            player?.pause()
            player = nil
        }
        .onKeyPress(.leftArrow) {
            move(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            move(1)
            return .handled
        }
        .navigationBarBackButtonHidden(true)
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
            VideoPlayer(player: player)
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
        player?.pause()
        player = nil
        guard let file = current else { return }
        let imageExts = Set(AppSettings.default.imageExtensions)
        guard !imageExts.contains(file.ext.lowercased()) else { return }
        guard file.error == nil else { return }
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let newPlayer = AVPlayer(url: URL(fileURLWithPath: file.path))
        newPlayer.isMuted = true
        player = newPlayer
        newPlayer.play()
    }
}

/// Keeps ←/→ working when `VideoPlayer` steals key focus.
@MainActor
private final class ArrowKeyMonitor: ObservableObject {
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?
    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            switch event.keyCode {
            case 123:
                DispatchQueue.main.async { self?.onLeft?() }
                return nil
            case 124:
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

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
