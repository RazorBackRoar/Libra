import SwiftUI

struct LibraView: View {
    @State private var selectedTool: Tool?
    @State private var section: HomeSection = .video

    var body: some View {
        Group {
            if let tool = selectedTool {
                ToolPage(tool: tool, onBack: { selectedTool = nil })
            } else {
                HomeView(selectedTool: $selectedTool, section: $section)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}
