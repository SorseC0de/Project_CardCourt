import SwiftUI

/// The rebound phase, played as a cutscene: the ball loose and spinning, streaks
/// tearing past behind it, while everyone commits a hidden bid.
struct ReboundCutsceneView: View {
    let shooter: Seat
    let revealedBids: [Seat: Int]?
    /// The table, for Monster Ball's board. SHOT is read off the screen's own HUD, over
    /// the top of this — the scene drew a second one of its own.
    let state: GameState
    /// What the miss was taken at, which is not what the board reads — a shot can be
    /// priced above or below the ball's SHOT by whatever paid for it.
    var chance: Int?

    @State private var spin = false
    @State private var lift = false
    /// Monster Ball's card shakes where the ball would be: lightly, and quickly.
    @State private var shake = false

    /// **Monster Ball's board**: the Intangible up for grabs, and the two after it.
    private var prize: CardDescriptor? { state.intangibleBoard.first }
    private var upNext: [CardDescriptor] { Array(state.intangibleBoard.dropFirst().prefix(2)) }

    private var order: [Seat] { shooter.clockwiseOrderFromHere }

    /// How far the title and ball ride above centre.
    private static let lift: CGFloat = 44
    /// Where the bids sit, measured from centre rather than from the ball — which is the
    /// whole point of them being a separate layer.
    ///
    /// **Above the title.** Below it they landed in the band the hand occupies, and the
    /// one thing on this screen you have to read was the one thing covered up.
    private static let bidsY: CGFloat = -180

    var body: some View {
        // Centred. The board used to share this alignment, which pinned the ball and the
        // title to the right edge along with it and put the two on top of each other.
        ZStack {
            Rectangle()
                .fill(Color.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            SideStreaks()

            // The title and the ball, and nothing else. They were stacked with the bids,
            // so the row of bids appearing grew the stack and re-centred it — which shoved
            // both of these upward at the exact moment the scene was meant to hold still.
            // Their own layer, at their own offset, and nothing below can reach them.
            VStack(spacing: 10) {
                // The same lettering a made shot gets. This is a moment, not a caption.
                SwishTitle(text: prize != nil ? "Monster Ball!"
                                : (revealedBids == nil ? "Rebound!" : "Crashing the Glass!"),
                            size: 34)

                // Under the line it belongs to. Down at the bids' offset it was in the
                // band the hand occupies, which is where it was being read from.
                //
                // Always drawn, and only faded: the stack is centred on its own height, so
                // a line that comes and goes moves the title and the ball with it.
                Text(prize.map { "Up for grabs: \($0.name)" }
                     ?? ("\(shooter.isLocal ? "Your" : shooter.playerName + "'s") miss"
                         + (chance.map { " (\($0)%)" } ?? "")))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkDim)
                    .opacity(revealedBids == nil ? 1 : 0)

                if let prize {
                    HStack(alignment: .center, spacing: 14) {
                        CardFrontView(descriptor: prize, displayWidth: 110)
                            .rotationEffect(.degrees(shake ? -2 : 2))
                            .offset(x: shake ? -1.5 : 1.5)
                            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                        VStack(spacing: 8) {
                            ForEach(Array(upNext.enumerated()), id: \.offset) { _, next in
                                CardFrontView(descriptor: next, displayWidth: 44)
                                    .opacity(0.6)
                            }
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: prize)
                } else {
                    BallView(diameter: 150)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .offset(y: lift ? -7 : 7)
                        .shadow(color: Theme.ball.opacity(0.55), radius: 14)
                }
            }
            // Clear of the hand, which the centred stack was sitting on top of.
            .offset(y: -Self.lift)

            // The bids, placed from the centre of the screen rather than from the bottom
            // of whatever happens to be above them.
            Group {
                if let revealedBids {
                    // Revealed shooter-first then clockwise, the order the rule names.
                    HStack(spacing: 10) {
                        ForEach(order, id: \.self) { seat in
                            VStack(spacing: 2) {
                                PlayerNameText(seat: seat, size: 12)
                                Text("\(revealedBids[seat] ?? 0)")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                                    .frame(width: 26, height: 24)
                                    .background(RoundedRectangle(cornerRadius: 6)
                                        .fill(Theme.color(for: seat).opacity(0.85)))
                            }
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .offset(y: Self.bidsY)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: revealedBids)
        .onAppear {
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { lift = true }
            withAnimation(.easeInOut(duration: 0.07).repeatForever(autoreverses: true)) { shake = true }
        }
    }
}
