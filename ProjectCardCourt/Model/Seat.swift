import Foundation

/// The four positions around the diamond.
enum Seat: Int, CaseIterable, Hashable, Identifiable, Codable {
    case north, east, south, west

    var id: Int { rawValue }

    var clockwise: Seat { Seat(rawValue: (rawValue + 1) % 4)! }
    var counterClockwise: Seat { Seat(rawValue: (rawValue + 3) % 4)! }
    var across: Seat { Seat(rawValue: (rawValue + 2) % 4)! }

    /// Players face the centre of the diamond, so the seat on your left is the next
    /// one clockwise: West's left is North, South's left is West.
    var left: Seat { clockwise }
    var right: Seat { counterClockwise }

    /// Geometric pass targets only; `backToPasser` needs game state to resolve.
    func seat(inDirection direction: PassTarget) -> Seat? {
        switch direction {
        case .left:         return left
        case .right:        return right
        case .across:       return across
        case .backToPasser: return nil
        }
    }

    /// Seats in bidding/reveal order starting from this one and moving clockwise.
    var clockwiseOrderFromHere: [Seat] {
        var order = [self]
        while order.count < Seat.allCases.count { order.append(order[order.count - 1].clockwise) }
        return order
    }

    var name: String {
        switch self {
        case .north: return "North"
        case .east:  return "East"
        case .south: return "South"
        case .west:  return "West"
        }
    }

    var abbreviation: String { String(name.prefix(1)) }

    /// Who sits here. Fixed to the seat for now; when archetypes are shuffled per game
    /// these move onto the player alongside the personality.
    var playerName: String {
        switch self {
        case .north: return "Raheem"
        case .east:  return "Tanaka"
        case .south: return "You"
        case .west:  return "John"
        }
    }

    var isHuman: Bool { self == GameRules.humanSeat }

    /// Where this seat appears on screen for a given viewer. The viewer is always nearest,
    /// their opposite is upcourt, and their own left and right are screen left and right.
    ///
    /// This is what lets four players each see themselves at the bottom, and what makes
    /// Traded Mid-Game a change of viewer rather than a change of the whole court.
    func slot(viewedFrom viewer: Seat) -> Seat {
        if self == viewer { return .south }
        if self == viewer.across { return .north }
        if self == viewer.left { return .west }
        return .east
    }

    /// "John plays", but "You play".
    func verb(_ thirdPerson: String, _ secondPerson: String) -> String {
        isHuman ? secondPerson : thirdPerson
    }
}
