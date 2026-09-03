import SwiftUI

/// Speed-line fields, ported from Project Stars' GameModeSplashView.
///
/// Both fields are ONE `Canvas` driven by ONE `TimelineView`. Do not split them into
/// per-streak views — ninety views each asking for a frame is ninety timelines, which is
/// the mistake that cost Project Stars a week.
enum StreakStyle {

    /// A fixed number in `0..<1` for this streak and this question. Scattered but stable,
    /// so the field looks the same every time without anything stored between frames.
    static func scatter(_ index: Int, _ question: Int) -> Double {
        let n = sin(Double(index) * 12.9898 + Double(question) * 78.233) * 43758.5453
        return n - n.rounded(.down)
    }

    /// Weighted so the field reads as one colour with sparks through it rather than confetti.
    static func colour(_ roll: Double) -> Color {
        switch roll * 10 {
        case ..<4: return Theme.clockAmber
        case ..<7: return Theme.ink
        case ..<9: return Theme.ball
        default:   return Theme.clockRed
        }
    }

    /// White and amber bloom harder under `plusLighter`, so each is pulled back to match.
    static func gain(of colour: Color) -> Double {
        switch colour {
        case Theme.ink:        return 0.44
        case Theme.clockAmber: return 0.60
        default:               return 1
        }
    }

    // ── Shared ────────────────────────────────────────────────────────
    static let faintest: Double = 0.15
    static let shortest: Double = 0.18
    static let slowest: Double = 0.35

    // ── The court's warp: radial, out of the horizon ───────────────────
    static var warp: Double = 0.30
    static let warpCount = 70
    static let warpThickness: CGFloat = 7.00
    /// Past the corners, so a streak is still travelling when it leaves.
    static let reach: CGFloat = 3.0
    static let speed: Double = 0.50
    static let paceSlowest: Double = 0.45
    /// Out faster than time goes — this is what reads as depth rather than a firework.
    static let curve: Double = 2.4
    static let stretch: Double = 0.34
    static let thinnest: Double = 0.25
    /// Streaks start in a band around the eye, not all on one ring, or the centre
    /// reads as a hard disc instead of a glow.
    static let core: Double = 0.06
    static let eyeRagged: Double = 0.5
    static let stretchLeast: Double = 0.22
    /// Raised to a power so most marks are faint and a few are not.
    static let glowBunching: Double = 2.2
    static let dawn: Double = 0.18
    static let dusk: Double = 0.12
    /// How far outside the floor a streak may run, as a multiple of the floor's
    /// half-width at that depth. Above 1 is off the court.
    static let laneInner: CGFloat = 1.04
    static let laneOuter: CGFloat = 2.3
    /// How far past the near edge a streak keeps travelling before it wraps, so it
    /// leaves the screen rather than stopping at the bottom.
    static let overrun: CGFloat = 1.9
    /// A streak's length, as a share of the depth it has already covered.
    static let trail: CGFloat = 0.42

    // ── The rebound's streaks: sideways, passing ───────────────────────
    static var sideWarp: Double = 0.72
    static let sideCount = 40
    static let sideThickness: CGFloat = 1.6
    static let sideLength: CGFloat = 0.18
    static let sideSpeed: CGFloat = 2.2
}

/// Streaks that ride the court's own curvature, from the horizon out past the viewer.
///
/// They are not rays. Each one is sampled through the same depth-to-point mapping the
/// floor uses, at a lateral offset just outside its edge, so it bends exactly as the
/// court bends. Change `Perspective.curve` and these follow with no work.
struct CourtStreaks: View {
    var intensity: Double = StreakStyle.warp

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard intensity > 0 else { return }
                context.blendMode = .plusLighter

                let court = CourtGeometry(size: size)
                let now = timeline.date.timeIntervalSinceReferenceDate

                for index in 0..<StreakStyle.warpCount {
                    // Alternating sides, so both wedges fill evenly.
                    let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                    let spread = StreakStyle.laneOuter - StreakStyle.laneInner
                    let lateral = side * (StreakStyle.laneInner
                        + CGFloat(StreakStyle.scatter(index, 1)) * spread)

                    let pace = StreakStyle.paceSlowest + StreakStyle.scatter(index, 2)
                    let turn = now * StreakStyle.speed * pace + StreakStyle.scatter(index, 3)
                    let phase = turn - turn.rounded(.down)

                    // Toward the viewer faster than time goes — the acceleration is what
                    // reads as depth rather than as drifting confetti.
                    let head = CGFloat(pow(phase, StreakStyle.curve)) * StreakStyle.overrun
                    let tail = max(0, head - head * StreakStyle.trail
                                   * CGFloat(StreakStyle.stretchLeast
                                             + StreakStyle.scatter(index, 8)
                                             * (1 - StreakStyle.stretchLeast)))
                    guard head > tail else { continue }

                    var path = Path()
                    let steps = 10
                    for step in 0...steps {
                        let depth = tail + (head - tail) * CGFloat(step) / CGFloat(steps)
                        let point = CGPoint(x: court.centreX + court.halfWidth(at: depth) * lateral,
                                            y: court.y(at: depth))
                        step == 0 ? path.move(to: point) : path.addLine(to: point)
                    }

                    let width = StreakStyle.warpThickness
                        * (StreakStyle.thinnest + CGFloat(phase))
                    let entering = min(1, phase / StreakStyle.dawn)
                    let leaving = min(1, (1 - phase) / StreakStyle.dusk)
                    let colour = StreakStyle.colour(StreakStyle.scatter(index, 5))
                    let own = StreakStyle.faintest
                        + pow(StreakStyle.scatter(index, 4), StreakStyle.glowBunching)
                        * (1 - StreakStyle.faintest)
                    let glow = intensity * entering * leaving * own * StreakStyle.gain(of: colour)

                    context.stroke(path, with: .color(colour.opacity(glow)),
                                   style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Seen from the side: streaks running past the thing they are behind, all one way.
struct SideStreaks: View {
    var intensity: Double = StreakStyle.sideWarp

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard intensity > 0 else { return }
                context.blendMode = .plusLighter

                let now = timeline.date.timeIntervalSinceReferenceDate

                for index in 0..<StreakStyle.sideCount {
                    let length = size.width * StreakStyle.sideLength
                        * (StreakStyle.shortest + StreakStyle.scatter(index, 2))
                    let speed = size.width * StreakStyle.sideSpeed
                        * (StreakStyle.slowest + StreakStyle.scatter(index, 3))

                    // Wrapped over the width plus one streak, so nothing is half-drawn
                    // at both ends at once.
                    let run = size.width + length
                    let travelled = (now * speed + Double(index) * 97)
                        .truncatingRemainder(dividingBy: run)
                    let x = travelled - length
                    // Spread over the whole height, all running the same way.
                    let y = StreakStyle.scatter(index, 1) * size.height
                    let streak = CGRect(x: x, y: y - StreakStyle.sideThickness / 2,
                                        width: length, height: StreakStyle.sideThickness)

                    let colour = StreakStyle.colour(StreakStyle.scatter(index, 5))
                    let glow = intensity
                        * (StreakStyle.faintest + StreakStyle.scatter(index, 4))
                        * StreakStyle.gain(of: colour)
                    context.fill(Capsule().path(in: streak), with: .color(colour.opacity(glow)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
