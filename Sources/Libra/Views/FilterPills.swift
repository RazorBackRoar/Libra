import SwiftUI

struct FilterPills: View {
    @Binding var filter4K: Bool
    @Binding var filter1080: Bool
    @Binding var filter720: Bool
    @Binding var filterSD: Bool
    @Binding var filterGPS: Bool
    @Binding var filteriPhone: Bool
    @Binding var filterDuplicates: Bool

    var body: some View {
        FlowLayout(spacing: 8) {
            Toggle("4K", isOn: $filter4K)
            Toggle("1080p", isOn: $filter1080)
            Toggle("720p", isOn: $filter720)
            Toggle("SD", isOn: $filterSD)
            Toggle("GPS", isOn: $filterGPS)
            Toggle("iPhone", isOn: $filteriPhone)
            Toggle("Duplicates", isOn: $filterDuplicates)
        }
        .toggleStyle(.button)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
