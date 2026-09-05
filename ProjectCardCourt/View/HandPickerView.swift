import SwiftUI

/// Somebody else's hand, face down, and a card taken out of it.
///
/// The whole point is that it is a guess: the cards are backs, fanned the way a hand is
/// held, and picking one is picking a position rather than a card. Raised and washed red
/// so the choice is visible before it is committed — a card taken from a hand you cannot
/// see should at least be a decision you can change your mind about.
///
/// Laid over the mode card's own shape, which is what the game says things on.
struct HandPickerView: View {
    let card: CardDescriptor
    let victim: Seat
    let hand: Int
    var onPick: (Int) -> Void

    @State private var chosen: Int?

    private enum Fan {
        static let card: CGFloat = 62
        static let lift: CGFloat = 26
        /// How far the fan opens, in degrees across the whole hand.
        static let spread: Double = 34
        static let radius: CGFloat = 260
    }

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()

            ModeCardView(title: "\(victim.playerName)'s Hand",
                         subtitle: card.name,
                         ink: .white,
                         subtitleInk: .white,
                         seat: victim,
                         accessory: AnyView(fan),
                         isLeaving: false,
                         onLanded: {},
                         onFinished: {})
        }
        .transition(.opacity)
    }

    private var fan: some View {
        VStack(spacing: 14) {
            ZStack {
                ForEach(0..<hand, id: \.self) { index in
                    let along = hand > 1 ? Double(index) / Double(hand - 1) - 0.5 : 0
                    let angle = along * Fan.spread
                    back(index)
                        .rotationEffect(.degrees(angle), anchor: .bottom)
                        .offset(y: -Fan.radius * CGFloat(1 - cos(angle * .pi / 180)))
                        .offset(y: chosen == index ? -Fan.lift : 0)
                        .zIndex(chosen == index ? 1 : 0)
                        .onTapGesture { chosen = index }
                }
            }
            .frame(height: Fan.card / CardMetrics.aspect + Fan.lift)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: chosen)

            ChunkyButton(title: chosen == nil ? "Pick one" : "Take it",
                         fill: chosen == nil ? CardPalette.gray : CardPalette.red,
                         stroke: CardPalette.gold, shade: CardPalette.orange,
                         size: 18, isEnabled: chosen != nil) {
                if let chosen { onPick(chosen) }
            }
            .frame(width: 200)
        }
        .fixedSize()
    }

    private func back(_ index: Int) -> some View {
        Image("CardBackFull")
            .resizable()
            .scaledToFit()
            .frame(width: Fan.card)
            .overlay {
                if chosen == index {
                    RoundedRectangle(cornerRadius: Fan.card * CardLayout.cornerFraction,
                                     style: .continuous)
                        .fill(Theme.danger.opacity(0.45))
                        .overlay {
                            RoundedRectangle(cornerRadius: Fan.card * CardLayout.cornerFraction,
                                             style: .continuous)
                                .stroke(Theme.danger, lineWidth: 3)
                        }
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
    }
}
