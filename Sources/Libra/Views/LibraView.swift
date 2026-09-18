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
            // Gold liner tracing the whole window edge — fullSizeContentView
            // puts our content under the transparent title bar, so this border
            // frames the traffic lights too.
            LibraWindowBorder()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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

private struct LibraWindowBorder: NSViewRepresentable {
    func makeNSView(context: Context) -> AttachmentView { AttachmentView() }

    func updateNSView(_ nsView: AttachmentView, context: Context) {
        nsView.attachBorder()
    }

    static func dismantleNSView(_ nsView: AttachmentView, coordinator: ()) {
        nsView.border.removeFromSuperview()
    }

    final class AttachmentView: NSView {
        let border = BorderView()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attachBorder()
        }

        func attachBorder() {
            guard let frameView = window?.contentView?.superview else {
                border.removeFromSuperview()
                return
            }
            guard border.superview !== frameView else { return }
            border.removeFromSuperview()
            border.frame = frameView.bounds
            border.autoresizingMask = [.width, .height]
            border.setAccessibilityElement(false)
            frameView.addSubview(border, positioned: .above, relativeTo: nil)
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    final class BorderView: NSView {
        override var isOpaque: Bool { false }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            needsDisplay = true
        }

        override func draw(_ dirtyRect: NSRect) {
            let path = NSBezierPath(
                roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75),
                xRadius: 11, yRadius: 11
            )
            path.lineWidth = 1
            NSColor(LibraTheme.gold.opacity(0.85)).setStroke()
            path.stroke()
        }
    }
}
