import SwiftUI

/// A card someone just played, sprung from their seat to the middle of the screen.
///
/// Whistles arrive face down. Arming one is deliberately secret — the log only says the
/// referees are watching — so showing the front here would give the trap away.
struct PlayedCardView: View {
    let played: PlayedCard
    let width: CGFloat

    /// One element shrinking away.
    private static let shrink = 0.32
    /// How long the whistle waits after the card before following it.
    private static let stagger = 0.20
    /// How long the pair take to leave, added up rather than guessed — the controller's
    /// hold has to cover this, and a number typed by hand was 0.18s short, which tore the
    /// whistle off the screen a third of the way through its exit.
    static let exitSeconds = shrink + stagger + shrink

    @State private var arrived = false
    /// The whistle lands after the card, not with it — the card is put down, and only
    /// then does the referee's mark come over the top of it.
    @State private var stamped = false
    /// They leave one at a time, in the order they came. Shrinking both at once reads as
    /// the pair being deleted rather than the play being put away.
    @State private var cardGone = false
    @State private var whistleGone = false

    private var origin: UnitPoint {
        switch played.seat.slot(viewedFrom: GameRules.localSeat) {
        case .north: return .top
        case .east:  return .trailing
        case .west:  return .leading
        case .south: return .bottom
        }
    }

    var body: some View {
        GeometryReader { geo in
            let start = CGPoint(x: geo.size.width * origin.x, y: geo.size.height * origin.y)
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            Group {
                if played.faceDown {
                    // A trap, not a card: the back drops back and the whistle sits over
                    // it. `WhistleRevealView` runs this in reverse when it is called.
                    ZStack {
                        Image("CardBackFull")
                            .resizable()
                            .scaledToFit()
                            .frame(width: width)
                            .drawingGroup()
                            // Steps back only once the whistle is over it.
                            .opacity(stamped ? 0.66 : 1)
                            .scaleEffect(cardGone ? 0.01 : 1)
                        Image("GoldWhistle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: width * 0.72)
                            .drawingGroup()
                            .shadow(color: .black.opacity(0.7), radius: 10, y: 3)
                            // Out from the middle of the card rather than down onto it.
                            .scaleEffect(whistleGone ? 0.01 : (stamped ? 1 : 0.15))
                            .opacity(stamped ? 1 : 0)
                    }
                } else {
                    CardFrontView(descriptor: played.descriptor, displayWidth: width)
                        .scaleEffect(cardGone ? 0.01 : 1)
                }
            }
            .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
            .scaleEffect(arrived ? 1 : 0.25)
            .rotationEffect(.degrees(arrived ? 0 : -14))
            .position(arrived ? centre : start)
            .opacity(arrived ? 1 : 0)
        }
        .allowsHitTesting(false)
        .task {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { arrived = true }
            if played.faceDown {
                try? await Task.sleep(for: .seconds(0.42))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { stamped = true }
            }

            // Held, then put away — the card first and the whistle after it, so the mark
            // is the last thing off the table.
            let hold = GameRules.playedCardSeconds - Self.exitSeconds
            try? await Task.sleep(for: .seconds(max(0, hold)))
            withAnimation(.easeIn(duration: Self.shrink)) { cardGone = true }
            guard played.faceDown else { return }
            try? await Task.sleep(for: .seconds(Self.stagger))
            withAnimation(.easeIn(duration: Self.shrink)) { whistleGone = true }
        }
    }
}
