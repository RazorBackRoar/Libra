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
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(2.5)
                        .foregroundStyle(.white)
                    Text("Video organization toolkit")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 12)
            }

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [LibraTheme.gold, LibraTheme.amber.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 56, height: 2.5)
                .padding(.leading, 2)

            videoGrid
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LibraTheme.bg.ignoresSafeArea())
    }

    private var videoGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(0..<2, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let index = row * 3 + col
                        if index < tools.count {
                            ToolCard(tool: tools[index], onTap: { selectedTool = tools[index] })
                                .frame(height: 148)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct ToolCard: View {
    let tool: Tool
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(LibraTheme.yellow)
                    Spacer()
                    Text(tool.category.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.38))
                }
                Text(tool.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tool.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(LibraCardFace(hovering: hovering))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(tool.title)
        .accessibilityHint(tool.description)
    }
}
