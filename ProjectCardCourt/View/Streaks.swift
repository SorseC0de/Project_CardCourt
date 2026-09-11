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
    /// **How fast the floor runs at you.** Raised from a half: the court is meant to
    /// read as ground going past rather than as a pattern drifting, and the slowest of
    /// them came up with it so the spread stays the same shape.
    static let speed: Double = 0.85
    static let paceSlowest: Double = 0.55
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

    // ── The floor's own: dark marks running with the boards ────────────
    /// Deliberately a fraction of the side field's. These are polish on a surface, not
    /// the space going past — anything you can count is too many.
    static var floorWarp: Double = 0.30
    static let floorCount = 20
    /// Wide, and squared off rather than capped. These are boards, not marks.
    static let floorThickness: CGFloat = 32.0
    /// How much of a tile's length is spent fading out behind it, as a share. The head is
    /// a clean edge and the tail is not there at all — a plank you can see both ends of
    /// is a stripe.
    static let floorTail: CGFloat = 0.55
    /// The faintest a tile gets, as a share of the ceiling. The ceiling is `floorWarp`,
    /// so this only ever spreads them below it.
    static let floorDimmest: Double = 0.28

    /// The grain, as it were. Warm black is the ground note and the browns are the boards
    /// that are not quite the same as their neighbours — which is the whole of what makes
    /// a floor read as laid rather than painted.
    static let floorTones: [Color] = [
        PixelPalette.warmBlack, PixelPalette.warmBlack,
        PixelPalette.mocha, PixelPalette.coffee, PixelPalette.maroon,
    ]

    static func floorTone(_ index: Int) -> Color {
        floorTones[min(floorTones.count - 1,
                       Int(scatter(index, 16) * Double(floorTones.count)))]
    }
    /// How far out they run, as a share of the floor's half-width. Inside 1, so they are
    /// on the boards rather than past the edge like `CourtStreaks`.
    static let floorReach: CGFloat = 0.88
    /// And clear of the middle, where the players stand and the piles sit.
    static let floorClear: CGFloat = 0.12
    /// Slower than the side field. The floor is the thing being travelled over, so its
    /// marks should read as sliding under rather than tearing past.
    static let floorSpeed: Double = 0.30

    // ── The rebound's streaks: sideways, passing ───────────────────────
    static var sideWarp: Double = 0.72
    static let sideCount = 40
    /// Thick enough to read as objects going past rather than as scratches on the lens.
    static let sideThickness: CGFloat = 3.0
    /// And thinner again on the name call, which is a fraction of the mother shape's
    /// height: the same stroke on a smaller plate reads as a much heavier one.
    static let sideThicknessSmall: CGFloat = 2.0
    /// The bloom under each one: how much wider, and how much of its brightness it keeps.
    static let sideBloom: CGFloat = 2.6
    static let sideBloomGain: Double = 0.35
    static let sideLength: CGFloat = 0.18
    static let sideSpeed: CGFloat = 3.4
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

/// Dark marks on the boards, running the way the court runs.
///
/// The same depth sampling `CourtStreaks` uses, so they bend exactly as the floor bends —
/// but inside its edge rather than outside it, in warm black rather than sparks, and few
/// enough to read as a surface rather than as weather. Drawn **normally**, not under
/// `plusLighter`: adding a dark colour to a dark floor adds nothing, and the whole point
/// of these is that they darken.
struct FloorStreaks: View {
    var intensity: Double = StreakStyle.floorWarp

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard intensity > 0 else { return }

                let court = CourtGeometry(size: size)
                let now = timeline.date.timeIntervalSinceReferenceDate

                for index in 0..<StreakStyle.floorCount {
                    let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                    let spread = StreakStyle.floorReach - StreakStyle.floorClear
                    // Own question numbers, or this field would sit in the same lanes the
                    // side one does and the two would read as one interrupted set.
                    let lateral = side * (StreakStyle.floorClear
                        + CGFloat(StreakStyle.scatter(index, 11)) * spread)

                    let pace = StreakStyle.paceSlowest + StreakStyle.scatter(index, 12)
                    let turn = now * StreakStyle.floorSpeed * pace
                        + StreakStyle.scatter(index, 13)
                    let phase = turn - turn.rounded(.down)

                    let head = CGFloat(pow(phase, StreakStyle.curve)) * StreakStyle.overrun
                    let tail = max(0, head - head * StreakStyle.trail
                                   * CGFloat(StreakStyle.stretchLeast
                                             + StreakStyle.scatter(index, 14)
                                             * (1 - StreakStyle.stretchLeast)))
                    guard head > tail else { continue }

                    var path = Path()
                    let steps = 10
                    var ends: (head: CGPoint, tail: CGPoint) = (.zero, .zero)
                    for step in 0...steps {
                        let depth = tail + (head - tail) * CGFloat(step) / CGFloat(steps)
                        let point = CGPoint(x: court.centreX + court.halfWidth(at: depth) * lateral,
                                            y: court.y(at: depth))
                        step == 0 ? path.move(to: point) : path.addLine(to: point)
                        if step == 0 { ends.tail = point }
                        if step == steps { ends.head = point }
                    }

                    let width = StreakStyle.floorThickness
                        * (StreakStyle.thinnest + CGFloat(phase))
                    let entering = min(1, phase / StreakStyle.dawn)
                    let leaving = min(1, (1 - phase) / StreakStyle.dusk)
                    // Spread under the ceiling rather than up to it: `intensity` is the
                    // most a tile is ever worth, and every one of them is some share of it.
                    let own = StreakStyle.floorDimmest
                        + StreakStyle.scatter(index, 15) * (1 - StreakStyle.floorDimmest)
                    let ink = intensity * entering * leaving * own

                    // Solid at the leading edge and gone behind it, run along the tile's
                    // own axis so the fade follows the bend the same way the shape does.
                    let tone = StreakStyle.floorTone(index)
                    let grain = Gradient(stops: [
                        .init(color: tone.opacity(0), location: 0),
                        .init(color: tone.opacity(ink), location: StreakStyle.floorTail),
                        .init(color: tone.opacity(ink), location: 1),
                    ])
                    context.stroke(path,
                                   with: .linearGradient(grain, startPoint: ends.tail,
                                                         endPoint: ends.head),
                                   style: StrokeStyle(lineWidth: width, lineCap: .butt))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Seen from the side: streaks running past the thing they are behind, all one way.
struct SideStreaks: View {
    var intensity: Double = StreakStyle.sideWarp
    /// One colour for the lot, for a ground that is already saying whose it is. Nil keeps
    /// the table's kit colours, which is what a black card wants.
    var ink: Color?
    /// How heavy each one is. The smaller the plate, the thinner they have to be drawn.
    var thickness: CGFloat = StreakStyle.sideThickness

    @State private var look = PlayerLook.shared

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
                    let streak = CGRect(x: x, y: y - thickness / 2,
                                        width: length, height: thickness)

                    // The table's own colours, not the port's four. What goes past is
                    // the players, so it should be the players' kit.
                    let seat = Seat.allCases[Int(StreakStyle.scatter(index, 5) * 4) % 4]
                    let colour = ink ?? look.jersey(for: seat)
                    let glow = intensity
                        * (StreakStyle.faintest + StreakStyle.scatter(index, 4))

                    // A wider, fainter pass under the solid one. Under `plusLighter` that
                    // reads as a bloom around the capsule rather than a blur of it, which
                    // is what a hard-edged game wants.
                    let bloom = streak.insetBy(
                        dx: 0,
                        dy: -thickness * (StreakStyle.sideBloom - 1) / 2)
                    context.fill(Capsule().path(in: bloom),
                                 with: .color(colour.opacity(glow * StreakStyle.sideBloomGain)))
                    context.fill(Capsule().path(in: streak), with: .color(colour.opacity(glow)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
