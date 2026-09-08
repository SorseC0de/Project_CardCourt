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
    /// Cards the rules refuse *right now* for a reason that is not a Clamp: Clear Out
    /// after the turn has started, a Move after Triple Threat, a Buzzer Beater off its
    /// clock. Blacked out rather than left looking live — a card you cannot use should
    /// look like one before you tap it.
    var barred: Set<Card.ID> = []
    /// A wash over every card, whatever else is going on. The red one marks a card out;
    /// this one marks the whole hand as not being what is being asked about.
    var wash: Color?
    /// **Cards already played, which the fan has not lost yet.** The hand lags the rules
    /// by a beat, and for that beat the card was on screen twice — held up in front of
    /// the court and apparently stuck in the fan behind it. See
    /// `GameController.justPlayed`.
    var justPlayed: Set<Card.ID> = []
    /// Referees already on the floor. Hung under a Whistle while it is being read.
    var activeReferees: Int = 0
    var onInspectReferees: () -> Void = {}
    /// The card a controller is pointing at, and nothing at all when nobody has one
    /// plugged in — see `PadRing`.
    var ringed: Card.ID?
    /// Handed the mechanic a reader pressed on a raised card — see `CardText`.
    var onKeyword: ((String) -> Void)?
    @Binding var detail: Card?
    var onCommit: (Card) -> Void

    /// **The gesture's own state, not the view's.**
    ///
    /// SwiftUI puts these back the moment the drag ends *or is cancelled*, which is the
    /// whole reason they are not `@State`. Held by hand they were cleared in `onEnded` —
    /// and a gesture whose view is taken away never gets one: a cutscene opening over the
    /// hand, a card leaving it, the floor being handed to a question. The drag then had
    /// nothing to end on, and the card hung exactly where the finger left it — lifted,
    /// upright, out of the fan and over the court — for the rest of the game, through
    /// every screen after it.
    @GestureState private var dragging: Card.ID?
    @GestureState private var drag: CGSize = .zero
    @State private var refused: Card.ID?
    @State private var refusal: CGFloat = 0

    /// How far a card must travel before releasing it counts as playing it.
    private let commitThreshold: CGFloat = 95

    private enum Hand {
        /// How far a chosen card stands out of the fan.
        static let chosenLift: CGFloat = 26
        /// What a card the rules will not take right now wears.
        static let barredWash = CardPalette.black.opacity(0.55)
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
                              isDormant: dormant.contains(card.id),
                              onKeyword: onKeyword)
                    .overlay {
                        // One wash, whatever it is for. A held card wears the same red a
                        // refused one does, because it is the same fact: this one is not
                        // going to be played. A whole hand wears the dark one when the
                        // question on screen is not about cards at all.
                        let marked = selected.contains(card.id) || refused == card.id
                            || locked.contains(card.id)
                        let out = !marked && barred.contains(card.id)
                        if let tint = marked ? Theme.danger.opacity(0.33)
                                             : (out ? Hand.barredWash : wash) {
                            RoundedRectangle(cornerRadius: 76 * CardLayout.cornerFraction,
                                             style: .continuous)
                                .fill(tint)
                                .overlay {
                                    if marked {
                                        RoundedRectangle(
                                            cornerRadius: 76 * CardLayout.cornerFraction,
                                            style: .continuous)
                                            .stroke(Theme.danger, lineWidth: 2.5)
                                    }
                                }
                                .allowsHitTesting(false)
                        }
                    }
                    // Half off the bottom edge, and inside the card's own frame so it
                    // grows with the card rather than sitting there at hand size while
                    // the card doubles around it.
                    .overlay(alignment: .bottom) {
                        if expanded, card.descriptor.whistle != nil, activeReferees > 0 {
                            RefereeTally(count: activeReferees, side: 11,
                                         onOpen: onInspectReferees)
                                .alignmentGuide(.bottom) { $0[VerticalAlignment.center] }
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    // Gone the instant it is played, not a beat later — and gone means
                    // out of reach as well as out of sight, or the beat it is invisible
                    // for is a beat it can be played a second time.
                    .opacity(justPlayed.contains(card.id) ? 0 : 1)
                    .allowsHitTesting(!justPlayed.contains(card.id))
                    .padRing(ringed == card.id && !justPlayed.contains(card.id),
                             corner: 76 * CardLayout.cornerFraction)
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
                            .updating($dragging) { _, held, _ in held = card.id }
                            .updating($drag) { value, moved, _ in moved = value.translation }
                            .onEnded { value in
                                let cleared = -value.translation.height > commitThreshold
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
