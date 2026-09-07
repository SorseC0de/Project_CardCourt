import Foundation

/// The three ways he finishes at the rim.
///
/// **They share a wind-up and part company after it.** Every one opens on the two cells
/// of `Sprite.dunkPrepare`; what differs is how he climbs, which is the whole of what
/// makes them read as three different dunks rather than three sheets.
enum Dunk: String, CaseIterable, Codable, Hashable {
    /// Held on his first cell the whole way up, and the rest of it at the rim.
    case oneHand
    /// The first three cells over and over on the climb, then the finish.
    case reverse
    /// Played straight through, timed so he is at the rim on the fifth cell.
    case whirlwind

    /// Which cells play on the way up. A one-hand holds its first; a reverse cycles its
    /// first three; a whirlwind is already going and does not repeat anything.
    var climb: ClosedRange<Int>? {
        switch self {
        case .oneHand:   return 0...0
        case .reverse:   return 0...2
        case .whirlwind: return nil
        }
    }

    /// How many times the climb runs before he arrives. A one-hand holds one cell, so
    /// this is the count of passes rather than of frames.
    var climbRepeats: Int { self == .reverse ? 3 : 1 }

    /// The cell he has to be at the rim by. The whirlwind is the only one whose climb is
    /// its own animation, so it is the only one with a deadline.
    var arrivesBy: Int? { self == .whirlwind ? 4 : nil }

    /// Whether this one can come apart in mid-air. A whirlwind is already spinning, so
    /// spinning it further says nothing; the two that hold a pose have somewhere to go.
    var canTumble: Bool { self != .whirlwind }

    /// **What a man of this position throws down instead of shooting**, and how often.
    ///
    /// A centre finishes at the rim nine times in ten; a power forward two in three; a
    /// small forward one in four. Guards shoot. Nobody spins in off a plain possession —
    /// a whirlwind is something a card asks for.
    static func ordinary(for position: Position, roll: Int) -> Dunk? {
        let odds: (in: Int, of: Int)
        switch position {
        case .centre:        odds = (9, 10)
        case .powerForward:  odds = (2, 3)
        case .smallForward:  odds = (1, 4)
        default:             return nil
        }
        guard roll % odds.of < odds.in else { return nil }
        return roll.isMultiple(of: 2) ? .oneHand : .reverse
    }
}


/// How a dunk fails.
///
/// **Three shapes, not one.** A missed dunk is the one shot where *how* it missed is the
/// whole story: he never got up to it, he got up and sailed past it, or he arrived and
/// the iron kept it. A single "miss" animation would make all three the same event.
enum DunkMiss: String, CaseIterable, Codable, Hashable, Identifiable {
    /// Up and over. He holds the pose he went up in and carries on past the rim.
    case fliesPast
    /// The same trip, coming apart on the way. Rare, and only on the two that hold a
    /// pose — see `Dunk.canTumble`.
    case tumbles
    /// He does not get up to it. The leap tops out under the rim and he lands.
    case short
    /// He gets there. The finish plays out whole and the ball comes off the iron.
    case ironOut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fliesPast: return "past"
        case .tumbles:   return "tumble"
        case .short:     return "short"
        case .ironOut:   return "iron"
        }
    }

    /// Whether he ever reaches the rim, which is what says if there is a ball to come
    /// off it and whether the ring has anything to give.
    var reachesTheRim: Bool { self == .ironOut }

    /// How often each one comes up, against the others.
    ///
    /// **Not an even four.** Coming up short is what missing a dunk mostly is, and the
    /// iron keeping one is the next most ordinary thing that can happen at a rim. Sailing
    /// clear over it is a rarer sight, and coming apart in mid-air should be something you
    /// tell somebody about.
    var weight: Int {
        switch self {
        case .short:     return 10
        case .ironOut:   return 6
        case .fliesPast: return 3
        case .tumbles:   return 1
        }
    }

    /// Which one this miss is. **Rolled per device, like `ShotDrama`**: it is how the
    /// thing looked, not what happened, and the rules have already said he missed.
    ///
    /// A whirlwind cannot tumble, so its weight leaves the pool entirely rather than
    /// being rolled and rejected — the other three share it out between them.
    static func roll(for dunk: Dunk) -> DunkMiss {
        let pool = allCases.filter { $0 != .tumbles || dunk.canTumble }
        let total = pool.reduce(0) { $0 + $1.weight }
        var pick = Int.random(in: 0..<max(1, total))
        for kind in pool {
            pick -= kind.weight
            if pick < 0 { return kind }
        }
        return .short
    }
}
