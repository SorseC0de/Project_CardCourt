import SwiftUI

/// What a mechanic means, said when somebody presses it on a card they are reading.
///
/// **Small and in the way of nothing.** It is a footnote a player asked for mid-hand, not
/// a screen — so it sits over the card rather than replacing it, and anything dismisses
/// it. See `Glossary`, which holds the words, and `CardText`, which makes them pressable.
struct GlossaryPopup: View {
    let title: String
    let says: String
    var onDismiss: () -> Void

    private enum Note {
        static let width: CGFloat = 268
        static let corner: CGFloat = 14
        /// South-east, three deep, like every other panel in the game.
        static let drop: CGFloat = 3
    }

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 8) {
                SmallCapsText(text: title, font: Chrome.display, size: 20,
                              tracking: 1.2)
                    .foregroundStyle(CardPalette.gold)
                    .shadow(color: CardPalette.orange, radius: 0,
                            x: Note.drop, y: Note.drop)
                Text(says)
                    .font(.custom(CardFont.name(CardTextTuning.shared.weight), size: 16))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: Note.width, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Note.corner, style: .continuous)
                    .fill(CardPalette.navy)
                    .overlay(
                        RoundedRectangle(cornerRadius: Note.corner, style: .continuous)
                            .strokeBorder(CardPalette.gold, lineWidth: 3))
                    .shadow(color: CardPalette.black, radius: 0,
                            x: Note.drop, y: Note.drop))
            .onTapGesture(perform: onDismiss)
        }
        .transition(.opacity)
    }
}
