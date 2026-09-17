import Foundation
import Observation

/// How long the table pauses so the player can follow what happened.
enum Pacing {
    /// An opponent's deliberation lands somewhere in here, so play never feels metronomic.
    /// Global for now; each archetype will carry its own range later.
    static var thinkTime: ClosedRange<Double> = 0.75...1.75
    /// Longer, because a throw-in is a decision made from the sideline with the whole
    /// floor set and waiting. At the ordinary think the court snapped into position and
    /// the ball was gone again before anybody could read who was where.
    static var inboundThink: ClosedRange<Double> = 1.5...2.5
    /// How long the round slab holds. Long enough to read a two-word line and see what
    /// is standing on it, short enough that it is not a gate between rounds.
    static let roundCall = 1.6
    /// How long a shot's scene holds, on top of whatever its drama costs. Long enough
    /// for the burst at the rim to have its life — that is the celebration, and it was
    /// being cut off with the view.
    static let cutscene = 4.2
    /// How long a figure takes to warp off the floor, or on to it — see `ColumnWarp`.
    ///
    /// The floor and the sideline take a turn each: he comes apart where he was, and only
    /// then does he put himself together where he is going. Everything else on the floor
    /// waits out both halves, or the ball is thrown before he has arrived to throw it.
    static let warp = 0.14
    /// Longer than the ball takes to arrive and settle, or the scene cuts away while it
    /// is still rolling — which is what made it look like it never stopped.
    static let turnover = 4.0
    /// The ball arriving, three cuts on it, and then the clock.
    static let shotClockTurnover = 5.5
    static let reveal = 1.0
    /// The whistle, the back, the flip, and the name under it.
    static let whistleReveal = 3.0
    /// **A call starts on the man making it.** How close the camera goes to him, how long
    /// it takes to get there, and how long he is left blowing it before the card comes up.
    static let whistleZoom: CGFloat = 1.8
    static let whistleFrame = 0.28
    static let whistleHold = 1.50
    /// **A challenge starts on the man taking it.** How close, how long to get there, and
    /// how long he is held while the star opens.
    static let challengeZoom: CGFloat = 2.0
    static let challengeFrame = 0.25
    static let challengeHold = 1.00
    /// One card crossing the court. Dealing is brisker than an in-game draw because
    /// twenty of them go by at once.
    /// How long a card takes to come off the pile. It was a third of a second, which is
    /// not long enough to read a card being turned over and put away — the stage had been
    /// quietly flying them for 0.55 all along, and that is the trip that reads.
    static let drawFlight = 0.55
    /// What the deck spends turning to face whoever is drawing, before it throws — see `CourtStage`,
    /// which plays that ahead of the card. The beat has to cover it, or the card lands in
    /// a hand before the pile has finished reaching for it.
    static let deckLean = 0.16
    /// The gap between one card being done with and the next being asked for. Small, and
    /// the only thing standing between a flight and being cancelled on its last frame.
    static let handover = 0.08
    /// How long a card takes to reach the pile from a hand.
    static let spendFlight = 0.34
    static let dealFlight = 0.30
    /// How long the host holds the opening deal waiting for the other devices to say they
    /// are on screen. Long enough for a slow join, short enough that a phone that never
    /// answers does not hold the game up.
    static let tableWait = 6.0
    /// The whole of a defender's swipe: arrive, take, drift off.
    /// The whole of a defender's swipe: arrive, hold, drift off, fade. Must outlast
    /// `DefenderSwipe`'s own timings or the scene is cut while he is still walking.
    static let clampSwipe = 1.3
    /// The inbound's own throw: how long the ball takes to cross from the sideline, and
    /// how long the thrower stands there having thrown it. He is watching it land.
    static let inboundThrow = 0.5
    /// **And how long everybody holds before the floor runs again.** At half a second they
    /// were off and running the moment the ball arrived, before the stoppage had read.
    static let inboundHold = 1.5
    /// How long a phase call holds before it takes itself off.
    static let actionCall = 1.4
    /// How long the board holds after a basket.
    static let scoreCall = 2.0
    /// The beat between one revealed card leaving and the next arriving.
    static let betweenReveals = 0.3
    static let bidReveal = 1.5
    /// How long a live match waits on somebody's phone before deciding for them.
    ///
    /// One number for every decision, because a player learning two different clocks is a
    /// worse game than one that is occasionally generous.
    ///
    /// **nil turns the clocks off**, and they stay off until online play is smooth. A
    /// seat that never answers should hang where you can see it rather than be papered
    /// over by a fallback that looks like the game working — while multiplayer is still
    /// being chased, a clock quietly answering for somebody is one more thing to rule out
    /// before you can trust what you are looking at.
    ///
    /// A real table cannot wait on somebody who has put their phone down, so this goes to
    /// 30 the moment a match runs clean.
    static let actionClock: Double? = nil
    /// One opponent attempt from the line, start to finish.
    static let freeThrow = 2.5

    static func think() -> Double { .random(in: thinkTime) }
    static func think(onInbound: Bool) -> Double {
        .random(in: onInbound ? inboundThink : thinkTime)
    }
}

struct LogLine: Identifiable {
    enum Kind { case normal, score, penalty, marker }
    let id = UUID()
    let text: String
    let kind: Kind
}

/// A make with a scene of its own.
///
/// Most shots play out the same way — the ball's business at the rim is the whole story.
/// These two are about the shooter rather than the ball, so he turns to face you once the
/// shot animation has finished with him.
enum ShotSignature: Equatable {
    case none
    /// Lethal Shooter. He already knew, and the arithmetic goes off around him.
    case understood
    /// Turnaround Three: he took it facing away, so facing you is where he ends up.
    case turnaround
}

struct ShotCutscene: Identifiable, Equatable {
    let id = UUID()
    let shooter: Seat
    let chance: Int
    let made: Bool
    /// Bodies the shooter was contesting, counted before the shot cleared them.
    let defenders: Int
    /// What the ball does at the rim before the result is admitted.
    let drama: ShotDrama
    /// How this one is being finished, when it is finished at the rim. Nil is a jumper,
    /// and a `var` so the memberwise initialiser defaults it — the bench builds scenes
    /// that way and none of them is a dunk.
    var dunk: Dunk?
    /// How it failed, when it did. Nil on a make and on anything that is not a dunk.
    var dunkMiss: DunkMiss?
    /// Picked once here rather than in the view, which re-evaluates.
    let spoils: String
    /// What the make says, if it says anything beyond the word.
    let line: SwisshLine
    /// Which way a miss caroms off. Rolled per shot so they do not all fly the same way.
    let caromSide: CGFloat

    /// What the miss gets called. Rolled once here rather than in the view, so it does
    /// not change under the player mid-animation.
    let missCall: String

    /// Whether this one gets a scene of its own.
    let signature: ShotSignature
    /// Taken from three, which puts the floor further back under the hoop.
    var isThree = false

    /// What a miss gets called.
    ///
    /// **A dunk is never a brick.** A brick is a shot that never had a chance from
    /// distance — a man at the rim who does not finish missed for a reason you watched,
    /// and the word for it is the reason. Rolled once, here, rather than in the view,
    /// so it does not change under the player mid-animation.
    static func missCall(chance: Int, dunk: DunkMiss?) -> String {
        switch dunk {
        case .short:     return "SHORT"
        case .fliesPast, .tumbles: return "SOMETHING'S A-MISS"
        case .ironOut:   return "NOPE"
        case .none:
            return chance < 40
                ? "BRRRICK"
                : ["NO GOOD", "A MISS", "MISSED", "NOPE"].randomElement()!
        }
    }

    /// Built directly, for replaying the scene from the debug panel.
    init(shooter: Seat, chance: Int, made: Bool, defenders: Int,
         signature: ShotSignature = .none, dunk: Dunk? = nil,
         dunkMiss: DunkMiss? = nil) {
        self.dunk = dunk
        let missed = dunk.map { made ? nil : (dunkMiss ?? DunkMiss.roll(for: $0)) } ?? nil
        self.dunkMiss = missed
        self.signature = signature
        self.shooter = shooter
        self.chance = chance
        self.made = made
        self.defenders = defenders
        self.drama = dunk == nil ? ShotDrama.choose(made: made, chance: chance)
                                 : ShotDrama.forDunk(miss: missed)
        self.spoils = ["🪣", "💸", "💰"].randomElement()!
        self.line = SwisshLine.roll()
        self.caromSide = Bool.random() ? 1 : -1
        self.missCall = ShotCutscene.missCall(chance: chance, dunk: missed)
    }

    init?(events: [GameEvent], defenders: Int = 0, lastPlay: String? = nil,
          dunk: Dunk? = nil) {
        var shooter: Seat?
        var chance = 0
        var made: Bool?
        var breakdown: ShotResolution?
        for event in events {
            switch event {
            case .shotAttempted(let seat, let pct, let steps):
                shooter = seat; chance = pct; breakdown = steps
            case .shotMade: made = true
            case .shotMissed: made = false
            default: break
            }
        }
        guard let shooter, let made else { return nil }
        // Settled by the rules and carried in the state, so every device watches the same
        // finish rather than four of them each rolling one — see `Rules.dunk(for:card:)`.
        self.dunk = dunk
        // **How it failed is not.** That is how the thing looked rather than what
        // happened, the same as `ShotDrama`, and the rules have already said he missed.
        self.dunkMiss = dunk.map { made ? nil : DunkMiss.roll(for: $0) } ?? nil
        // Read off the shot's own arithmetic rather than off the rules: whatever set the
        // number is named in the breakdown, which is the one place that already knows.
        if breakdown?.steps.contains(where: { $0.label == CardLibrary.lethalShooter.name }) == true {
            self.signature = .understood
        } else if lastPlay == CardLibrary.turnaroundThree.id {
            self.signature = .turnaround
        } else {
            self.signature = .none
        }
        self.shooter = shooter
        self.chance = chance
        self.made = made
        self.defenders = defenders
        // A brick is its own announcement; everything else takes an even roll.
        self.drama = dunk == nil ? ShotDrama.choose(made: made, chance: chance)
                                 : ShotDrama.forDunk(miss: self.dunkMiss)
        self.spoils = ["🪣", "💸", "💰"].randomElement()!
        self.line = SwisshLine.roll()
        self.caromSide = Bool.random() ? 1 : -1
        self.missCall = ShotCutscene.missCall(chance: chance, dunk: self.dunkMiss)
    }
}

/// A board coming down, played on the floor rather than on the rebound screen.
///
/// The screen says who won it; this is him going up to take it, with the ball thrown out
/// of the hoop on the horizon to meet his hands at the top.
struct ReboundLeap: Identifiable, Equatable {
    let id = UUID()
    let seat: Seat
    /// **He threw it up himself.** A pass named his own seat, so the ball does not come
    /// out of the hoop — it leaves his hands, rises to the height a board is taken at,
    /// and he goes up and gets it. The leap and the follow-through are the same ones.
    var offTheGlass = false
}

/// A throw-in on its way. Identified, so each one is a fresh flight rather than the last
/// one's view handed a new pair of points — which leaves it already arrived.
struct ThrowIn: Identifiable, Equatable {
    let id = UUID()
    let from: Seat
    let to: Seat
}

/// A turnover, played as a beat rather than processed instantly.
struct TurnoverCutscene: Identifiable, Equatable {
    enum Kind: Equatable {
        /// The clock running out, which is the one turnover with nobody to blame and its
        /// own close-up to say so.
        case shotClock
        /// Behind-the-Back with nobody to give it back to.
        case badReturn
        case whistle(String)
        /// **Anything else the rules charged, by the name they charged it under** — a
        /// Travel, a Clear Out to nobody, a card that cost the ball. It was defaulting to
        /// `shotClock`, so every one of them played the dying-clock close-up and read
        /// "Shot Clock Violation" whatever had actually happened.
        case named(String)
    }

    let id = UUID()
    let seat: Seat
    let kind: Kind
    /// Which bit Travel plays. Rolled here rather than in the view, so the pause can be
    /// the length of the bit that is actually going to run.
    let travelBit: TravelBit?
    /// Which side the ball comes in from, read off the pass that lost it. A ball that
    /// arrives from the same side it was thrown from keeps the play's direction.
    let fromLeft: Bool

    /// How long to hold the scene.
    var hold: Double {
        if let travelBit { return travelBit.hold }
        return kind == .shotClock ? Pacing.shotClockTurnover : Pacing.turnover
    }

    /// Built directly, for playing a bit from the debug panel.
    init(seat: Seat, kind: Kind, fromLeft: Bool = Bool.random()) {
        self.seat = seat
        self.kind = kind
        self.fromLeft = fromLeft
        self.travelBit = kind == .whistle("Travel") ? .allCases.randomElement() : nil
    }

    init?(events: [GameEvent]) {
        var kind = Kind.shotClock
        var seat: Seat?
        var thrower: Seat?
        var charged: String?
        for event in events {
            switch event {
            case .failedReturn:                 kind = .badReturn
            case .whistleBlew(_, let card, _, _, _, _): kind = .whistle(card.name)
            case .turnover(let who, let cause):
                seat = who
                // Nil is the clock, which is the only turnover nobody caused.
                if let cause { charged = cause }
            case .passed(_, let from, _, _, _):    thrower = from
            default: break
            }
        }
        guard let seat else { return nil }
        self.seat = seat
        // A Whistle or a failed return has already named itself; otherwise the rules'
        // own reason is the name.
        if case .shotClock = kind, let charged { kind = .named(charged) }
        self.kind = kind
        // Whoever last threw it decides which side it comes in from; with nobody to read,
        // either side is as true as the other.
        self.fromLeft = thrower.map { $0.slot(viewedFrom: GameRules.localSeat) == .west }
            ?? Bool.random()
        self.travelBit = kind == .whistle("Travel") ? .allCases.randomElement() : nil
    }
}

/// A card someone just played, held up for everyone.
struct PlayedCard: Identifiable, Equatable {
    let id = UUID()
    let seat: Seat
    let descriptor: CardDescriptor
    /// Whistles stay face down; arming one is meant to be secret.
    let faceDown: Bool

    static func first(in events: [GameEvent]) -> PlayedCard? {
        for event in events {
            switch event {
            case .passed(let card, let from, _, _, let returning):
                // **A leg home is not a second play.** Right Back sends the ball out and
                // has it thrown straight back, and the return carries the same card from
                // the other man's seat — which held the card up all over again.
                if returning { continue }
                return PlayedCard(seat: from, descriptor: card, faceDown: false)
            case .movePlayed(let seat, let card, _):
                return PlayedCard(seat: seat, descriptor: card, faceDown: false)
            case .clampSet(let seat, let card):
                return PlayedCard(seat: seat, descriptor: card, faceDown: false)
            case .whistleUsed(let seat, let card):
                // Face up: a Timeout is called out loud. Only an armed Whistle is private.
                return PlayedCard(seat: seat, descriptor: card, faceDown: false)
            case .whistleArmed(let seat):
                return PlayedCard(seat: seat, descriptor: CardLibrary.timeout, faceDown: true)
            default:
                continue
            }
        }
        return nil
    }
}

/// One card on its way from the deck to a player.
struct DrawFlight: Identifiable, Equatable {
    let id = UUID()
    let seat: Seat
}

/// An opponent's attempt from the line. Played out rather than resolved silently, so a
/// trip looks the same from either side of the table.
struct AIFreeThrow: Identifiable, Equatable {
    let id = UUID()
    let trip: FreeThrowTrip
    let made: Bool
}

/// A Whistle being called, turned face up for everyone.
/// A basket: what it was worth, and who is owed for it.
struct ScoreCall: Identifiable, Equatable {
    let id = UUID()
    let seat: Seat
    let points: Int
    /// Everyone credited. More than one only when a card hands the assist around.
    let assists: [Seat]
}

struct WhistleReveal: Identifiable, Equatable {
    let id = UUID()
    /// **Which official blew it**, by his place in the crew rather than by his card — any
    /// of the three can call a travel, so the card no longer names the man.
    var caller: UUID?
    /// **Nil for the crew**, which is every referee now: they are dealt face-up off the
    /// officials deck and belong to nobody.
    let owner: Seat?
    let card: CardDescriptor
    let cancelled: String
    /// The card it was called on, so the referee can hold up the evidence.
    let cancelledCard: CardDescriptor?
    /// First time this player has ever met this card.
    let isNew: Bool

    /// A Whistle counts as met when it is *called*, not when it is set down — a badge on
    /// the face-down card would give away the trap the game works hard to keep.
    static func first(in events: [GameEvent], seen: SeenCards) -> WhistleReveal? {
        for case .whistleBlew(let owner, let card, let cancelled, let victim, _, let caller) in events {
            return WhistleReveal(caller: caller, owner: owner, card: card,
                                 cancelled: cancelled, cancelledCard: victim,
                                 isNew: seen.meet(card.id))
        }
        return nil
    }
}

/// A Game Break or Intangible shown large to everyone as it is drawn.
struct RevealCutscene: Identifiable, Equatable {
    let id = UUID()
    let seat: Seat
    let card: CardDescriptor
    let isIntangible: Bool
    let isNew: Bool

    /// One apply can reveal several — Designed Play refills a hand and anything in that
    /// refill reveals too — so they queue rather than overwrite.
    static func queue(from events: [GameEvent], seen: SeenCards) -> [RevealCutscene] {
        events.compactMap { event in
            switch event {
            case .gameBreakRevealed(let seat, let card), .injuryRevealed(let seat, let card):
                return RevealCutscene(seat: seat, card: card, isIntangible: false,
                                      isNew: seen.meet(card.id))
            case .intangibleRevealed(let seat, let card):
                return RevealCutscene(seat: seat, card: card, isIntangible: true,
                                      isNew: seen.meet(card.id))
            default:
                return nil
            }
        }
    }
}

@MainActor
@Observable
final class GameController {

    enum Gate: Equatable {
        case thinking

        /// Whether the floor is waiting on the game rather than on a player.
        var isThinking: Bool { if case .thinking = self { return true }; return false }

        case awaitingInbound(Seat)
        case awaitingMove(Seat)
        case awaitingBid(shooter: Seat)
        case awaitingDiscard(card: CardDescriptor, bonusEach: Int)
        /// Stepping out of the play, asked the moment the ball reaches you.
        case awaitingCounter(cards: [Card])
        /// A card's "You may": yes or no.
        case awaitingOption(CardOption)
        /// Bone Bruise's toll at the top of the turn. Its own case, because the shot
        /// discard resolves into a shot and this one resolves into a turn.
        case awaitingGiveUp(card: CardDescriptor, count: Int)
        /// A card that names a player, and the branches of one that names a mode.
        case awaitingTarget(card: CardDescriptor, choices: [Seat])
        case awaitingMode(card: CardDescriptor)
        /// A defender beaten: which of the three things that is worth.
        case awaitingPayoff(clamp: CardDescriptor)
        /// A call, and the one challenge a game that can throw it out.
        case awaitingChallenge(card: CardDescriptor)
        /// A card out of somebody else's hand, face down.
        case awaitingCardFrom(card: CardDescriptor, victim: Seat)
        /// Wet Spot: one Injury off the table, some of them face down.
        case awaitingInjuryPick(card: CardDescriptor)
        /// A fourth passive on a full board: which of the four goes.
        case awaitingIntangibleDrop(offered: [CardDescriptor])
        /// Franchise Player: his board face up, his hand face down.
        case awaitingToll(victim: Seat)
        /// Wide-Open Three: naming the others, one at a time, until you stop.
        case awaitingNaming(card: CardDescriptor, named: [Seat])
        case awaitingFreeThrow(FreeThrowTrip)
        case gameOver
    }

    private(set) var state: GameState
    /// What the board is showing, which lags what the rules have already decided.
    ///
    /// The rules run in full before a single frame of the play is drawn, so a card that
    /// moves SHOT had already moved it before the card itself was held up — the number
    /// changed and then the reason for it appeared. This catches up on the play's own
    /// beat, like every line in the log.
    /// **The state the table is looking at**, which lags the state the rules are in.
    ///
    /// The rules run a whole chain in one go — a card is played, a Break turns up, a
    /// referee takes the floor, a hand empties — and the presentation walks that chain a
    /// beat at a time. Views bound to `state` show every consequence the instant the rules
    /// reach it, which is how a referee arrived before the Whistle that called him had
    /// finished being shown, and a pending-draw icon lit before its card had left the
    /// screen. Every one of those was fixed on its own, per card, forever.
    ///
    /// So the floor reads this instead. It is advanced by `catchUp()` at each beat of
    /// `present`, and it is **always equal to `state` by the time anybody is asked for
    /// anything** — see the call in `run`, which is what keeps a decision from being made
    /// against a stale board.
    private(set) var shown: GameState

    private(set) var shownShot = 0
    /// S.O.S: a three picked up on Sell-Out Stadium, waiting on whether it goes up as a two.
    private(set) var sellOutChoice: Card?
    /// What the pile is showing. A card leaves the deck when it lands in a hand, not when
    /// the rules decide it has — the same lag `shownShot` carries, for the same reason.
    private(set) var shownDeck = 0
    /// Who the court draws holding the ball.
    ///
    /// The rules hand it over the instant the card is played, so the receiver was already
    /// holding it before the throw had been drawn — and then the throw was drawn, which
    /// is the ball crossing twice. This lags across a pass and nothing else.
    private(set) var shownBall: Seat?
    /// A throw-in that has left his hands and not yet arrived. The court keeps its set
    /// while this is on: the dim stays, everybody stays where they were, and the thrower
    /// stands frozen on the pose he threw in.
    private(set) var throwing: ThrowIn?
    private(set) var log: [LogLine] = []
    /// Whether this device has put its bid in and is waiting on the rest of the table.
    ///
    /// **The board asks everybody at once**, so the bar cannot simply close when you
    /// answer — the gate is still `.awaitingBid` while the others think. Without this the
    /// host could keep picking cards after bidding, and a guest's bar vanished instead of
    /// saying it had been heard.
    private(set) var bidPlaced = false

    private(set) var gate: Gate = .thinking {
        didSet {
            // A bid belongs to the board that asked for it.
            if case .awaitingBid = gate {} else { bidPlaced = false }
            guard gate.isThinking else { wentQuiet = nil; return }
            // Only the moment it *went* quiet, so a run of thinking gates does not keep
            // resetting the clock the watchdog is reading.
            if !oldValue.isThinking { wentQuiet = .now }
        }
    }
    /// When the gate last went to `.thinking`, or nil while somebody is being asked for
    /// something. The watchdog reads it — see `watchTheLoop`.
    private var wentQuiet: Date?
    private var watchdog: Task<Void, Never>?
    /// How many tasks are driving the floor.
    ///
    /// **A chain playing out is not a stopped game.** The gate reads `.thinking` for the
    /// whole of a presentation, and plenty of them run well past eight seconds — the
    /// opening deal, a rebound's reveal and its cutscene, a shot with drama on it. The
    /// watchdog was cutting those in half and starting a second chain over the top.
    ///
    /// Counted here rather than guessed at from what is on screen: a task is either
    /// driving the floor or it is not, and `zero and thinking` is the whole definition of
    /// a game that has stopped.
    private var working = 0
    private(set) var cutscene: ShotCutscene?
    private(set) var turnover: TurnoverCutscene?
    private(set) var reveal: RevealCutscene?
    private(set) var whistleReveal: WhistleReveal?
    private(set) var flight: DrawFlight?
    private(set) var aiFreeThrow: AIFreeThrow?
    /// What the deck is doing. Idle unless something asks it to perform.
    private(set) var deckRoutine: DeckRoutine = .rest
    /// Who the stage is dealing a card to, and a token so the same seat twice still counts
    /// as a second throw.
    private(set) var stageDeal: (seat: Seat, id: UUID)?
    /// A card on its way from a hand to the pile. Cards were simply vanishing out of
    /// hands, which reads as the game deleting them rather than somebody giving one up.
    private(set) var spend: (seat: Seat, id: UUID)?
    /// The opening performance. Set once, at the top of a match.
    private(set) var opening: OpeningDeal?
#if DEBUG
    /// A pass thrown for the eye only. No cards, no rules, no turn — it exists so the
    /// catch can be tuned without playing a hand to reach one.
    private(set) var practicePass: (from: Seat, to: Seat)?
#endif
    /// **Cards the fan still shows that the rules no longer hold.**
    ///
    /// The rules take a card the moment it is played; the hand is drawn from `shown`,
    /// which walks the chain a beat at a time — so for the length of the activation the
    /// same card was on screen twice, one held up in front of the court and one
    /// apparently stuck in the fan behind it.
    ///
    /// **Worked out, never remembered.** Marking a card as spent when it is played needs
    /// unmarking on every path where the rules give it back — a card the rules refuse, a
    /// Whistle blown over the play, a possession that ends underneath it — and one missed
    /// path is a card invisible in your hand for the rest of the game. This is the whole
    /// of the idea instead: held by the fan, and not by the rules.
    var justPlayed: Set<Card.ID> {
        let real = Set(state[GameRules.localSeat].bag.map(\.id))
        return Set(shownBag(of: GameRules.localSeat).map(\.id)).subtracting(real)
    }
    private(set) var playedCard: PlayedCard?
    /// The play the last card-flash was for — see `showPlayedCard`.
    private var flashed: PlayedCard?
    /// Stamped once the cutscenes clear, which is when the catch should play.
    private(set) var ballSettledAt: Date?
    /// A made three, celebrating. The points are withheld from the scoreboard until the
    /// number reaches it.
    private(set) var celebratingThree: Seat?
    /// A basket, and who is credited for it. Up on every make, not only the big ones.
    private(set) var scoreCall: ScoreCall?
    /// A one-off Clamp taking its cards: who from, and a stamp so a second one replays
    /// rather than being mistaken for the first.
    private(set) var clampSwipe: (seat: Seat, id: UUID)?
    /// The phase or event currently announcing itself. See `ActionCall`.
    private(set) var actionCall: ActionCall?
    /// The slab said between rounds and at the half — see `RoundCallView`.
    private(set) var roundCall: RoundCall?
    /// The Clamps the `.clamped` call is holding up. Alongside the call rather than
    /// inside it: every other call is a word and nothing else.
    private(set) var clampCall: [ClampBrief] = []
    /// Who the **court** is setting up for on the sideline, which is not the same seat the
    /// rules have inbounding.
    ///
    /// The rules name him the moment a possession ends, and everything that ended it —
    /// the draws, a Game Break turning up, a reveal — is still queued to be shown. Reading
    /// the phase directly put the whole floor into the inbound pose behind those, so a
    /// Game Break played out over four players stood in a line waiting for a throw that
    /// had not been called yet. This is raised when the presentation gets there.
    private(set) var inbounding: Seat?
    /// Who the **floor** shows as clamped.
    ///
    /// The rules put the coils on a man the instant his possession opens, which is a
    /// beat or two before the call that explains them — so he was already bound while
    /// the card that bound him was still being held up. Raised when the presentation
    /// gets there, and dropped when the Clamps do.
    private(set) var boundSeats: Set<Seat> = []
    /// Raised when the played card's beat is nearly up, so the name over it can leave
    /// before the card does.
    private(set) var playedCardLeaving = false

    /// The game held where it stands — the pause button, and anything that takes the
    /// screen over to be read.
    ///
    /// **Only ever a solo thing.** The other phones in a live match are not waiting for
    /// this one, so pausing there just means missing your turn.
    private(set) var isPaused = false

    /// Cards the rules have dealt that the table has not seen arrive.
    ///
    /// Everything a move does is decided the instant the rules run, and the hand is drawn
    /// from the rules — so a card that draws put its card in the fan before the card that
    /// drew it had finished being played, and the flight across the court landed on a hand
    /// that already had it. Held out of the bag until the flight lands, the same way
    /// `shownBall` and `shownDeck` hold back the ball and the pile.
    private(set) var undelivered: Set<UUID> = []

    /// Passives the rules have slotted that the table has not seen turn over.
    ///
    /// Same fault as an instant draw, one board along: a passive drawn in the opening
    /// deal took its slot the moment the rules ran, so it was sitting on the plate before
    /// the card that put it there had been shown. Counted per seat rather than held by
    /// id — an Intangible is a descriptor and has none, and they are appended, so the
    /// ones still owed are the ones on the end.
    private(set) var unrevealed: [Seat: Int] = [:]

    /// The slots as the table has seen them.
    func shownIntangibles(of seat: Seat) -> [CardDescriptor] {
        Array(shown[seat].intangibles.dropLast(unrevealed[seat] ?? 0))
    }

    /// A bag as the table has seen it.
    func shownBag(of seat: Seat) -> [Card] {
        guard !undelivered.isEmpty else { return shown[seat].bag }
        return shown[seat].bag.filter { !undelivered.contains($0.id) }
    }

    /// Whether this table can be paused at all.
    /// Whether this table can be paused at all. **Somebody leaving pauses it regardless**:
    /// the game cannot carry on until it is told whether to, and the people still here are
    /// not waiting on the one who went.
    var canPause: Bool { Table.shared.remotes.isEmpty || !walkedOut.isEmpty }

    /// Whether the floor can be read right now. Always, when nobody else is waiting; in a
    /// live match only during your own possession, since the game carries on without you.
    var canInspect: Bool { canPause || state.ball == GameRules.localSeat }

    /// **Counted, because more than one thing can hold the game at once.** A first
    /// sighting waiting to be tapped and a card raised off the floor are two holds, and
    /// putting one down used to release the other.
    private var holds = 0

    func pause() {
        guard canPause else { return }
        holds += 1
        isPaused = true
    }

    func resume() {
        holds = max(0, holds - 1)
        isPaused = holds > 0
    }
    /// What the last attempt was actually taken at.
    ///
    /// Not the same number as the board: the board reads the ball's SHOT, and a shot can
    /// be priced above or below it by whatever paid for it. The rebound says what he
    /// missed *at*.
    private(set) var lastChance: Int?
    private(set) var withheldPoints: (seat: Seat, amount: Int)?
    /// Whether the log has already said this device has nobody to broadcast to.
    private var toldNobodyIsListening = false
    private(set) var flightDuration = Pacing.drawFlight
    /// Set for a beat after a rebound so the reveal can be shown, then cleared.
    private(set) var revealedBids: [Seat: Int]?
    /// Who is going up for the board right now, if anybody.
    private(set) var reboundLeap: ReboundLeap?
    /// The last board this device sent or was sent, for reading off a screen beside
    /// another phone — see `fingerprint`.
    private(set) var lastBoard = "—"
    /// When the last pass left the passer's hands, so the beat can wait out the catch
    /// without waiting for what has already been spent — see `settleTheCatch`.
    private var passLeftAt: Date?
    var bidSelection: Set<Card.ID> = []

    /// The shuffle this game came from. Rolled again when a match starts — see
    /// `dealForTheTable`.
    private(set) var seed: UInt64
    private var ai: AITable
    /// Held back from `init` so the deal can be animated once the view is up.
    private var openingDraws: [GameEvent] = []
    private var loop: Task<Void, Never>?

    let mode: MatchRules

    init(seed: UInt64 = UInt64.random(in: 1...9_999_999), mode: MatchRules = .standard) {
        self.seed = seed
        self.mode = mode
        self.ai = AITable(seed: seed)
        let (state, events) = Rules.newGame(seed: seed, rules: mode)
        self.state = state
        shown = state
        self.openingDraws = events
        record(events)
    }

    // MARK: - Lessons

    /// **A How To Play table**: no deal, no opponents taking turns. The lesson stages each
    /// hand and waits on the player — see `TutorialDirector`.
    static func lesson() -> GameController {
        let controller = GameController()
        controller.isLesson = true
        return controller
    }

    private(set) var isLesson = false
    /// The player's plays in this lesson, counted once the table has shown each one.
    private(set) var lessonPlays = 0
    /// Set once the ball has left the player: the lesson's cue for what comes next.
    private(set) var lessonBallGone = false

    /// The ball crosses slower while a lesson shows a pass, and the camera follows it.
    private(set) var lessonSlowMotion = false

    func setLessonSlowMotion(_ slow: Bool) {
        lessonSlowMotion = slow
        PassTiming.tempo = slow ? PassTiming.slowMotion : 1
        if !slow { camera = nil }
    }

    /// What the court's camera is framing, if anything — see `CourtCamera`.
    private(set) var camera: CourtCamera?
    /// Points the court's camera, or gives it back the whole floor with nil.
    func frame(_ shot: CourtCamera?) { camera = shot }
    /// The last pass thrown, which the court plays the throw off.
    private(set) var passThrow: PassThrow?

    /// **The referee the set pieces draw**: whoever was on the floor as this batch began.
    ///
    /// Read live off `shown`, he gave the game away — `shown` jumps to the end of a batch
    /// at its first event, so a Whistle spent by the shot took the referee out of the scene
    /// that was still playing, and a shot scene with no referee in it was a shot that had
    /// gone in.
    private(set) var refereeOnFloor: ArmedWhistle?

    /// A coin in the air, held long enough to be watched — see `CoinFlipView`.
    private(set) var coinFlip: CoinFlip?

    /// One leg of a lesson: these cards in the player's hand, the ball in his hands at the
    /// top of a possession, and nothing else on the floor. No hand carries on as things
    /// stand. Either way the next draws turn up `deckTop`, first draw first.
    func stageLesson(hand: [CardDescriptor]?, deckTop: [CardDescriptor] = []) {
        // Drawn off the end, so the first draw goes on last.
        state.deck.append(contentsOf: deckTop.reversed().map {
            Card($0.resolved(passShotBonus: state.rules.passShotBonus))
        })
        guard let hand else { return }
        loop?.cancel()
        let me = GameRules.localSeat
        for seat in Seat.allCases {
            state[seat].clamps = []
            state[seat].injuries = []
            state[seat].injuryUnlocked = []
            state[seat].intangibles = []
        }
        state[me].bag = hand.map { Card($0.resolved(passShotBonus: state.rules.passShotBonus)) }
        state.pendingClamps = []
        state.armedWhistles = []
        state.pending = []
        state.courtCard = nil
        state.ballCard = nil
        state.ball = me
        state.phase = .possession(holder: me)
        state.lastPlayThisPossession = nil
        state.lastPlayWasCombo = false
        state.movesThisPossession = 0
        state.movesPlayedThisPossession = []
        state.moveCardsThisPossession = 0
        state.movesClosed = false
        state.lastPasser = nil
        state.arrivedBy = nil
        state.mustShootFirst = nil
        state.shot = state.rules.startingShot
        state.shotClock = state.shotClockLength
        lessonBallGone = false
        catchUp()
        shownShot = state.shot
        shownBall = me
        gate = .awaitingMove(me)
    }

    /// What the table can see of your chair — the staged board, like everything else
    /// the floor draws. See `shown`.
    var human: PlayerState { shown[GameRules.localSeat] }

    /// Passives sitting in a slot that currently pay nothing — Hot Hand without a make
    /// behind it, and anything like it.
    var dormantIntangibles: Set<String> {
        Set(shownIntangibles(of: GameRules.localSeat)
            .filter { Rules.isDormant($0, for: GameRules.localSeat, in: shown) }
            .map(\.id))
    }

    var humanPasses: [Card] { human.bag.filter(\.isPass) }

    // MARK: - The match

    /// The other devices, when there are any. `nil` is a solo game, and every path below
    /// falls through to exactly what it did before there was such a thing as a match.
    private(set) var match: (any MatchTransport)?

    /// True when this device only chooses and watches. The rules are running elsewhere,
    /// and nothing here may touch `state` except by being told to.
    ///
    /// **Latched at `join`, not read off the transport.** It used to be
    /// `match.isActive && !match.isHost` asked fresh every time — and `isActive` is
    /// `match != nil && !seats.isEmpty`, a live property of a connection that can report
    /// anything mid-match. The only thing standing between a hiccup there and disaster
    /// was `guard !isGuest` in a watchdog that fires every two seconds: read `false` once
    /// and a guest starts its own `run()` over the host's board — a board whose RNG
    /// `redacted(for:)` has zeroed, so it would resolve the rest of the game from seed 0
    /// and broadcast none of it. A role is decided when you sit down.
    private(set) var isGuest = false

    /// What has arrived from the other devices and not been acted on yet. One slot per
    /// seat: a client that sends twice before the host looks has changed its mind, which
    /// is allowed — it is still only ever one decision.
    private var bidsFromWire: [Seat: Posted<[Card.ID]>] = [:]
    private var movesFromWire: [Seat: Posted<Move>] = [:]
    private var discardsFromWire: [Seat: Posted<[Card.ID]>] = [:]
    private var giveUpsFromWire: [Seat: Posted<[Card.ID]>] = [:]
    private var freeThrowsFromWire: [Seat: Posted<Bool>] = [:]
    private var decisionsFromWire: [Seat: Posted<Decision>] = [:]

    /// An answer, and the question it was answering.
    ///
    /// **The stamp is the whole point.** Every one of these is accepted only while the
    /// phase says this seat is the one being asked — but a message that arrived in time
    /// and was never *consumed* used to sit in its slot until the next `waitOn` for that
    /// seat spent it on something else. `.move` is the worst of them: it is accepted
    /// whenever the seat is the acting one, which is every `awaiting*` phase, so a play
    /// made a moment late could be parked and then handed over as the answer to the next
    /// possession.
    ///
    /// Stamped with the batch that carried the question, and read back only while the
    /// host is still on that batch. Sweeping on a phase change would have been the
    /// obvious fix and is wrong: there is a window between the phase moving and the sweep
    /// noticing in which a perfectly good answer arrives and is thrown away.
    struct Posted<Value> {
        let batch: Int
        let value: Value
    }

    /// Which question is on the table, as the wire counts it — see `Digest`.
    private var askedAt: Int { digest.batches }

    /// Who has left and not yet been answered for. The floor holds while this is not
    /// empty — see `keepPlaying` and `stopHere`.
    private(set) var walkedOut: Set<Seat> = []

    /// Whether the device the rules were running on has gone. There is nothing to play
    /// on with — see `keepPlaying`, which will not pretend otherwise.
    private(set) var hostGone = false

    /// **Play on without them.** Their hand, their turn and their strip stay exactly where
    /// they were; the house chooses from here, the name is marked, and the skin goes to
    /// metal so nobody mistakes it for somebody still sitting there.
    func keepPlaying() {
        // Nothing to keep playing. Said here as well as in the view, so the answer does
        // not depend on which button somebody was offered.
        guard !hostGone else { stopHere(); return }
        let gone = walkedOut
        walkedOut.removeAll()
        for seat in gone { Table.shared.replaceWithComputer(at: seat) }
        resume()
        guard !isGuest else { return }
        loop?.cancel()
        drive { await run() }
    }

    /// **Put it down.** A game two people started is not one game once one of them has
    /// gone, and finishing it alone is not always what anybody wants.
    func stopHere() {
        walkedOut.removeAll()
        resume()
        quit()
    }

    /// Seats whose device has said it is on screen and ready to be dealt to. The host
    /// holds the opening deal until they all have — see `waitForTheTable`.
    private var readySeats: Set<Seat> = []
    /// Whether the game has been started. See `begin`.
    private var hasBegun = false
    /// Everything this device has been told, folded in order — see `Digest`. The host
    /// builds it as it sends; a guest builds it as it receives; they should match.
    private(set) var digest = Digest()
    /// What each guest has been told, folded as *it* was told it. The host keeps one per
    /// seat because each seat is told a different story — see `broadcast`.
    private var digests: [Seat: Digest] = [:]
    /// Whether the two have already been seen to disagree, so it is said once rather than
    /// on every batch after it.
    private(set) var parted = false

    /// One thing the host says happened, waiting its turn to be shown.
    struct Batch {
        let state: GameState
        let events: [GameEvent]
    }

    /// **What a guest has been told and has not finished watching.**
    ///
    /// A batch used to cancel the one before it. The host broadcasts at the *top* of its
    /// own presentation and then spends the animation budget locally, so the next batch
    /// leaves it about when it finishes showing this one — one network hop ahead of a
    /// guest that started later and is still going. Everything past the cancellation
    /// point was simply lost, `record(ledger)` included, which is why a guest's game log
    /// is missing lines a host's is not. `present`'s own comment concedes it: *"on a
    /// guest that is most of them"*.
    ///
    /// The queue is the fix, and it is the small version of the one the whole engine is
    /// headed for — see `_Design/one-queue.md`. Arrivals are added at the back and drained
    /// one at a time, so a guest shows every beat in the order the host sent it and simply
    /// runs behind when it has to.
    private var watching: [Batch] = []
    /// Whether the drain is already running. It feeds itself until the queue is empty.
    private var watchingNow = false
    /// Which drain is the current one.
    ///
    /// **A cancelled drain still has a tail.** It is suspended inside `present`, and when
    /// the cancellation lets it go it runs its last two lines — putting `watchingNow`
    /// down and setting the gate — over the top of whichever drain replaced it. The next
    /// batch then found the flag clear, started a *third*, and cancelled the second
    /// mid-beat. Every arrival after a catch-up truncated the one before it, which is the
    /// fault this queue existed to fix. Only the drain still holding the current number
    /// may write anything shared.
    private var watchGeneration = 0

    /// The guest saying it is here, until it is dealt to. See `announceUntilDealt`.
    private var ready: Task<Void, Never>?
    /// Whether the opening deal has gone out to the other devices yet. Until it has, a
    /// board sent to anybody is a hand that arrives without being dealt.
    private var dealtTheTable = false

    /// Attaches the transport. Safe to call before there is a match: nothing changes
    /// until `isActive`, and doing it early is the point — a handler wired after the
    /// first message has already been delivered will never see it.
    func join(_ transport: any MatchTransport) {
        match = transport
        // Whatever the connection says later, this is the seat we took.
        isGuest = transport.isActive && !transport.isHost
        DevLog.say(.net, "join: active=\(transport.isActive) host=\(transport.isHost)"
                   + " → \(isGuest ? "GUEST" : "HOST")"
                   + "  seat=\(GameRules.localSeat.name)"
                   + "  remotes=\(Table.shared.remotes.map(\.name).joined(separator: ","))")
        transport.onHostMessage = { [weak self] in self?.receive($0) }
        transport.onClientMessage = { [weak self] in self?.receive($1, from: $0) }
        // A seat whose player has gone is played by the house for the rest of the game.
        // Pausing a four-handed game on one dropped phone would end it in practice.
        // **Somebody walking out is the table's business, not the wire's.** It used to
        // swap them for the house without a word, so a game quietly became a different
        // one — you were beaten by a machine wearing a person's name and never told.
        // Everybody left is asked instead; see `walkedOut`.
        transport.onSeatLost = { [weak self] seat in
            guard let self else { return }
            // **The host leaving is not somebody leaving.** The rules were running on
            // that device; there is no game here to play on without it, and offering to
            // would strand this one — `keepPlaying` swaps the seat for a computer and
            // then returns early on a guest, leaving it with no loop, no host, and a gate
            // stuck on `.thinking` for good.
            if self.isGuest, seat == transport.hostSeat { self.hostGone = true }
            self.walkedOut.insert(seat)
            self.pause()
        }
    }

    /// Shows what is waiting, one batch at a time, in the order it arrived.
    ///
    /// **Nothing here cancels anything.** The only reason to interrupt a guest mid-beat
    /// is something that cannot wait — somebody leaving — and that pauses the floor
    /// rather than cutting the story short.
    private func drainTheWatch() {
        guard !watchingNow, !watching.isEmpty else { return }
        watchingNow = true
        watchGeneration += 1
        let mine = watchGeneration
        loop?.cancel()
        drive { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.watchGeneration == mine, !self.watching.isEmpty {
                let next = self.watching.removeFirst()
                self.state = next.state
                await self.present(next.events,
                                   defenders: self.defenderCount(
                                    on: next.state.phase.actingSeat ?? GameRules.localSeat))
            }
            guard self.watchGeneration == mine else { return }
            self.watchingNow = false
            self.gate = self.localGate
        }
    }

    /// Puts the lagging readouts where the board actually is.
    ///
    /// The ball, the pile and the SHOT are all drawn a beat behind the rules on purpose —
    /// a card leaves the deck when it lands in a hand, not when the rules say so. That
    /// lag is right while a batch is playing and wrong the moment the board is replaced
    /// wholesale, which is what a catch-up is.
    private func settleTheReadouts() {
        shownBall = state.ball
        shownDeck = state.deck.count
        shownShot = state.shot + state.holderShot
    }

    /// Takes whatever a cut-off presentation left on screen back off it.
    ///
    /// A catch-up board replaces the story, and a story stopped in the middle leaves its
    /// scenery standing — a cutscene held, a card in the air, bids revealed, a man still
    /// up at the rim. None of it belongs to the board that just arrived.
    private func clearTheScene() {
        throwing = nil
        cutscene = nil
        turnover = nil
        whistleReveal = nil
        stageDeal = nil
        opening = nil
        playedCard = nil
        clampSwipe = nil
        actionCall = nil
        revealedBids = nil
        reboundLeap = nil
        flashed = nil
        undelivered.removeAll()
        unrevealed.removeAll()
    }

    /// **One line that says what board this device is looking at.**
    ///
    /// Printed by the host as it sends and by every guest as it receives, so two phones
    /// side by side either read the same thing or say exactly where they parted. Only
    /// what both devices are entitled to know — hand *sizes*, not hands — since a guest
    /// cannot check what it is not allowed to see.
    private func fingerprint(_ state: GameState) -> String {
        let hands = Seat.allCases.map { "\(state[$0].bag.count)" }.joined(separator: "/")
        let scores = Seat.allCases.map { "\(state[$0].score)" }.joined(separator: "/")
        return "R\(state.round) \(state.phase.label)"
            + " ball=\(state.ball?.name ?? "-")"
            + " shot=\(state.shot) deck=\(state.deck.count) discard=\(state.discard.count)"
            + " hands=\(hands) score=\(scores)"
    }

    /// Hands every other device the game as it is allowed to see it.
    ///
    /// One snapshot each, redacted for its own seat — the host holds the only complete
    /// state and never sends it anywhere.
    private func broadcast(_ events: [GameEvent]) {
        // **Silently, when there is nobody to talk to.** A solo game refuses every batch
        // it plays, and saying so each time buried the log it shares with everything else
        // — twenty lines, then a play, then twenty more, all game. Said once, when the
        // first batch finds no transport, and never again.
        guard let match else {
            if !toldNobodyIsListening {
                toldNobodyIsListening = true
                DevLog.say(.net, "solo: nothing is broadcast, and this is the only line "
                           + "that will say so")
            }
            return
        }
        guard match.isHost else {
            DevLog.say(.net, "broadcast REFUSED: not the host")
            return
        }
        if Table.shared.remotes.isEmpty {
            DevLog.say(.net, "broadcast REFUSED: nobody is remote — the table reads "
                       + Seat.allCases.map { "\($0.name)=\(Table.shared.occupant(at: $0))" }
                        .joined(separator: " "))
        }
        // **One fingerprint per seat, because one batch is not one batch.** Every device
        // is told a different version of what happened — its own draws by name, everybody
        // else's face down — so a single digest over the unredacted truth is a number no
        // guest could ever reproduce. The host folds exactly what it sends to each, and
        // each guest folds exactly what it was told; matching still means the same game,
        // and the leak is closed at the same time.
        // **Folded before any of it goes out, not inside the loop that sends it.** A
        // `broadcast` that throws part-way through would otherwise leave the seats it
        // reached folded and the rest not — and then the very next batch would fold
        // cleanly on both sides and agree, so the batch that went missing is the one
        // thing the digest can never report.
        var told: [Seat: [GameEvent]] = [:]
        for seat in Table.shared.remotes {
            let theirs = events.map { $0.redacted(for: seat) }
            told[seat] = theirs
            digests[seat, default: Digest()].fold(theirs)
        }
        // The host's own readout is what the *host* was told, so it is folded the way a
        // guest folds: its own draws by name, everybody else's face down. Two phones can
        // no longer be compared by eye — they are told different stories on purpose —
        // and they no longer need to be, because every guest's copy is checked against
        // its own on arrival.
        digest.fold(events.map { $0.redacted(for: GameRules.localSeat) })
        lastBoard = fingerprint(state)
        DevLog.say(.net, "host → \(lastBoard)  [\(events.count) event(s)]")
        // **Said out loud when it fails.** This was `try?`, and for a week that silence
        // *was* the bug: every board was over GameKit's reliable size limit, every send
        // threw, and nothing anywhere said so. A wire that cannot deliver has to complain.
        do {
            try match.broadcast { seat in
                .turn(state: state.redacted(for: seat), events: told[seat] ?? events,
                      digest: digests[seat] ?? Digest(),
                      shape: (told[seat] ?? events).map(\.kind))
            }
        } catch {
            DevLog.say(.net, "BROADCAST FAILED: \(error)")
        }
    }

    /// What this device's player is being asked for, read off the state alone.
    ///
    /// The host works this out on its way round `run`. A guest has only the state, so this
    /// is the whole of how it knows whose turn it is.
    private var localGate: Gate {
        if state.isOver { return .gameOver }
        switch state.phase {
        case .awaitingRebound(let shooter):
            // Everybody bids on a miss, so this one is never somebody else's turn.
            return .awaitingBid(shooter: shooter)
        case .freeThrows(let trip):
            return trip.shooter.isLocal ? .awaitingFreeThrow(trip) : .thinking
        case .awaitingDiscard(let seat, let card, let bonus):
            return seat.isLocal ? .awaitingDiscard(card: card, bonusEach: bonus) : .thinking
        case .awaitingCounter(let seat, let cards):
            return seat.isLocal ? .awaitingCounter(cards: cards) : .thinking
        case .awaitingOption(let seat, let option):
            return seat.isLocal ? .awaitingOption(option) : .thinking
        case .awaitingTarget(let seat, let card, let choices):
            return seat.isLocal ? .awaitingTarget(card: card, choices: choices) : .thinking
        case .awaitingMode(let seat, let card):
            return seat.isLocal ? .awaitingMode(card: card) : .thinking
        case .awaitingPayoff(let seat, let clamp):
            return seat.isLocal ? .awaitingPayoff(clamp: clamp) : .thinking
        case .awaitingChallenge(let seat, let card):
            return seat.isLocal ? .awaitingChallenge(card: card) : .thinking
        case .awaitingCardFrom(let seat, let card, let victim):
            return seat.isLocal ? .awaitingCardFrom(card: card, victim: victim) : .thinking
        case .awaitingInjuryPick(let seat, let card):
            return seat.isLocal ? .awaitingInjuryPick(card: card) : .thinking
        case .awaitingIntangibleDrop(let seat, let offered):
            return seat.isLocal ? .awaitingIntangibleDrop(offered: offered) : .thinking
        case .awaitingToll(let seat, let victim):
            return seat.isLocal ? .awaitingToll(victim: victim) : .thinking
        case .awaitingNaming(let seat, let card, let named):
            return seat.isLocal ? .awaitingNaming(card: card, named: named) : .thinking
        case .awaitingGiveUp(let seat, let card, let count):
            // The card that asked comes with the question now, so nothing has to go
            // looking for an Injury that may not be what asked.
            return seat.isLocal ? .awaitingGiveUp(card: card, count: count) : .thinking
        case .inbound(let seat):
            return seat.isLocal ? .awaitingInbound(seat) : .thinking
        case .possession(let seat):
            return seat.isLocal ? .awaitingMove(seat) : .thinking
        case .gameOver:
            return .gameOver
        }
    }

    /// The host, hearing what somebody chose.
    ///
    /// Every branch checks that the sender is the seat actually being asked. A client that
    /// speaks out of turn is ignored rather than believed — that check is the whole of the
    /// host's authority, and the reason a modified client can make bad choices but cannot
    /// rewrite the game.
    private func receive(_ message: ClientMessage, from seat: Seat) {
        guard let match, match.isHost else { return }
        switch message {
        case .ready(let look):
            readySeats.insert(seat)
            // What they built, so everybody's court has the same men on it. Sent back to
            // the whole table rather than kept here — the other guests have to draw him
            // too.
            Table.shared.setLook(look, at: seat)
            // Seated again before the state, because the first seating goes out the
            // instant the match is adopted — before the other device has a handler to
            // catch it. A guest that missed it is sitting in the wrong chair and does not
            // know it.
            match.reseatEveryone()
            // **Not before the deal.** The opening board sent here is the same one
            // `begin` is about to broadcast with the deal events attached, and a guest
            // given it first watched its whole hand appear, vanish, and fly in again —
            // with a gate open on a possession it could act in before a card had landed.
            // A late arrival still needs catching up, so this stands once the deal is out.
            if dealtTheTable {
                do {
                    try match.send(.board(state: state.redacted(for: seat),
                                          digest: digests[seat, default: Digest()]),
                                   to: seat)
                } catch {
                    DevLog.say(.net, "SENDING THE BOARD FAILED: \(error)")
                }
            }
            DevLog.say(.net, "\(seat.name) is ready"
                       + (dealtTheTable ? " — sent the table and the board" : " — waiting on the deal"))
        // Posted rather than played. The loop is already standing at this seat waiting
        // for exactly this, and cancelling it to apply the move from here is how a client
        // that answers a moment late ends up racing the seat's own clock.
        case .move(let move):
            guard state.phase.actingSeat == seat else { return }
            movesFromWire[seat] = Posted(batch: askedAt, value: move)
        case .reboundBid(let cards):
            guard case .awaitingRebound = state.phase else { return }
            bidsFromWire[seat] = Posted(batch: askedAt, value: cards)
        case .discardForShot(let cards):
            guard case .awaitingDiscard(let asked, _, _) = state.phase, asked == seat
            else { return }
            discardsFromWire[seat] = Posted(batch: askedAt, value: cards)
        case .giveUp(let cards):
            guard case .awaitingGiveUp(let asked, _, _) = state.phase, asked == seat
            else { return }
            giveUpsFromWire[seat] = Posted(batch: askedAt, value: cards)
        // Nothing acts on it. It is here so the whole story reaches one console.
        case .parted(let report):
            DevLog.say(.net, "\(seat.name) HAS PARTED FROM US —\n\(report)")
        case .freeThrow(let made):
            guard case .freeThrows(let trip) = state.phase, trip.shooter == seat
            else { return }
            freeThrowsFromWire[seat] = Posted(batch: askedAt, value: made)
        // Refused unless the phase says this is the seat being asked, like everything
        // else here — which is the whole of the host's authority.
        case .decision(let decision):
            guard state.phase.actingSeat == seat else { return }
            decisionsFromWire[seat] = Posted(batch: askedAt, value: decision)
        }
    }

    /// A guest, hearing what happened.
    private func receive(_ message: HostMessage) {
        switch message {
        // Acted on by the wire before it gets here — see `GameCenterMatch.readAsGuest`.
        // Repeated rather than skipped: a loopback has no wire to do it, and seating the
        // same table twice is seating the same table.
        case .seated(let seat, let chairs, let crew):
            Table.shared.seat(chairs, asLocal: seat)
            Table.shared.setCrew(crew)
            DevLog.say(.net, "seated at \(seat.name)")
        case .start:
            DevLog.say(.net, "the host started the game")
            begin()
        // Caught up rather than told a story. **Adopted, not folded** — see
        // `HostMessage.board`.
        case .board(let state, let theirs):
            dealtTheTable = true
            digest = theirs
            parted = false
            lastBoard = fingerprint(state)
            DevLog.say(.net, "guest ← caught up at batch \(theirs.batches)  \(lastBoard)")
            // A board with no story attached replaces the story. Anything still waiting
            // to be watched is about a game that has moved on without it, and anything a
            // half-played one left standing has to come off the screen with it.
            watching.removeAll()
            watchGeneration += 1
            watchingNow = false
            loop?.cancel()
            clearTheScene()
            settleTheReadouts()
            self.state = state
            self.shown = state
            gate = localGate
        case .turn(let state, let events, let theirs, let theirShape):
            // Dealt to. Whatever else this board is, it is proof the host can hear us.
            dealtTheTable = true
            // **The one comparison two devices can actually make.** Their boards are
            // redacted differently and cannot be diffed; the events are not. A mismatch
            // names the batch where the two games parted, which is the thing a week of
            // holding two phones side by side could never establish.
            digest.fold(events)
            if digest != theirs, !parted {
                parted = true
                // **Says what they parted about, not only that they did.** The shapes are
                // the event kinds in order — the one thing two devices told different
                // stories are still obliged to agree on.
                let ours = events.map(\.kind)
                var report = "DESYNC at batch \(theirs.batches) — "
                    + "host \(theirs) ours \(digest)"
                report += "\n  host sent: \(theirShape.joined(separator: " "))"
                report += "\n  we  heard: \(ours.joined(separator: " "))"
                if theirShape == ours {
                    report += "\n  same shape — so the two disagree about a payload, not "
                        + "about what happened. Suspect a redaction that is not symmetric, "
                        + "or a field that does not round-trip."
                } else {
                    let firstOff = zip(theirShape, ours).enumerated()
                        .first { $0.element.0 != $0.element.1 }?.offset
                        ?? min(theirShape.count, ours.count)
                    report += "\n  they diverge at event \(firstOff) of "
                        + "\(theirShape.count)/\(ours.count)"
                }
                DevLog.say(.net, report)
                // **Sent up as well as printed.** Only a guest can notice this — it holds
                // both fingerprints — but the host is the device attached to Xcode, so a
                // report that printed only over here was one nobody read.
                try? match?.send(.parted(report: report))
            }
            lastBoard = fingerprint(state)
            DevLog.say(.net, "guest ← \(lastBoard)  [\(events.count) event(s)]"
                       + "  seat=\(GameRules.localSeat.name)")
            // **Queued, not cut in on.** See `watching`.
            watching.append(Batch(state: state, events: events))
            drainTheWatch()
        }
    }

    /// **A guest's answer goes up the wire and the board does not move.**
    ///
    /// True when it was sent, which is the caller's cue to stop — the host will say what
    /// it meant, and anything resolved here in the meantime is this device playing its
    /// own game. Every prompt has to go through here: eight of them did not, and a guest
    /// answering one of those went off on its own from that moment and never came back.
    private func sendUp(_ decision: Decision) -> Bool {
        guard isGuest else { return false }
        gate = .thinking
        try? match?.send(.decision(decision))
        return true
    }

    /// What a seat chose, when its device is somewhere else.
    ///
    /// Nil for a seat played here, and nil again when a device sat on the question until
    /// its clock ran out — both fall through to the house's answer. The game never waits
    /// on a phone forever.
    private func decision(from seat: Seat) async -> Decision? {
        guard Table.shared.isRemote(seat) else { return nil }
        gate = .thinking
        return await waitOn(seat, for: \.decisionsFromWire)
    }

    /// A choice this device's player made.
    ///
    /// On a guest it goes up the wire and the board does not move until the host says what
    /// it meant. Anywhere else it is resolved here and now.
    private func choose(_ move: Move) {
        loop?.cancel()
        if isGuest {
            gate = .thinking
            try? match?.send(.move(move))
            return
        }
        drive {
            await apply(move, by: GameRules.localSeat)
            await run()
        }
    }

    /// **The game must never stop.**
    ///
    /// Every path that answers a question is supposed to hand the floor back to `run`, and
    /// one that forgets leaves the match frozen: the gate stays `.thinking`, so every card
    /// greys out and the shot button goes, and there is nothing the player can do about it.
    /// That has happened twice, from two different causes, and both times it made the game
    /// unplayable rather than merely wrong.
    ///
    /// So the loop is watched rather than trusted. A gate that has been thinking for eight
    /// seconds with nothing on screen — no scene, no card in the air, no call — is a game
    /// that has stopped, and it is started again. Nothing legitimate sits there that long:
    /// the longest honest wait is a shot cutscene, and a cutscene is something on screen.
    private func watchTheLoop() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self else { return }
                self.restartIfStalled()
            }
        }
    }

    private func restartIfStalled() {
        guard !isGuest, !isPaused, !state.isOver, working == 0 else { return }
        guard case .thinking = gate, let since = wentQuiet else { return }
        guard Date().timeIntervalSince(since) > 8 else { return }
        DevLog.say(.input, "➜ Restarting Input Loop  (\(state.phase.label), "
                   + "quiet \(Int(Date().timeIntervalSince(since)))s)")
        wentQuiet = .now
        drive { await self.run() }
    }

    /// Starts the one task that drives the floor, cancelling whatever was driving it.
    ///
    /// Every scene the game plays runs inside one of these, which is what lets the
    /// watchdog tell a long presentation from a stopped game.
    /// `@_implicitSelfCapture` for the same reason `Task.init` carries it: every one of
    /// these bodies is a piece of this controller's own work, and writing `self.` through
    /// two dozen of them would say something about lifetime that is not true.
    private func drive(@_implicitSelfCapture _ body: @escaping () async -> Void) {
        loop?.cancel()
        // `Task`, not `drive` — this **is** `drive`. A find-and-replace across every
        // `loop = Task {` in the file rewrote this one too, and a function whose whole
        // body is a call to itself wedges the main thread the first time the floor is
        // driven, which is the opening deal.
        loop = Task {
            self.working += 1
            defer { self.working -= 1 }
            await body()
        }
    }

    func begin() {
        // **Once, whoever asks.** A game that is begun twice is dealt twice: two
        // shuffles, two seeds, and the second cancelling the first somewhere in the
        // middle of telling the other devices about it. Both callers were real — the
        // view when it appeared, and the match when it started — and either alone is
        // right, so the second one is simply refused.
        guard !hasBegun else {
            DevLog.say(.input, "begin: already under way, ignored")
            return
        }
        hasBegun = true
        // A lesson deals nothing and runs no loop of its own: it stages its hands.
        if isLesson { return }
        // Rolled here rather than in `init`. SwiftUI re-creates a View struct on every
        // state change, so `@State private var controller = GameController()` runs that
        // initialiser every time and throws all but the first result away — but any side
        // effect in it has already happened. Faces were being re-rolled on every inbound.
        Table.shared.randomiseTheCrew()
        watchTheLoop()
        loop?.cancel()
        // A guest has no game of its own to open. It says it is on screen and waits to be
        // dealt to, which is what a player does at a table.
        if isGuest {
            DevLog.say(.net, "begin: GUEST — clearing the solo game, announcing")
            forgetTheSoloGame()
            gate = .thinking
            announceUntilDealt()
            return
        }
        DevLog.say(.net, "begin: HOST — match active=\(match?.isActive == true)")
        // **A match deals for the table that turned up.** The initialiser had to deal
        // one — a controller has to have a game — but that deck was shuffled when the
        // screen appeared, before anybody had joined, for a table that did not exist.
        // Handing it to a match makes the match somebody's pre-rolled solo game.
        if match?.isActive == true { dealForTheTable() }
        DevLog.say(.deck, "piles drawn "
                   + (RenderDebug.shared.courtStage ? "by the 3D stage" : "flat"))
        drive {
            // **Nobody is dealt to until everybody is looking.** The opening deal is the
            // one thing that happens before anyone can act, and a guest still building
            // its view when it goes out never sees it — it ends up holding a hand it did
            // not watch arrive, with a log that starts in the middle.
            await waitForTheTable()
            DevLog.say(.input, "begin: dealing \(openingDraws.count) cards out")
            // Told to the other devices before it is shown here, so the cards fly on
            // every screen rather than only on the one running the rules.
            dealtTheTable = true
            DevLog.say(.net, "begin: sending the deal — \(self.openingDraws.count) event(s)"
                       + " to \(Table.shared.remotes.count) device(s)")
            broadcast(openingDraws)
            // The opening deal goes out card by card before anyone can act.
            await flyDraws(in: openingDraws, each: Pacing.dealFlight)
            // **Round one is called here or not at all.** Its `roundBegan` is dealt with
            // the opening hand rather than folded out of a possession, so it never
            // reaches `present` — which is where every later round is announced from.
            await callTheRound(in: openingDraws)
            openingDraws = []
            DevLog.say(.input, "begin: dealt, entering the loop")
            await run()
            DevLog.say(.input, "begin: the loop handed back at \(state.phase.label)")
        }
    }

    /// **Says it is here until somebody deals.**
    ///
    /// One `ready` is one packet, and a packet sent before the host has a controller to
    /// hear it lands in a handler that does not exist yet — the host then waits out the
    /// whole table clock and deals to a man it thinks never sat down. Saying so again
    /// every half second costs nothing and closes that window whichever side is slow.
    ///
    /// It stops at the first board, which is the only acknowledgement there is.
    private func announceUntilDealt() {
        ready?.cancel()
        ready = Task { [weak self] in
            for _ in 0..<Int(Pacing.tableWait / 0.5) {
                guard let self, self.isGuest, !self.dealtTheTable else { return }
                try? self.match?.send(.ready(Table.shared.myLook))
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    /// A fresh game, for the people actually at the table.
    ///
    /// Everything the old one left behind goes with it: the log of a deal nobody watched,
    /// the cards still owed to a hand, and the shuffle itself.
    private func dealForTheTable() {
        seed = UInt64.random(in: 1...9_999_999)
        ai = AITable(seed: seed)
        let (fresh, events) = Rules.newGame(seed: seed, rules: mode)
        state = fresh
        shown = fresh
        openingDraws = events
        log.removeAll()
        undelivered.removeAll()
        unrevealed.removeAll()
        boundSeats.removeAll()
        record(events)
        DevLog.say(.net, "host: dealt a fresh game for the table — seed \(seed)")
    }

    /// **A guest has no game of its own.**
    ///
    /// The initialiser deals one — it must, since a controller cannot know yet whether it
    /// is about to be a solo game — and on a guest every bit of that is wrong: a hand
    /// nobody dealt, an opening deal waiting to fly, and a log narrating a game that will
    /// never be played. All of it goes before the host's first board arrives, or the two
    /// devices are looking at different matches from the first line.
    private func forgetTheSoloGame() {
        // **The board itself, not just the trimmings.** Clearing the log and the opening
        // draws left the hands, the deck and the discard exactly as this device dealt
        // them, and those are what the court actually draws.
        state = state.awaitingTheDeal()
        shown = state
        // **And the readouts that lag it.** `shownDeck` and its neighbours are only ever
        // written by `record`, which ran in `init` for the solo deal — so a guest sat
        // showing its own deck's count until the host's first board arrived and the
        // number jumped. Nothing dealt is nothing to show.
        settleTheReadouts()
        openingDraws = []
        log.removeAll()
        undelivered.removeAll()
        unrevealed.removeAll()
        boundSeats.removeAll()
        playedCard = nil
        flashed = nil
        DevLog.say(.net, "guest: cleared the solo game, waiting to be dealt to")
    }

    /// Holds the deal until every other device has said it is on screen.
    private func waitForTheTable() async {
        let remotes = Set(Table.shared.remotes)
        guard !remotes.isEmpty else { return }
        let deadline = Date().addingTimeInterval(Pacing.tableWait)
        while !Task.isCancelled, Date() < deadline, !remotes.isSubset(of: readySeats) {
            try? await Task.sleep(for: .milliseconds(80))
        }
        DevLog.say(.net, "table ready: \(readySeats.count)/\(remotes.count) answered")
    }

    /// **Puts the game down for good.**
    ///
    /// Quitting is not pausing: nothing is left running to be resumed, the table is given
    /// back, and whoever else was in the match is told rather than left waiting on a
    /// device that has walked away. The controller itself is dropped by whoever owns it —
    /// this is what has to happen first.
    func quit() {
        loop?.cancel()
        loop = nil
        if isLesson { setLessonSlowMotion(false) }
        watchdog?.cancel()
        watchdog = nil
        ready?.cancel()
        ready = nil
        match?.leave()
        match = nil
        gate = .thinking
        DevLog.say(.input, "quit — the session is over")
    }

    /// Waits on one seat's device for one decision, and gives up when its clock runs out.
    ///
    /// Written against the inbox rather than a continuation because a client is allowed to
    /// answer twice — a player who taps a card and then changes their mind before the host
    /// has looked has simply made one decision, and a continuation would have fired on the
    /// first tap.
    private func waitOn<T>(_ seat: Seat,
                           for inbox: ReferenceWritableKeyPath<GameController, [Seat: Posted<T>]>)
    async -> T? {
        let asked = askedAt
        let deadline = Pacing.actionClock.map { Date().addingTimeInterval($0) }
        while !Task.isCancelled, deadline.map({ Date() < $0 }) ?? true {
            if let posted = self[keyPath: inbox].removeValue(forKey: seat) {
                // An answer to a question that has already been settled. Dropped rather
                // than spent on this one.
                if posted.batch == asked { return posted.value }
                DevLog.say(.net, "\(seat.name): dropped a stale answer from batch "
                           + "\(posted.batch), asking at \(asked)")
            }
            try? await Task.sleep(for: .milliseconds(80))
        }
        return nil
    }

    /// What a seat does when its clock runs out.
    ///
    /// A shot is always legal — whatever is in the bag, and whatever the SHOT reads, even
    /// at nothing. Paired with the free draw every possession opens with, that closes the
    /// loop: a table of four absent players still draws, still shoots, still leaves the
    /// board to nobody, and still runs out of rounds with a winner at the end of them.
    /// Nothing about an idle match can stall it.
    private func fallback(for seat: Seat) -> Move {
        guard case .inbound = state.phase else { return .shoot }
        // The one decision with no way to decline it — the ball has to go somewhere, so
        // the house throws it in.
        let anybody = Seat.allCases.first { $0 != seat && $0 != state.inboundBarred }
        return ai.move(state, for: seat) ?? .inbound(to: anybody ?? seat.clockwise)
    }

    /// Holds the board up until every other device has bid, or until it is plain that one
    /// of them is not going to.
    ///
    /// A seat that says nothing in time bids nothing. A game that stops dead on one quiet
    /// phone is a worse outcome than a player who missed a board.
    private func waitForBids() async {
        let remotes = Table.shared.remotes
        guard !remotes.isEmpty else { return }
        let deadline = Pacing.actionClock.map { Date().addingTimeInterval($0) }
        while !Task.isCancelled, remotes.contains(where: { bidsFromWire[$0] == nil }),
              deadline.map({ Date() < $0 }) ?? true {
            try? await Task.sleep(for: .milliseconds(80))
        }
    }

    /// Runs a card across the court for each draw, and blocks until they have all landed.
    private func flyDraws(in events: [GameEvent], each duration: Double) async {
        for case .drew(let seat, _, let card) in events {
            await fly(to: seat, over: duration, delivering: card)
            if Task.isCancelled { return }
        }
        flight = nil
    }

    /// One card from a hand to the pile, and the beat it takes to get there.
    private func spendCard(from seat: Seat) async {
        spend = (seat, UUID())
        try? await Task.sleep(for: .seconds(Pacing.spendFlight))
        spend = nil
    }

    private func fly(to seat: Seat, over duration: Double, delivering card: UUID? = nil) async {
        // Counted off as it leaves, not when the rules dealt it.
        if shownDeck > 0 { shownDeck -= 1 }
        flightDuration = duration
        // **The pile throws it when there is a pile.** `stageDeal` was only ever set by
        // the bench, so every real draw took the flat path and the deck stood still
        // through all of it — the lean, the bow and the card growing on its way over
        // were written for a throw nothing was asking for.
        if RenderDebug.shared.courtStage {
            stageDeal = (seat, UUID())
        } else {
            flight = DrawFlight(seat: seat)
        }
        // The flight, and a little more — not exactly it, since waiting the same number
        // to the millisecond means the next draw arrives on the last frame of the last
        // one and cancels it there. The pile's own turn is not in this: it happens
        // alongside the card rather than in front of it.
        try? await Task.sleep(for: .seconds(duration + (RenderDebug.shared.courtStage
                                                        ? Pacing.handover : 0)))
        // It is in the bag now, and not a moment before.
        if let card { undelivered.remove(card) }
    }

    // MARK: - Human input

    func inbound(to seat: Seat) {
        guard !isPaused else { return }
        guard case .awaitingInbound = gate else { return }
        choose(.inbound(to: seat))
    }

    func play(_ card: Card) {
        guard !isPaused else { return }
        guard case .awaitingMove = gate else {
            DevLog.say(.input, "tapped \(card.name) — ignored, gate is \(gate)")
            return
        }
        // S.O.S: the same card, two ways to put it up. Asked before anything is played.
        if Rules.legalMoves(shown, for: GameRules.localSeat).contains(.playAsTwo(card.id)) {
            sellOutChoice = card
            return
        }
        DevLog.say(.input, "play \(card.name)"
                   + (card.descriptor.special?.shotOverride.map { "  (SHOT = \($0)%)" } ?? ""))
        choose(.play(card.id))
    }

    /// S.O.S answered: the three as printed, or a two at double SHOT. Nil backs out.
    func sellOut(asTwo: Bool?) {
        guard let card = sellOutChoice else { return }
        sellOutChoice = nil
        guard let asTwo, !isPaused, case .awaitingMove = gate else { return }
        DevLog.say(.input, "play \(card.name) \(asTwo ? "as a two at double SHOT" : "as a three")")
        choose(asTwo ? .playAsTwo(card.id) : .play(card.id))
    }

    /// Traderous Tarmac: one Clamp on the player, handed to somebody else.
    func handOff(clamp: UUID, to seat: Seat) {
        guard !isPaused, case .awaitingMove = gate else { return }
        DevLog.say(.input, "hand a Clamp off to \(seat.name)")
        choose(.handOffClamp(clamp: clamp, to: seat))
    }

    /// Varsitile: the floor, the ball or both, swapped for cards in the discard.
    func exchange(court: UUID?, ball: UUID?) {
        guard !isPaused, case .awaitingMove = gate, court != nil || ball != nil else { return }
        DevLog.say(.input, "exchange the slots from the discard")
        choose(.exchangeSlots(court: court, ball: ball))
    }

    /// **What throwing a card at the table means, wherever the throw came from.**
    ///
    /// A flick on glass, a second tap, and up on a pad are one act, and what it does
    /// depends entirely on what is being asked: on your turn it plays the card, and at
    /// every gate that wants a fistful of them it puts this one in or takes it back out.
    /// One owner, or the pad and the hand answer the same gate differently.
    func commit(_ card: Card) {
        // **Already gone.** For the beat between the rules taking a card and the fan
        // losing it, the card is on screen and must not be reachable — see `justPlayed`.
        guard !justPlayed.contains(card.id) else { return }
        switch gate {
        case .awaitingMove:
            guard Rules.legalMoves(shown, for: GameRules.localSeat).contains(.play(card.id))
            else { return }
            play(card)
        case .awaitingBid, .awaitingDiscard, .awaitingGiveUp:
            // Nothing moves once the bid is in.
            guard !bidPlaced else { return }
            if bidSelection.contains(card.id) {
                bidSelection.remove(card.id)
            } else {
                bidSelection.insert(card.id)
            }
        default:
            break
        }
    }

    func shoot() { shoot(as: .layup) }

    /// **One of the three buttons.** The free action, and which finish it is.
    func shoot(as finish: ShotType) {
        guard !isPaused else { return }
        guard case .awaitingMove = gate else { return }
        DevLog.say(.input, "shoot a \(finish.name) (the free action, no card)")
        choose(.shootAs(finish))
    }

    /// What beating the defender in front of you was worth.
    /// **The one challenge a game**, taken or turned down.
    ///
    /// Taking one stops everything and goes to the man: the camera closes on him, the
    /// floor holds, and the star opens out of him — and only then does the card come up.
    func challenge(_ taking: Bool) {
        guard !isPaused, case .awaitingChallenge(let seat, _) = state.phase else { return }
        DevLog.say(.input, taking ? "challenge the call" : "let the call stand")
        Task {
            if taking {
                challenging = seat
                camera = CourtCamera(subjects: [.seat(seat)], zoom: Pacing.challengeZoom,
                                     seconds: Pacing.challengeFrame)
                try? await Task.sleep(for: .seconds(Pacing.challengeHold))
            }
            await present(Rules.resolveChallenge(taking, state: &state))
            challenging = nil
            camera = nil
        }
    }

    /// **Who is challenging**, while the floor holds on them. Nil the rest of the time.
    private(set) var challenging: Seat?

    func take(payoff: ClampPayoff) {
        guard !isPaused else { return }
        guard case .awaitingPayoff = gate else { return }
        DevLog.say(.input, "payoff: \(payoff.label)")
        choose(.beatClamp(payoff: payoff))
    }

    /// Sixth Man's second Shoot button.
    func shootAtOffer() {
        guard !isPaused else { return }
        guard case .awaitingMove = gate else { return }
        DevLog.say(.input, "shoot at the SHOT an Intangible offers")
        choose(.shootAtOffer)
    }

    /// A player named.
    /// True while the floor is being asked whose hand to play out of, rather than which
    /// player a card is naming — the same question, a different thing done with the answer.

    /// Free Agent: the hand to play out of is chosen on the floor, the way every other
    /// "which of them" in the game is asked.
    func beginBorrow() {
        guard !isPaused else { return }
        guard case .awaitingMove(let seat) = gate else { return }
        let hands = Seat.allCases.filter { $0 != seat && !state[$0].bag.isEmpty }
        guard !hands.isEmpty else { return }
        gate = .awaitingTarget(card: CardLibrary.freeAgent, choices: hands)
    }

    func choose(target: Seat) {
        guard !isPaused else { return }
        guard case .awaitingTarget = gate else { return }
        if sendUp(.target(target)) { return }
        loop?.cancel()
        drive {
            await present(Rules.resolveTarget(target, state: &state), playedCard: true)
            await run()
        }
    }

    /// One more man named for the shot, or the naming closed.
    func choose(naming seat: Seat?) {
        guard !isPaused else { return }
        guard case .awaitingNaming = gate else { return }
        if sendUp(.naming(seat)) { return }
        loop?.cancel()
        drive {
            await present(Rules.resolveNaming(seat, state: &state), playedCard: true)
            await run()
        }
    }

    /// What a pass cost the man who took it.
    func choose(toll pick: CardPick?) {
        guard !isPaused else { return }
        guard case .awaitingToll = gate else { return }
        if sendUp(.toll(pick)) { return }
        loop?.cancel()
        drive {
            await present(Rules.resolveToll(pick, state: &state))
            await run()
        }
    }

    /// The passive given up when a fourth arrives.
    func choose(dropping id: String) {
        guard !isPaused else { return }
        guard case .awaitingIntangibleDrop = gate else { return }
        if sendUp(.dropping(id)) { return }
        loop?.cancel()
        drive {
            await present(Rules.resolveIntangibleDrop(id, state: &state))
            await run()
        }
    }

    /// An Injury taken off the table.
    func choose(injury id: String) {
        guard !isPaused else { return }
        guard case .awaitingInjuryPick = gate else { return }
        if sendUp(.injury(id)) { return }
        loop?.cancel()
        drive {
            await present(Rules.resolveInjuryPick(id, state: &state))
            await run()
        }
    }

    /// The card offered as the possession arrives — taken, or turned down.
    /// - Parameter chosen: which of the offered cards is being spent, nil to decline.
    func choose(counter chosen: Card.ID?) {
        guard !isPaused else { return }
        guard case .awaitingCounter = gate else { return }
        if sendUp(.counter(chosen)) { return }
        drive {
            await present(Rules.resolveCounter(chosen, state: &state), playedCard: true)
            await run()
        }
    }

    /// A card's "You may", answered.
    func choose(option taken: Bool) {
        guard !isPaused else { return }
        guard case .awaitingOption = gate else { return }
        if sendUp(.option(taken)) { return }
        drive {
            await present(Rules.resolveOption(taken, state: &state), playedCard: true)
            await run()
        }
    }

    /// A card picked out of a hand nobody can see.
    func choose(card id: Card.ID) {
        guard !isPaused else { return }
        guard case .awaitingCardFrom = gate else { return }
        if sendUp(.cardFrom(id)) { return }
        loop?.cancel()
        drive {
            await present(Rules.resolveCardFrom(id, state: &state), playedCard: true)
            await run()
        }
    }

    /// A branch chosen.
    func choose(mode index: Int) {
        guard !isPaused else { return }
        guard case .awaitingMode = gate else { return }
        if sendUp(.mode(index)) { return }
        loop?.cancel()
        drive {
            await present(Rules.resolveMode(index, state: &state), playedCard: true)
            await run()
        }
    }

    /// The toll, paid by hand. Picked with the same selection the bid and the shot
    /// discard use — one way of choosing cards, whatever is being asked for.
    func submitGiveUp() {
        guard !isPaused else { return }
        guard case .awaitingGiveUp = gate else { return }
        loop?.cancel()
        let chosen = Array(bidSelection)
        bidSelection.removeAll()
        if isGuest {
            gate = .thinking
            try? match?.send(.giveUp(chosen))
            return
        }
        drive {
            await present(Rules.resolveGiveUp(chosen, state: &state))
            await run()
        }
    }

    func submitDiscard() {
        guard !isPaused else { return }
        guard case .awaitingDiscard = gate else { return }
        loop?.cancel()
        let chosen = Array(bidSelection)
        bidSelection.removeAll()
        if isGuest {
            gate = .thinking
            try? match?.send(.discardForShot(chosen))
            return
        }
        drive {
            let defenders = defenderCount(on: GameRules.localSeat)
            await present(Rules.resolveDiscardForShot(chosen, state: &state),
                          defenders: defenders)
            await run()
        }
    }

    /// The player's own attempt, decided by the mini-game rather than by a roll.
    func shootFreeThrow(made: Bool) {
        guard !isPaused else { return }
        guard case .awaitingFreeThrow = gate else { return }
        DevLog.say(.input, "free throw \(made ? "good" : "missed")")
        loop?.cancel()
        if isGuest {
            gate = .thinking
            try? match?.send(.freeThrow(made: made))
            return
        }
        drive {
            await present(Rules.resolveFreeThrow(made: made, state: &state))
            await run()
        }
    }

    func submitBid() {
        guard !isPaused else { return }
        guard case .awaitingBid = gate else { return }
        loop?.cancel()
        let mine = Array(bidSelection)
        bidSelection.removeAll()
        // **Placed, not closed.** The gate stays on the board — everybody bids at once —
        // and this is what greys the bar out until the rest of the table has answered.
        bidPlaced = true
        if isGuest {
            try? match?.send(.reboundBid(mine))
            return
        }
        drive {
            var bids: [Seat: [Card.ID]] = [:]
            bids[GameRules.localSeat] = mine
            for seat in Seat.allCases where seat != GameRules.localSeat {
                guard !Table.shared.isRemote(seat) else { continue }
                bids[seat] = ai.reboundBid(state, for: seat)
            }
            // Everybody bids at once, so the board waits on the other devices rather than
            // asking them one at a time.
            await waitForBids()
            // Same rule as `waitOn`: a bid stamped against an older board is an answer
            // to a rebound that has already been settled.
            let asked = askedAt
            for seat in Table.shared.remotes {
                let posted = bidsFromWire[seat]
                bids[seat] = posted?.batch == asked ? (posted?.value ?? []) : []
            }
            bidsFromWire.removeAll()

            let events = Rules.resolveRebound(bids: bids, state: &state)
            await present(events)
            await run()
        }
    }

#if DEBUG
    /// Pulls one card for the human, flight animation and all.
    func debugDraw() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        loop?.cancel()
        drive {
            var events: [GameEvent] = []
            Rules.testDraw(GameRules.localSeat, state: &state, events: &events)
            await present(events)
            await run()
        }
    }

    func debugDiscardHand() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        Rules.discardHand(GameRules.localSeat, state: &state)
    }

    /// Asks the deck to perform. Nothing about the game changes — it is the deck doing a
    /// thing, which is the point of it having a repertoire at all.
    func debugDeck(_ routine: DeckRoutine) {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        deckRoutine = routine
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.6))
            if deckRoutine == routine { deckRoutine = .rest }
        }
    }

    /// Runs the whole opening: in from the horizon, round the table, home, and down.
    func debugOpening() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        opening = OpeningDeal(id: UUID(),
                              order: GameRules.localSeat.clockwiseOrderFromHere,
                              each: state.rules.startingBagSize)
    }

    /// Throws one card from the deck to the next seat round, on the court-wide stage.
    func debugDeal() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        let next = stageDeal.map { $0.seat.clockwise } ?? GameRules.localSeat
        stageDeal = (next, UUID())
    }

    /// Gravity on one seat and a Contest in your hand, so a Clamp can be sent and watched
    /// landing without waiting for either card to be dealt.
    func debugGravity(to seat: Seat) {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        loop?.cancel()
        drive {
            for other in Seat.allCases {
                state[other].intangibles.removeAll { $0.id == CardLibrary.gravity.id }
            }
            state[seat].intangibles.append(CardLibrary.gravity)
            state[GameRules.localSeat].bag.append(
                Card(CardLibrary.contest.resolved(passShotBonus: state.rules.passShotBonus)))
            catchUp()
            await run()
        }
    }

    /// Sets a Whistle down face-down, the way arming one looks from the table.
    func debugArmWhistle() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        loop?.cancel()
        drive {
            playedCard = PlayedCard(seat: GameRules.localSeat,
                                    descriptor: Self.aWhistle(), faceDown: true)
            try? await Task.sleep(for: .seconds(GameRules.playedCardSeconds))
            playedCard = nil
            await run()
        }
    }

    /// Calls one, so the reveal can be watched without waiting to be caught by one.
    ///
    /// Goes through `SeenCards` like the real thing, so the first press on a given card
    /// shows the New badge and waits for a tap. `unsee` puts them all back.
    func debugBlowWhistle() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        loop?.cancel()
        drive {
            let card = Self.aWhistle()
            let scene = WhistleReveal(owner: GameRules.localSeat, card: card,
                                      cancelled: "Drive", cancelledCard: CardLibrary.drive,
                                      isNew: SeenCards.shared.meet(card.id))
            whistleReveal = scene
            await hold(scene.isNew, seconds: Pacing.whistleReveal) { self.whistleReveal }
            whistleReveal = nil
            await run()
        }
    }

    /// A different one each press, so the art is exercised rather than one card's.
    private static func aWhistle() -> CardDescriptor {
        CardLibrary.whistles.randomElement() ?? CardLibrary.travel
    }

    /// Plays a turnover scene without waiting to lose the ball.
    func debugTurnover(_ kind: TurnoverCutscene.Kind) {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        loop?.cancel()
        drive {
            let scene = TurnoverCutscene(seat: GameRules.localSeat, kind: kind)
            turnover = scene
            try? await Task.sleep(for: .seconds(scene.hold))
            turnover = nil
            await run()
        }
    }

    /// Throws a pass across the court without touching the game.
    func debugPass(to seat: Seat) {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        loop?.cancel()
        drive {
            practicePass = (GameRules.localSeat, seat)
            // Restamped, so a second press replays rather than being ignored.
            ballSettledAt = Date()
            // Long enough for the throw *and* the catch that follows it. Clearing this
            // at the end of the flight pulled the receiver's `caughtAt` away a tenth of a
            // second into the catch, so the sheet never got past its first frames.
            try? await Task.sleep(for: .seconds(PassTiming.flight
                                                + PassTiming.hold
                                                + PassTiming.catchSeconds + 0.2))
            practicePass = nil
            await run()
        }
    }

    /// Sends the human to the line for two, for working on the mini-game.
    func debugFreeThrows() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        loop?.cancel()
        drive {
            await present(Rules.debugAwardFreeThrows(2, to: GameRules.localSeat,
                                                         state: &state))
            await run()
        }
    }

    /// Replays a missed shot, which is where most of the rim drama lives.
    func debugMiss() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        loop?.cancel()
        drive {
            cutscene = ShotCutscene(shooter: GameRules.localSeat,
                                    chance: Int(ShotTuning.shared.debugChance),
                                    made: false, defenders: 0)
            try? await Task.sleep(for: .seconds(Pacing.cutscene + (cutscene?.drama.seconds ?? 0)))
            cutscene = nil
            await run()
        }
    }

    /// Replays the shot scene on demand, for matching its timing to the sprite.
    func debugShot() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        loop?.cancel()
        drive {
            cutscene = ShotCutscene(shooter: GameRules.localSeat,
                                    chance: Int(ShotTuning.shared.debugChance),
                                    made: true, defenders: 0)
            try? await Task.sleep(for: .seconds(Pacing.cutscene + (cutscene?.drama.seconds ?? 0)))
            cutscene = nil
            await run()
        }
    }

    /// Throws one down on demand, for matching the climb to the sheet. See `DunkBench`.
    ///
    /// A miss makes it a miss: the bench picks which of the three ways it comes apart.
    func debugDunk(_ dunk: Dunk, miss: DunkMiss? = nil) {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        loop?.cancel()
        drive {
            cutscene = ShotCutscene(shooter: GameRules.localSeat,
                                    chance: Int(ShotTuning.shared.debugChance),
                                    made: miss == nil, defenders: 0, dunk: dunk,
                                    dunkMiss: miss)
            try? await Task.sleep(for: .seconds(Pacing.cutscene + (cutscene?.drama.seconds ?? 0)))
            cutscene = nil
            await run()
        }
    }

    /// Puts a name call on screen on its own, for looking at the plate in a live game
    /// rather than waiting for a cutscene to bring one.
    ///
    /// A plain `Task`, not `drive`: this is scenery, and the game should carry on behind
    /// it exactly as it does when the plate rides a played card.
    func debugNameCall() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        Task {
            playedCardLeaving = false
            playedCard = PlayedCard(seat: GameRules.localSeat,
                                    descriptor: CardLibrary.dime, faceDown: false)
            let lead = min(GameRules.playedCardSeconds * 0.4, 0.9)
            try? await Task.sleep(for: .seconds(GameRules.playedCardSeconds - lead))
            playedCardLeaving = true
            try? await Task.sleep(for: .seconds(lead))
            playedCard = nil
        }
    }

    /// Plays a Lethal Shooter make, which is otherwise a card and a rebound away.
    func debugUnderstood() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        cutscene = ShotCutscene(shooter: GameRules.localSeat, chance: 100, made: true,
                                defenders: 2, signature: .understood)
        Task {
            try? await Task.sleep(for: .seconds(Pacing.cutscene))
            cutscene = nil
        }
    }

    /// Sends the local seat up for a board, for tuning the leap without waiting for a
    /// miss and a bid — see `ReboundBench`.
    func debugRebound() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        reboundLeap = ReboundLeap(seat: GameRules.localSeat)
        Task {
            try? await Task.sleep(for: .seconds(ReboundTiming.run))
            reboundLeap = nil
        }
    }

    /// Plays the three's celebration on the local seat, for looking at it on demand.
    func debugThree() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        Task {
            celebratingThree = GameRules.localSeat
            withheldPoints = (seat: GameRules.localSeat, amount: 3)
        }
    }

    /// Dump and redraw, for getting to a hand worth testing quickly.
    func debugReshuffleHand() {
        // The bench cannot start a game on a device that is not running one.
        guard !isGuest else { return }
        Rules.reshuffleHand(GameRules.localSeat, state: &state)
    }
#endif

    // MARK: - Loop

    private func run() async {
        while !Task.isCancelled {
            // The chain has played out by the time the loop comes round, so the floor and
            // the rules agree before anybody is asked for anything.
            catchUp()
            // Held between decisions rather than mid-scene: a cutscene stopped halfway is
            // a broken animation, not a paused game.
            while isPaused, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(80))
            }
            if Task.isCancelled { return }
            if state.isOver { gate = .gameOver; return }

            // A lesson has no opponents: once the ball has left the player, the lesson
            // stages what comes next.
            if isLesson, state.phase.actingSeat != GameRules.localSeat {
                lessonBallGone = true
                gate = .thinking
                return
            }

            if case .awaitingRebound(let shooter) = state.phase {
                // No call in front of it. The board's own scene is black with the same
                // streaks across it and the word "Rebound!" already on it — a card saying
                // that first is the same picture twice.
                gate = .awaitingBid(shooter: shooter)
                return
            }
            if case .freeThrows(let trip) = state.phase {
                // The line takes the screen from the shot that awarded it, in one change.
                cutscene = nil
                if trip.shooter == GameRules.localSeat {
                    gate = .awaitingFreeThrow(trip)
                    return
                }
                // Somebody else's line. Their device is playing the mini-game, and if it
                // never answers that is a violation — no points, same as standing at the
                // line and not shooting.
                if Table.shared.isRemote(trip.shooter) {
                    gate = .thinking
                    let made = await waitOn(trip.shooter, for: \.freeThrowsFromWire) ?? false
                    if Task.isCancelled { return }
                    await present(Rules.resolveFreeThrow(made: made, state: &state))
                    continue
                }
                gate = .thinking
                await think()
                if Task.isCancelled { return }
                let made = Rules.rollFreeThrow(state: &state)
                aiFreeThrow = AIFreeThrow(trip: trip, made: made)
                try? await Task.sleep(for: .seconds(Pacing.freeThrow))
                aiFreeThrow = nil
                await present(Rules.resolveFreeThrow(made: made, state: &state))
                continue
            }
            if case .awaitingCounter(let seat, let offered) = state.phase {
                if seat.isLocal { gate = localGate; return }
                // Worth it for what is about to land on him, and nothing otherwise: the
                // card is a way out of the defenders, not a way of moving the ball.
                // The house does not weigh one answer against another yet — it takes the
                // first on offer when there is anything to break, and nothing otherwise.
                // "Dunk It?" is always worth taking; a counter only with defenders coming.
                var chosen = state.heldPossession == nil ? offered.first?.id
                    : (state.pendingClamps.isEmpty ? nil
                       : Rules.countersOnOffer(to: seat, in: state).first?.id)
                if case .counter(let said)? = await decision(from: seat) {
                    chosen = said
                } else if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                await present(Rules.resolveCounter(chosen, state: &state), playedCard: true)
                continue
            }
            if case .awaitingOption(let seat, let option) = state.phase {
                if seat.isLocal { gate = localGate; return }
                var taken = Rules.houseTakes(option, for: seat, in: state)
                if case .option(let said)? = await decision(from: seat) {
                    taken = said
                } else if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                await present(Rules.resolveOption(taken, state: &state), playedCard: true)
                continue
            }
            if case .awaitingTarget(let seat, _, let choices) = state.phase {
                if seat.isLocal { gate = localGate; return }
                // Whoever holds the most is the man worth finding — and the man worth
                // taking from. One rule, because the AI has no reason to prefer another.
                let worth = Rules.sensibleTargets(choices, for: state.pendingActor ?? seat,
                                                  in: state)
                var pick = worth.max { state[$0].bag.count < state[$1].bag.count } ?? worth[0]
                if case .target(let said)? = await decision(from: seat), choices.contains(said) {
                    pick = said
                } else if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                await present(Rules.resolveTarget(pick, state: &state), playedCard: true)
                continue
            }
            if case .awaitingNaming(let seat, _, let named) = state.phase {
                if seat.isLocal { gate = localGate; return }
                // Everyone but the leader. The SHOT is worth having; handing the man in
                // front an assist is not.
                let shooter = state.ball
                let best = Seat.allCases.max { state[$0].score < state[$1].score }
                var next = Seat.allCases.first {
                    $0 != shooter && $0 != best && !named.contains($0)
                }
                if case .naming(let said)? = await decision(from: seat) {
                    next = said
                } else if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                await present(Rules.resolveNaming(next, state: &state), playedCard: true)
                continue
            }
            if case .awaitingToll(let seat, let victim) = state.phase {
                if seat.isLocal { gate = localGate; return }
                // A passive is worth more than a card off a hand nobody can read.
                var pick: CardPick? = state[victim].intangibles.first.map { .named($0.id) }
                    ?? .position(Int.random(in: 0..<max(1, state[victim].bag.count)))
                if case .toll(let said)? = await decision(from: seat) {
                    pick = said
                } else if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                await present(Rules.resolveToll(pick, state: &state))
                continue
            }
            if case .awaitingIntangibleDrop(let seat, let offered) = state.phase {
                if seat.isLocal { gate = localGate; return }
                // A passive that only hurts is the one to give up; failing that, the
                // oldest, which is what the rule used to do on its own.
                let worst = offered.first { ($0.intangible?.shotBonus ?? 0) < 0 }
                var dropping = worst?.id ?? offered[0].id
                if case .dropping(let said)? = await decision(from: seat),
                   offered.contains(where: { $0.id == said }) {
                    dropping = said
                } else if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                await present(Rules.resolveIntangibleDrop(dropping, state: &state))
                continue
            }
            if case .awaitingInjuryPick(let seat, _) = state.phase {
                if seat.isLocal { gate = localGate; return }
                // Whatever is face up and mildest; failing that, whatever is on offer.
                let offered = state.injuriesOffered
                let seen = offered.filter { !state.injuriesHidden.contains($0.id) }
                var pick = (seen.first ?? offered.first)?.id
                if case .injury(let said)? = await decision(from: seat),
                   offered.contains(where: { $0.id == said }) {
                    pick = said
                } else if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                if let pick { await present(Rules.resolveInjuryPick(pick, state: &state)) }
                continue
            }
            if case .awaitingCardFrom(let seat, _, let victim) = state.phase {
                if seat.isLocal { gate = localGate; return }
                // Face down to everybody, so there is nothing to be clever about.
                // An empty hand is answerable: nothing is taken, and the question closes.
                // Reading `hand[0]` off one was a crash waiting for a Free Agent.
                var pick = state[victim].bag.randomElement()?.id ?? UUID()
                if case .cardFrom(let said)? = await decision(from: seat),
                   state[victim].bag.contains(where: { $0.id == said }) {
                    pick = said
                } else if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                await present(Rules.resolveCardFrom(pick, state: &state), playedCard: true)
                continue
            }
            if case .awaitingMode(let seat, let card) = state.phase {
                if seat.isLocal { gate = localGate; return }
                var mode = ai.mode(of: card, state, for: seat)
                if case .mode(let said)? = await decision(from: seat),
                   card.modes.indices.contains(said) {
                    mode = said
                } else if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                await present(Rules.resolveMode(mode, state: &state), playedCard: true)
                continue
            }
            // **Beating your man is a question, and an opponent has to answer it.**
            // Without this the loop reached a payoff nobody could take and sat there:
            // the man who had just blown by his defender held the ball for ever.
            //
            // TODO: no wire case yet, so a remote seat's payoff is decided by the host.
            if case .awaitingChallenge(let seat, _) = state.phase {
                if seat.isLocal { gate = localGate; return }
                let taking = AIPolicy.challenges(state, for: seat)
                if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                await present(Rules.resolveChallenge(taking, state: &state))
                continue
            }
            if case .awaitingPayoff(let seat, _) = state.phase {
                if seat.isLocal { gate = localGate; return }
                let payoff = AIPolicy.payoff(state, for: seat)
                if !Table.shared.isRemote(seat) {
                    gate = .thinking
                    await think()
                }
                if Task.isCancelled { return }
                await present(Rules.takePayoff(payoff, by: seat, state: &state),
                              playedCard: true)
                continue
            }
            if case .awaitingGiveUp(let seat, _, let count) = state.phase {
                if seat.isLocal {
                    gate = localGate
                    return
                }
                gate = .thinking
                if Table.shared.isRemote(seat) {
                    let chosen = await waitOn(seat, for: \.giveUpsFromWire) ?? []
                    if Task.isCancelled { return }
                    await present(Rules.resolveGiveUp(chosen, state: &state))
                    continue
                }
                await think()
                if Task.isCancelled { return }
                // Nothing clever to decide yet: the cheapest card is a judgement the AI
                // does not make anywhere else either.
                let chosen = Array(ai.discardForShot(state, for: seat).prefix(count))
                await present(Rules.resolveGiveUp(chosen, state: &state))
                continue
            }
            if case .awaitingDiscard(let seat, let card, let bonusEach) = state.phase {
                if seat == GameRules.localSeat {
                    gate = .awaitingDiscard(card: card, bonusEach: bonusEach)
                    return
                }
                if Table.shared.isRemote(seat) {
                    gate = .thinking
                    // Nothing fed into the shot is a legal answer, so it is the one an
                    // absent player gives.
                    let chosen = await waitOn(seat, for: \.discardsFromWire) ?? []
                    if Task.isCancelled { return }
                    await present(Rules.resolveDiscardForShot(chosen, state: &state),
                                  defenders: defenderCount(on: seat))
                    continue
                }
                gate = .thinking
                await think()
                if Task.isCancelled { return }
                let chosen = ai.discardForShot(state, for: seat)
                let defenders = defenderCount(on: seat)
                await present(Rules.resolveDiscardForShot(chosen, state: &state),
                                  defenders: defenders)
                continue
            }
            guard let seat = state.phase.actingSeat else { gate = .thinking; return }

            // **Every** throw-in is called, whoever is taking it. It used to be announced
            // only when it was yours, which left an opponent's inbound as the one thing
            // on the floor the game never said out loud.
            let throwingIn = { if case .inbound = state.phase { return true }; return false }()
            inbounding = throwingIn ? seat : nil
            if throwingIn {
                // Out of one place and into the other, in that order. The call waits for
                // both halves rather than talking over a man who is still in pieces.
                try? await Task.sleep(for: .seconds(Pacing.warp * 2))
                if Task.isCancelled { return }
                await announce(.inbound)
                if Task.isCancelled { return }
            }

            if seat == GameRules.localSeat {
                gate = throwingIn ? .awaitingInbound(seat) : .awaitingMove(seat)
                return
            }
            // A seat somebody is sitting in decides for itself — but not forever. The
            // loop stands here holding that seat's clock.
            if Table.shared.isRemote(seat) {
                gate = .thinking
                let move = await waitOn(seat, for: \.movesFromWire) ?? fallback(for: seat)
                if Task.isCancelled { return }
                await apply(move, by: seat)
                continue
            }

            gate = .thinking
            try? await Task.sleep(for: .seconds(Pacing.think(onInbound: throwingIn)))
            if Task.isCancelled { return }
            guard let move = ai.move(state, for: seat) else { gate = .thinking; return }
            await apply(move, by: seat)
        }
    }

    // MARK: - Scenes

    /// Every card turned up by this play, one at a time.
    private func showReveals(in events: [GameEvent]) async {
        for scene in RevealCutscene.queue(from: events, seen: SeenCards.shared) {
            reveal = scene
            await hold(scene.isNew, seconds: Pacing.reveal) { self.reveal }
            reveal = nil
            // Turned over, so it can take its slot. Not a moment before.
            if scene.isIntangible, let owed = unrevealed[scene.seat], owed > 0 {
                unrevealed[scene.seat] = owed - 1
            }
            // The gap is the point. Clearing and setting in the same breath gives SwiftUI
            // nothing to animate between, and the card appears to change rather than to be
            // replaced — which tells the player one card did two things.
            try? await Task.sleep(for: .seconds(Pacing.betweenReveals))
        }
    }

    /// A Clamp that takes cards and goes.
    ///
    /// Standing Clamps are drawn on the player for as long as they last — see `BindLines`.
    /// This is the other sort: he arrives, swipes, and drifts off, which is the only time
    /// anybody sees him.
    private func showClampBite(in events: [GameEvent]) async {
        // **Only a Clamp brings a body.** `clampBit` is the event for anything that takes
        // cards out of a hand — a Clamp, an Injury's toll each turn, a Bullet Pass
        // knocking one loose on the way in — and the floor was answering all three by
        // sending a defender out to swipe at him. The card says which it was.
        for case .clampBit(let seat, let card, _) in events where card.type == .clamp {
            clampSwipe = (seat: seat, id: UUID())
            try? await Task.sleep(for: .seconds(Pacing.clampSwipe))
            clampSwipe = nil
        }
    }

    /// **Which official is making a call, while he is making it.** Set before the card is
    /// shown and cleared after it, so the floor plays the call out on its own first — see
    /// `showWhistle`. The reveal is the card; this is the man.
    private(set) var callOnFloor: UUID?

    /// A Whistle turning face up.
    /// **A call, in three beats.** The referee who made it first: the camera goes to him
    /// and he blows it where he stands, so the call comes from a man on the floor rather
    /// than from a card appearing. Then the card comes up as the Z with the whistle
    /// shaking over it — that is the blast — and only then does it turn over and say what
    /// it was. See `WhistleRevealView`, which runs the last two.
    private func showWhistle(in events: [GameEvent]) async {
        guard let scene = WhistleReveal.first(in: events, seen: SeenCards.shared) else { return }
        // Which of the crew it was, by where his card stands in the line — the court lays
        // the men out in that order, so the index is the man.
        let slot = state.armedWhistles.firstIndex { $0.id == scene.caller }
        // **The floor first, and nothing over it.** Play stops, the crew turn to the man
        // making the call, he blows it where he stands and the camera goes to him — all of
        // it readable, because the card is not on top of it yet.
        callOnFloor = scene.caller
        if let slot {
            camera = CourtCamera(subjects: [.referee(slot)], zoom: Pacing.whistleZoom,
                                 seconds: Pacing.whistleFrame)
        }
        try? await Task.sleep(for: .seconds(Pacing.whistleHold))
        // Only then the Z card, and the turn.
        whistleReveal = scene
        await hold(scene.isNew, seconds: Pacing.whistleReveal) { self.whistleReveal }
        whistleReveal = nil
        callOnFloor = nil
        if slot != nil { camera = nil }
    }

    /// Waits out a scene: on a clock normally, on the player when the card is new to them.
    private func hold(_ untilTapped: Bool, seconds: Double,
                      while alive: @escaping () -> Any?) async {
        // **Nobody holds a table up.** A first sighting is worth stopping a solo game
        // for; at a table with other people on it, three of them are watching a card they
        // have already met while one reads. `pause` already refuses in a live match — so
        // this waited on a tap with the game running behind it, which is worse than
        // either. Online every card takes its beat and goes.
        guard untilTapped, Table.shared.remotes.isEmpty else {
            try? await Task.sleep(for: .seconds(seconds))
            return
        }
        // **A card nobody has put down stops the game.** The chain waiting here is one
        // thread of it and the run loop is another, and the loop went on taking turns
        // behind a first sighting the player had not dismissed yet. Never in a live
        // match — `pause` refuses when there is anybody else at the table.
        pause()
        defer { resume() }
        while alive() != nil { try? await Task.sleep(for: .milliseconds(60)) }
    }

    /// The beat a player takes before acting — and, on a single-player table, however
    /// much longer the screen is busy.
    ///
    /// A move landing behind a card that is still on its way off is the game carrying on
    /// without the player. The loop only checks between decisions, which is too coarse:
    /// the check has to be after the thinking, not before it.
    private func think() async {
        try? await Task.sleep(for: .seconds(Pacing.think()))
        while isPaused, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(80)) }
    }

    /// Holds up whatever was just played, so everyone can read it.
    private func showPlayedCard(in events: [GameEvent]) async {
        guard let card = PlayedCard.first(in: events) else { return }
        // **One flash per play.** A card that asks a question resolves in two halves — the
        // card is chosen, then the target is named — and both halves come through here
        // carrying the same play. Cleared by the next move, so two Dimes in a row are two
        // cards held up and one Dime is one.
        guard flashed?.descriptor.id != card.descriptor.id || flashed?.seat != card.seat
        else { return }
        flashed = card
        playedCardLeaving = false
        playedCard = card
        // The name plate rides the same beat and starts its trip out before the card
        // does, so its slide finishes on screen rather than being cut with the view.
        let lead = min(GameRules.playedCardSeconds * 0.4, 0.9)
        try? await Task.sleep(for: .seconds(GameRules.playedCardSeconds - lead))
        playedCardLeaving = true
        try? await Task.sleep(for: .seconds(lead))
        playedCard = nil
    }

    /// Sends the ball across the court.
    ///
    /// Stamped with the pass itself, not after the beats that follow it. Waiting until the
    /// receiver's drawn card had flown and every cutscene had cleared put the throw
    /// seconds behind the card that caused it — the ball crossed long after the play had
    /// been read. The draw now flies alongside it, which is also the order they happen in.
    private func stampSettled(_ events: [GameEvent]) {
        for case .passed(let card, let from, let to, _, _) in events {
            passThrow = PassThrow(from: from, to: to,
                                  blind: [CardLibrary.noLook.id, CardLibrary.behindTheBack.id]
                                      .contains(card.id),
                                  at: Date())
            if lessonSlowMotion {
                camera = CourtCamera(subjects: [.ball], zoom: CourtCamera.lessonPass)
            }
            ballSettledAt = Date()
            passLeftAt = Date()
            // Handed over when it lands, not when it was played. The court flies it for
            // exactly this long — both read the same constant, so they cannot drift.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(PassTiming.windup + PassTiming.flight))
                self.shownBall = self.state.ball
            }
            return
        }
    }

    /// A three is anything worth more than an ordinary bucket.
    /// The board, said out loud.
    ///
    /// Every make, because a basket is the only thing in the game that changes the score
    /// and the assists at once — and with Wide-Open Three there can be three men owed for
    /// one shot.
    private func callTheScore(in events: [GameEvent]) async {
        guard case .shotMade(let seat, let points, _, _)? = events.first(where: {
            if case .shotMade = $0 { return true }; return false
        }) else { return }
        var helpers: [Seat] = []
        for case .assisted(let passer) in events where !helpers.contains(passer) {
            helpers.append(passer)
        }
        scoreCall = ScoreCall(seat: seat, points: points, assists: helpers)
        // **Together.** The call is what says the basket counted, so the board changes on
        // the same frame it goes up rather than a beat ahead of it.
        withheldPoints = nil
        try? await Task.sleep(for: .seconds(Pacing.scoreCall))
        scoreCall = nil
    }

    /// Keeps a basket off the board until it has been called.
    ///
    /// A three withholds already, so that it can be flown to the cell it changes — see
    /// `celebrateThree`. This is the same hold for every other make, and both are let go
    /// in `callTheScore`.
    private func holdTheScore(in events: [GameEvent]) {
        for case .shotMade(let seat, let points, _, _) in events {
            withheldPoints = (seat, points)
            return
        }
    }

    private func celebrateThree(in events: [GameEvent]) async {
        for case .shotMade(let seat, let points, _, _) in events
        where points > state.rules.madeShotPoints {
            withheldPoints = (seat, points)
            celebratingThree = seat
            // Held until the view says the number has landed and then finished.
            while celebratingThree != nil { try? await Task.sleep(for: .milliseconds(60)) }
        }
    }

    /// Both reveals hand the player the dismissal on a first sighting, so the scene can
    /// be read rather than raced.
    func dismissReveal() { reveal = nil }
    func dismissWhistleReveal() { whistleReveal = nil }

    /// The flying number has landed, so the cell it changed may show it. A three only —
    /// every other make is let go by `callTheScore`.
    func threeScoreLanded() { withheldPoints = nil }
    func threeCelebrationFinished() { celebratingThree = nil }
    func actionCallFinished() { actionCall = nil }

    /// Puts a call up and waits for it to take itself off again.
    /// **The round, said out loud.** Its own call rather than an `ActionCall`: those are
    /// four words on a scrim and this is a slab with a card's own icon standing on it.
    private func callTheRound(in events: [GameEvent]) async {
        guard GameRules.announcesPhases else { return }
        for event in events {
            switch event {
            case .roundBegan(let round, _):
                roundCall = RoundCall(round: round)
            default:
                continue
            }
            try? await Task.sleep(for: .seconds(Pacing.roundCall))
            roundCall = nil
        }
    }

    /// **The half, said before its deal goes out.**
    ///
    /// Its own call rather than part of `callTheRound`, and run at a different point: a
    /// round is announced once everything the last one did has been watched, and the half
    /// has to land *before* twenty cards fly, or the cards arrive from nowhere and the
    /// half explains them afterwards.
    private func callTheHalf(in events: [GameEvent]) async {
        guard GameRules.announcesPhases else { return }
        guard events.contains(where: { if case .halftime = $0 { return true }; return false })
        else { return }
        roundCall = RoundCall(round: state.round, isHalftime: true)
        // **Held until somebody taps it.** The deal is behind this, so the half is a
        // stoppage rather than a caption: nothing is dealt, nothing moves, and the game
        // waits — which is what a half is.
        while roundCall != nil, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(60))
        }
    }

    /// The Z card has finished its trip and taken itself off.
    func roundCallFinished() { roundCall = nil }

    private func announce(_ call: ActionCall, clamps: [ClampBrief] = []) async {
        guard GameRules.announcesPhases else { return }
        clampCall = clamps
        actionCall = call
        while actionCall != nil, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(60))
        }
        clampCall = []
    }

    /// The Injury asking for the card, so the prompt can name it.
    private func injury(on seat: Seat) -> CardDescriptor? {
        state[seat].injuries.first { ($0.injury?.discardsEachTurn ?? 0) > 0 }
    }

    /// Counted before the move, because resolving a shot clears the Clamps that caused it.
    private func defenderCount(on seat: Seat) -> Int { state.defenders(on: seat) }

    private func apply(_ move: Move, by seat: Seat) async {
        flashed = nil
        let defenders = defenderCount(on: seat)
        let events = Rules.apply(move, by: seat, to: &state)
        await present(events, defenders: defenders, playedCard: true)
        if isLesson, seat == GameRules.localSeat, !events.isEmpty { lessonPlays += 1 }
    }

    /// Everything the table is shown, in the order it happens at one.
    ///
    /// Takes only events, never a move — which is what lets a guest play exactly the same
    /// scenes off the wire that the host plays off its own rules. The host resolves and
    /// then presents; a guest is handed the resolution and presents.
    /// Hands the floor everything the rules have done since it last looked.
    ///
    /// One line, called at each beat rather than at the end, so the table is shown the
    /// chain in the order it happened instead of all of it at once.
    private func catchUp() { shown = state }

    private func present(_ events: [GameEvent], defenders: Int = 0,
                         playedCard: Bool = false) async {
        // A board's bids are read out on the board itself, so the gate that draws it stays
        // up until they have been — see the bid scene below.
        let opensOnBids: Bool = {
            if case .reboundBids? = events.first { return true }
            return false
        }()
        if !opensOnBids { gate = .thinking }
        // Before a single scene plays, and before the board catches up — see `refereeOnFloor`.
        refereeOnFloor = shown.armedWhistles.first
        // **Whatever the last batch never got to show has been shown by events.** A
        // presentation cancelled part-way leaves its cards marked as still in the air, and
        // nothing else ever unmarks them.
        undelivered.removeAll()
        unrevealed.removeAll()
        // Marked before a single scene plays: the rules dealt these on the way in, and the
        // hand must not have them until their flight says so.
        for case .drew(_, _, let card) in events { undelivered.insert(card) }
        for case .shotAttempted(_, let chance, _) in events { lastChance = chance }
        for case .intangibleRevealed(let seat, _) in events {
            unrevealed[seat, default: 0] += 1
        }
        // A combo the player strung together is one the COMBO button can now show.
        for case .comboLanded(let seat, let card, let opener?, _) in events
            where seat == GameRules.localSeat {
            DoneCombos.shared.record(opener, into: card.id)
        }
        broadcast(events)
        DevLog.record(events)
        // Anything but a pass moves the ball at once. Only a throw has a journey to wait for.
        if !events.contains(where: { if case .passed = $0 { return true }; return false }) {
            shownBall = state.ball
        }

        // **One queue.** The rules wrote the play down in the order it happened, and it is
        // shown in exactly that order: one event, its scene, its line in the log, then the
        // next. Nothing is sorted into beats, so nothing can be shown before the thing that
        // caused it — a turnover before the round it ended, a round before the shot that
        // won it.
        var heldCardUp = !playedCard
        var caughtUp = false
        var sinceTurnover = events.startIndex
        var index = events.startIndex
        while index < events.endIndex {
            if Task.isCancelled { return }
            let event = events[index]
            // The card that started the play is held up before anything it did.
            if !heldCardUp, PlayedCard.first(in: [event]) != nil {
                heldCardUp = true
                await showPlayedCard(in: [event])
                if Task.isCancelled { return }
            }
            if !caughtUp {
                // **The tallies wait for their scenes.** Catching up hands the board the
                // whole play at once, so a rebound, an assist or a turnover is put back
                // until the scene that earns it has been shown — see below.
                let tallies = Dictionary(uniqueKeysWithValues: Seat.allCases.map {
                    ($0, (rebounds: shown[$0].rebounds, assists: shown[$0].assists,
                          turnovers: shown[$0].turnovers))
                })
                let heldPhase = shown.phase
                let heldRound = shown.round
                let heldClock = shown.shotClock
                catchUp()
                for (seat, tally) in tallies {
                    shown[seat].rebounds = min(tally.rebounds, state[seat].rebounds)
                    shown[seat].assists = min(tally.assists, state[seat].assists)
                    shown[seat].turnovers = min(tally.turnovers, state[seat].turnovers)
                }
                // Nor whose turn it is, the round, or the clock: a lit seat or a reset clock
                // says where the ball ends up before the scenes have taken it there.
                shown.phase = heldPhase
                shown.round = heldRound
                shown.shotClock = heldClock
                caughtUp = true
            }
            var scene = [event]
            switch event {
            case .inbounded(let from, let to):
                // The throw-in, and the man who threw it watching it go.
                inbounding = nil
                throwing = ThrowIn(from: from, to: to)
                try? await Task.sleep(for: .seconds(Pacing.inboundThrow + Pacing.inboundHold))
                throwing = nil
            case .passed(_, let from, let to, let shot, _):
                if shot >= 0 { shownShot = shot }
                let travelled: Bool = {
                    guard index + 1 < events.endIndex,
                          case .turnover = events[index + 1] else { return false }
                    return true
                }()
                if from == to, !travelled {
                    // Off the glass and back to himself: a rebound in every way that shows.
                    reboundLeap = ReboundLeap(seat: from, offTheGlass: true)
                    try? await Task.sleep(for: .seconds(ReboundTiming.run))
                    reboundLeap = nil
                } else {
                    stampSettled([event])
                    // **The ball lands, and then he draws.**
                    await settleTheThrow()
                }
            case .movePlayed(_, _, let shot):
                if shot >= 0 { shownShot = shot }
            case .discarded(let seat, let cards):
                for _ in cards {
                    if Task.isCancelled { return }
                    await spendCard(from: seat)
                }
            case .whistleBlew:
                await announce(.whistle)
                await showWhistle(in: [event])
            case .drew(let seat, _, let card):
                await fly(to: seat, over: Pacing.drawFlight, delivering: card)
                flight = nil
            case .gameBreakRevealed:
                // Called before it is shown: nobody played it.
                await announce(.gameBreak)
                await showReveals(in: [event])
            case .injuryRevealed:
                await announce(.injury)
                await showReveals(in: [event])
            case .intangibleRevealed:
                await showReveals(in: [event])
            case .clampedPossession(let seat, let clamps):
                // Named before anybody swipes.
                await announce(.clamped, clamps: clamps)
                boundSeats.insert(seat)
            case .clampBit:
                await showClampBite(in: [event])
            case .shotAttempted:
                // The attempt and how it went are one scene.
                var end = index + 1
                while end < events.endIndex, events[end].tellsHowTheShotWent { end += 1 }
                scene = Array(events[index..<end])
                let anotherShot = events[end...].contains {
                    if case .shotAttempted = $0 { return true }
                    return false
                }
                await playTheShot(scene, defenders: defenders, isLast: !anotherShot)
            case .calledGlass(let seat, let card):
                // A called board pays in the open: the card says itself again, then he goes up.
                reveal = RevealCutscene(seat: seat, card: card, isIntangible: false,
                                        isNew: SeenCards.shared.meet(card.id))
                await hold(false, seconds: Pacing.reveal) { self.reveal }
                reveal = nil
                reboundLeap = ReboundLeap(seat: seat, offTheGlass: true)
                try? await Task.sleep(for: .seconds(ReboundTiming.run))
                reboundLeap = nil
            case .reboundBids(let bids, _):
                revealedBids = Dictionary(uniqueKeysWithValues: bids.map { ($0.seat, $0.count) })
                try? await Task.sleep(for: .seconds(Pacing.bidReveal))
                revealedBids = nil
                // Off the board before anything it set off plays.
                gate = .thinking
            case .rebounded(let winner):
                reboundLeap = ReboundLeap(seat: winner)
                try? await Task.sleep(for: .seconds(ReboundTiming.run))
                reboundLeap = nil
            case .turnover:
                // Read off everything since the last one: the whistle that called it, the
                // pass that lost it, the return that had nowhere to go.
                if let cutscene = TurnoverCutscene(events: Array(events[sinceTurnover...index])) {
                    turnover = cutscene
                    try? await Task.sleep(for: .seconds(cutscene.hold))
                    turnover = nil
                }
                sinceTurnover = index + 1
            case .halftime:
                // Held until tapped, before its own deal goes out.
                await callTheHalf(in: [event])
            case .coinRun(let seat, let card, let heads):
                // Thrown where it can be seen. It decided something, and it was over
                // inside a frame — see `CoinFlipView`.
                coinFlip = CoinFlip(seat: seat, card: card, heads: heads,
                                    flips: max(1, card.special?.coinRunFlips ?? 1))
                try? await Task.sleep(for: .seconds(CoinFlip.seconds))
                coinFlip = nil
            case .roundBegan(let round, _):
                shown.round = round
                await callTheRound(in: [event])
            default:
                break
            }
            if Task.isCancelled { return }
            // Its lines, now that it has been seen, and the tallies it earned.
            writeLog(scene)
            for played in scene {
                switch played {
                case .rebounded(let seat):
                    shown[seat].rebounds = min(shown[seat].rebounds + 1, state[seat].rebounds)
                case .assisted(let seat):
                    shown[seat].assists = min(shown[seat].assists + 1, state[seat].assists)
                case .turnover(let seat, _):
                    shown[seat].turnovers = min(shown[seat].turnovers + 1, state[seat].turnovers)
                default:
                    break
                }
            }
            index += scene.count
        }
        if !caughtUp { catchUp() }

        // **The turn does not start until the ball is in his hands.**
        await settleTheCatch()
        catchUp()
        settleBoard()
        // A scene held open for the line — see `playTheShot` — comes down if the line
        // never arrived.
        if cutscene != nil {
            if case .freeThrows = state.phase {} else { cutscene = nil }
        }
    }

    /// One attempt: the cutscene, and the calls that say how it went.
    ///
    /// The points are in the state the moment the shot is folded, so the board waits for the
    /// call — see `holdTheScore`.
    private func playTheShot(_ shot: [GameEvent], defenders: Int, isLast: Bool) async {
        guard var scene = ShotCutscene(events: shot, defenders: defenders,
                                       lastPlay: state.lastPlayThisPossession,
                                       dunk: state.dunking) else { return }
        // Worth more than a make, or taken off a card that shoots a three.
        scene.isThree = shot.contains {
            if case .shotMade(_, let points, _, _) = $0 { return points > state.rules.madeShotPoints }
            return false
        } || (state.lastPlayThisPossession.flatMap { CardLibrary.byID[$0]?.isThree } ?? false)
        holdTheScore(in: shot)
        cutscene = scene
        try? await Task.sleep(for: .seconds(Pacing.cutscene + scene.drama.seconds))
        // **No board behind the shot.** The rebound goes up once this batch has finished
        // playing — the loop puts it up — never under a scene still on screen.
        _ = isLast
        // **Held for the line.** Make-or-Take sends him to the free throws off this very
        // miss: taking the scene down here put the floor on screen for the beat between
        // the two, which reads as the shot being over and something else starting.
        let toTheLine = shot.contains {
            if case .freeThrowsAwarded = $0 { return true }
            return false
        }
        if !toTheLine { cutscene = nil }
        await celebrateThree(in: shot)
        await callTheScore(in: shot)
    }

    /// Whatever is left of the throw alone — the ball reaching his hands.
    ///
    /// The catch plays on past this, and the draw goes out over the top of it. Kept
    /// separate from `settleTheCatch` for that reason: one is where the ball *is*, and
    /// the other is when the man has finished closing his hands on it.
    private func settleTheThrow() async {
        guard let thrown = passLeftAt else { return }
        let owing = PassTiming.windup + PassTiming.flight - Date().timeIntervalSince(thrown)
        guard owing > 0 else { return }
        try? await Task.sleep(for: .seconds(owing))
    }

    /// Whatever is left of the throw and the catch, which are one movement.
    ///
    /// **The remainder, not the whole.** The draws fly alongside a pass on purpose — see
    /// `stampSettled` — so by the time the beat gets here some of it has already been
    /// spent, and waiting the full pair again would put a hole after every pass.
    private func settleTheCatch() async {
        guard let thrown = passLeftAt else { return }
        passLeftAt = nil
        let whole = PassTiming.windup + PassTiming.flight + PassTiming.catchSeconds
        let owing = whole - Date().timeIntervalSince(thrown)
        guard owing > 0 else { return }
        try? await Task.sleep(for: .seconds(owing))
    }

    /// A batch's lines and its board at once, for a deal nobody watches event by event.
    private func record(_ events: [GameEvent]) {
        DevLog.record(events)
        writeLog(events)
        settleBoard()
    }

    /// The lines for what has just been shown, in the order it happened.
    private func writeLog(_ events: [GameEvent]) {
        // A card still marked in the air here was never flown. Stranded, it is a card
        // missing from the hand for the rest of the game.
        for case .drew(_, _, let card) in events { undelivered.remove(card) }
        for event in events where event.isLoggable {
            log.append(LogLine(text: event.logLine, kind: kind(of: event)))
        }
    }

    /// The lagging readouts, put where the board actually is once everything has played.
    private func settleBoard() {
        // Anything still owed here was never turned over — a slot missing from the board
        // for the rest of the game if it stayed.
        unrevealed.removeAll()
        // A man stays bound until the rules let him go.
        boundSeats = boundSeats.filter { !state[$0].clamps.isEmpty }
        if !state.phase.isMidPlay { shownShot = state.shot + state.holderShot }
        shownBall = state.ball
        // Catches a reshuffle, and anything that moved the pile without flying a card.
        shownDeck = state.deck.count
    }

    private func kind(of event: GameEvent) -> LogLine.Kind {
        switch event {
        case .shotMade, .rebounded, .assisted:      return .score
        case .freeThrowMade, .freeThrowsAwarded:    return .score
        case .freeThrowMissed:                      return .penalty
        case .turnover:                             return .penalty
        case .roundBegan, .halftime, .gameEnded:    return .marker
        default:                                    return .normal
        }
    }
}

private extension GameEvent {
    /// Whether this is part of the shot just attempted: how it went, and who is owed for it.
    var tellsHowTheShotWent: Bool {
        switch self {
        case .shotMade, .shotMissed, .assisted: return true
        default: return false
        }
    }
}
