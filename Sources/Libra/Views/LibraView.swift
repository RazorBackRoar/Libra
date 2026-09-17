import AppKit
import SwiftUI

struct LibraView: View {
    @State private var selectedTool: Tool?
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            if let tool = selectedTool {
                if tool == .photoSweep {
                    PhotoSweepView(onBack: { selectedTool = nil })
                } else {
                    ToolPage(tool: tool, onBack: { selectedTool = nil })
                }
            } else {
                HomeView(selectedTool: $selectedTool)
            }
        }
        .background(LibraTheme.bg.ignoresSafeArea())
        .overlay {
            // Gold liner tracing the whole window edge — the title bar is
            // transparent and the name hidden, so this border carries the brand.
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    LinearGradient(
                        colors: [
                            LibraTheme.yellow.opacity(0.9),
                            LibraTheme.gold.opacity(0.65),
                            LibraTheme.amber.opacity(0.4),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .padding(0.75)
                .allowsHitTesting(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: LibraCommands.openSettings)) { _ in
            openSettings()
        }
        .onAppear {
            if selectedTool == nil {
                DispatchQueue.main.async { resizeWindow(forTool: nil) }
            }
        }
        .onChange(of: selectedTool) { _, tool in
            resizeWindow(forTool: tool)
        }
    }

    /// The window hugs its content: home stays snug around the cards,
    /// tool pages grow to workspace height. Resizes animate downward from
    /// a fixed top edge.
    private func resizeWindow(forTool tool: Tool?) {
        guard let window = NSApp?.mainWindow
            ?? NSApp?.windows.first(where: { $0.isVisible && !($0 is NSPanel) })
        else { return }
        let expanded = tool != nil
        window.minSize = NSSize(width: 780, height: expanded ? 740 : 430)
        var frame = window.frame
        let target = NSSize(width: 900, height: expanded ? 860 : 445)
        frame.origin.y += frame.height - target.height
        frame.size = target
        if let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        }
        window.setFrame(frame, display: true, animate: true)
    }
}
