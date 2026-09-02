import SwiftUI

struct ShotCutsceneView: View {
    let scene: ShotCutscene

    @State private var flight: CGFloat = 0
    @State private var settle: CGFloat = 0
    @State private var showResult = false
    @State private var showBurst = false
    /// When the ball reached the rim, which is what the net decays from.
    @State private var struckAt: Date?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.96).ignoresSafeArea()

                // Backdrop, ball, then the near half of the rim on top — the ball
                // passes between the two halves rather than over the ring.
                VStack {
                    HoopBackdrop(struckAt: struckAt)
                        .padding(.top, 46)
                    Spacer()
                }
                .zIndex(0)

                // Held until the ball is actually at the rim.
                if let burst, showBurst {
                    EmojiBurst(emoji: burst.emoji, count: burst.count)
                        .position(rimPoint(in: geo.size))
                }

                Group {
                    if scene.made {
                        if showResult { SwisshTitle() }
                    } else {
                        Text(scene.missCall)
                            .font(.system(size: scene.missCall == "BRRRICK" ? 40 : 34,
                                          weight: .black, design: .rounded))
                            .tracking(scene.missCall == "BRRRICK" ? 2 : 0)
                            .foregroundStyle(Theme.danger)
                            .opacity(showResult ? 1 : 0)
                            .scaleEffect(showResult ? 1 : 0.7)
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height * 0.42)

                // Whoever was contesting is still contesting.
                ForEach(0..<scene.defenders, id: \.self) { index in
                    let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                    let rank = CGFloat(index / 2 + 1)
                    DefenderFigure()
                        .scaleEffect(1.7, anchor: .bottom)
                        .position(x: geo.size.width / 2 + side * 62 * rank,
                                  y: geo.size.height - 150 - 14 * rank)
                }

                VStack(spacing: 8) {
                    PlayerFigure(seat: scene.shooter, sprite: .shoot)
                        .scaleEffect(1.7)
                    Text(scene.shooter.playerName.uppercased())
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(Theme.inkDim)
                    Text("SHOT \(scene.chance)%")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }
                .position(x: geo.size.width / 2, y: geo.size.height - 132)

                PixelBallView(scale: 4)
                    .position(ballPoint(in: geo.size))
                    .zIndex(1)

                VStack {
                    RimHalf(isNear: true, width: 138 * 0.54)
                        .padding(.top, 46 + 138 * 0.67 - 138 * 0.04)
                    Spacer()
                }
                .zIndex(2)
            }
            .task { await run() }
        }
    }

    /// What the hoop throws back. Deliberately gapped — an ordinary make or a
    /// respectable miss gets nothing, so the burst always means something.
    private var burst: (emoji: String, count: Int)? {
        if scene.made {
            if scene.chance >= 80 { return ("🔥", 24) }
            if scene.chance >= 50 { return ("🪣", 20) }
            return nil
        }
        return scene.chance < 40 ? ("🧱", 22) : nil
    }

    private func rimPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: 46 + 92 + 4)
    }

    private func ballPoint(in size: CGSize) -> CGPoint {
        let start = CGPoint(x: size.width / 2, y: size.height - 178)
        let end = rimPoint(in: size)
        let control = CGPoint(x: size.width / 2 - 40, y: end.y - 130)
        let arc = quadratic(start, control, end, t: flight)

        guard settle > 0 else { return arc }
        // Through the net, or kicked out off the iron.
        let after = scene.made
            ? CGPoint(x: end.x, y: end.y + 96)
            : CGPoint(x: end.x + 118, y: end.y + 54)
        return CGPoint(x: arc.x + (after.x - arc.x) * settle,
                       y: arc.y + (after.y - arc.y) * settle)
    }

    private func quadratic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
                       y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y)
    }

    private func run() async {
        try? await Task.sleep(for: .seconds(0.35))
        withAnimation(.easeOut(duration: 0.62)) { flight = 1 }
        try? await Task.sleep(for: .seconds(0.62))
        showBurst = true
        // Only a make disturbs the net; a miss never reaches it.
        if scene.made { struckAt = Date() }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { showResult = true }
        withAnimation(.easeIn(duration: 0.42)) { settle = 1 }
    }
}
