import SwiftUI

/// The rim, split so a ball can pass through it.
///
/// The ring is one ellipse drawn twice and masked into halves: the far half sits behind
/// the ball, the near half in front. Stacking the ball between them is what sells the
/// ball going *through* rather than over.
/// Where the hoop hangs, and where the ring runs through it.
///
/// **The board is pinned to the top of the scene and never moves.** A scene with a hoop in
/// it is laid out in `HoopStage`, so everything counted up from its floor stays a fixed
/// distance under this line on every phone.
enum Hoop {
    /// How far the backboard hangs below the top of the scene.
    static let drop: CGFloat = 46
    /// The backboard's height, against the hoop's width.
    static let board: CGFloat = 0.67
    /// How far the ring is set back up into the board.
    static let lift: CGFloat = 0.04
    /// The ring's own width, against the hoop's.
    static let ring: CGFloat = 0.54
    /// How deep the ring reads, against its own width — it is an ellipse, not a line.
    static let depth: CGFloat = 0.27

    /// Where the ring's line falls, in points below the top of the scene: the board,
    /// then the set-back, then half the ellipse. That line is what the ball drops
    /// through and what a hand takes hold of.
    static func line(width: CGFloat) -> CGFloat {
        drop + width * (board - lift + ring * depth / 2)
    }
}

/// **The box a scene with a hoop in it is laid out in**: the iPhone 17 Pro canvas's own
/// scene, measured, pinned to the top and centred. A number tuned in the canvas then lands in
/// the same place on every phone — only the black around it changes. An iPhone 16's scene is
/// 393×759 and a 16 Pro Max's 440×860.
enum HoopStage {
    static let size = CGSize(width: 402, height: 778)
}

extension View {
    /// Lays this out in `HoopStage.size`, pinned to the top and centred across the space it
    /// is given. **Nothing inside may be wider than the stage** — a wider child widens the
    /// stack and moves everything placed in it.
    func onHoopStage() -> some View {
        frame(width: HoopStage.size.width, height: HoopStage.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct RimHalf: View {
    let isNear: Bool
    var width: CGFloat
    var thickness: CGFloat = 4
    var tint: Color = Theme.ball

    private var height: CGFloat { width * Hoop.depth }

    var body: some View {
        Ellipse()
            .stroke(tint, lineWidth: thickness)
            .frame(width: width, height: height)
            .mask(
                VStack(spacing: 0) {
                    Rectangle().fill(isNear ? Color.clear : Color.black)
                    Rectangle().fill(isNear ? Color.black : Color.clear)
                }
            )
    }
}

/// A net of hanging strands that reacts when the ball goes through.
///
/// Not a simulation. Energy is derived from how long ago the ball struck, so the whole
/// thing is a function of the clock — nothing is stored or stepped per frame, and the
/// decay cannot drift.
struct NetView: View {
    /// The swish. The ball drives the waist of the net down and out, and the hem is
    /// thrown up past the ring behind it — so one strand reads down-then-up, and the
    /// whole net snaps into a ~ at the top of the flip.
    private enum Swish {
        /// How far out the hem is thrown, as a share of the net's width.
        static let flare: CGFloat = 0.42
        /// The waist being punched down, as a share of the net's depth.
        static let waist: CGFloat = 0.35
        /// The hem coming back up. Above 1 carries it over the ring.
        static let hem: CGFloat = 1.05
        /// What is left to swing once the whip has gone.
        static let settle: CGFloat = 0.15
    }

    var width: CGFloat
    var strands = 12
    var segments = 5
    /// When the ball last passed through. nil leaves the net at rest.
    var struckAt: Date?

    private var depth: CGFloat { width * 0.72 }
    private var rimHeight: CGFloat { width * 0.27 }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let energy = energy(at: now)
                let phase = now.timeIntervalSinceReferenceDate

                let kick = snap(at: now)

                func knot(_ strand: Int, _ segment: Int) -> CGPoint {
                    let angle = Double(strand % strands) / Double(strands) * 2 * .pi
                    let t = CGFloat(segment) / CGFloat(segments)
                    // Cinched toward the bottom, the way a real net tapers.
                    let radius = size.width / 2 * (1 - t * 0.55)
                    let sway = swing(strand: strand, t: t, energy: energy, phase: phase)
                    // Thrown outward hardest at the hem, so the taper inverts as it flips.
                    let flare = size.width * Swish.flare * kick * (t * t)
                    return CGPoint(
                        x: size.width / 2 + CGFloat(cos(angle)) * (radius + sway + flare),
                        y: rimHeight / 2 + depth * t
                            + CGFloat(sin(angle)) * (radius + sway + flare) * 0.27
                            // The waist goes down — nothing at either end, most in the
                            // middle — while the hem is thrown up hard enough to pass the
                            // ring. Down then up along one strand is the tilde.
                            + depth * Swish.waist * kick * CGFloat(sin(Double(t) * .pi))
                            - depth * Swish.hem * kick * (t * t * t)
                            // What is left once the whip has gone: an ordinary settle.
                            + depth * Swish.settle * energy * t)
                }

                let ink = GraphicsContext.Shading.color(.white.opacity(0.55))
                let stroke = StrokeStyle(lineWidth: 1, lineCap: .round)

                // Down the strands.
                for strand in 0..<strands {
                    var path = Path()
                    for segment in 0...segments {
                        let point = knot(strand, segment)
                        segment == 0 ? path.move(to: point) : path.addLine(to: point)
                    }
                    context.stroke(path, with: ink, style: stroke)
                }

                // And around them. Without these rings it reads as fringe, not a net.
                for segment in 1...segments {
                    var ring = Path()
                    for strand in 0...strands {
                        let point = knot(strand, segment)
                        strand == 0 ? ring.move(to: point) : ring.addLine(to: point)
                    }
                    context.stroke(ring, with: ink, style: stroke)
                }
            }
        }
        .frame(width: width, height: depth + rimHeight)
        .allowsHitTesting(false)
    }

    /// Decays from a strike rather than being animated into, so a Canvas can read it.
    private func energy(at now: Date) -> CGFloat {
        guard let struckAt else { return 0 }
        let elapsed = now.timeIntervalSince(struckAt)
        guard elapsed >= 0, elapsed < 3 else { return 0 }
        return CGFloat(exp(-elapsed * 1.5))
    }

    /// The kick of the ball going through: hard, brief, and gone before the sway is.
    ///
    /// The whole flip has to be over quickly — a net that hangs inside-out reads as
    /// broken rather than as a swish.
    private func snap(at now: Date) -> CGFloat {
        guard let struckAt else { return 0 }
        let elapsed = now.timeIntervalSince(struckAt)
        guard elapsed >= 0, elapsed < 0.8 else { return 0 }
        // Rises almost instantly, then falls away.
        let rise = min(1, elapsed / 0.05)
        return CGFloat(rise * exp(-(elapsed - 0.05) * 9))
    }

    /// Pinned at the rim, free at the hem — so the swing grows down the strand.
    private func swing(strand: Int, t: CGFloat, energy: CGFloat, phase: Double) -> CGFloat {
        guard energy > 0 else { return 0 }
        let offset = Double(strand) * 0.7
        // Lagged down the strand, so the hem trails the rim rather than swinging with it.
        let lag = Double(t) * 1.1
        let fast = sin(phase * 11 + offset - lag)
        let slow = sin(phase * 4.3 + offset * 0.5 - lag) * 0.55
        return CGFloat((fast + slow) * Double(energy)) * width * 0.26 * t * t
    }
}

/// Backboard and net — everything that sits behind the ball.
struct HoopBackdrop: View {
    var width: CGFloat = 138
    var struckAt: Date?
    /// What the board is lit with, if anything. Green for a make — and green then red
    /// when a shot is counted and then taken away.
    var light: Color?
    /// How hard somebody is hanging on it, nought to one. **The board does not move** —
    /// it is glass bolted to a wall; the ring comes down and the net goes with it. See
    /// `DunkStyle.rimDrop`.
    var pull: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.10))
                RoundedRectangle(cornerRadius: 5)
                    .stroke(light ?? Color.white.opacity(0.75), lineWidth: 2.5)
                    .shadow(color: light ?? .clear, radius: 10)
                Rectangle()
                    .stroke(light ?? Color.white.opacity(0.85), lineWidth: 2)
                    .shadow(color: light ?? .clear, radius: 10)
                    .frame(width: width * 0.40, height: width * 0.30)
                    .offset(y: width * 0.12)
            }
            .frame(width: width, height: width * Hoop.board)
            .animation(.easeOut(duration: 0.18), value: light)

            ZStack(alignment: .top) {
                RimHalf(isNear: false, width: width * Hoop.ring,
                        thickness: 8, tint: PixelPalette.darkRed)
                NetView(width: width * Hoop.ring, struckAt: struckAt)
                    // The ring is iron and keeps its shape; the net is string and does not.
                    .scaleEffect(y: 1 + pull * DunkStyle.netStretch, anchor: .top)
            }
            .offset(y: -width * Hoop.lift + pull * width * DunkStyle.rimDrop)
        }
    }
}
