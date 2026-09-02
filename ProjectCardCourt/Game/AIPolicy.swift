import Foundation

/// One opponent's dial settings. Every number is a knob, not a finding. An archetype
/// is a preset of this struct.
struct AITuning {
    /// The SHOT at which shooting becomes a coin flip — the centre of the curve, not a cutoff.
    var shootThreshold = 60
    /// How wide the curve is around that centre. Smaller is more decisive.
    var shootSpread = 12.0
    /// Cards this opponent tends to spend chasing a board.
    var reboundBidCap = 2
    /// Cards it prefers to keep back rather than bid.
    var reboundReserve = 2
    /// Typical Move cards per possession. Jittered, but always finite — a Dribble loop
    /// never terminates on its own.
    var maxMovesPerPossession = 3
    /// Clock it would rather not spend on Rhythm Dribble.
    var clockReserve = 2
    /// How often it takes the best target rather than any target.
    var argmaxBias = 0.75
}

struct AIPolicy {
    var tuning: AITuning
    private var rng: SeededRNG

    init(seed: UInt64, tuning: AITuning = AITuning()) {
        self.tuning = tuning
        self.rng = SeededRNG(seed: seed)
    }

    // MARK: - Decisions

    mutating func chooseMove(_ state: GameState, for seat: Seat) -> Move? {
        let legal = Rules.legalMoves(state, for: seat)
        guard !legal.isEmpty else { return nil }

        if case .inbound = state.phase {
            let targets = legal.compactMap { move -> Seat? in
                if case .inbound(let to) = move { return to }
                return nil
            }
            return .inbound(to: pickTarget(from: targets, state: state))
        }

        if state.movesThisPossession < moveAllowance(),
           let card = bestMoveCard(state, for: seat) {
            return .play(card)
        }

        let passes = state[seat].bag.filter { playablePass($0, state: state) }

        // A good look beats setting anything up — and a Special Move that shoots is a
        // better version of the same decision, so it is checked here rather than among
        // the Move cards.
        if willShoot(at: state.shot) {
            let shooters = legal.compactMap { move -> Card? in
                guard case .play(let id) = move,
                      let card = state[seat].bag.first(where: { $0.id == id }),
                      card.descriptor.special?.shootsImmediately == true else { return nil }
                return card
            }
            if let best = shooters.max(by: { lhs, rhs in
                (lhs.descriptor.baseShotDelta, lhs.descriptor.special?.bonusPointOnMake ?? 0)
                    < (rhs.descriptor.baseShotDelta, rhs.descriptor.special?.bonusPointOnMake ?? 0)
            }), best.descriptor.baseShotDelta >= 0 || best.descriptor.special?.shotOverride != nil {
                return .play(best.id)
            }
            return .shoot
        }

        // Only one Whistle is ever live, so there is nothing to gain from overwriting
        // your own — and re-arming in a loop would never end the possession.
        if !state.armedWhistles.contains(where: { $0.owner == seat }),
           let trap = state[seat].bag.first(where: { $0.descriptor.whistle != nil }) {
            return .play(trap.id)
        }

        // A Clamp is only worth setting when the ball is about to move — and only one,
        // or the possession never ends.
        if !passes.isEmpty, state.pendingClamps.isEmpty,
           let clamp = state[seat].bag.first(where: { $0.descriptor.clamp != nil }) {
            return .play(clamp.id)
        }

        // With nothing to pass, anything that lifts SHOT beats heaving at whatever the
        // ball happens to be worth — which is often nothing at all.
        if passes.isEmpty {
            let raisers = legal.compactMap { move -> Card? in
                guard case .play(let id) = move,
                      let card = state[seat].bag.first(where: { $0.id == id }),
                      card.descriptor.baseShotDelta > 0
                        || card.descriptor.special?.shotOverride != nil else { return nil }
                return card
            }
            if let best = raisers.max(by: {
                ($0.descriptor.special?.shotOverride ?? $0.descriptor.baseShotDelta)
                    < ($1.descriptor.special?.shotOverride ?? $1.descriptor.baseShotDelta)
            }) {
                return .play(best.id)
            }
        }

        // Checked last, so a hand of Whistles and Clamps is never mistaken for a hand
        // with nothing in it.
        guard !passes.isEmpty else { return .shoot }
        return .play(choosePass(state, for: seat, from: passes))
    }

    /// Behind-the-Back with nobody behind is a self-inflicted turnover.
    private func playablePass(_ card: Card, state: GameState) -> Bool {
        guard card.isPass else { return false }
        if card.descriptor.passTarget == .backToPasser { return state.lastPasser != nil }
        return true
    }

    private mutating func bestMoveCard(_ state: GameState, for seat: Seat) -> Card.ID? {
        let bag = state[seat].bag
        func first(_ id: String) -> Card? { bag.first { $0.descriptor.id == id } }

        // Cash the combo the moment it is armed.
        if state.lastPlayThisPossession == CardLibrary.dribble.id, let drive = first(CardLibrary.drive.id) {
            return drive.id
        }
        // Only set the combo up when it can actually be finished.
        if first(CardLibrary.drive.id) != nil, let dribble = first(CardLibrary.dribble.id) {
            return dribble.id
        }
        guard !willShoot(at: state.shot) else { return nil }
        if let clock = state.shotClock, clock > tuning.clockReserve + jitter(),
           let rhythm = first(CardLibrary.rhythmDribble.id) {
            return rhythm.id
        }
        return first(CardLibrary.drive.id)?.id
    }

    /// Feeds a Turnaround Three just enough to reach a shot worth taking.
    mutating func discardForShot(_ state: GameState, for seat: Seat) -> [Card.ID] {
        let affordable = max(0, state[seat].bag.count - tuning.reboundReserve)
        let shortfall = max(0, tuning.shootThreshold - state.shot)
        let needed = Int(ceil(Double(shortfall) / 10))
        let count = max(0, min(affordable, needed + jitter()))
        return state[seat].bag.suffix(count).map(\.id)
    }

    mutating func chooseReboundBid(_ state: GameState, for seat: Seat) -> [Card.ID] {
        // Winning the board ticks the clock; at 1 that hands the winner a turnover.
        if let clock = state.shotClock, clock <= 1 { return [] }
        let affordable = max(0, state[seat].bag.count - tuning.reboundReserve)
        guard affordable > 0 else { return [] }
        let base = min(tuning.reboundBidCap, affordable)
        let bid = max(0, min(affordable, base + jitter()))
        return state[seat].bag.suffix(bid).map(\.id)
    }

    // MARK: - Likelihoods

    /// Shooting gets likelier as SHOT climbs rather than switching on at a threshold.
    private mutating func willShoot(at shot: Int) -> Bool {
        let x = Double(shot - tuning.shootThreshold) / tuning.shootSpread
        return chance() < 1 / (1 + exp(-x))
    }

    private mutating func moveAllowance() -> Int {
        max(0, tuning.maxMovesPerPossession + jitter())
    }

    private mutating func jitter() -> Int {
        [-1, 0, 0, 1].randomElement(using: &rng)!
    }

    private mutating func chance() -> Double {
        Double.random(in: 0..<1, using: &rng)
    }

    // MARK: - Choices

    /// Usually feeds whoever is furthest behind, but not so reliably that it can be read.
    private mutating func pickTarget(from seats: [Seat], state: GameState) -> Seat {
        guard !seats.isEmpty else { return .north }
        guard chance() < tuning.argmaxBias else { return seats.randomElement(using: &rng)! }
        return seats.min { state[$0].score < state[$1].score } ?? seats[0]
    }

    private mutating func choosePass(_ state: GameState, for seat: Seat, from cards: [Card]) -> Card.ID {
        guard chance() < tuning.argmaxBias else { return cards.randomElement(using: &rng)!.id }
        let scored = cards.map { card -> (Card.ID, Int) in
            let target = card.descriptor.passTarget.flatMap { seat.seat(inDirection: $0) } ?? state.lastPasser
            return (card.id, target.map { state[$0].score } ?? Int.max)
        }
        return scored.min { $0.1 < $1.1 }?.0 ?? cards[0].id
    }
}

/// One policy per seat, so archetypes can differ from each other.
struct AITable {
    private var policies: [Seat: AIPolicy]

    init(seed: UInt64, tuning: (Seat) -> AITuning = { _ in AITuning() }) {
        policies = Dictionary(uniqueKeysWithValues: Seat.allCases.map {
            ($0, AIPolicy(seed: seed &* 31 &+ UInt64($0.rawValue &+ 1), tuning: tuning($0)))
        })
    }

    mutating func move(_ state: GameState, for seat: Seat) -> Move? {
        policies[seat]!.chooseMove(state, for: seat)
    }

    mutating func reboundBid(_ state: GameState, for seat: Seat) -> [Card.ID] {
        policies[seat]!.chooseReboundBid(state, for: seat)
    }

    mutating func discardForShot(_ state: GameState, for seat: Seat) -> [Card.ID] {
        policies[seat]!.discardForShot(state, for: seat)
    }

    subscript(seat: Seat) -> AITuning {
        get { policies[seat]!.tuning }
        set { policies[seat]!.tuning = newValue }
    }
}
