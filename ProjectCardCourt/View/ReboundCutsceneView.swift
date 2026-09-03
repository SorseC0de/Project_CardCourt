import SwiftUI

/// The rebound phase, played as a cutscene: the ball loose and spinning, streaks
/// tearing past behind it, while everyone commits a hidden bid.
struct ReboundCutsceneView: View {
    let shooter: Seat
    let revealedBids: [Seat: Int]?
    /// The board comes with, because a bid is a decision and SHOT is what it is made on.
    let state: GameState
    /// What the board should read. The scene is played after the rules have run, so the
    /// live numbers are already the ones from the other side of it.
    var shot: Int?
    var deck: Int?

    @State private var spin = false
    @State private var lift = false

    private var order: [Seat] { shooter.clockwiseOrderFromHere }

    /// How far the title and ball ride above centre.
    private static let lift: CGFloat = 44
    /// Where the bids sit, measured from centre rather than from the ball — which is the
    /// whole point of them being a separate layer.
    private static let bidsY: CGFloat = 96

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
                SwisshTitle(text: revealedBids == nil ? "Loose Ball!" : "Crashing the Glass!",
                            size: 34)

                BallView(diameter: 150)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .offset(y: lift ? -7 : 7)
                    .shadow(color: Theme.ball.opacity(0.55), radius: 14)
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
                                Text(seat.playerName.uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Theme.inkDim)
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
                } else {
                    Text("\(shooter.isLocal ? "your" : shooter.playerName + "'s") miss · SHOT stays live")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.inkDim)
                }
            }
            .offset(y: Self.bidsY)
        }
        // The board, larger than the court draws it. A bid is a decision and this is the
        // only number it is made on, so it belongs in the room.
        .overlay(alignment: .topTrailing) {
            StatusHUDView(state: state, shot: shot, deck: deck, ballSize: 74)
                .padding(.trailing, 20)
                .padding(.top, 14)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: revealedBids)
        .onAppear {
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { lift = true }
        }
    }
}
