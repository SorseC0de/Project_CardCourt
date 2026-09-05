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
    /// The Zone, if this player has popped one — see `SwisshUp`. One at a time.
    var swisshUp: ActiveSwisshUp?
    /// All-Swissh Selection: cards owed on the next make, and shown in the HUD until they
    /// are paid. Survives the round — it is a selection, not a hot streak.
    var drawsOwedOnMake = 0
    /// Unselfish: owed to this player's next attempt, whenever it comes.
    var nextShotBonus = 0
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
    /// A card that names a player: which one, and who is being asked.
    ///
    /// One phase for every kind of it — a pass of choice, a Nutmeg's two, an Ankle
    /// Breaker's victim. What the choice *does* is on the card; this only collects it.
    case awaitingTarget(seat: Seat, card: CardDescriptor, choices: [Seat])
    /// Triple Threat: one of the card's own branches.
    case awaitingMode(seat: Seat, card: CardDescriptor)
    /// A card taken out of somebody else's hand, chosen rather than rolled for. The hand
    /// is face down — picking one is a guess, which is the point.
    case awaitingCardFrom(seat: Seat, card: CardDescriptor, victim: Seat)
    /// Wet Spot: one Injury off the table, some of them face down.
    case awaitingInjuryPick(seat: Seat, card: CardDescriptor)
    /// A fourth passive arriving on a full board: which of the four goes.
    case awaitingIntangibleDrop(seat: Seat, offered: [CardDescriptor])
    /// Wide-Open Three: naming the others, one at a time, until you stop.
    case awaitingNaming(seat: Seat, card: CardDescriptor, named: [Seat])
    /// Franchise Player: something off the man who just took the pass. His passives are
    /// face up and his hand is not, so this is one question over two kinds of card.
    case awaitingToll(seat: Seat, victim: Seat)
    /// Bone Bruise: the turn opens by giving one up, and the sheet says whose choice it
    /// is. Its own phase rather than `awaitingDiscard`, which is a price paid for a shot
    /// and resolves into one.
    case awaitingInjuryDiscard(seat: Seat, count: Int)
    /// Clear Out: asked the moment the ball arrives, before the defenders land on him.
    /// Answering no puts the card down for the possession; answering yes spends it and the
    /// ball carries on without him.
    case awaitingClearOut(seat: Seat, card: CardDescriptor)
    /// At the line. One attempt at a time until the trip runs out.
    case freeThrows(trip: FreeThrowTrip)
    case gameOver

    /// **A card that is still being played.**
    ///
    /// It has been laid down and has asked its own question, and nothing it does is
    /// settled until that question is answered — so the board holds what it showed
    /// before. Dime's ten per cent was landing while the prompt naming who to pass it to
    /// was still open, which read as the card paying out before it had been played.
    var isMidPlay: Bool {
        switch self {
        case .awaitingTarget, .awaitingMode, .awaitingCardFrom, .awaitingInjuryPick,
             .awaitingNaming, .awaitingToll, .awaitingIntangibleDrop:
            return true
        default:
            return false
        }
    }

    /// The seat that owes a decision, if any.
    /// A short name for the phase, for logs.
    var label: String {
        switch self {
        case .inbound(let s): return "inbound(\(s))"
        case .possession(let s): return "possession(\(s))"
        default: return "\(self)".prefix(while: { $0 != "(" }).description
        }
    }

    var actingSeat: Seat? {
        switch self {
        case .inbound(let seat):    return seat
        case .possession(let seat): return seat
        case .awaitingDiscard(let seat, _, _): return seat
        case .awaitingInjuryDiscard(let seat, _): return seat
        case .awaitingTarget(let seat, _, _): return seat
        case .awaitingMode(let seat, _): return seat
        case .awaitingCardFrom(let seat, _, _): return seat
        case .awaitingInjuryPick(let seat, _): return seat
        case .awaitingIntangibleDrop(let seat, _): return seat
        case .awaitingToll(let seat, _): return seat
        case .awaitingClearOut(let seat, _): return seat
        case .awaitingNaming(let seat, _, _): return seat
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
    /// Attempts already taken this round, so Sixth Man can count to six.
    var shotsThisRound = 0
    /// Rock Fight: nobody shoots from a look this good, for the rest of the round.
    var shotCeilingThisRound: Int?
    /// Fundamentalist: which Moves have already been played this possession.
    var movesPlayedThisPossession: Set<String> = []
    /// Triple Threat: no more Moves for the rest of it.
    var movesClosed = false
    /// Lob: the man it found owes a shot before anything else.
    var mustShootFirst: Seat?
    /// Dime: who threw it, so a make pays them the extra assist.
    var dimeFrom: Seat?
    /// Gravity: where the pending Clamps are actually going to land.
    var clampMagnet: Seat?
    /// The card waiting on an answer, and the seat that played it — which is not always
    /// the seat being asked. Floor General aims other people's passes.
    var pendingPlay: CardDescriptor?
    var pendingActor: Seat?
    /// Nutmeg: where the card taken is headed, rather than to the pile.
    var stealTravelsTo: Seat?
    /// Wide-Open Three: who has been named so far, and who is owed an assist if it drops.
    var namedForAssist: [Seat] = []
    /// Kick-Out: the next basket this possession is worth one more.
    var pendingBonusPoint = 0
    /// Whether the last play was itself a combo — a Drive off a Dribble is a dribble
    /// drive, and a card can ask for that rather than for a Drive.
    var lastPlayWasCombo = false
    /// Alley-Oop: the man it found owes a shot the instant the chain settles. Queued for
    /// the same reason a hand dump is — a shot resolved mid-draw is a shot taken before
    /// the cards that were still arriving.
    var shootsAtOnce: Seat?
    /// Right Back: the ball owes a trip home, and which card is paying for it. Queued to
    /// the chain's edge so whatever the outward leg cost him lands first.
    var returnsTo: Seat?
    var returnLeg: CardDescriptor?
    /// Fresh Ball: the next possession opens without its draw.
    var skipsNextDraw = false
    /// Free Agent: hands owed to the pile once the draw chain that turned it up is done.
    ///
    /// Queued rather than dumped where it lands. Turning it up on the second card of an
    /// opening deal should cost the hand you end up with, not the one card you had.
    var handsOwed: Set<Seat> = []
    /// Boards holding more passives than the rules allow, waiting to be asked which goes.
    /// Queued for the same reason a hand is: the phase set where the overflow happens is
    /// overwritten by whatever the draw chain does next.
    var overflowing: Set<Seat> = []
    /// Wet Spot: what is on offer, and which of them the picker cannot see.
    var injuriesOffered: [CardDescriptor] = []
    var injuriesHidden: Set<String> = []
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
    /// A possession held mid-arrival while its man is asked whether he is stepping out of
    /// it — see `Rules.beginPossession`. Everything it needs to pick up where it stopped.
    struct HeldPossession: Hashable, Codable {
        let seat: Seat
        let ticks: Bool
        let fromRebound: Bool
    }
    var heldPossession: HeldPossession?
    /// Back-and-Forth Game: how many more Breaks get waved away as they land.
    var breaksWaived = 0
    /// Mic'd Up: SHOT carried by whoever is holding the ball. Not part of `shot`, which
    /// is the ball's and travels with it — this one is gone the moment he gives it up.
    var holderShot = 0
    /// Altercation: the man you just shoved is not the man you throw it in to.
    var inboundBarred: Seat?
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
