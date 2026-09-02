import Foundation
import Observation

/// How long the table pauses so the player can follow what happened.
enum Pacing {
    /// An opponent's deliberation lands somewhere in here, so play never feels metronomic.
    /// Global for now; each archetype will carry its own range later.
    static var thinkTime: ClosedRange<Double> = 0.75...1.85
    static let cutscene = 2.3
    static let turnover = 2.2
    static let reveal = 1.5
    /// One card crossing the court. Dealing is brisker than an in-game draw because
    /// twenty of them go by at once.
    static let drawFlight = 0.30
    static let dealFlight = 0.14
    static let bidReveal = 1.6

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
    /// What the miss gets called. Rolled once here rather than in the view, so it does
    /// not change under the player mid-animation.
    let missCall: String

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

    init?(events: [GameEvent]) {
        var kind = Kind.shotClock
        var seat: Seat?
        for event in events {
            switch event {
            case .failedReturn:                 kind = .badReturn
            case .whistleBlew(_, let card, _):  kind = .whistle(card.name)
            case .turnover(let who):            seat = who
            default: break
            }
        }
        guard let seat else { return nil }
        self.seat = seat
        self.kind = kind
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

/// A Game Break or Intangible shown large to everyone as it is drawn.
struct RevealCutscene: Identifiable, Equatable {
    let id = UUID()
    let seat: Seat
    let card: CardDescriptor
    let isIntangible: Bool

    /// One apply can reveal several — Designed Play refills a hand and anything in that
    /// refill reveals too — so they queue rather than overwrite.
    static func queue(from events: [GameEvent]) -> [RevealCutscene] {
        events.compactMap { event in
            switch event {
            case .gameBreakRevealed(let seat, let card):
                return RevealCutscene(seat: seat, card: card, isIntangible: false)
            case .intangibleRevealed(let seat, let card):
                return RevealCutscene(seat: seat, card: card, isIntangible: true)
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
        case gameOver
    }

    private(set) var state: GameState
    private(set) var log: [LogLine] = []
    private(set) var gate: Gate = .thinking
    private(set) var cutscene: ShotCutscene?
    private(set) var turnover: TurnoverCutscene?
    private(set) var reveal: RevealCutscene?
    private(set) var flight: DrawFlight?
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
        let (state, events) = Rules.newGame(seed: seed, rules: mode)
        self.state = state
        self.openingDraws = events
        record(events)
    }

    var human: PlayerState { state[GameRules.humanSeat] }

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
        await flyDraws(in: events, each: Pacing.drawFlight)
        for scene in RevealCutscene.queue(from: events) {
            reveal = scene
            try? await Task.sleep(for: .seconds(Pacing.reveal))
            reveal = nil
        }
        if let scene = ShotCutscene(events: events, defenders: defenders) {
            cutscene = scene
            try? await Task.sleep(for: .seconds(Pacing.cutscene))
            cutscene = nil
            await celebrateThree(in: events)
        }
        if let scene = TurnoverCutscene(events: events) {
            turnover = scene
            try? await Task.sleep(for: .seconds(Pacing.turnover))
            turnover = nil
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
        await flyDraws(in: events, each: Pacing.drawFlight)
        for scene in RevealCutscene.queue(from: events) {
            reveal = scene
            try? await Task.sleep(for: .seconds(Pacing.reveal))
            reveal = nil
        }
        if let scene = ShotCutscene(events: events) {
            cutscene = scene
            try? await Task.sleep(for: .seconds(Pacing.cutscene))
            cutscene = nil
        }
        if let scene = TurnoverCutscene(events: events) {
            turnover = scene
            try? await Task.sleep(for: .seconds(Pacing.turnover))
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
        case .turnover:                             return .penalty
        case .roundBegan, .halftime, .gameEnded:    return .marker
        default:                                    return .normal
        }
    }
}
