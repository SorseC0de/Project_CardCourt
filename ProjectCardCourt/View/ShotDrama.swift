import SwiftUI

/// What the ball does at the rim before the result is admitted.
///
/// The outcome is already settled by the rules, so a variant is never *deciding* anything
/// — it is chosen to match a result that already exists. Some can end either way and are
/// therefore available to both; the rest are tied to one.
///
/// Borrowed from Pokémon's capture shake: suspense on every throw stops being suspense, and
/// a near-certain one earns none at all.
enum ShotDrama: Equatable {
    case none
    /// Rattles the iron and drops off. Misses only.
    case rattle
    /// Rides the ring all the way round, then falls whichever way it was always going to.
    case roll
    /// Kicked straight up off the back iron, then in or past.
    case highBounce
    /// Off the glass and through. Makes only, and only from the middle percentages.
    case bank
    /// Through the ring and spun back out. Misses only.
    case halfwayOut
    /// All the way in, the board lights, and then it comes back out. Reserved for the
    /// high-percentage misses that deserve to be resented.
    case robbery

    /// Above this the shot is a formality and goes straight in.
    static let certainty = 75
    /// Roughly one shot in three gets the treatment.
    static let odds = 3

    /// The band a robbery can happen in: high enough to sting, below the point where
    /// suspense is skipped entirely.
    static let robberyFloor = 60
    /// How often an eligible miss becomes one. Rare on purpose.
    static let robberyOdds = 3

    static func choose(made: Bool, chance: Int) -> ShotDrama {
        guard chance < certainty, Int.random(in: 0..<odds) == 0 else { return .none }

        // Only ever steals a shot that looked good.
        if !made, chance >= robberyFloor, Int.random(in: 0..<robberyOdds) == 0 {
            return .robbery
        }

        var pool: [ShotDrama] = [.roll, .highBounce]
        if made {
            // Banking is a middling shot's move; nobody banks a wide-open one.
            if (40...60).contains(chance) { pool.append(.bank) }
        } else {
            pool += [.rattle, .halfwayOut]
        }
        return pool.randomElement() ?? .none
    }

    /// How long the ball spends at the rim before resolving.
    var seconds: Double {
        switch self {
        case .none:        return 0
        case .rattle:      return 0.85
        case .roll:        return 1.25
        case .highBounce:  return 1.05
        case .bank:        return 0.55
        case .halfwayOut:  return 0.90
        case .robbery:     return 2.00
        }
    }

    /// Banking wants its own burst, whatever the percentage would otherwise have given.
    var burst: (emoji: String, count: Int)? {
        self == .bank ? ("🏦", 18) : nil
    }
}

/// The robbery's beats, as fractions of its run. Shared so the board lights on the same
/// clock the ball moves on rather than a second one that can drift out of step.
enum Robbery {
    /// The ball is clear of the net and the shot looks good. Short, because a made ball
    /// is through the ring the moment it arrives — a slow drop lights the board late.
    static let through: CGFloat = 0.10
    /// It starts climbing back out, and the board takes the points away.
    static let reverse: CGFloat = 0.62
}

/// The ball's whole performance at the rim, as one animatable value.
///
/// Every variant is a function of `progress` 0...1 rather than a chain of offsets toggled
/// on and off. That was the first attempt and it threw the ball across the screen: turning
/// a roll on snapped its radius from nothing to full in a single frame, and clearing the
/// offset at the end snapped it back. One value, evaluated per frame, cannot jump.
struct DramaPath: GeometryEffect {
    var progress: CGFloat
    let drama: ShotDrama
    /// The ring's radius, which every variant is scaled against.
    let rim: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let p = min(max(progress, 0), 1)
        let offset = displacement(at: p)
        return ProjectionTransform(
            CGAffineTransform(translationX: offset.width, y: offset.height))
    }

    private func displacement(at p: CGFloat) -> CGSize {
        switch drama {
        case .none:
            return .zero

        case .rattle:
            // Three knocks, each smaller than the last, damped to nothing.
            let decay = 1 - p
            let bounce = abs(sin(Double(p) * .pi * 3))
            return CGSize(width: rim * 0.22 * decay * CGFloat(sin(Double(p) * .pi * 6)),
                          height: -rim * 0.18 * decay * CGFloat(bounce))

        case .roll:
            // All the way round the ring, seen at a slant, easing off as it drops in.
            let angle = Double(p) * 2 * .pi
            let grip = 1 - p * 0.35
            return CGSize(width: cos(angle - .pi / 2) * rim * 0.5 * grip,
                          height: sin(angle - .pi / 2) * rim * 0.5 * 0.3 * grip
                                  + rim * 0.5 * 0.3 * grip)

        case .highBounce:
            // Straight up off the back iron and back down.
            let rise = sin(Double(p) * .pi)
            return CGSize(width: rim * 0.10 * p, height: -rim * 1.5 * CGFloat(rise))

        case .bank:
            // Out to the glass, then back through the ring.
            let out = sin(Double(p) * .pi)
            return CGSize(width: rim * 0.42 * CGFloat(out), height: -rim * 0.5 * CGFloat(out))

        case .robbery:
            // All the way down through the net, a long beat to let it count, then back
            // up the way it came and out over the front of the ring. Run linear, so the
            // hold below is the time it says it is — eased, the plateau lands in the
            // fastest part of the curve and vanishes.
            if p < Robbery.through {
                let fall = p / Robbery.through
                return CGSize(width: 0, height: rim * 1.5 * CGFloat(fall * fall))
            }
            if p < Robbery.reverse { return CGSize(width: 0, height: rim * 1.5) }
            let rise = (p - Robbery.reverse) / (1 - Robbery.reverse)
            return CGSize(width: rim * 0.5 * CGFloat(rise * rise),
                          height: rim * 1.5 - rim * 2.4 * CGFloat(rise))

        case .halfwayOut:
            // Down into the ring, then spat back up and clear of it.
            let dip = sin(Double(min(p, 0.5)) * .pi)
            let spit = max(0, p - 0.5) * 2
            return CGSize(width: rim * 0.3 * spit,
                          height: rim * 0.45 * CGFloat(dip) - rim * 0.7 * spit * spit)
        }
    }
}

/// Carries the ball round the ring. Like the flight, the angle has to be the animatable
/// value — interpolating the resulting point would cut straight across the circle.
struct RimRoll: GeometryEffect {
    var angle: Double
    let radius: CGFloat
    /// The ring is seen at a slant, so the vertical travel is a fraction of the width.
    var squash: CGFloat = 0.27

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: cos(angle) * radius,
            y: sin(angle) * radius * squash))
    }
}
