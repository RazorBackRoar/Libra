import SwiftUI

struct HomeView: View {
    @Binding var selectedTool: Tool?

    private let tools = Tool.homeTools

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "film.stack")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(LibraTheme.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Libra")
                        .font(.system(size: 18, weight: .bold))
                    Text("Video organization toolkit")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 12)
            }

            videoGrid
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LibraTheme.bg.ignoresSafeArea())
    }

    private var videoGrid: some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 14) {
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

struct ToolCard: View {
    let tool: Tool
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                    Spacer()
                    Text(tool.category)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.black.opacity(0.55))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(tool.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tool.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.72))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(LibraCardFace(hovering: hovering))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(tool.title)
        .accessibilityHint(tool.description)
    }
}
