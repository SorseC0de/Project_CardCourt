import SwiftUI

/// The gold ring and the lift that say which one is chosen.
private struct Picked: ViewModifier {
    let on: Bool
    let side: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                if on {
                    RoundedRectangle(cornerRadius: side * CardLayout.cornerFraction,
                                     style: .continuous)
                        .strokeBorder(CardPalette.gold, lineWidth: 4)
                }
            }
            .shadow(color: .black.opacity(0.5), radius: on ? 10 : 4, y: on ? 6 : 2)
    }
}

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
    /// Cards that can only be pointed at — a hand nobody may read. Drawn as backs after
    /// the named ones, and answered by position.
    var backs: Int = 0
    var tint: Color = CardPalette.red
    /// What taking it is called, when "Take it" is not what is being done.
    var taking: String = "Take it"
    /// What declining is called, when declining is allowed at all.
    var declining: String?
    /// **Held outside.** A pad picks the same way a finger does, and both have to be
    /// picking the same card — see `GameView.picked`.
    @Binding var chosen: CardPick?
    /// The one a controller is pointing at, which is not the same as the one taken.
    var ringed: PadSpot?
    var onDecline: () -> Void = {}
    var onPick: (CardPick) -> Void

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
                        face(card, pick: .named(card.id))
                            .padRing(ringed == .offer(.named(card.id)),
                                     corner: Table.card * CardLayout.cornerFraction)
                            .offset(y: chosen == .named(card.id) ? -Table.lift : 0)
                            .onTapGesture { chosen = .named(card.id) }
                    }
                    // A hand is held, not laid out: what is face down fans.
                    if backs > 0 {
                        CardBackFan(count: backs, width: Table.card, lift: Table.lift,
                                    tint: tint,
                                    isChosen: { chosen == .position($0) },
                                    ringed: { if case .offer(.position(let at)) = ringed
                                              { return at } else { return nil } }(),
                                    onPick: { chosen = .position($0) })
                    }
                }
                .padding(.vertical, Table.lift)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 320)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: chosen)

            VStack(spacing: 8) {
                ChunkyButton(title: chosen == nil ? "Pick one" : taking,
                             fill: chosen == nil ? CardPalette.gray : tint,
                             stroke: CardPalette.gold, shade: CardPalette.orange,
                             size: 18, isEnabled: chosen != nil) {
                    if let chosen { onPick(chosen) }
                }
                .padRing(pill: ringed == .confirm)
                if let declining {
                    ChunkyButton(title: declining, fill: CardPalette.navy,
                                 stroke: CardPalette.gray, shade: CardPalette.black,
                                 size: 16, run: onDecline)
                        .padRing(pill: ringed == .decline)
                }
            }
            .frame(width: 200)
        }
        .fixedSize()
    }

    @ViewBuilder private func back(pick: CardPick) -> some View {
        Image("CardBackFull").resizable().scaledToFit().frame(width: Table.card)
            .modifier(Picked(on: chosen == pick, side: Table.card))
    }

    @ViewBuilder private func face(_ card: CardDescriptor, pick: CardPick) -> some View {
        let on = chosen == pick
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
