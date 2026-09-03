import Foundation

/// A Clamp sitting on a player for the duration of their possession.
struct ActiveClamp: Hashable, Codable, Identifiable {
    let id: UUID
    let card: CardDescriptor
    let from: Seat

    init(card: CardDescriptor, from: Seat, id: UUID = UUID()) {
        self.id = id; self.card = card; self.from = from
    }
}

struct PlayerState: Hashable, Identifiable, Codable {
    let seat: Seat
    var bag: [Card] = []
    /// Lasts exactly one possession — see Rules.beginPossession.
    var clamps: [ActiveClamp] = []
    /// Passives in play, oldest first. Capped by MatchRules.intangibleSlots.
    var intangibles: [CardDescriptor] = []
    /// Drives Hot Hand. Rolled over when a round ends.
    var scoredThisRound = false
    var scoredLastRound = false
    var points = 0
    var assists = 0
    var rebounds = 0
    var turnovers = 0

    var id: Seat { seat }
    var score: Int { points + assists + rebounds - turnovers }
}

enum Phase: Hashable, Codable {
    case inbound(inbounder: Seat)
    case possession(holder: Seat)
    case awaitingRebound(shooter: Seat)
    /// Turnaround Three: pick any number to discard, then the shot goes up.
    case awaitingDiscard(seat: Seat, card: CardDescriptor, bonusEach: Int)
    /// At the line. One attempt at a time until the trip runs out.
    case freeThrows(trip: FreeThrowTrip)
    case gameOver

    /// The seat that owes a decision, if any.
    var actingSeat: Seat? {
        switch self {
        case .inbound(let seat):    return seat
        case .possession(let seat): return seat
        case .awaitingDiscard(let seat, _, _): return seat
        case .freeThrows(let trip): return trip.shooter
        default:                    return nil
        }
    }
}

struct GameState: Codable {
    /// Frozen at creation — see MatchRules.
    let rules: MatchRules
    var players: [PlayerState]
    var deck: [Card] = []
    var discard: [Card] = []
    var phase: Phase = .inbound(inbounder: .south)
    var round = 1
    var inbounder: Seat = .south
    var ball: Seat?
    /// nil while the inbounder decides — the UI shows "--".
    var shotClock: Int?
    var shot = 0
    /// Whistles set down and waiting. Resolved in the order they were armed, so a
    /// Whistle that cancels another Whistle has a defined winner.
    var armedWhistles: [ArmedWhistle] = []
    /// Played, but with nobody to land on yet. Attaches to the next ball-holder.
    var pendingClamps: [ActiveClamp] = []
    /// An armed Whistle that let a Clamp resolve and is waiting for it to land, so it can
    /// negate what it does rather than the play that made it.
    var pendingClampVoid: UUID?
    /// Swallowed Whistle. Cleared when the round turns over.
    var whistlesSilenced = false
    /// Awarded but not yet shot. Never set straight into `phase` — a Foul is drawn from
    /// inside `beginPossession`, which overwrites whatever phase it finds on the way out.
    var pendingFreeThrows: FreeThrowTrip?
    /// How many times each Whistle has been called this round, by descriptor id. Cleared
    /// at the top of a round, which is what makes Delay-of-Game's second call a foul.
    var whistleCallsThisRound: [String: Int] = [:]
    /// Set by a Special Move for the shot it is about to take.
    var pendingShotOverride: ShotOverride?
    var lastPasser: Seat?
    /// Descriptor id of the last card played in the current possession; arms combos.
    var lastPlayThisPossession: String?
    /// Move cards played in the current possession. Uncapped by the rules, but read by
    /// the AI and by cards that restrict further Move plays.
    var movesThisPossession = 0
    var rng: SeededRNG

    subscript(seat: Seat) -> PlayerState {
        get { players[seat.rawValue] }
        set { players[seat.rawValue] = newValue }
    }

    var half: Int { round <= rules.roundsPerHalf ? 1 : 2 }
    var isOver: Bool { if case .gameOver = phase { return true }; return false }
}

/// RNG access goes through these so no call site takes overlapping `inout` access to state.
extension GameState {
    mutating func shuffled(_ cards: [Card]) -> [Card] { cards.shuffled(using: &rng) }
    mutating func pick(from seats: [Seat]) -> Seat { seats.randomElement(using: &rng)! }
    mutating func roll(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &rng) }
}
