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
    @State private var numberShown = false
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
        /// Between the palm and each finger. Three fingers landing inside a third of a
        /// second read as one shape appearing rather than as three arriving.
        static let between: Double = 0.20
    }

    var body: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)

            ZStack {
                ZStack {
                    ForEach(0..<4, id: \.self) { layer in
                        // The art is filled black in the file, so each layer is a
                        // template in the catalogue — without that the tint is silently
                        // ignored, all four draw as identical black silhouettes over one
                        // another, and the sequence is invisible. Which is how it looked.
                        Image("ThreeHand_\(layer)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: side, height: side)
                            .foregroundStyle(handGradient)
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
                    SpriteAnimation(sprite: .sparkleBurst, scale: sparkleScale,
                                    fps: Theme.Figure.playerFPS,
                                    playsOnce: true, startedAt: sparkleAt)
                        .position(centre)
                        .allowsHitTesting(false)
                }

                if numberShown {
                    Text("3")
                        .font(.custom("AvenirNextCondensed-Heavy", size: numberFlying ? 22 : 120))
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.navy, radius: 0, x: 3, y: 3)
                        .position(numberFlying ? scoreTarget : centre)
                }
            }
            .opacity(fading ? 0 : 1)
            .task { await run() }
        }
        .allowsHitTesting(false)
    }

    /// Warm at the fingertips, cooling into the palm.
    private var handGradient: LinearGradient {
        LinearGradient(colors: [CardPalette.gold, CardPalette.orange, CardPalette.red],
                       startPoint: .top, endPoint: .bottom)
    }

    private func run() async {
        // The palm lands first and the burst goes off with it, not before it — the sparkle
        // was firing against an empty screen.
        withAnimation(.spring(response: 0.34, dampingFraction: 1)) { arrived[0] = true }
        sparkleAt = Date()
        try? await Task.sleep(for: .seconds(Beat.between))
        for finger in 1..<4 {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) { arrived[finger] = true }
            try? await Task.sleep(for: .seconds(Beat.between))
        }
        try? await Task.sleep(for: .seconds(0.25))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { numberShown = true }

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
