import SwiftUI

/// A row of cards, and one of them taken.
///
/// The shape every "pick one of these" in the game uses: laid on the mode card, tapped to
/// raise, confirmed underneath. `hidden` names the ones the picker may not read — Wet
/// Spot shows what is still in the deck face down, because knowing an Injury is in there
/// is not the same as knowing which.
struct CardChoiceView: View {
    let title: String
    let note: String
    let offered: [CardDescriptor]
    var hidden: Set<String> = []
    var tint: Color = CardPalette.red
    var onPick: (String) -> Void

    @State private var chosen: String?

    private enum Table {
        static let card: CGFloat = 66
        static let lift: CGFloat = 18
    }

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()

            ModeCardView(title: title, subtitle: note, ink: .white, subtitleInk: tint,
                         accessory: AnyView(table), isLeaving: false,
                         onLanded: {}, onFinished: {})
        }
        .transition(.opacity)
    }

    private var table: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(offered, id: \.id) { card in
                        face(card)
                            .offset(y: chosen == card.id ? -Table.lift : 0)
                            .onTapGesture { chosen = card.id }
                    }
                }
                .padding(.vertical, Table.lift)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 320)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: chosen)

            ChunkyButton(title: chosen == nil ? "Pick one" : "Take it",
                         fill: chosen == nil ? CardPalette.gray : tint,
                         stroke: CardPalette.gold, shade: CardPalette.orange,
                         size: 18, isEnabled: chosen != nil) {
                if let chosen { onPick(chosen) }
            }
            .frame(width: 200)
        }
        .fixedSize()
    }

    @ViewBuilder private func face(_ card: CardDescriptor) -> some View {
        let on = chosen == card.id
        Group {
            if hidden.contains(card.id) {
                Image("CardBackFull").resizable().scaledToFit().frame(width: Table.card)
            } else {
                CardFrontView(descriptor: card, displayWidth: Table.card)
            }
        }
        .overlay {
            if on {
                RoundedRectangle(cornerRadius: Table.card * CardLayout.cornerFraction,
                                 style: .continuous)
                    .strokeBorder(CardPalette.gold, lineWidth: 4)
            }
        }
        .shadow(color: .black.opacity(0.5), radius: on ? 10 : 4, y: on ? 6 : 2)
    }
}
