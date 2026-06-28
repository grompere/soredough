import SwiftUI

/// Deterministic color for a tag using a stable DJB2 hash.
/// (Swift's `hashValue` is randomized per launch, so we use DJB2 instead.)
func tagColor(for tag: String) -> Color {
    let palette: [Color] = [
        .blue, .purple, .pink, .red, .orange,
        .yellow, .green, .teal, .cyan, .indigo, .mint
    ]
    // DJB2 hash – stable across launches, unlike Swift's built-in hashValue.
    var hash: UInt64 = 5381
    for byte in tag.utf8 {
        hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
    }
    return palette[Int(hash % UInt64(palette.count))]
}

/// Read-only flow layout of tag pills. Compact display for lists.
struct TagFlowView: View {
    let tags: [String]
    var compact: Bool = false

    var body: some View {
        if !tags.isEmpty {
            FlowLayout(spacing: 4) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(compact ? .system(size: 9) : .caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, compact ? 5 : 7)
                        .padding(.vertical, compact ? 2 : 3)
                        .background(tagColor(for: tag), in: RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }
}

/// Simple wrapping horizontal layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

#Preview {
    TagFlowView(tags: ["Office", "Push Day", "Heavy", "Morning"])
        .padding()
}
