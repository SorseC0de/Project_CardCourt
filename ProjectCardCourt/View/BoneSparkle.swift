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
    var tint: Color = PixelPalette.gold
    var count: Int = 7

    private enum Twinkle {
        /// Seconds for a full breath, fastest and slowest.
        static let quickest: Double = 1.1
        static let slowest: Double = 2.9
        /// How big a twinkle is against the bone, smallest and largest.
        static let smallest: CGFloat = 0.10
        static let largest: CGFloat = 0.30
        /// How far out they sit; over one puts them off the edges.
        static let spread: CGFloat = 1.15
        /// The soft halo under each, and how much of it there is.
        static let glowLayers = 2
        static let glow: Double = 0.5
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    let seed = Self.spread(index)
                    let size = side * (Twinkle.smallest
                        + (Twinkle.largest - Twinkle.smallest) * seed.size)
                    star(at: index, size: size, beat: Self.beat(index, at: now))
                        .offset(x: (seed.x - 0.5) * side * Twinkle.spread,
                                y: (seed.y - 0.5) * side * Twinkle.spread)
                }
            }
            .frame(width: side, height: side)
        }
        .allowsHitTesting(false)
    }

    /// One twinkle: a white core with the tint blooming around it, breathing.
    private func star(at index: Int, size: CGFloat, beat: CGFloat) -> some View {
        ZStack {
            // The colour lives in the soft copies, where the light is thin enough to keep
            // it — stacked additively they still brighten toward the middle, which is what
            // puts the white core underneath.
            ForEach(0..<Twinkle.glowLayers, id: \.self) { step in
                SparkleGlyph()
                    .fill(tint)
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
    private static func beat(_ index: Int, at now: TimeInterval) -> CGFloat {
        let seed = spread(index)
        let period = Twinkle.quickest
            + (Twinkle.slowest - Twinkle.quickest) * Double(seed.rate)
        let turns = now / period * 2 * .pi + Double(seed.rate) * 2 * .pi
        return CGFloat(sin(turns) + 1) / 2
    }

    /// A cheap hash of the number, so neighbours do not land on neighbouring rates or in
    /// a line. Four values out of one multiply, which is enough scatter for seven marks.
    private static func spread(_ index: Int) -> (x: CGFloat, y: CGFloat,
                                                 size: CGFloat, rate: CGFloat) {
        func slice(_ salt: Int) -> CGFloat {
            CGFloat((index &* 2654435761 &+ salt &* 40503) % 1000) / 1000
        }
        return (slice(1), slice(7), slice(13), slice(29))
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
