import SwiftUI

struct LibraView: View {
    @State private var selectedTool: Tool? = nil

    var body: some View {
        NavigationStack {
            HomeView(selectedTool: $selectedTool)
                .navigationDestination(item: $selectedTool) { tool in
                    ToolPage(tool: tool)
                }
        }
        .background(Color.black.ignoresSafeArea())
    }
}
