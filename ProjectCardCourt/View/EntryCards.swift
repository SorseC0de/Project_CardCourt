import SwiftUI

/// **The hand the front screen is holding.**
///
/// A fan of backs laid across the top of the entry screen, dealt in when the screen
/// opens and never quite still afterwards. The deck elsewhere in this game is written as
/// an enchanted object with a repertoire — see `DeckStage` — and this is the flat,
/// cheap version of the same idea: three routines by name, running off one clock.
///
/// - **Deal** — the cards arrive one at a time from below the screen, each turning up
///   into its place in the arc and overshooting it slightly before settling.
/// - **Breathe** — the fan is never static. Every card sways on its own phase, so the
///   arc reads as held rather than printed.
/// - **Riffle** — every few seconds a lift travels along the fan, one card after the
///   next, the way a thumb runs down a hand being squared up.
///
/// Nothing here can be pressed: it is scenery, and the buttons are underneath it.
struct EntryCards: View {
    /// How many backs are in the hand.
    var count = 7
    /// One card's width. Everything else is a share of it.
    var width: CGFloat = 118
    /// How far apart the cards sit at the wrist, as a share of a card's width.
    var step: CGFloat = 0.42
    /// The whole arc, in degrees.
    var spread: Double = 58
    /// How far the middle of the arc rises above its ends, as a share of a card's width.
    var arc: CGFloat = 0.20
    /// Held back so the screen is up before the hand arrives.
    var wait: TimeInterval = 0.35

    private var height: CGFloat { width / CardMetrics.aspect }

    /// One card's place in the arc, and the phase that keeps it out of step with its
    /// neighbours. Worked out once per card rather than per frame.
    private struct Slot {
        let x: CGFloat
        let y: CGFloat
        let turn: Double
        let phase: Double
        /// When this card leaves the dealer's hand.
        let dealt: TimeInterval
    }

    private var slots: [Slot] {
        let middle = Double(count - 1) / 2
        return (0..<count).map { index in
            let off = Double(index) - middle
            let share = middle == 0 ? 0 : off / middle
            return Slot(x: CGFloat(off) * width * step,
                        // A parabola, so the ends of the fan hang and the middle stands.
                        y: CGFloat(share * share) * width * arc,
                        turn: share * spread / 2,
                        // Irrational enough that seven cards never line back up.
                        phase: Double(index) * 1.618,
                        dealt: wait + Double(index) * Deal.apart)
        }
    }

    private enum Deal {
        /// How long one card takes to fly from the dealer to its place.
        static let flight: TimeInterval = 0.62
        /// The gap between one card leaving and the next.
        static let apart: TimeInterval = 0.11
        /// How far below the screen they come from, as a share of a card's height.
        static let from: CGFloat = 2.4
        /// How far off to the side, as a share of a card's width. They arrive from one
        /// hand rather than from directly underneath.
        static let side: CGFloat = 1.9
        /// The turn a card carries on the way in, on top of where it is going.
        static let tumble: Double = -38
    }

    private enum Drop {
        /// How far the hard drop falls behind a card, as a share of its width. The cards'
        /// own, so a back on the front screen and one on the table fall the same way.
        static let away: CGFloat = 0.03
    }

    private enum Breath {
        /// A full sway, in seconds.
        static let period: Double = 4.4
        /// How far a card turns as it sways.
        static let turn: Double = 1.7
        /// And how far it rises, as a share of a card's height.
        static let rise: CGFloat = 0.022
    }

    private enum Riffle {
        /// How often the lift runs along the hand.
        static let every: Double = 7.0
        /// How long the lift takes to cross the whole fan.
        static let across: Double = 0.62
        /// How much of the fan is off the ground at once, in cards.
        static let width: Double = 1.15
        /// How high a card gets, as a share of its own height.
        static let lift: CGFloat = 0.11
        /// And how far it turns at the top of that.
        static let turn: Double = 5
    }

    /// When the screen opened, so the deal runs from the first frame this is on screen
    /// rather than from whenever the app started.
    @State private var opened = Date.timeIntervalSinceReferenceDate

    var body: some View {
        TimelineView(.animation) { pass in
            let since = pass.date.timeIntervalSinceReferenceDate - opened
            let hand = slots
            ZStack {
                ForEach(Array(hand.enumerated()), id: \.offset) { index, slot in
                    card(slot, index: index, since: since)
                }
            }
        }
        .frame(width: width * (CGFloat(count - 1) * step + 1.6), height: height * 1.6)
        .allowsHitTesting(false)
    }

    private func card(_ slot: Slot, index: Int, since: TimeInterval) -> some View {
        // How far into its flight this card is. Nothing before it is dealt, and one all
        // the way through once it has landed.
        let flying = min(max((since - slot.dealt) / Deal.flight, 0), 1)
        let landed = overshoot(flying)

        // The two idles only start once the card is down, so a card still in the air is
        // not also breathing.
        let settled = flying >= 1 ? 1.0 : 0.0
        let breath = sin(since * .pi * 2 / Breath.period + slot.phase) * settled
        let wave = riffle(at: since, card: index) * settled

        let x = slot.x + (1 - landed) * width * Deal.side
        let y = slot.y + (1 - landed) * height * Deal.from
            - CGFloat(breath) * height * Breath.rise
            - CGFloat(wave) * height * Riffle.lift
        let turn = slot.turn + (1 - landed) * Deal.tumble
            + breath * Breath.turn
            + wave * Riffle.turn

        // **The drop is a shape, not a shadow.** Every card is redrawn each frame, and a
        // `shadow` costs an offscreen pass apiece for something that is only ever the
        // card's own outline moved three points — which a rounded rectangle *is*.
        return ZStack {
            RoundedRectangle(cornerRadius: width * CardLayout.cornerFraction,
                             style: .continuous)
                .fill(CardPalette.navy)
                .frame(width: width, height: height)
                .offset(x: width * Drop.away, y: width * Drop.away)
            Image("CardBackFull")
                .resizable()
                .scaledToFit()
                .frame(width: width)
        }
            .rotationEffect(.degrees(turn), anchor: .bottom)
            .offset(x: x, y: y)
            .opacity(flying > 0 ? 1 : 0)
    }

    /// The last tenth of the flight, spent going slightly too far and coming back.
    ///
    /// A card that decelerates cleanly into its place looks placed; one that arrives a
    /// touch past where it belongs and rocks back looks thrown, which is what a deal is.
    private func overshoot(_ t: Double) -> CGFloat {
        guard t > 0 else { return 0 }
        guard t < 1 else { return 1 }
        let eased = 1 - pow(1 - t, 3)
        return CGFloat(eased + sin(t * .pi) * 0.06)
    }

    /// Where the lift is along the hand, and how much of it this card has.
    ///
    /// One bump travelling from the first card to the last and then nothing at all until
    /// the next time round, rather than a wave running continuously — a hand being
    /// squared up is a thing that happens now and then.
    private func riffle(at since: Double, card index: Int) -> Double {
        let into = since.truncatingRemainder(dividingBy: Riffle.every)
        guard into < Riffle.across else { return 0 }
        let head = (into / Riffle.across) * Double(count - 1)
        let away = abs(Double(index) - head) / Riffle.width
        guard away < 1 else { return 0 }
        // A cosine bump: nothing at the edges of the lift, all of it at the middle.
        return (cos(away * .pi) + 1) / 2
    }
}

#if DEBUG
#Preview("Entry cards") {
    ZStack {
        CardPalette.blue.ignoresSafeArea()
        EntryCards()
    }
}
#endif
