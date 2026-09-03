import Foundation
import Observation

/// How long the table pauses so the player can follow what happened.
enum Pacing {
    /// An opponent's deliberation lands somewhere in here, so play never feels metronomic.
    /// Global for now; each archetype will carry its own range later.
    static var thinkTime: ClosedRange<Double> = 0.75...1.75
    static let cutscene = 3.0
    /// Longer than the ball takes to arrive and settle, or the scene cuts away while it
    /// is still rolling — which is what made it look like it never stopped.
    static let turnover = 4.0
    /// The ball arriving, three cuts on it, and then the clock.
    static let shotClockTurnover = 5.5
    static let reveal = 1.5
    /// The whistle, the back, the flip, and the name under it.
    static let whistleReveal = 3.5
    /// One card crossing the court. Dealing is brisker than an in-game draw because
    /// twenty of them go by at once.
    static let drawFlight = 0.30
    static let dealFlight = 0.15
    static let bidReveal = 1.5
    /// One opponent attempt from the line, start to finish.
    static let freeThrow = 2.5

    static func think() -> Double { .random(in: thinkTime) }
}

struct LogLine: Identifiable {
    enum Kind { case normal, score, penalty, marker }
    let id = UUID()
    let text: String
    let kind: Kind
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

    /// Built directly, for replaying the scene from the debug panel.
    init(shooter: Seat, chance: Int, made: Bool, defenders: Int) {
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

    init?(events: [GameEvent], defenders: Int = 0) {
        var shooter: Seat?
        var chance = 0
        var made: Bool?
        for event in events {
            switch event {
            case .shotAttempted(let seat, let pct, _): shooter = seat; chance = pct
            case .shotMade: made = true
            case .shotMissed: made = false
            default: break
            }
        }
        guard let shooter, let made else { return nil }
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
            case .whistleBlew(_, let card, _, _): kind = .whistle(card.name)
            case .turnover(let who):            seat = who
            case .passed(_, let from, _, _):    thrower = from
            default: break
            }
        }
        guard let seat else { return nil }
        self.seat = seat
        self.kind = kind
        // Whoever last threw it decides which side it comes in from; with nobody to read,
        // either side is as true as the other.
        self.fromLeft = thrower.map { $0.slot(viewedFrom: GameRules.humanSeat) == .west }
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
        for case .whistleBlew(let owner, let card, let cancelled, let victim) in events {
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
        case awaitingInbound(Seat)
        case awaitingMove(Seat)
        case awaitingBid(shooter: Seat)
        case awaitingDiscard(card: CardDescriptor, bonusEach: Int)
        case awaitingFreeThrow(FreeThrowTrip)
        case gameOver
    }

    private(set) var state: GameState
    private(set) var log: [LogLine] = []
    private(set) var gate: Gate = .thinking
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
    /// The opening performance. Set once, at the top of a match.
    private(set) var opening: OpeningDeal?
#if DEBUG
    /// A pass thrown for the eye only. No cards, no rules, no turn — it exists so the
    /// catch can be tuned without playing a hand to reach one.
    private(set) var practicePass: (from: Seat, to: Seat)?
#endif
    private(set) var playedCard: PlayedCard?
    /// Stamped once the cutscenes clear, which is when the catch should play.
    private(set) var ballSettledAt: Date?
    /// A made three, celebrating. The points are withheld from the scoreboard until the
    /// number reaches it.
    private(set) var celebratingThree: Seat?
    private(set) var withheldPoints: (seat: Seat, amount: Int)?
    private(set) var flightDuration = Pacing.drawFlight
    /// Set for a beat after a rebound so the reveal can be shown, then cleared.
    private(set) var revealedBids: [Seat: Int]?
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
        PlayerLook.shared.randomiseOpponents(except: GameRules.humanSeat)
        let (state, events) = Rules.newGame(seed: seed, rules: mode)
        self.state = state
        self.openingDraws = events
        record(events)
    }

    var human: PlayerState { state[GameRules.humanSeat] }

    /// Passives sitting in a slot that currently pay nothing — Hot Hand without a make
    /// behind it, and anything like it.
    var dormantIntangibles: Set<String> {
        Set(human.intangibles
            .filter { Rules.isDormant($0, for: GameRules.humanSeat, in: state) }
            .map(\.id))
    }

    var humanPasses: [Card] { human.bag.filter(\.isPass) }

    func begin() {
        loop?.cancel()
        loop = Task {
            // The opening deal goes out card by card before anyone can act.
            await flyDraws(in: openingDraws, each: Pacing.dealFlight)
            openingDraws = []
            await run()
        }
    }

    /// Runs a card across the court for each draw, and blocks until they have all landed.
    private func flyDraws(in events: [GameEvent], each duration: Double) async {
        for case .drew(let seat, _) in events {
            flightDuration = duration
            flight = DrawFlight(seat: seat)
            try? await Task.sleep(for: .seconds(duration))
            if Task.isCancelled { return }
        }
        flight = nil
    }

    // MARK: - Human input

    func inbound(to seat: Seat) {
        guard case .awaitingInbound = gate else { return }
        loop?.cancel()
        loop = Task {
            await apply(.inbound(to: seat), by: GameRules.humanSeat)
            await run()
        }
    }

    func play(_ card: Card) {
        guard case .awaitingMove = gate else { return }
        loop?.cancel()
        loop = Task {
            await apply(.play(card.id), by: GameRules.humanSeat)
            await run()
        }
    }

    func shoot() {
        guard case .awaitingMove = gate else { return }
        loop?.cancel()
        loop = Task {
            await apply(.shoot, by: GameRules.humanSeat)
            await run()
        }
    }

    func submitDiscard() {
        guard case .awaitingDiscard = gate else { return }
        loop?.cancel()
        let chosen = Array(bidSelection)
        bidSelection.removeAll()
        loop = Task {
            let defenders = defenderCount(on: GameRules.humanSeat)
            await applyEvents(Rules.resolveDiscardForShot(chosen, state: &state),
                              defenders: defenders)
            await run()
        }
    }

    /// The player's own attempt, decided by the mini-game rather than by a roll.
    func shootFreeThrow(made: Bool) {
        guard case .awaitingFreeThrow = gate else { return }
        loop?.cancel()
        loop = Task {
            await applyEvents(Rules.resolveFreeThrow(made: made, state: &state))
            await run()
        }
    }

    func submitBid() {
        guard case .awaitingBid = gate else { return }
        loop?.cancel()
        let mine = Array(bidSelection)
        bidSelection.removeAll()
        loop = Task {
            var bids: [Seat: [Card.ID]] = [:]
            for seat in Seat.allCases {
                bids[seat] = seat == GameRules.humanSeat ? mine : ai.reboundBid(state, for: seat)
            }
            let events = Rules.resolveRebound(bids: bids, state: &state)
            record(events)
            if let scene = TurnoverCutscene(events: events) {
                turnover = scene
                try? await Task.sleep(for: .seconds(Pacing.turnover))
                turnover = nil
            }
            for case .reboundBids(let counts, _) in events {
                revealedBids = counts
                try? await Task.sleep(for: .seconds(Pacing.bidReveal))
                revealedBids = nil
            }
            await run()
        }
    }

#if DEBUG
    /// Pulls one card for the human, flight animation and all.
    func debugDraw() {
        loop?.cancel()
        loop = Task {
            var events: [GameEvent] = []
            Rules.testDraw(GameRules.humanSeat, state: &state, events: &events)
            await applyEvents(events)
            await run()
        }
    }

    func debugDiscardHand() {
        Rules.discardHand(GameRules.humanSeat, state: &state)
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
                              order: GameRules.humanSeat.clockwiseOrderFromHere,
                              each: state.rules.startingBagSize)
    }

    /// Throws one card from the deck to the next seat round, on the court-wide stage.
    func debugDeal() {
        let next = stageDeal.map { $0.seat.clockwise } ?? GameRules.humanSeat
        stageDeal = (next, UUID())
    }

    /// Sets a Whistle down face-down, the way arming one looks from the table.
    func debugArmWhistle() {
        loop?.cancel()
        loop = Task {
            playedCard = PlayedCard(seat: GameRules.humanSeat,
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
        loop = Task {
            let card = Self.aWhistle()
            let scene = WhistleReveal(owner: GameRules.humanSeat, card: card,
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
        loop = Task {
            let scene = TurnoverCutscene(seat: GameRules.humanSeat, kind: kind)
            turnover = scene
            try? await Task.sleep(for: .seconds(scene.hold))
            turnover = nil
            await run()
        }
    }

    /// Throws a pass across the court without touching the game.
    func debugPass(to seat: Seat) {
        loop?.cancel()
        loop = Task {
            practicePass = (GameRules.humanSeat, seat)
            // Restamped, so a second press replays rather than being ignored.
            ballSettledAt = Date()
            // Long enough for the throw *and* the catch that follows it. Clearing this
            // at the end of the flight pulled the receiver's `caughtAt` away a tenth of a
            // second into the catch, so the sheet never got past its first frames.
            let tuning = BallTuning.shared
            let catchSeconds = Double(Sprite.catchBall.frames) / tuning.catchFPS
            try? await Task.sleep(for: .seconds(tuning.flightSeconds + tuning.holdSeconds
                                                + catchSeconds + 0.2))
            practicePass = nil
            await run()
        }
    }

    /// Sends the human to the line for two, for working on the mini-game.
    func debugFreeThrows() {
        loop?.cancel()
        loop = Task {
            await applyEvents(Rules.debugAwardFreeThrows(2, to: GameRules.humanSeat,
                                                         state: &state))
            await run()
        }
    }

    /// Replays a missed shot, which is where most of the rim drama lives.
    func debugMiss() {
        loop?.cancel()
        loop = Task {
            cutscene = ShotCutscene(shooter: GameRules.humanSeat,
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
        loop = Task {
            cutscene = ShotCutscene(shooter: GameRules.humanSeat,
                                    chance: Int(ShotTuning.shared.debugChance),
                                    made: true, defenders: 0)
            try? await Task.sleep(for: .seconds(Pacing.cutscene + (cutscene?.drama.seconds ?? 0)))
            cutscene = nil
            await run()
        }
    }

    /// Dump and redraw, for getting to a hand worth testing quickly.
    func debugReshuffleHand() {
        Rules.reshuffleHand(GameRules.humanSeat, state: &state)
    }
#endif

    // MARK: - Loop

    private func run() async {
        while !Task.isCancelled {
            if state.isOver { gate = .gameOver; return }

            if case .awaitingRebound(let shooter) = state.phase {
                gate = .awaitingBid(shooter: shooter)
                return
            }
            if case .freeThrows(let trip) = state.phase {
                if trip.shooter == GameRules.humanSeat {
                    gate = .awaitingFreeThrow(trip)
                    return
                }
                gate = .thinking
                try? await Task.sleep(for: .seconds(Pacing.think()))
                if Task.isCancelled { return }
                let made = Rules.rollFreeThrow(state: &state)
                aiFreeThrow = AIFreeThrow(trip: trip, made: made)
                try? await Task.sleep(for: .seconds(Pacing.freeThrow))
                aiFreeThrow = nil
                await applyEvents(Rules.resolveFreeThrow(made: made, state: &state))
                continue
            }
            if case .awaitingDiscard(let seat, let card, let bonusEach) = state.phase {
                if seat == GameRules.humanSeat {
                    gate = .awaitingDiscard(card: card, bonusEach: bonusEach)
                    return
                }
                gate = .thinking
                try? await Task.sleep(for: .seconds(Pacing.think()))
                if Task.isCancelled { return }
                let chosen = ai.discardForShot(state, for: seat)
                let defenders = defenderCount(on: seat)
                await applyEvents(Rules.resolveDiscardForShot(chosen, state: &state),
                                  defenders: defenders)
                continue
            }
            guard let seat = state.phase.actingSeat else { gate = .thinking; return }

            if seat == GameRules.humanSeat {
                gate = { if case .inbound = state.phase { return .awaitingInbound(seat) }
                         return .awaitingMove(seat) }()
                return
            }

            gate = .thinking
            try? await Task.sleep(for: .seconds(Pacing.think()))
            if Task.isCancelled { return }
            guard let move = ai.move(state, for: seat) else { gate = .thinking; return }
            await apply(move, by: seat)
        }
    }

    private func applyEvents(_ events: [GameEvent], defenders: Int = 0) async {
        record(events)
        await showWhistle(in: events)
        stampSettled(events)
        await flyDraws(in: events, each: Pacing.drawFlight)
        await showReveals(in: events)
        if let scene = ShotCutscene(events: events, defenders: defenders) {
            cutscene = scene
            try? await Task.sleep(for: .seconds(Pacing.cutscene + scene.drama.seconds))
            cutscene = nil
            await celebrateThree(in: events)
        }
        if let scene = TurnoverCutscene(events: events) {
            turnover = scene
            try? await Task.sleep(for: .seconds(scene.hold))
            turnover = nil
        }
    }

    /// Every card turned up by this play, one at a time.
    private func showReveals(in events: [GameEvent]) async {
        for scene in RevealCutscene.queue(from: events, seen: SeenCards.shared) {
            reveal = scene
            await hold(scene.isNew, seconds: Pacing.reveal) { self.reveal }
            reveal = nil
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
        while alive() != nil { try? await Task.sleep(for: .milliseconds(60)) }
    }

    /// Holds up whatever was just played, so everyone can read it.
    private func showPlayedCard(in events: [GameEvent]) async {
        guard let card = PlayedCard.first(in: events) else { return }
        playedCard = card
        try? await Task.sleep(for: .seconds(GameRules.playedCardSeconds))
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
            return
        }
    }

    /// A three is anything worth more than an ordinary bucket.
    private func celebrateThree(in events: [GameEvent]) async {
        for case .shotMade(let seat, let points, _) in events
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

    /// Counted before the move, because resolving a shot clears the Clamps that caused it.
    private func defenderCount(on seat: Seat) -> Int {
        state[seat].clamps.reduce(0) { $0 + ($1.card.clamp?.defenders ?? 1) }
    }

    private func apply(_ move: Move, by seat: Seat) async {
        let defenders = defenderCount(on: seat)
        let events = Rules.apply(move, by: seat, to: &state)
        record(events)
        // Held up first, then thrown. The card is what caused the pass, so it reads
        // before the ball moves rather than over the top of it.
        await showPlayedCard(in: events)
        await showWhistle(in: events)
        stampSettled(events)
        await flyDraws(in: events, each: Pacing.drawFlight)
        await showReveals(in: events)
        if let scene = ShotCutscene(events: events) {
            cutscene = scene
            try? await Task.sleep(for: .seconds(Pacing.cutscene + scene.drama.seconds))
            cutscene = nil
        }
        if let scene = TurnoverCutscene(events: events) {
            turnover = scene
            try? await Task.sleep(for: .seconds(scene.hold))
            turnover = nil
        }
    }

    private func record(_ events: [GameEvent]) {
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
