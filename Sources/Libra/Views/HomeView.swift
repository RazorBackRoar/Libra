import SwiftUI

enum HomeSection: String, CaseIterable {
    case video = "Video"
    case photos = "Photos"
}

struct HomeView: View {
    @Binding var selectedTool: Tool?
    @Binding var section: HomeSection

    private let tools = Tool.videoHomeTools

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
            ForEach(0..<2, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let index = row * 3 + col
                        if index < tools.count {
                            ToolCard(tool: tools[index], onTap: { selectedTool = tools[index] })
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
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
