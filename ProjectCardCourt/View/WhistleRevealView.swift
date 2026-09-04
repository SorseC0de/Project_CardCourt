import SwiftUI

/// A Whistle being called.
///
/// Run backwards from how one is played. Setting a Whistle down shows the back with the
/// whistle over it — a trap, no card named. Calling it undoes that in order: the whistle
/// arrives first, the back comes up behind it, and only then does the card turn over and
/// say what it was.
///
/// The reveal borrows the trick from Plentacle's wheel: a rounded-rectangle stroke thick
/// enough to fill the whole card, clipped to the card's own shape and run back to zero.
/// The card starts solid white and the white retreats to the edges — no mask to animate,
/// and it works over any artwork underneath.
struct WhistleRevealView: View {
    /// How dark it goes behind the card. A round number, unlike the 0.82 it inherited.
    static let dim: Double = 0.80

    let scene: WhistleReveal
    var onDismiss: () -> Void = {}

    private let width: CGFloat = 210
    /// Thick enough to close over the middle of the card from both edges at once.
    private static let peelStart: CGFloat = 500

    @State private var dimmed = false
    @State private var whistleIn = false
    @State private var backIn = false
    @State private var flipped = false
    @State private var peel = WhistleRevealView.peelStart
    @State private var named = false
    /// Opaque white over the front for the whole turn, lifted the instant the peel takes
    /// over. The stroke alone left the card readable part-way through the spin.
    @State private var covered = true

    private var corner: CGFloat { width * 0.08 }

    var body: some View {
        ZStack {
            // The screen's dim is `GameView`'s, always there and turned up — a scrim
            // that arrives with the view it belongs to is laid out as it arrives, which
            // reads as a rectangle growing rather than the lights going down.
            Color.clear

            whistle
            card.opacity(backIn ? 1 : 0)

            VStack {
                Spacer()
                if named {
                    VStack(spacing: 10) {
                        verdict
                        if scene.isNew { TapToContinue() }
                    }
                    .transition(.opacity)
                    .padding(.bottom, 70)
                }
            }
        }
        .contentShape(Rectangle())
        // Only a first sighting waits on the player. Everything else keeps its own clock,
        // or a Whistle would stop the game every time one was called.
        .onTapGesture { if scene.isNew { onDismiss() } }
        .task { await run() }
    }

    /// The drawn gold whistle, not the flat card icon — the flat one is now the HUD's
    /// way of saying a Whistle *cannot* be called.
    private var whistle: some View {
        Image("GoldWhistle")
            .resizable()
            .scaledToFit()
            .frame(width: width * 1.15)
            .drawingGroup()
            .shadow(color: CardPalette.gold.opacity(0.5), radius: 26)
            .scaleEffect(whistleIn ? 1 : 0.2)
            .rotationEffect(.degrees(whistleIn ? 0 : -30))
            // Pushed back once the card is on top of it, rather than removed — it stays
            // behind the card as the thing that summoned it.
            .opacity(whistleIn ? (backIn ? 0.22 : 1) : 0)
    }

    private var card: some View {
        ZStack {
            if flipped {
                CardFrontView(descriptor: scene.card, displayWidth: width)
                    .overlay {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(lineWidth: peel)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    }
                    .overlay {
                        if covered {
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .fill(.white)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if scene.isNew, peel < 1 {
                            NewBadge().offset(x: 10, y: -10).transition(.scale)
                        }
                    }
                    // Counter-turned, or the front would come up mirrored.
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                Image("CardBackFull")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width)
                    .drawingGroup()
            }
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .shadow(color: .black.opacity(0.6), radius: 22, y: 10)
        .scaleEffect(backIn ? 1 : 0.82)
    }

    /// The referee, with what he called it on tucked under his arm.
    ///
    /// No words: the whistle card is already face up above this, and the card down here
    /// is the one it cancelled. A player's name has no business in it either — a Whistle
    /// is the referees' call, whoever put the card down.
    private var verdict: some View {
        ZStack {
            if let victim = scene.cancelledCard {
                CardFrontView(descriptor: victim, displayWidth: 84)
                    .rotationEffect(.degrees(10))
                    .compositingGroup()
                    .shadow(color: CardPalette.navy, radius: 0, x: 3, y: 3)
                    .offset(x: 40)
            }
            Image("RefereeIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 84)
                // Hard and south-east, like every other mark in the game.
                .shadow(color: CardPalette.blue, radius: 0, x: 3, y: 3)
                .offset(x: -28)
        }
        .frame(height: 124)
    }

    private func run() async {
        withAnimation(.easeOut(duration: 0.25)) { dimmed = true }
        try? await Task.sleep(for: .seconds(0.18))

        withAnimation(.spring(response: 0.34, dampingFraction: 0.52)) { whistleIn = true }
        try? await Task.sleep(for: .seconds(0.62))

        withAnimation(.easeOut(duration: 0.3)) { backIn = true }
        try? await Task.sleep(for: .seconds(0.42))

        withAnimation(.easeInOut(duration: 0.42)) { flipped = true }
        // Held until the card is past edge-on, so the peel is never seen in mirror.
        try? await Task.sleep(for: .seconds(0.42))

        // Handed straight over: the stroke is already at full white, so dropping the
        // cover on the same frame is invisible.
        covered = false
        withAnimation(.easeInOut(duration: 0.9)) { peel = 0 }
        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.easeOut(duration: 0.35)) { named = true }
    }
}

#if DEBUG
#Preview("Whistle called") {
    WhistleRevealView(scene: WhistleReveal(owner: .west, card: CardLibrary.travel,
                                           cancelled: "Drive",
                                           cancelledCard: CardLibrary.drive, isNew: false))
}

#Preview("Whistle called — first time") {
    WhistleRevealView(scene: WhistleReveal(owner: .east, card: CardLibrary.goaltending,
                                           cancelled: "Contest",
                                           cancelledCard: CardLibrary.contest, isNew: true))
}
#endif
