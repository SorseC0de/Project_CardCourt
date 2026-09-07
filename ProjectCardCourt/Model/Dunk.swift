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
