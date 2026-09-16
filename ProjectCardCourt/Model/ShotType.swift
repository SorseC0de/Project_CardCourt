import Foundation

/// **How the ball is going up.** The shoot button is three buttons now: the shot you can
/// always take, and two that have to be earned.
///
/// They sit in a triangle. A layup is always available and pays a card back. A dunk wants
/// the look to already be good and costs somebody else a card. A three wants a full hand
/// and is worth the extra point, and it takes something off the floor on the way down.
///
/// The officials are the other half of it: each shot has a call watching for it, and a
/// Clamp can force a player into the one the crew is eyeing. Both are face-up, so the man
/// being squeezed can see it coming.
enum ShotType: String, Hashable, Codable, CaseIterable, Identifiable {
    /// The shot that is always there. Nothing gates it — a player with nothing left can
    /// still put the ball on the floor and go.
    case layup
    /// Earned with SHOT. The finish at the rim.
    case dunk
    /// Earned with a full hand. Worth one more point.
    case three

    var id: String { rawValue }

    var name: String {
        switch self {
        case .layup: return "Layup"
        case .dunk: return "Dunk"
        case .three: return "Three"
        }
    }

    /// What the scoreboard pays for one.
    func points(in rules: MatchRules) -> Int {
        self == .three ? rules.madeShotPoints + 1 : rules.madeShotPoints
    }

    /// SHOT a player must already have to go up with it.
    var requiredShot: Int? { self == .dunk ? 50 : nil }
    /// Cards a player must be holding to go up with it.
    var requiredHand: Int? { self == .three ? 5 : nil }

    /// **The layup's reward for having nothing left.** An empty hand is a man already at
    /// the rim; it is the one place in the game where being broke is worth something.
    static let emptyHandedLayupBonus = 25

    /// Printed under the button, so the gate is read rather than discovered.
    func requirement(in state: GameState) -> String? {
        switch self {
        case .layup: return nil
        case .dunk: return "SHOT \(requiredShot ?? 0)%"
        case .three: return "\(state.handLimit) cards"
        }
    }

    /// Whether a player may put this one up right now, before any Clamp has its say.
    func available(to seat: Seat, in state: GameState) -> Bool {
        if let shot = requiredShot, state.shot < shot { return false }
        if let hand = requiredHand, state[seat].bag.count < min(hand, state.handLimit) {
            return false
        }
        return true
    }
}


/// **What beating your man is worth.** The same three every time, so the choice is read
/// once and known for the rest of the game — you blew by him, and now you are the one
/// with the advantage.
enum ClampPayoff: String, Hashable, Codable, CaseIterable, Identifiable {
    /// Keep going.
    case draw
    /// Rise into the space he left.
    case shoot
    /// **He rotates.** The defender you just beat picks up whoever you throw it to,
    /// instead of going to the pile. You blew by him; now he is somebody else's problem.
    case passAndRotate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draw: return "Draw 1 card"
        case .shoot: return "Shoot at SHOT +\(ClampPayoff.shotBonus)%"
        case .passAndRotate: return "Pass, and he follows"
        }
    }

    /// What rising into the space is worth, for the one attempt.
    static let shotBonus = 25
}
