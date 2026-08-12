import SwiftUI

struct HomeView: View {
    @Binding var selectedTool: Tool?
    @ObservedObject private var appState = AppState.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "film.stack")
                    .font(.system(size: 28))
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("L!bra")
                        .font(.system(size: 20, weight: .bold))
                    Text("Local-first video organization toolkit")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if appState.missingScanTools {
                HStack {
                    Text("ffprobe missing — scanning needs it. Install ffmpeg (includes ffprobe).")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                    Button("Install") { appState.installDependencies() }
                        .buttonStyle(LibraPrimaryButtonStyle())
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Tool.allCases) { tool in
                    ToolCard(tool: tool, onTap: { selectedTool = tool })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}

struct ToolCard: View {
    let tool: Tool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 22))
                        .foregroundColor(.yellow)
                    Spacer()
                    Text(tool.category)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Text(tool.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(tool.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemGray).opacity(0.15))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
