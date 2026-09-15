import SwiftUI

/// **A card's bonus, hung off its BONUS button.** Blue with a gold drop, in the game's own
/// lettering — the system popover wore the phone's theme, and navy text on a dark one could
/// not be read. A tap anywhere puts it away.
struct BonusBubble: View {
    let lines: [String]
    /// The top-middle of the button, on screen.
    let anchor: CGPoint
    let onDismiss: () -> Void

    @State private var tuning = CardTextTuning.shared

    private enum Layout {
        static let width: CGFloat = 250
        static let text: CGFloat = 16
        static let padding: CGFloat = 14
        static let corner: CGFloat = 14
        static let drop: CGFloat = 4
        /// Between the bubble and the button it hangs off.
        static let gap: CGFloat = 10
        /// Kept clear of the screen's edges.
        static let margin: CGFloat = 12
    }

    var body: some View {
        GeometryReader { screen in
            let origin = screen.frame(in: .global).origin
            let above = max(0, anchor.y - origin.y - Layout.gap)
            let across = min(max(anchor.x - origin.x, Layout.width / 2 + Layout.margin),
                             screen.size.width - Layout.width / 2 - Layout.margin)
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                // Its bottom edge sits just above the button, whatever height the words make it.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    bubble
                }
                .frame(width: Layout.width, height: above)
                .position(x: across, y: above / 2)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines, id: \.self) { line in
                // Read as a Pass reads its mechanics: orange, which holds on the blue.
                CardText(text: line, font: CardFont.name(tuning.weight), size: Layout.text,
                         ink: .white, highlight: tuning.highlight, face: .pass)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Layout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Layout.corner, style: .continuous)
            .fill(CardPalette.blue)
            .shadow(color: CardPalette.gold, radius: 0, x: Layout.drop, y: Layout.drop))
    }
}
