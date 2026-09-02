import SwiftUI

/// The rim, split so a ball can pass through it.
///
/// The ring is one ellipse drawn twice and masked into halves: the far half sits behind
/// the ball, the near half in front. Stacking the ball between them is what sells the
/// ball going *through* rather than over.
struct RimHalf: View {
    let isNear: Bool
    var width: CGFloat
    var thickness: CGFloat = 4

    private var height: CGFloat { width * 0.27 }

    var body: some View {
        Ellipse()
            .stroke(Theme.ball, lineWidth: thickness)
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

                for strand in 0..<strands {
                    let angle = Double(strand) / Double(strands) * 2 * .pi
                    var path = Path()

                    for segment in 0...segments {
                        let t = CGFloat(segment) / CGFloat(segments)
                        // Cinched toward the bottom, the way a real net tapers.
                        let radius = size.width / 2 * (1 - t * 0.55)
                        let sway = swing(strand: strand, t: t, energy: energy, phase: phase)

                        let point = CGPoint(
                            x: size.width / 2 + CGFloat(cos(angle)) * (radius + sway),
                            y: rimHeight / 2 + depth * t
                                + CGFloat(sin(angle)) * (radius + sway) * 0.27
                                // Dragged down as the ball passes, springing back after.
                                + depth * 0.18 * energy * t)
                        segment == 0 ? path.move(to: point) : path.addLine(to: point)
                    }
                    context.stroke(path, with: .color(.white.opacity(0.55)),
                                   style: StrokeStyle(lineWidth: 1, lineCap: .round))
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
        return CGFloat(exp(-elapsed * 2.6))
    }

    /// Pinned at the rim, free at the hem — so the swing grows down the strand.
    private func swing(strand: Int, t: CGFloat, energy: CGFloat, phase: Double) -> CGFloat {
        guard energy > 0 else { return 0 }
        let offset = Double(strand) * 0.7
        let wobble = sin(phase * 9 + offset) * Double(energy)
        return CGFloat(wobble) * width * 0.10 * t
    }
}

/// Backboard and net — everything that sits behind the ball.
struct HoopBackdrop: View {
    var width: CGFloat = 138
    var struckAt: Date?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.10))
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(0.75), lineWidth: 2.5)
                Rectangle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                    .frame(width: width * 0.40, height: width * 0.30)
                    .offset(y: width * 0.12)
            }
            .frame(width: width, height: width * 0.67)

            ZStack(alignment: .top) {
                RimHalf(isNear: false, width: width * 0.54)
                NetView(width: width * 0.54, struckAt: struckAt)
            }
            .offset(y: -width * 0.04)
        }
    }
}
