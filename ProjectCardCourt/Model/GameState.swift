import Foundation

/// A Clamp sitting on a player for the duration of their possession.
struct ActiveClamp: Hashable, Codable, Identifiable {
    /// Which cards this Clamp is holding down, chosen when it lands and then left alone.
    /// A lock that moved every time the hand was looked at could not be played around.
    var locked: [UUID] = []

    let id: UUID
    let card: CardDescriptor
    let from: Seat

    init(card: CardDescriptor, from: Seat, id: UUID = UUID()) {
        self.id = id; self.card = card; self.from = from
    }
}

/// A Clamp named for the scene that announces it: which card, and who set it. Carried on
/// the event rather than read back off the board, because the board is cleared by the
/// time some of these are read.
struct ClampBrief: Hashable, Codable, Identifiable {
    let id: UUID
    let card: CardDescriptor
    let from: Seat
}

extension ActiveClamp {
    var brief: ClampBrief { ClampBrief(id: id, card: card, from: from) }
}

/// The last shot a player made: which round it went in, and what its chance had been
/// talked up to. Public — everybody watched it happen.
struct Make: Hashable, Codable {
    let round: Int
    let chance: Int
}

struct PlayerState: Hashable, Identifiable, Codable {
    let seat: Seat
    var bag: [Card] = []
    /// Lasts exactly one possession — see Rules.beginPossession.
    var clamps: [ActiveClamp] = []
    /// Passives in play, oldest first. Capped by MatchRules.intangibleSlots.
    var intangibles: [CardDescriptor] = []
    /// Drives Hot Hand. Rolled over when a round ends.
    /// Injuries carried right now.
    ///
    /// **Not in the discard.** An Injury is on the man, which is what keeps a Devastating
    /// one out of the halftime shuffle — that gathers the deck, the pile and every bag,
    /// and a card sitting here is in none of them. A round Injury is shed into the pile
    /// when the round ends, so the shuffle does pick it up.
    var injuries: [CardDescriptor] = []
    /// Torn Achilles: the cards that survived this turn's lock, rolled once per
    /// possession and then left alone.
    var injuryUnlocked: [UUID] = []
    /// All-Swissh Selection: cards owed on the next make, and shown in the HUD until they
    /// are paid. Survives the round — it is a selection, not a hot streak.
    var drawsOwedOnMake = 0
    var lastMake: Make?
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
    /// Bone Bruise: the turn opens by giving one up, and the sheet says whose choice it
    /// is. Its own phase rather than `awaitingDiscard`, which is a price paid for a shot
    /// and resolves into one.
    case awaitingInjuryDiscard(seat: Seat, count: Int)
    /// At the line. One attempt at a time until the trip runs out.
    case freeThrows(trip: FreeThrowTrip)
    case gameOver

    /// The seat that owes a decision, if any.
    var actingSeat: Seat? {
        switch self {
        case .inbound(let seat):    return seat
        case .possession(let seat): return seat
        case .awaitingDiscard(let seat, _, _): return seat
        case .awaitingInjuryDiscard(let seat, _): return seat
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
    /// What a shooting Special Move is paying for the attempt it is about to take.
    ///
    /// Not part of SHOT: it is spent on that one shot and cleared, so a cancelled attempt
    /// leaves the board exactly where it was. See the note in `Rules.apply`.
    var pendingShotBonus = 0
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
    /// Benched: whoever has to hand the ball over, queued rather than set.
    ///
    /// A Game Break resolves from inside `draw`, which runs in the middle of
    /// `beginPossession` — and `beginPossession` sets the phase on its way out, over
    /// whatever it finds there. Setting the phase from inside it is writing to something
    /// that is about to be overwritten, which is why Benched did nothing at all.
    var pendingInbound: Seat?
    /// How many times each Whistle has been called this round, by descriptor id. Cleared
    /// at the top of a round, which is what makes Delay-of-Game's second call a foul.
    var whistleCallsThisRound: [String: Int] = [:]
    /// Set by a Special Move for the shot it is about to take.
    var pendingShotOverride: ShotOverride?
    /// True when this possession began by grabbing a miss. Putback Tip is the only card
    /// that asks, and it is the whole of what makes it a *putback*.
    var possessionFromRebound = false
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
    /// How many bodies are standing on a player: what every Clamp on them brings, which
    /// the sheet sets per card.
    func defenders(on seat: Seat) -> Int {
        self[seat].clamps.reduce(0) { $0 + ($1.card.clamp?.defenders ?? 1) }
    }

    var isOver: Bool { if case .gameOver = phase { return true }; return false }
}

/// RNG access goes through these so no call site takes overlapping `inout` access to state.
extension GameState {
    mutating func shuffled(_ cards: [Card]) -> [Card] { cards.shuffled(using: &rng) }
    mutating func pick(from seats: [Seat]) -> Seat { seats.randomElement(using: &rng)! }
    mutating func roll(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &rng) }
}
