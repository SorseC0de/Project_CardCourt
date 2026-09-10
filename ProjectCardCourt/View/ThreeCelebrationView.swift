import SwiftUI

/// The three-fingered salute after a made three.
///
/// The hand arrived as one SVG path with four subpaths, split into layers so the fingers
/// can arrive one at a time — palm first, then left to right, each overshooting its size
/// before settling.
struct ThreeCelebrationView: View {
    let seat: Seat
    /// Where the number flies to: that player's points on the scoreboard.
    let scoreTarget: CGPoint
    var onScoreLands: () -> Void
    var onFinished: () -> Void

    @State private var arrived: [Bool] = Array(repeating: false, count: 4)
    @State private var sparkleAt: Date?
    /// **The count, not the answer.** It comes up with the first finger and follows the
    /// other two, so the number on screen is however many are up — and three arrives when
    /// the third one does rather than after the hand is already made.
    @State private var counted = 0
    @State private var numberFlying = false
    @State private var fading = false

    private let side: CGFloat = 200
    /// Room for a finger to overshoot into: the springs settle from past 1, and a hand
    /// cut off at the moment it is largest is the moment it is most visible.
    private var room: CGFloat { side * 1.6 }
    /// The burst, in whole art pixels. Its sheet is 64 square, so this is 192 points —
    /// inside the hand rather than swallowing it.
    private let sparkleScale: CGFloat = 3

    private enum Beat {
        /// The fist arrives on its own and sits there. Fingers on the way up before
        /// anybody has read the hand is one shape appearing, not a gesture being made.
        static let fistHolds: Double = 0.40
        /// And then one finger at a time.
        static let between: Double = 0.30
        /// How long the sparkle sheet runs, which is when it has to go: it is a one-shot
        /// and a one-shot holds its last cell forever. Those were the pixels left stuck
        /// on the floor after the hand had gone.
        static var sparkle: Double {
            Double(Sprite.sparkleBurst.frames) / Theme.Figure.playerFPS
        }
    }

    var body: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)
            // **The cell, in this view's own space.** `scoreTarget` is measured on the
            // board in `Chrome.screen`, and `position` is read against whatever this
            // reader happens to be standing in — the two are the same point only if this
            // view starts at the screen's own origin, which it does not. Unconverted, the
            // number flew to the same place whoever had scored.
            let mine = geo.frame(in: .named(Chrome.screen))
            let landing = CGPoint(x: scoreTarget.x - mine.minX,
                                  y: scoreTarget.y - mine.minY)

            ZStack {
                ZStack {
                    ForEach(0..<4, id: \.self) { layer in
                        hand(layer)
                            // **No `drawingGroup` here.** It rasterises at the layer's own
                            // bounds, and the spring that lands each finger settles from
                            // past 1 — so the overshoot was drawn against the edge of its
                            // own raster and cut off square.
                            .scaleEffect(arrived[layer] ? 1 : 0.1)
                            .opacity(arrived[layer] ? 1 : 0)
                    }
                }
                .frame(width: room, height: room)
                .position(centre)

                if let sparkleAt {
                    // Four art pixels down: the sheet is centred on its own frame and the
                    // hand is not centred on the burst.
                    SpriteAnimation(sprite: .sparkleBurst, scale: sparkleScale,
                                    fps: Theme.Figure.playerFPS,
                                    playsOnce: true, startedAt: sparkleAt)
                        .position(x: centre.x, y: centre.y + 4 * sparkleScale)
                        .allowsHitTesting(false)
                }

                if counted > 0 {
                    Text("\(counted)")
                        .font(.custom("AvenirNextCondensed-Heavy", size: numberFlying ? 22 : 120))
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.navy, radius: 0, x: 3, y: 3)
                        // Ticks over rather than being replaced — one number counting up,
                        // not three numbers taking turns.
                        .contentTransition(.numericText())
                        .position(numberFlying ? landing : centre)
                }
            }
            .opacity(fading ? 0 : 1)
            .task { await run() }
        }
        .allowsHitTesting(false)
    }

    /// One layer of the hand: the palm, then a finger at a time. The art is filled black
    /// in the file, so each layer is a template in the catalogue — without that the tint
    /// is silently ignored, all four draw as identical black silhouettes over one another,
    /// and the sequence is invisible. Which is how it looked.
    @ViewBuilder private func hand(_ layer: Int) -> some View {
        let art = Image("ThreeHand_\(layer)")
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
        if lit {
            SpectrumFill(resting: CardPalette.gold) { art }
        } else {
            art.foregroundStyle(handGradient)
        }
    }

    /// **Warm at the fingertips, cooling into the palm.** The hand's first look, kept:
    /// set `lit` to false and this is what is drawn. Worth having both — this one is the
    /// game's own colours and the lit one is borrowed.
    private var handGradient: LinearGradient {
        LinearGradient(colors: [CardPalette.gold, CardPalette.orange, CardPalette.red],
                       startPoint: .top, endPoint: .bottom)
    }

    /// **Whether the hand takes the spectrum.** Project Stars' Start button, turned into
    /// a fill — see `SpectrumFill`. Off, it wears `handGradient` as it always did.
    var lit = true

    private func run() async {
        // The palm lands first and the burst goes off with it, not before it — the sparkle
        // was firing against an empty screen.
        withAnimation(.spring(response: 0.34, dampingFraction: 1)) { arrived[0] = true }
        sparkleAt = Date()
        // Taken off on its own clock, so the fingers are not waiting on it.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Beat.sparkle))
            sparkleAt = nil
        }
        try? await Task.sleep(for: .seconds(Beat.fistHolds))
        for finger in 1..<4 {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) {
                arrived[finger] = true
                counted = finger
            }
            try? await Task.sleep(for: .seconds(Beat.between))
        }
        // Held on three for a beat before it goes to the board.
        try? await Task.sleep(for: .seconds(0.55))
        withAnimation(.easeInOut(duration: 0.5)) { numberFlying = true }
        try? await Task.sleep(for: .seconds(0.5))
        // The score only moves once the number gets there.
        onScoreLands()

        try? await Task.sleep(for: .seconds(0.2))
        withAnimation(.easeOut(duration: 0.35)) { fading = true }
        try? await Task.sleep(for: .seconds(0.35))
        onFinished()
    }
}
