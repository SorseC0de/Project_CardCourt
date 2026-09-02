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

    private let side: CGFloat = 260

    var body: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)

            ZStack {
                ZStack {
                    ForEach(0..<4, id: \.self) { layer in
                        Image("ThreeHand_\(layer)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: side, height: side)
                            .foregroundStyle(handGradient)
                            .scaleEffect(arrived[layer] ? 1 : 0.1)
                            .opacity(arrived[layer] ? 1 : 0)
                    }
                }
                .position(centre)

                if let sparkleAt {
                    SpriteAnimation(sprite: .sparkleBurst, scale: 5, fps: 14,
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
        sparkleAt = Date()
        // The palm just arrives; only the fingers overshoot, left to right.
        withAnimation(.spring(response: 0.28, dampingFraction: 1)) { arrived[0] = true }
        try? await Task.sleep(for: .seconds(0.11))
        for finger in 1..<4 {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.42)) { arrived[finger] = true }
            try? await Task.sleep(for: .seconds(0.11))
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
