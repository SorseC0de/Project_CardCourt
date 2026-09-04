import SwiftUI

/// The Bag, arced into a fan and laid straight over the court.
///
/// Gestures, per card: tap raises the full text, tapping again while that is up commits
/// it, and dragging it clear of the log commits it directly. A drag that stops short
/// snaps home. Cards are only removed by the game, never by the drag, so the gap a
/// lifted card leaves stays open until it has actually gone.
struct FannedBagView: View {
    let cards: [Card]
    let seat: Seat
    let lastPasser: Seat?
    let playable: Set<Card.ID>
    /// Playable, but currently unable to do anything.
    var dormant: Set<Card.ID> = []
    /// Rebound bids and Turnaround Three pick cards rather than playing one.
    let isSelecting: Bool
    let selected: Set<Card.ID>
    /// Cards a Clamp is holding down — see `Rules.lockedCards`.
    var locked: Set<Card.ID> = []
    @Binding var detail: Card?
    var onCommit: (Card) -> Void

    @State private var dragging: Card.ID?
    @State private var drag: CGSize = .zero
    @State private var refused: Card.ID?
    @State private var refusal: CGFloat = 0

    /// How far a card must travel before releasing it counts as playing it.
    private let commitThreshold: CGFloat = 95

    private enum Hand {
        /// How far a chosen card stands out of the fan.
        static let chosenLift: CGFloat = 26
    }

    private var arc: (spread: Double, radius: CGFloat) {
        let count = max(cards.count, 1)
        // Tighten as the hand grows, so twelve cards do not wrap into a circle.
        return (min(46, Double(count) * 7), 300)
    }

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let placement = placement(index)
                let lifted = dragging == card.id
                let expanded = detail?.id == card.id && dragging == nil

                CardFrontView(descriptor: card.descriptor, displayWidth: 76,
                              expanded: expanded,
                              isDormant: dormant.contains(card.id))
                    .overlay {
                        // A held card wears the same wash a refused one does, because
                        // it is the same fact: this one is not going to be played.
                        if selected.contains(card.id) || refused == card.id
                            || locked.contains(card.id) {
                            RoundedRectangle(cornerRadius: 76 * CardLayout.cornerFraction,
                                             style: .continuous)
                                .fill(Theme.danger.opacity(0.33))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 76 * CardLayout.cornerFraction,
                                                     style: .continuous)
                                        .stroke(Theme.danger, lineWidth: 2.5)
                                }
                                .allowsHitTesting(false)
                        }
                    }
                    .modifier(ShakeEffect(progress: refused == card.id ? refusal : 0))
                    .rotationEffect(.degrees(lifted || expanded ? 0 : placement.angle))
                    // Grown from the bottom edge, so it rises out of the hand rather
                    // than pushing down off the screen.
                    .scaleEffect(expanded ? 2 : (lifted ? 1.08 : 1), anchor: .bottom)
                    // Chosen cards stand out of the fan. On a rebound you can flick them
                    // up and they stay there, which is the whole gesture.
                    .offset(x: placement.x + (lifted ? drag.width : 0),
                            y: placement.y + (lifted ? drag.height : 0) + (expanded ? -14 : 0)
                               + (selected.contains(card.id) || locked.contains(card.id)
                                  ? -Hand.chosenLift : 0))
                    .shadow(color: .black.opacity(lifted || expanded ? 0.5 : 0.28),
                            radius: lifted || expanded ? 14 : 4, y: lifted || expanded ? 10 : 2)
                    .zIndex(expanded ? 200 : (lifted ? 100 : Double(index)))
                    .onTapGesture { tap(card) }
                    // A minimum distance so a tap is never read as a drag.
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onChanged { value in
                                dragging = card.id
                                drag = value.translation
                            }
                            .onEnded { value in
                                let cleared = -value.translation.height > commitThreshold
                                dragging = nil
                                drag = .zero
                                guard isSelecting || playable.contains(card.id) else {
                                    if cleared { refuse(card) }
                                    return
                                }
                                if cleared { onCommit(card) }
                            }
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.72), value: dragging)
                    .animation(.spring(response: 0.32, dampingFraction: 0.74), value: detail?.id)
                    .animation(.spring(response: 0.34, dampingFraction: 0.78), value: cards.count)
            }
        }
        .frame(height: 132)
    }

    private func tap(_ card: Card) {
        guard detail?.id == card.id else {
            detail = card
            return
        }
        // A second tap only ever plays a card the rules currently allow. Checked here
        // rather than trusting the handler, so an out-of-turn tap can never get through.
        guard isSelecting || playable.contains(card.id) else { refuse(card); return }
        detail = nil
        onCommit(card)
    }

    /// Says no out loud: a damped shake and a red wash that fades straight back out.
    private func refuse(_ card: Card) {
        refused = card.id
        refusal = 0
        withAnimation(.easeOut(duration: 0.45)) { refusal = 1 }
        Task {
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.easeOut(duration: 0.2)) { refused = nil }
            refusal = 0
        }
    }

    /// Position on the arc. One card sits dead centre rather than off at an angle.
    private func placement(_ index: Int) -> (x: CGFloat, y: CGFloat, angle: Double) {
        guard cards.count > 1 else { return (0, 0, 0) }
        let (spread, radius) = arc
        let t = Double(index) / Double(cards.count - 1) - 0.5
        let angle = spread * t
        let radians = angle * .pi / 180
        return (radius * CGFloat(sin(radians)),
                radius * CGFloat(1 - cos(radians)),
                angle)
    }
}
