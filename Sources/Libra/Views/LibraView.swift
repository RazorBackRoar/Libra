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
        .onReceive(NotificationCenter.default.publisher(for: LibraCommands.openSettings)) { _ in
            openSettings()
        }
    }
}
