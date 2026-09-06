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
    /// One card crossing the court. Dealing is brisker than an in-game draw because
    /// twenty of them go by at once.
    static let drawFlight = 0.30
    /// What the deck spends turning to face whoever is drawing, before it throws — see `CourtStage`,
    /// which plays that ahead of the card. The beat has to cover it, or the card lands in
    /// a hand before the pile has finished reaching for it.
    static let deckLean = 0.16
    /// How long a card takes to reach the pile from a hand.
    static let spendFlight = 0.34
    static let dealFlight = 0.15
    /// The whole of a defender's swipe: arrive, take, drift off.
    /// The whole of a defender's swipe: arrive, hold, drift off, fade. Must outlast
    /// `DefenderSwipe`'s own timings or the scene is cut while he is still walking.
    static let clampSwipe = 1.3
    /// The inbound's own throw: how long the ball takes to cross from the sideline, and
    /// how long the thrower stands there having thrown it. He is watching it land.
    static let inboundThrow = 0.5
    static let inboundHold = 0.5
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
    /// **nil turns the clocks off**, which is where they are for the first live tests: a
    /// seat that never answers should hang where you can see it rather than be quietly
    /// papered over by a fallback that looks like the game working. Put it back to 30.
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

    /// Built directly, for replaying the scene from the debug panel.
    init(shooter: Seat, chance: Int, made: Bool, defenders: Int,
         signature: ShotSignature = .none) {
        self.signature = signature
        self.shooter = shooter
        self.chance = chance
        self.made = made
        self.defenders = defenders
        self.drama = ShotDrama.choose(made: made, chance: chance)
        self.spoils = ["🪣", "💸", "💰"].randomElement()!
        self.line = SwisshLine.roll()
        self.caromSide = Bool.random() ? 1 : -1
        self.missCall = chance < 40
            ? "BRRRICK"
            : ["NO GOOD", "A MISS", "MISSED", "NOPE"].randomElement()!
    }

    init?(events: [GameEvent], defenders: Int = 0, lastPlay: String? = nil) {
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
        self.drama = ShotDrama.choose(made: made, chance: chance)
        self.spoils = ["🪣", "💸", "💰"].randomElement()!
        self.line = SwisshLine.roll()
        self.caromSide = Bool.random() ? 1 : -1
        self.missCall = chance < 40
            ? "BRRRICK"
            : ["NO GOOD", "A MISS", "MISSED", "NOPE"].randomElement()!
    }
}

/// A board coming down, played on the floor rather than on the rebound screen.
///
/// The screen says who won it; this is him going up to take it, with the ball thrown out
/// of the hoop on the horizon to meet his hands at the top.
struct ReboundLeap: Identifiable, Equatable {
    let id = UUID()
    let seat: Seat
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
        case shotClock
        /// Behind-the-Back with nobody to give it back to.
        case badReturn
        case whistle(String)
    }

    let id = UUID()
    let seat: Seat
    let kind: Kind
    /// Which bit Travel plays. Rolled here rather than in the view, so the pause can be
    /// the length of the bit that is actually going to run.
    let travelBit: TravelCutsceneView.Bit?
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
        for event in events {
            switch event {
            case .failedReturn:                 kind = .badReturn
            case .whistleBlew(_, let card, _, _, _): kind = .whistle(card.name)
            case .turnover(let who, _):         seat = who
            case .passed(_, let from, _, _):    thrower = from
            default: break
            }
        }
        guard let seat else { return nil }
        self.seat = seat
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
            case .passed(let card, let from, _, _):
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
    let owner: Seat
    let card: CardDescriptor
    let cancelled: String
    /// The card it was called on, so the referee can hold up the evidence.
    let cancelledCard: CardDescriptor?
    /// First time this player has ever met this card.
    let isNew: Bool

    /// A Whistle counts as met when it is *called*, not when it is set down — a badge on
    /// the face-down card would give away the trap the game works hard to keep.
    static func first(in events: [GameEvent], seen: SeenCards) -> WhistleReveal? {
        for case .whistleBlew(let owner, let card, let cancelled, let victim, _) in events {
            return WhistleReveal(owner: owner, card: card, cancelled: cancelled,
                                 cancelledCard: victim, isNew: seen.meet(card.id))
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
            case .gameBreakRevealed(let seat, let card):
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
        case awaitingClearOut(card: CardDescriptor)
        /// Bone Bruise's toll at the top of the turn. Its own case, because the shot
        /// discard resolves into a shot and this one resolves into a turn.
        case awaitingInjuryDiscard(card: CardDescriptor, count: Int)
        /// A card that names a player, and the branches of one that names a mode.
        case awaitingTarget(card: CardDescriptor, choices: [Seat])
        case awaitingMode(card: CardDescriptor)
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
    private(set) var gate: Gate = .thinking {
        didSet {
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
    private(set) var deckRoutine: DeckStage.Routine = .rest
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
    var canPause: Bool { Table.shared.remotes.isEmpty }

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
    private(set) var flightDuration = Pacing.drawFlight
    /// Set for a beat after a rebound so the reveal can be shown, then cleared.
    private(set) var revealedBids: [Seat: Int]?
    /// Who is going up for the board right now, if anybody.
    private(set) var reboundLeap: ReboundLeap?
    var bidSelection: Set<Card.ID> = []

    let seed: UInt64
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
    var isGuest: Bool { match.map { $0.isActive && !$0.isHost } ?? false }

    /// What has arrived from the other devices and not been acted on yet. One slot per
    /// seat: a client that sends twice before the host looks has changed its mind, which
    /// is allowed — it is still only ever one decision.
    private var bidsFromWire: [Seat: [Card.ID]] = [:]
    private var movesFromWire: [Seat: Move] = [:]
    private var discardsFromWire: [Seat: [Card.ID]] = [:]
    private var freeThrowsFromWire: [Seat: Bool] = [:]

    /// Attaches the transport. Safe to call before there is a match: nothing changes
    /// until `isActive`, and doing it early is the point — a handler wired after the
    /// first message has already been delivered will never see it.
    func join(_ transport: any MatchTransport) {
        match = transport
        transport.onHostMessage = { [weak self] in self?.receive($0) }
        transport.onClientMessage = { [weak self] in self?.receive($1, from: $0) }
        // A seat whose player has gone is played by the house for the rest of the game.
        // Pausing a four-handed game on one dropped phone would end it in practice.
        transport.onSeatLost = { [weak self] seat in
            guard let self, !self.isGuest else { return }
            Table.shared.replaceWithComputer(at: seat)
            self.loop?.cancel()
            self.drive { await self.run() }
        }
    }

    /// Hands every other device the game as it is allowed to see it.
    ///
    /// One snapshot each, redacted for its own seat — the host holds the only complete
    /// state and never sends it anywhere.
    private func broadcast(_ events: [GameEvent]) {
        guard let match, match.isHost else { return }
        try? match.broadcast { seat in
            .turn(state: state.redacted(for: seat), events: events)
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
        case .awaitingClearOut(let seat, let card):
            return seat.isLocal ? .awaitingClearOut(card: card) : .thinking
        case .awaitingTarget(let seat, let card, let choices):
            return seat.isLocal ? .awaitingTarget(card: card, choices: choices) : .thinking
        case .awaitingMode(let seat, let card):
            return seat.isLocal ? .awaitingMode(card: card) : .thinking
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
        case .awaitingInjuryDiscard(let seat, let count):
            guard seat.isLocal, let injury = injury(on: seat) else { return .thinking }
            return .awaitingInjuryDiscard(card: injury, count: count)
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
        case .ready:
            // Seated again before the state, because the first seating goes out the
            // instant the match is adopted — before the other device has a handler to
            // catch it. A guest that missed it is sitting in the wrong chair and does not
            // know it.
            (match as? GameCenterMatch)?.reseat(seat)
            try? match.send(.turn(state: state.redacted(for: seat), events: []), to: seat)
            DevLog.say(.net, "\(seat.name) is ready — sent the table and the board")
        // Posted rather than played. The loop is already standing at this seat waiting
        // for exactly this, and cancelling it to apply the move from here is how a client
        // that answers a moment late ends up racing the seat's own clock.
        case .move(let move):
            guard state.phase.actingSeat == seat else { return }
            movesFromWire[seat] = move
        case .reboundBid(let cards):
            guard case .awaitingRebound = state.phase else { return }
            bidsFromWire[seat] = cards
        case .discardForShot(let cards):
            guard case .awaitingDiscard(let asked, _, _) = state.phase, asked == seat
            else { return }
            discardsFromWire[seat] = cards
        case .freeThrow(let made):
            guard case .freeThrows(let trip) = state.phase, trip.shooter == seat
            else { return }
            freeThrowsFromWire[seat] = made
        }
    }

    /// A guest, hearing what happened.
    private func receive(_ message: HostMessage) {
        switch message {
        case .seated(let seat, let chairs):
            Table.shared.seat(chairs, asLocal: seat)
            DevLog.say(.net, "seated at \(seat.name)")
        case .start:
            DevLog.say(.net, "the host started the game")
            begin()
        case .turn(let state, let events):
            DevLog.say(.net, "board arrived — \(events.count) event(s), "
                       + "phase \(String(describing: state.phase))")
            loop?.cancel()
            self.state = state
            drive {
                await self.present(events,
                                   defenders: self.defenderCount(on: state.phase.actingSeat
                                                                 ?? GameRules.localSeat))
                self.gate = self.localGate
            }
        }
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
        // Rolled here rather than in `init`. SwiftUI re-creates a View struct on every
        // state change, so `@State private var controller = GameController()` runs that
        // initialiser every time and throws all but the first result away — but any side
        // effect in it has already happened. Faces were being re-rolled on every inbound.
        PlayerLook.shared.randomiseOpponents(except: GameRules.localSeat)
        watchTheLoop()
        loop?.cancel()
        // A guest has no game of its own to open. It says it is on screen and waits to be
        // dealt to, which is what a player does at a table.
        if isGuest {
            gate = .thinking
            try? match?.send(.ready)
            return
        }
        DevLog.say(.deck, "piles drawn "
                   + (RenderDebug.shared.courtStage ? "by the 3D stage" : "flat"))
        drive {
            DevLog.say(.input, "begin: dealing \(openingDraws.count) cards out")
            // The opening deal goes out card by card before anyone can act.
            await flyDraws(in: openingDraws, each: Pacing.dealFlight)
            openingDraws = []
            DevLog.say(.input, "begin: dealt, entering the loop")
            await run()
            DevLog.say(.input, "begin: the loop handed back at \(state.phase.label)")
        }
    }

    /// Waits on one seat's device for one decision, and gives up when its clock runs out.
    ///
    /// Written against the inbox rather than a continuation because a client is allowed to
    /// answer twice — a player who taps a card and then changes their mind before the host
    /// has looked has simply made one decision, and a continuation would have fired on the
    /// first tap.
    private func waitOn<T>(_ seat: Seat,
                           for inbox: ReferenceWritableKeyPath<GameController, [Seat: T]>) async -> T? {
        let deadline = Pacing.actionClock.map { Date().addingTimeInterval($0) }
        while !Task.isCancelled, deadline.map({ Date() < $0 }) ?? true {
            if let answer = self[keyPath: inbox].removeValue(forKey: seat) { return answer }
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
        try? await Task.sleep(for: .seconds(duration + (RenderDebug.shared.courtStage
                                                        ? Pacing.deckLean : 0)))
        // It is in the bag now, and not a moment before.
        if let card { undelivered.remove(card) }
    }

    /// Cards flying in and cards turning face up, in the order they actually happened.
    ///
    /// These used to be two passes — every draw, then every reveal — which told the story
    /// backwards for any card whose whole effect is drawing. MVP Vote filled a hand and
    /// only then said it was MVP Vote, by which point there was nothing left to explain.
    private func playDrawsAndReveals(in events: [GameEvent]) async {
        for event in events {
            if Task.isCancelled { return }
            switch event {
            case .drew(let seat, _, let card):
                await fly(to: seat, over: Pacing.drawFlight, delivering: card)
            case .gameBreakRevealed:
                flight = nil
                // Announced before it is shown: a Break is not something anybody played,
                // and the call is what says so before the card can be mistaken for a play.
                await announce(.gameBreak)
                await showReveals(in: [event])
            case .intangibleRevealed:
                flight = nil
                await showReveals(in: [event])
            default:
                break
            }
        }
        flight = nil
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
        DevLog.say(.input, "play \(card.name)"
                   + (card.descriptor.special?.shotOverride.map { "  (SHOT = \($0)%)" } ?? ""))
        choose(.play(card.id))
    }

    func shoot() {
        guard !isPaused else { return }
        guard case .awaitingMove = gate else { return }
        DevLog.say(.input, "shoot (the free action, no card)")
        choose(.shoot)
    }

    /// A player named.
    /// True while the floor is being asked whose hand to play out of, rather than which
    /// player a card is naming — the same question, a different thing done with the answer.
    private var borrowing = false

    /// Free Agent: the hand to play out of is chosen on the floor, the way every other
    /// "which of them" in the game is asked.
    func beginBorrow() {
        guard !isPaused else { return }
        guard case .awaitingMove(let seat) = gate else { return }
        let hands = Seat.allCases.filter { $0 != seat && !state[$0].bag.isEmpty }
        guard !hands.isEmpty else { return }
        borrowing = true
        gate = .awaitingTarget(card: CardLibrary.freeAgent, choices: hands)
    }

    func choose(target: Seat) {
        guard !isPaused else { return }
        guard case .awaitingTarget = gate else { return }
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
        loop?.cancel()
        drive {
            await present(Rules.resolveInjuryPick(id, state: &state))
            await run()
        }
    }

    /// Stepping out of the play, or standing in it.
    func choose(clearOut taken: Bool) {
        guard !isPaused else { return }
        guard case .awaitingClearOut = gate else { return }
        drive {
            await present(Rules.resolveClearOut(taken, state: &state), playedCard: true)
            await run()
        }
    }

    /// A card picked out of a hand nobody can see.
    func choose(card id: Card.ID) {
        guard !isPaused else { return }
        guard case .awaitingCardFrom = gate else { return }
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
        loop?.cancel()
        drive {
            await present(Rules.resolveMode(index, state: &state), playedCard: true)
            await run()
        }
    }

    /// The toll, paid by hand. Picked with the same selection the bid and the shot
    /// discard use — one way of choosing cards, whatever is being asked for.
    func submitInjuryDiscard() {
        guard !isPaused else { return }
        guard case .awaitingInjuryDiscard = gate else { return }
        loop?.cancel()
        let chosen = Array(bidSelection)
        bidSelection.removeAll()
        if isGuest {
            gate = .thinking
            try? match?.send(.discardForShot(chosen))
            return
        }
        drive {
            await present(Rules.resolveInjuryDiscard(chosen, state: &state))
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
        if isGuest {
            gate = .thinking
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
            for seat in Table.shared.remotes { bids[seat] = bidsFromWire[seat] ?? [] }
            bidsFromWire.removeAll()

            let events = Rules.resolveRebound(bids: bids, state: &state)
            broadcast(events)
            var ledger = events

            // The bids are shown before they are read out, and who won the board is not
            // written until the numbers are on screen.
            for case .reboundBids(let counts, _) in events {
                revealedBids = counts
                try? await Task.sleep(for: .seconds(Pacing.bidReveal))
                revealedBids = nil
            }
            release(.bid, from: &ledger)

            if let scene = TurnoverCutscene(events: events) {
                turnover = scene
                try? await Task.sleep(for: .seconds(scene.hold))
                turnover = nil
            }
            release(.turnover, from: &ledger)

            // Off the scene before the winner's card flies. Whoever takes the board draws
            // to open the possession that follows it, and that draw belongs to the
            // possession — not to the scramble, which is over. Recording it here was
            // moving the hand and the pile while the rebound was still on screen.
            gate = .thinking
            // **On the floor, before he draws for it.** The board is off the screen by
            // now, so the man who won it goes up on the court itself — and the draw that
            // opens the possession waits until he has come down with the ball.
            for case .rebounded(let winner) in events {
                catchUp()
                reboundLeap = ReboundLeap(seat: winner)
                try? await Task.sleep(for: .seconds(Theme.Figure.reboundSeconds))
                reboundLeap = nil
            }
            await playDrawsAndReveals(in: events)
            release(.draw, from: &ledger)
            release(.reveal, from: &ledger)

            record(ledger)
            await run()
        }
    }

#if DEBUG
    /// Pulls one card for the human, flight animation and all.
    func debugDraw() {
        loop?.cancel()
        drive {
            var events: [GameEvent] = []
            Rules.testDraw(GameRules.localSeat, state: &state, events: &events)
            await present(events)
            await run()
        }
    }

    func debugDiscardHand() {
        Rules.discardHand(GameRules.localSeat, state: &state)
    }

    /// Asks the deck to perform. Nothing about the game changes — it is the deck doing a
    /// thing, which is the point of it having a repertoire at all.
    func debugDeck(_ routine: DeckStage.Routine) {
        deckRoutine = routine
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.6))
            if deckRoutine == routine { deckRoutine = .rest }
        }
    }

    /// Runs the whole opening: in from the horizon, round the table, home, and down.
    func debugOpening() {
        opening = OpeningDeal(id: UUID(),
                              order: GameRules.localSeat.clockwiseOrderFromHere,
                              each: state.rules.startingBagSize)
    }

    /// Throws one card from the deck to the next seat round, on the court-wide stage.
    func debugDeal() {
        let next = stageDeal.map { $0.seat.clockwise } ?? GameRules.localSeat
        stageDeal = (next, UUID())
    }

    /// Sets a Whistle down face-down, the way arming one looks from the table.
    func debugArmWhistle() {
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
        loop?.cancel()
        drive {
            practicePass = (GameRules.localSeat, seat)
            // Restamped, so a second press replays rather than being ignored.
            ballSettledAt = Date()
            // Long enough for the throw *and* the catch that follows it. Clearing this
            // at the end of the flight pulled the receiver's `caughtAt` away a tenth of a
            // second into the catch, so the sheet never got past its first frames.
            try? await Task.sleep(for: .seconds(Theme.Pass.flightSeconds
                                                + Theme.Pass.holdSeconds
                                                + Theme.Pass.catchSeconds + 0.2))
            practicePass = nil
            await run()
        }
    }

    /// Sends the human to the line for two, for working on the mini-game.
    func debugFreeThrows() {
        loop?.cancel()
        drive {
            await present(Rules.debugAwardFreeThrows(2, to: GameRules.localSeat,
                                                         state: &state))
            await run()
        }
    }

    /// Replays a missed shot, which is where most of the rim drama lives.
    func debugMiss() {
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

    /// Puts a name call on screen on its own, for looking at the plate in a live game
    /// rather than waiting for a cutscene to bring one.
    ///
    /// A plain `Task`, not `drive`: this is scenery, and the game should carry on behind
    /// it exactly as it does when the plate rides a played card.
    func debugNameCall() {
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
        cutscene = ShotCutscene(shooter: GameRules.localSeat, chance: 100, made: true,
                                defenders: 2, signature: .understood)
        Task {
            try? await Task.sleep(for: .seconds(Pacing.cutscene))
            cutscene = nil
        }
    }

    /// Plays the three's celebration on the local seat, for looking at it on demand.
    func debugThree() {
        Task {
            celebratingThree = GameRules.localSeat
            withheldPoints = (seat: GameRules.localSeat, amount: 3)
        }
    }

    /// Dump and redraw, for getting to a hand worth testing quickly.
    func debugReshuffleHand() {
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

            if case .awaitingRebound(let shooter) = state.phase {
                // No call in front of it. The board's own scene is black with the same
                // streaks across it and the word "Rebound!" already on it — a card saying
                // that first is the same picture twice.
                gate = .awaitingBid(shooter: shooter)
                return
            }
            if case .freeThrows(let trip) = state.phase {
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
            if case .awaitingClearOut(let seat, _) = state.phase {
                if seat.isLocal { gate = localGate; return }
                gate = .thinking
                await think()
                if Task.isCancelled { return }
                // Worth it for what is about to land on him, and nothing otherwise: the
                // card is a way out of the defenders, not a way of moving the ball.
                await present(Rules.resolveClearOut(!state.pendingClamps.isEmpty,
                                                    state: &state), playedCard: true)
                continue
            }
            if case .awaitingTarget(let seat, _, let choices) = state.phase {
                if seat.isLocal { gate = localGate; return }
                gate = .thinking
                await think()
                if Task.isCancelled { return }
                // Whoever holds the most is the man worth finding — and the man worth
                // taking from. One rule, because the AI has no reason to prefer another.
                let pick = choices.max { state[$0].bag.count < state[$1].bag.count } ?? choices[0]
                await present(Rules.resolveTarget(pick, state: &state), playedCard: true)
                continue
            }
            if case .awaitingNaming(let seat, _, let named) = state.phase {
                if seat.isLocal { gate = localGate; return }
                gate = .thinking
                await think()
                if Task.isCancelled { return }
                // Everyone but the leader. The SHOT is worth having; handing the man in
                // front an assist is not.
                let shooter = state.ball
                let best = Seat.allCases.max { state[$0].score < state[$1].score }
                let next = Seat.allCases.first {
                    $0 != shooter && $0 != best && !named.contains($0)
                }
                await present(Rules.resolveNaming(next, state: &state), playedCard: true)
                continue
            }
            if case .awaitingToll(let seat, let victim) = state.phase {
                if seat.isLocal { gate = localGate; return }
                gate = .thinking
                await think()
                if Task.isCancelled { return }
                // A passive is worth more than a card off a hand nobody can read.
                let pick: CardPick = state[victim].intangibles.first.map { .named($0.id) }
                    ?? .position(Int.random(in: 0..<max(1, state[victim].bag.count)))
                await present(Rules.resolveToll(pick, state: &state))
                continue
            }
            if case .awaitingIntangibleDrop(let seat, let offered) = state.phase {
                if seat.isLocal { gate = localGate; return }
                gate = .thinking
                await think()
                if Task.isCancelled { return }
                // A passive that only hurts is the one to give up; failing that, the
                // oldest, which is what the rule used to do on its own.
                let worst = offered.first { ($0.intangible?.shotBonus ?? 0) < 0
                                            || $0.intangible?.blocksMoves == true }
                await present(Rules.resolveIntangibleDrop(worst?.id ?? offered[0].id,
                                                          state: &state))
                continue
            }
            if case .awaitingInjuryPick(let seat, _) = state.phase {
                if seat.isLocal { gate = localGate; return }
                gate = .thinking
                await think()
                if Task.isCancelled { return }
                // Whatever is face up and mildest; failing that, whatever is on offer.
                let offered = state.injuriesOffered
                let seen = offered.filter { !state.injuriesHidden.contains($0.id) }
                let pick = (seen.first ?? offered.first)?.id
                if let pick { await present(Rules.resolveInjuryPick(pick, state: &state)) }
                continue
            }
            if case .awaitingCardFrom(let seat, _, let victim) = state.phase {
                if seat.isLocal { gate = localGate; return }
                gate = .thinking
                await think()
                if Task.isCancelled { return }
                // Face down to everybody, so there is nothing to be clever about.
                // An empty hand is answerable: nothing is taken, and the question closes.
                // Reading `hand[0]` off one was a crash waiting for a Free Agent.
                let pick = state[victim].bag.randomElement()?.id ?? UUID()
                await present(Rules.resolveCardFrom(pick, state: &state), playedCard: true)
                continue
            }
            if case .awaitingMode(let seat, let card) = state.phase {
                if seat.isLocal { gate = localGate; return }
                gate = .thinking
                await think()
                if Task.isCancelled { return }
                await present(Rules.resolveMode(ai.mode(of: card, state, for: seat),
                                                state: &state), playedCard: true)
                continue
            }
            if case .awaitingInjuryDiscard(let seat, let count) = state.phase {
                if seat.isLocal {
                    gate = localGate
                    return
                }
                gate = .thinking
                if Table.shared.isRemote(seat) {
                    let chosen = await waitOn(seat, for: \.discardsFromWire) ?? []
                    if Task.isCancelled { return }
                    await present(Rules.resolveInjuryDiscard(chosen, state: &state))
                    continue
                }
                await think()
                if Task.isCancelled { return }
                // Nothing clever to decide yet: the cheapest card is a judgement the AI
                // does not make anywhere else either.
                let chosen = Array(ai.discardForShot(state, for: seat).prefix(count))
                await present(Rules.resolveInjuryDiscard(chosen, state: &state))
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

    // MARK: - Telling the player in the right order

    /// Which beat of the presentation an event belongs to.
    ///
    /// Everything a move does is decided the instant the rules run, but the player learns
    /// it from the table, one beat at a time. Writing the whole log up front means the
    /// reader is told the outcome before the scene that shows it — bid nothing and the
    /// log already says who got the board. So each line is held until its own beat plays.
    private enum Beat {
        case play, whistle, draw, reveal, shot, turnover, bid, freeThrow, after
    }

    private func beat(of event: GameEvent) -> Beat {
        switch event {
        case .passed, .movePlayed, .clampSet, .whistleArmed, .whistleUsed, .comboLanded,
             .coinRun, .discardedForShot:
            return .play
        case .whistleBlew, .whistleRefocused, .whistlesDismissed, .clampVoided,
             .clampsShaken, .intangiblesStripped, .clampBit:
            return .whistle
        case .drew, .deckReshuffled:
            return .draw
        case .gameBreakRevealed, .intangibleRevealed, .intangibleDisplaced:
            return .reveal
        case .shotAttempted, .shotMade, .shotMissed, .assisted:
            return .shot
        case .turnover, .failedReturn:
            return .turnover
        case .reboundBids, .rebounded:
            return .bid
        case .freeThrowsAwarded, .freeThrowBonus, .freeThrowMade, .freeThrowMissed,
             .freeThrowsEnded:
            return .freeThrow
        default:
            return .after
        }
    }

    /// Writes the lines for one beat and takes them off the ledger, in the order the rules
    /// produced them.
    private func release(_ beat: Beat, from ledger: inout [GameEvent]) {
        let due = ledger.filter { self.beat(of: $0) == beat }
        guard !due.isEmpty else { return }
        ledger.removeAll { self.beat(of: $0) == beat }
        record(due)
    }

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
        for case .clampBit(let seat, _, _) in events {
            clampSwipe = (seat: seat, id: UUID())
            try? await Task.sleep(for: .seconds(Pacing.clampSwipe))
            clampSwipe = nil
        }
    }

    /// A Whistle turning face up.
    private func showWhistle(in events: [GameEvent]) async {
        guard let scene = WhistleReveal.first(in: events, seen: SeenCards.shared) else { return }
        whistleReveal = scene
        await hold(scene.isNew, seconds: Pacing.whistleReveal) { self.whistleReveal }
        whistleReveal = nil
    }

    /// Waits out a scene: on a clock normally, on the player when the card is new to them.
    private func hold(_ untilTapped: Bool, seconds: Double,
                      while alive: @escaping () -> Any?) async {
        guard untilTapped else {
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
        for case .passed in events {
            ballSettledAt = Date()
            // Handed over when it lands, not when it was played. The court flies it for
            // exactly this long — both read the same constant, so they cannot drift.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Theme.Pass.flightSeconds))
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
        try? await Task.sleep(for: .seconds(Pacing.scoreCall))
        scoreCall = nil
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

    func threeScoreLanded() { withheldPoints = nil }
    func threeCelebrationFinished() { celebratingThree = nil }
    func actionCallFinished() { actionCall = nil }

    /// Puts a call up and waits for it to take itself off again.
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
        state[seat].injuries.first { ($0.gameBreak?.discardsEachTurn ?? 0) > 0 }
    }

    /// Counted before the move, because resolving a shot clears the Clamps that caused it.
    private func defenderCount(on seat: Seat) -> Int { state.defenders(on: seat) }

    private func apply(_ move: Move, by seat: Seat) async {
        flashed = nil
        let defenders = defenderCount(on: seat)
        let events = Rules.apply(move, by: seat, to: &state)
        // The throw-in gets its own beat before anything else happens: the ball crosses,
        // and the man who threw it watches it go. Cutting to the next possession the
        // instant the card is chosen is what made him warp off the sideline.
        if case .inbound(let target) = move {
            // Handed straight over: the throw takes the scene from here, so there is never
            // a frame with neither of them set.
            inbounding = nil
            throwing = ThrowIn(from: seat, to: target)
            try? await Task.sleep(for: .seconds(Pacing.inboundThrow + Pacing.inboundHold))
            throwing = nil
        }
        await present(events, defenders: defenders, playedCard: true)
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
        // The gate is what the stage draws from, and it still holds whatever the player
        // was last asked for. Left alone, the rebound board sits behind every cutscene
        // that follows a bid and flashes back the moment one clears.
        gate = .thinking
        // Marked before a single beat plays: the rules dealt these on the way in, and the
        // hand must not have them until their flight says so.
        for case .drew(_, _, let card) in events { undelivered.insert(card) }
        for case .shotAttempted(_, let chance, _) in events { lastChance = chance }
        for case .intangibleRevealed(let seat, _) in events {
            unrevealed[seat, default: 0] += 1
        }
        broadcast(events)
        // Anything but a pass moves the ball at once: an inbound, a rebound, a turnover.
        // Only a throw has a journey to wait for.
        if !events.contains(where: { if case .passed = $0 { return true }; return false }) {
            shownBall = state.ball
        }
        var ledger = events

        if playedCard {
            // Held up first, then thrown. The card is what caused the pass, so it reads
            // before the ball moves rather than over the top of it.
            await showPlayedCard(in: events)
        }
        // **A cancelled chain stops here rather than playing itself out.** Whatever
        // cancelled it has taken the floor, and two chains on one floor is the game
        // carrying on behind whatever is on screen.
        if Task.isCancelled { return }
        // **Here, and not before.** Whatever the card did — a referee taking the floor, a
        // count lighting up, a hand emptying — is shown once the card itself has gone.
        catchUp()
        release(.play, from: &ledger)
        // What the card cost, thrown rather than deleted. Before the draws, because a card
        // that pays for a draw pays for it first.
        for case .discarded(let seat, let count) in events {
            for _ in 0..<count {
                if Task.isCancelled { return }
                await spendCard(from: seat)
            }
        }
        // **Not while the card is still asking.** See `Phase.isMidPlay`: a play that has
        // put a question up has not finished, and what it did to SHOT is not the board's
        // until it has been answered.
        if !state.phase.isMidPlay { shownShot = state.shot + state.holderShot }
        if events.contains(where: { if case .whistleBlew = $0 { return true }; return false }) {
            await announce(.whistle)
        }
        await showWhistle(in: events)
        if Task.isCancelled { return }
        catchUp()
        release(.whistle, from: &ledger)
        stampSettled(events)
        await playDrawsAndReveals(in: events)
        if Task.isCancelled { return }
        catchUp()
        release(.draw, from: &ledger)
        release(.reveal, from: &ledger)
        // Named before anybody swipes: the call is what the possession opens with, and a
        // Clamp taking cards out of the bag first leaves the announcement explaining
        // something that has already happened.
        for case .clampedPossession(let seat, let clamps) in events {
            await announce(.clamped, clamps: clamps)
            boundSeats.insert(seat)
            break
        }
        await showClampBite(in: events)
        if Task.isCancelled { return }
        catchUp()

        if let scene = ShotCutscene(events: events, defenders: defenders,
                                    lastPlay: state.lastPlayThisPossession) {
            cutscene = scene
            try? await Task.sleep(for: .seconds(Pacing.cutscene + scene.drama.seconds))
            // The board goes up **behind** the shot before the shot comes down. Clearing
            // the cutscene first put the bare floor on screen for the beat it took the
            // loop to reach the rebound, which reads as the game losing its place between
            // two halves of the same moment.
            if case .awaitingRebound(let shooter) = state.phase {
                gate = .awaitingBid(shooter: shooter)
            }
            cutscene = nil
            await celebrateThree(in: events)
            await callTheScore(in: events)
        }
        release(.shot, from: &ledger)

        if let scene = TurnoverCutscene(events: events) {
            turnover = scene
            try? await Task.sleep(for: .seconds(scene.hold))
            turnover = nil
        }
        catchUp()
        record(ledger)
    }

    private func record(_ events: [GameEvent]) {
        // Whatever is left was never flown — an event released outside the draw beat, or
        // a presentation cut short. A card stranded here is a card missing from the hand.
        for case .drew(_, _, let card) in events { undelivered.remove(card) }
        // Anything still owed here was never turned over — a beat that did not play, or
        // a presentation cut short. A passive stranded here is a slot missing from the
        // board for the rest of the game.
        unrevealed.removeAll()
        // A man stays bound until the rules let him go.
        boundSeats = boundSeats.filter { !state[$0].clamps.isEmpty }
        if !state.phase.isMidPlay { shownShot = state.shot + state.holderShot }
        shownBall = state.ball
        // Catches a reshuffle, and anything that moved the pile without flying a card.
        shownDeck = state.deck.count
        DevLog.record(events)
        for event in events where event.isLoggable {
            log.append(LogLine(text: event.logLine, kind: kind(of: event)))
        }
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
