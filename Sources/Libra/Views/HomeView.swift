import SwiftUI

struct HomeView: View {
    @Binding var selectedTool: Tool?
    @ObservedObject private var appState = AppState.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "film.stack")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading) {
                        Text("L!bra")
                            .font(.system(size: 22, weight: .bold))
                        Text("Local-first video organization toolkit")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                if appState.missingDeps {
                    HStack {
                        Text("ffmpeg or ffprobe missing.")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                        Button("Install") { appState.installDependencies() }
                            .buttonStyle(LibraPrimaryButtonStyle())
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Tool.allCases) { tool in
                        ToolCard(tool: tool, onTap: { selectedTool = tool })
                    }
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}

struct ToolCard: View {
    let tool: Tool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 28))
                        .foregroundColor(.yellow)
                    Spacer()
                    Text(tool.category)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Text(tool.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(tool.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding()
            .frame(height: 130)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray).opacity(0.15))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
