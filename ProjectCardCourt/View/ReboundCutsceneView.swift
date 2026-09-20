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

    @State private var tuning = ReboundSceneTuning.shared
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
    /// **What a bidder is drawn at**: his head, his name, and what he has to bid with.
    private static let head: CGFloat = 4
    private static let name: CGFloat = 17
    private static let count: CGFloat = 18
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
                // **The clock stands over it.** A board is played against the same
                // twenty-four the possession was, and it is the one number a bid is
                // actually weighed against.
                ShotClockBoard(value: state.shotClock, round: state.round)
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

                Group {
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
                // The ball has a line of its own: it is the thing being gone up for, and
                // the words above it are read rather than watched.
                .scaleEffect(tuning.ballScale)
                .offset(y: tuning.ballY)
            }
            // Clear of the hand, which the centred stack was sitting on top of.
            .scaleEffect(tuning.titleScale)
            .offset(y: -Self.lift + tuning.titleY)

            // The bids, placed from the centre of the screen rather than from the bottom
            // of whatever happens to be above them.
            // **Who is bidding, and what they have to bid with.** The Bag counts are up
            // from the moment the board goes loose — a board is a guess at what the other
            // three can afford, and the number is public.
            // **A list, not a row.** Four men side by side gave every name a quarter of
            // the screen to fit in; down the left they each get the whole of it, and the
            // Bag they are bidding out of sits beside the man rather than under him.
            VStack(alignment: .leading, spacing: 8) {
                ForEach(order, id: \.self) { seat in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            // **Who it is, before what he is called.** A face reads
                            // across the scene at a glance where four names do not.
                            SpriteAnimation(sprite: .heads, scale: Self.head,
                                            isPlaying: false,
                                            restFrame: PlayerLook.shared.face(for: seat))
                                .paletteSwap(PlayerLook.shared.skin(for: seat))
                            PlayerNameText(seat: seat, size: Self.name)
                        }
                        HStack(spacing: 3) {
                            Image("BagIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: Self.count, height: Self.count)
                            Text("\(state[seat].bag.count)")
                                .font(.system(size: Self.count, weight: .heavy, design: .rounded))
                                .contentTransition(.numericText())
                        }
                        .foregroundStyle(Theme.ink)
                        // Revealed shooter-first then clockwise, the order the rule names.
                        if let revealedBids {
                            Text("\(revealedBids[seat] ?? 0)")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 26, height: 24)
                                .background(RoundedRectangle(cornerRadius: 6)
                                    .fill(Theme.color(for: seat).opacity(0.85)))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .scaleEffect(tuning.bidsScale)
            .offset(y: Self.bidsY + tuning.bidsY)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: revealedBids)
        .onAppear {
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { lift = true }
            withAnimation(.easeInOut(duration: 0.07).repeatForever(autoreverses: true)) { shake = true }
        }
    }
}
