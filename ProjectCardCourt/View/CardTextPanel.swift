import SwiftUI

/// **The card you are reading, set out in full**, in the room beside the board.
///
/// A card in the hand is small enough to hold a dozen of and too small to read, and the
/// raised card covered the floor to say four lines. The words live here instead: what it
/// is, what it does, and what it pays for a combo or a bonus, all at once and all at a
/// size that can be read without taking the game off the screen.
struct CardTextPanel: View {
    let card: CardDescriptor

    @State private var tuning = CardTextTuning.shared

    private enum Panel {
        static let name: CGFloat = 19
        static let type: CGFloat = 12
        static let text: CGFloat = 15
        static let label: CGFloat = 11
        static let gap: CGFloat = 5
        static let corner: CGFloat = 8
        /// How far the words may shrink to fit the band they are given.
        static let shrink: CGFloat = 0.7
    }

    private var face: CardFace { CardFace(of: card) }

    var body: some View {
        VStack(alignment: .leading, spacing: Panel.gap) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                SmallCapsText(text: card.name, font: Chrome.display, size: Panel.name,
                              tracking: Panel.name * 0.02)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                SmallCapsText(text: card.type.rawValue, font: Chrome.display, size: Panel.type,
                              tracking: Panel.type * 0.08)
                    .foregroundStyle(LogView.ink(for: card.type))
            }
            .shadow(color: CardPalette.black, radius: 0, x: 2, y: 2)

            CardText(text: card.effect, font: CardFont.name(tuning.weight),
                     size: Panel.text, lineHeight: 1.05, maxLines: 8,
                     minScale: Panel.shrink,
                     ink: .white, highlight: tuning.highlight, face: face)

            if let bonus = card.bonus { clause("Bonus", bonus) }
            if let combo = card.combo {
                clause(Combo.involving(card).first?.name ?? "Combo", combo)
            }
            Spacer(minLength: 0)
        }
        // **Whatever room it is given**: the band under the names, edge to edge.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.panel)
        .overlay(alignment: .top) {
            Rectangle().fill(CardSkin.of(face).ring).frame(height: 2)
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    /// One of the two extra clauses, under its own heading.
    private func clause(_ heading: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            SmallCapsText(text: heading, font: Chrome.display, size: Panel.label,
                          tracking: Panel.label * 0.1)
                .foregroundStyle(CardPalette.gold)
            CardText(text: text, font: CardFont.name(tuning.weight),
                     size: Panel.text - 2, lineHeight: 1.05, maxLines: 8,
                     ink: .white, highlight: tuning.highlight, face: face)
        }
    }
}

#if DEBUG
#Preview("Card text") {
    VStack(spacing: 10) {
        CardTextPanel(card: CardLibrary.crossover)
        CardTextPanel(card: CardLibrary.curlCut)
    }
    .frame(width: 240)
    .padding(20)
    .background(Theme.sceneGround)
}
#endif
