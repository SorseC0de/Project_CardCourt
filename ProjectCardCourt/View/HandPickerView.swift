import SwiftUI

/// A hand held face down: backs fanned the way a hand is held, and picked by position.
///
/// Shared, because every "point at one of these" in the game is the same gesture — a hand
/// laid out in a straight row is a row of cards, not a hand somebody is holding.
struct CardBackFan: View {
    let count: Int
    var width: CGFloat = 62
    var lift: CGFloat = 26
    /// How far the fan opens, in degrees across the whole hand, and the radius it opens
    /// around. **The hand's own numbers** — see `FannedBagView.arc`, which is the arc every
    /// hand in the game is laid out on, tightening as it grows so a big one does not wrap
    /// into a circle.
    var radius: CGFloat = 300
    var tint: Color = Theme.danger
    var isChosen: (Int) -> Bool
    var onPick: (Int) -> Void

    private var spread: Double { min(46, Double(max(count, 1)) * 7) }

    /// Where a card sits on the arc: along it, out from its centre, and turned to face
    /// out of it. Stacking them on one spot and only turning them — which is what this
    /// was doing — is a pile of cards, not a hand being held.
    private func placement(_ index: Int) -> (x: CGFloat, y: CGFloat, angle: Double) {
        guard count > 1 else { return (0, 0, 0) }
        let t = Double(index) / Double(count - 1) - 0.5
        let angle = spread * t
        let radians = angle * .pi / 180
        return (radius * CGFloat(sin(radians)),
                radius * CGFloat(1 - cos(radians)),
                angle)
    }

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let at = placement(index)
                back(index)
                    .rotationEffect(.degrees(at.angle), anchor: .bottom)
                    .offset(x: at.x, y: at.y + (isChosen(index) ? -lift : 0))
                    .zIndex(isChosen(index) ? 1 : 0)
                    .onTapGesture { onPick(index) }
            }
        }
        .frame(width: width + CGFloat(max(0, count - 1)) * width * 0.62,
               height: width / CardMetrics.aspect + lift)
    }

    private func back(_ index: Int) -> some View {
        Image("CardBackFull")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .overlay {
                if isChosen(index) {
                    RoundedRectangle(cornerRadius: width * CardLayout.cornerFraction,
                                     style: .continuous)
                        .fill(tint.opacity(0.45))
                        .overlay {
                            RoundedRectangle(cornerRadius: width * CardLayout.cornerFraction,
                                             style: .continuous)
                                .stroke(tint, lineWidth: 3)
                        }
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
    }
}

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
            CardBackFan(count: hand,
                        isChosen: { chosen == $0 },
                        onPick: { chosen = $0 })
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
}
