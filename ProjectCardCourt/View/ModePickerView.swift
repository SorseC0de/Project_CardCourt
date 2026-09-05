import SwiftUI

/// A card that offers a choice, and the choice.
///
/// Triple Threat is the only one so far. The card is held up so the branches are read
/// against the thing offering them, rather than as three buttons with no context.
struct ModePickerView: View {
    let card: CardDescriptor
    var onPick: (Int) -> Void

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()

            VStack(spacing: 18) {
                CardFrontView(descriptor: card, displayWidth: 150, expanded: true)
                    .shadow(color: .black.opacity(0.55), radius: 20, y: 10)

                VStack(spacing: 10) {
                    ForEach(Array(card.modes.enumerated()), id: \.offset) { index, mode in
                        ChunkyButton(title: mode.label, fill: CardPalette.gold,
                                     stroke: CardPalette.gold, shade: CardPalette.orange,
                                     size: 20) { onPick(index) }
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
    }
}
