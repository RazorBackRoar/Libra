import SwiftUI

enum HomeSection: String, CaseIterable {
    case video = "Video"
    case photo = "Photo"
}

struct HomeView: View {
    @Binding var selectedTool: Tool?
    @Binding var section: HomeSection
    @ObservedObject private var appState = AppState.shared

    private let tools = Array(Tool.allCases)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "film.stack")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 1) {
                    Text("L!bra")
                        .font(.system(size: 18, weight: .bold))
                    Text("Video organization toolkit")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 12)
                HomeTabBar(section: $section)
            }

            if appState.missingScanTools {
                HStack {
                    Text("ffprobe missing — scanning needs it. Install ffmpeg (includes ffprobe).")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                    Button("Install") { appState.installDependencies() }
                        .buttonStyle(LibraPrimaryButtonStyle())
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            if section == .video {
                videoGrid
            } else {
                PhotoSweepView()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.ignoresSafeArea())
    }

    private var videoGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let tool = tools[row * 3 + col]
                        ToolCard(tool: tool, onTap: { selectedTool = tool })
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HomeTabBar: View {
    @Binding var section: HomeSection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeSection.allCases, id: \.self) { item in
                Button {
                    section = item
                } label: {
                    VStack(spacing: 5) {
                        Text(item.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(section == item ? .yellow : .secondary)
                        Rectangle()
                            .fill(section == item ? Color.yellow : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(width: 72)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ToolCard: View {
    let tool: Tool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.yellow)
                    Spacer()
                    Text(tool.category)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Text(tool.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(tool.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
