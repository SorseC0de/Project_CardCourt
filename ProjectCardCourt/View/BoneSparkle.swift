import SwiftUI

/// A four-point twinkle with concave sides, drawn rather than imported.
///
/// Lifted from Project Stars, where it marks a tile the pickup might land on. **Drawn is
/// the point**: the bone is a vector with its own shading, and a pixel-art burst laid over
/// it reads as two different games in one frame.
struct SparkleGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let midX = rect.midX, midY = rect.midY
        let waist = min(rect.width, rect.height) / 2 * 0.28
        var path = Path()
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: midY),
                          control: CGPoint(x: midX + waist, y: midY - waist))
        path.addQuadCurve(to: CGPoint(x: midX, y: rect.maxY),
                          control: CGPoint(x: midX + waist, y: midY + waist))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: midY),
                          control: CGPoint(x: midX - waist, y: midY + waist))
        path.addQuadCurve(to: CGPoint(x: midX, y: rect.minY),
                          control: CGPoint(x: midX - waist, y: midY - waist))
        path.closeSubpath()
        return path
    }
}

/// A scatter of twinkles around something, each on its own rate.
///
/// **Off the clock, not off an animation.** One `TimelineView` drives them all, and each
/// takes its period and its phase from a hash of its own number — staggering phase alone
/// is not enough, since a set sharing one period reads as a single blinking object however
/// it is offset.
struct BoneSparkles: View {
    /// The box they are scattered in — the bone's own side.
    var side: CGFloat
    /// The one colour they all catch. Nil gives each its own off the wheel, which is
    /// what glass does — see `rainbow`.
    var tint: Color? = PixelPalette.gold
    /// Seconds for a twinkle's own colour to come back round, when it has one.
    var wheel: Double = 9
    /// **A handful of big ones, not a field of small ones.** Many small twinkles read
    /// as glitter on the whole frame; a few large ones read as light coming off an object.
    var count: Int = 4
    /// Places left empty, by their number in the ring — see `BallShine`.
    var omitted: Set<Int> = []

    private enum Twinkle {
        /// Seconds for a full breath, fastest and slowest.
        static let quickest: Double = 1.1
        static let slowest: Double = 2.9
        /// How big a twinkle is against the bone, smallest and largest.
        static let smallest: CGFloat = 0.22
        static let largest: CGFloat = 0.46
        /// How far out from the middle they sit, nearest and furthest, as a share of the
        /// side. Past a half is off the edge of the bone, which is where most should be.
        static let nearest: CGFloat = 0.34
        static let furthest: CGFloat = 0.55
        /// Where in its own sector a twinkle sits: how far in it starts, and how much of
        /// the sector it may wander over. Under one, so no two can meet at a border.
        static let sectorLead: CGFloat = 0.28
        static let sectorPlay: CGFloat = 0.44
        /// The stream every placement is drawn from, in order.
        static let seed: UInt64 = 0x5F1E_2B77
        /// The soft halo under each, and how much of it there is.
        static let glowLayers = 2
        static let glow: Double = 0.5
    }

    var body: some View {
        let placed = scatter
        return TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(Array(placed.enumerated()).filter { !omitted.contains($0.offset) },
                        id: \.offset) { index, spot in
                    let size = side * (Twinkle.smallest
                        + (Twinkle.largest - Twinkle.smallest) * spot.size)
                    star(size: size, beat: Self.beat(spot.rate, at: now),
                         ink: ink(at: now, seed: spot.turn))
                        .offset(x: spot.x * side, y: spot.y * side)
                }
            }
            .frame(width: side, height: side)
        }
        .allowsHitTesting(false)
    }

    /// Where one twinkle sits and how it behaves.
    private struct Place {
        var turn: CGFloat
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var rate: CGFloat
    }

    /// The set, placed once.
    ///
    /// **A ring, not a box, and a sector each.** Four points scattered freely in a square
    /// land wherever the numbers put them, and with only four that is regularly all on
    /// one side — which is exactly what happened: every `x` for the first eight indices
    /// came out under a half. Giving each twinkle its own arc and letting it wander
    /// *within* that arc spreads them round the bone by construction rather than by luck.
    ///
    /// One stream drawn in order, too. Seeding per index off the index itself made each
    /// one's numbers the previous one's shifted along by a place, which is a diagonal
    /// wearing a different hat.
    private var scatter: [Place] {
        var rng = SeededRNG(seed: Twinkle.seed)
        func roll() -> CGFloat { CGFloat(rng.next() % 1000) / 1000 }
        return (0..<count).map { index in
            let turn = (CGFloat(index) + Twinkle.sectorLead
                        + Twinkle.sectorPlay * roll()) / CGFloat(count)
            let reach = Twinkle.nearest + (Twinkle.furthest - Twinkle.nearest) * roll()
            return Place(turn: turn,
                         x: cos(turn * 2 * .pi) * reach,
                         y: sin(turn * 2 * .pi) * reach,
                         size: roll(), rate: roll())
        }
    }

    /// One twinkle: a white core with the tint blooming around it, breathing.
    /// What one twinkle is lit in. **Glass has no colour of its own** — each of its
    /// twinkles takes a different place on the wheel and walks it, so the set reads as
    /// light being split rather than as a set of coloured lamps.
    private func ink(at now: TimeInterval, seed: CGFloat) -> Color {
        guard tint == nil else { return tint ?? .white }
        let turn = now / wheel + Double(seed)
        return Color(hue: turn - turn.rounded(.down), saturation: 0.85, brightness: 1)
    }

    private func star(size: CGFloat, beat: CGFloat, ink: Color) -> some View {
        ZStack {
            // The colour lives in the soft copies, where the light is thin enough to keep
            // it — stacked additively they still brighten toward the middle, which is what
            // puts the white core underneath.
            ForEach(0..<Twinkle.glowLayers, id: \.self) { step in
                SparkleGlyph()
                    .fill(ink)
                    .frame(width: size, height: size)
                    .blur(radius: size * 0.18 * (1 + CGFloat(step) * 0.9))
                    .opacity(Twinkle.glow / Double(step + 1))
            }
            .blendMode(.plusLighter)
            SparkleGlyph()
                .fill(.white)
                .frame(width: size * 0.52, height: size * 0.52)
        }
        // Never quite gone and never quite still: a twinkle that reaches nothing reads as
        // a light being switched off.
        .scaleEffect(0.55 + 0.45 * beat)
        .opacity(0.25 + 0.75 * Double(beat))
    }

    /// `0`…`1` on this twinkle's own period and offset.
    private static func beat(_ rate: CGFloat, at now: TimeInterval) -> CGFloat {
        let period = Twinkle.quickest + (Twinkle.slowest - Twinkle.quickest) * Double(rate)
        let turns = now / period * 2 * .pi + Double(rate) * 2 * .pi
        return CGFloat(sin(turns) + 1) / 2
    }

}

#if DEBUG
#Preview("Twinkles") {
    ZStack {
        Chrome.ground.ignoresSafeArea()
        BoneSparkles(side: 120).frame(width: 160, height: 160)
    }
}
#endif
