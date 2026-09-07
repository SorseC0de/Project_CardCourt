import Foundation

// Moved out of View/ShotDrama.swift: what the ball does at the rim is a fact about
// the shot, not about how it is drawn. `DramaPath` and `RimRoll` — the two that
// actually draw it — stay behind. See _Design/one-queue.md: a step has to be
// describable without a view.

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
    /// Driven straight through. **A dunk has no rim drama** — the whole point of going up
    /// and putting it in by hand is that the iron never gets a say, so it never rattles,
    /// rolls or banks. Never chosen by `choose`: it is assigned to any scene carrying one.
    case dunk

    /// Above this the shot is a formality and goes straight in.
    static let certainty = 75
    /// Roughly one shot in three gets the treatment.
    static let odds = 3

    /// The band a robbery can happen in: high enough to sting, below the point where
    /// suspense is skipped entirely.
    static let robberyFloor = 60
    /// How often an eligible miss becomes one. Rare on purpose.
    static let robberyOdds = 3

    /// What the rim does with a dunk.
    ///
    /// A finish put down has none of it — see `.dunk`. One that comes off the iron gets
    /// the two variants that make sense for a ball driven at the ring from above: it
    /// rattles, or it kicks off the back of it. **Not the roll** — a ball rolling the
    /// ring is a jumper's death, and nothing dropped from the rim rides it. Nor the bank,
    /// which needs glass, nor a robbery, which is a make being taken back.
    static func offTheIron() -> ShotDrama {
        [.rattle, .highBounce].randomElement() ?? .rattle
    }

    /// What a dunk's ball does, given how the dunk went. A trip that never reaches the
    /// iron has nothing at the rim to watch.
    static func forDunk(miss: DunkMiss?) -> ShotDrama {
        switch miss {
        case .none:    return .dunk
        case .ironOut: return offTheIron()
        default:       return .none
        }
    }

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
        case .dunk:        return 0.40
        }
    }

    /// Banking wants its own burst, whatever the percentage would otherwise have given.
    var burst: (emoji: [String], count: Int)? {
        self == .bank ? (["🏦"], 18) : nil
    }
}
