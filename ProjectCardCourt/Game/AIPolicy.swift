import Foundation

/// One opponent's dial settings. Every number is a knob, not a finding. An archetype
/// is a preset of this struct.
struct AITuning {
    /// The SHOT at which shooting becomes a coin flip — the centre of the curve, not a cutoff.
    var shootThreshold = 60
    /// How wide the curve is around that centre. Smaller is more decisive.
    var shootSpread = 12.0
    /// **A look not worth the board it hands over.** At or under this, anything else on
    /// the table beats shooting: the attempt cannot score, and the miss puts the ball up
    /// for a rebound that costs the whole table cards. A possession with nothing to do
    /// ends on the clock instead, which at least hands the next man a fresh SHOT.
    var hopelessShot = 10
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
        // **The hand it may actually spend from.** Several branches below reach into the
        // bag directly, and a bag is not a list of legal plays — a Clamp holds cards
        // down, Triple Threat closes the book on Moves, a Lob owes a shot. Asked for
        // one of those the rules simply refuse, and an opponent that keeps asking is an
        // opponent whose turn never ends.
        let playableIDs = Set(legal.compactMap { move -> Card.ID? in
            if case .play(let id) = move { return id } else { return nil }
        })
        let playable = state[seat].bag.filter { playableIDs.contains($0.id) }

        // A Free Agent with nothing of his own has only other people's bags. Reaching for
        // the fullest one is the same rule the rest of this policy uses for a target.
        let ownCards = legal.contains { if case .play = $0 { return true }; return false }
        if !ownCards {
            let borrows = legal.compactMap { move -> Seat? in
                if case .borrow(let from) = move { return from }
                return nil
            }
            if let fullest = borrows.max(by: { state[$0].bag.count < state[$1].bag.count }) {
                return .borrow(from: fullest)
            }
        }

        if case .inbound = state.phase {
            let targets = legal.compactMap { move -> Seat? in
                if case .inbound(let to) = move { return to }
                return nil
            }
            return .inbound(to: pickTarget(from: targets, state: state))
        }

        // Traderous Tarmac: every Clamp on it goes to whoever is winning.
        let receivers = Rules.handOffTargets(state, for: seat)
        if let clamp = state[seat].clamps.first, !receivers.isEmpty {
            let leader = receivers.max { state[$0].score < state[$1].score } ?? receivers[0]
            return .handOffClamp(clamp: clamp.id, to: leader)
        }

        let canPass = playable.contains { playablePass($0, state: state) }
        if let slot = slotCard(state, for: seat, from: playable, passing: canPass) {
            return .play(slot)
        }

        if state.movesThisPossession < moveAllowance(),
           let card = bestMoveCard(state, for: seat, from: playable) {
            return .play(card)
        }

        let passes = playable.filter { playablePass($0, state: state) }

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
                // S.O.S: a two at double the look, when that is worth more than the three.
                if legal.contains(.playAsTwo(best.id)) {
                    let look = min(100, max(0, state.shot + best.descriptor.baseShotDelta))
                    if 2 * min(100, look * 2) > 3 * look { return .playAsTwo(best.id) }
                }
                return .play(best.id)
            }
            // Sixth Man's button, when it is the better look.
            if legal.contains(.shootAtOffer), let offer = state.shotOffer(for: seat),
               offer.amount > Double(state.shot) {
                return .shootAtOffer
            }
            if let shot = finish(legal, state, for: seat) { return shot }
        }

        // Only one Whistle is ever live, so there is nothing to gain from overwriting
        // your own — and re-arming in a loop would never end the possession.
        if !state.armedWhistles.contains(where: { $0.owner == seat }),
           let trap = playable.first(where: { $0.descriptor.whistle != nil }) {
            return .play(trap.id)
        }

        // A Clamp is only worth setting when the ball is about to move — and only one,
        // or the possession never ends.
        if !passes.isEmpty, state.pendingClamps.isEmpty,
           let clamp = playable.first(where: { $0.descriptor.clamp != nil }) {
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
        guard !passes.isEmpty else {
            // **Never heave at nothing.** A quarter of every attempt in the game used to
            // be taken at 0%, and four in five of those had something else playable —
            // each one a guaranteed miss that put the ball back up for a board.
            if state.shot <= tuning.hopelessShot,
               let anything = legal.first(where: { if case .play = $0 { return true }
                                                   return false }) {
                return anything
            }
            // Nothing to pass and nothing to shoot with: play whatever is left rather
            // than asking for a shot the rules will refuse.
            return finish(legal, state, for: seat)
                ?? legal.first(where: { if case .play = $0 { return true }; return false })
                ?? legal.first
        }
        return .play(choosePass(state, for: seat, from: passes))
    }

    /// **Which of the three buttons.** A three pays a point more for the same roll, so it
    /// is taken whenever it is on offer; a dunk costs an opponent a card and a layup gives
    /// one back, which is the tie-break between them at a thin hand.
    ///
    ///
    /// **Nil when there is no finish on offer at all** — a defender forcing one the man
    /// cannot take, a floor that has barred it. Returning the plain button there had the
    /// opponent ask for a shot the rules refuse, over and over, and the possession never
    /// ended.
    func finish(_ legal: [Move], _ state: GameState, for seat: Seat) -> Move? {
        let offered = legal.compactMap { move -> ShotType? in
            if case .shootAs(let type) = move { return type }
            return nil
        }
        if offered.contains(.three) { return .shootAs(.three) }
        // A hand worth protecting would rather take one off somebody else.
        if offered.contains(.dunk), state[seat].bag.count >= 3 { return .shootAs(.dunk) }
        if offered.contains(.layup) { return .shootAs(.layup) }
        return offered.first.map { Move.shootAs($0) }
    }

    /// What to take for beating a defender. Cards first while the hand is thin, the free
    /// look once it is not — and the rotation when there is somebody worth putting him on.
    static func payoff(_ state: GameState, for seat: Seat) -> ClampPayoff {
        if state[seat].bag.count <= 2 { return .draw }
        if state.shot >= 50 { return .shoot }
        return .passAndRotate
    }

    /// **A floor or a ball worth putting down.** Most go down as the first thing; the balls
    /// that hurt whoever holds them only go down when there is a pass to hand them on with.
    private mutating func slotCard(_ state: GameState, for seat: Seat, from playable: [Card],
                                   passing: Bool) -> Card.ID? {
        // An Intangible in hand goes down as soon as it can: one a possession, and a slot
        // is worth nothing sitting in the hand.
        if let passive = playable.first(where: { $0.descriptor.intangible != nil }) {
            return passive.id
        }
        let slots = playable.filter {
            $0.descriptor.varena != nil || $0.descriptor.variaball != nil
        }
        guard !slots.isEmpty, chance() < 0.7 else { return nil }
        let weapons: Set<String> = [
            CardLibrary.benchBall.id, CardLibrary.dishtractingBall.id, CardLibrary.blightBall.id,
            CardLibrary.snowBall.id, CardLibrary.brickBall.id, CardLibrary.handBall.id,
            CardLibrary.brandNewBall.id,
        ]
        for card in slots {
            let id = card.descriptor.id
            // Already out. Putting it down again changes nothing.
            if id == state.currentCourt.id || id == state.currentBall?.id { continue }
            if weapons.contains(id), !passing { continue }
            return card.id
        }
        return nil
    }

    /// Behind-the-Back with nobody behind is a self-inflicted turnover.
    private func playablePass(_ card: Card, state: GameState) -> Bool {
        guard card.isPass else { return false }
        if card.descriptor.passTarget == .backToPasser { return state.lastPasser != nil }
        return true
    }

    private mutating func bestMoveCard(_ state: GameState, for seat: Seat,
                                       from playable: [Card]) -> Card.ID? {
        let bag = playable
        func first(_ id: String) -> Card? { bag.first { $0.descriptor.id == id } }

        // Free points, and the Clamps come off the shot that follows. Worth taking the
        // moment anyone is standing on you.
        if !state[seat].clamps.isEmpty, let flop = first(CardLibrary.flop.id) { return flop.id }

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

    /// Which branch of a card that offers several.
    ///
    /// The best look on offer, and a draw when nothing on offer improves the shot — which
    /// is the same shape as every other decision this policy makes.
    func mode(of card: CardDescriptor, _ state: GameState, for seat: Seat) -> Int {
        let best = card.modes.enumerated().max { left, right in
            left.element.shotDelta < right.element.shotDelta
        }
        guard let best, best.element.shotDelta > 0 else { return 0 }
        return best.offset
    }

    subscript(seat: Seat) -> AITuning {
        get { policies[seat]!.tuning }
        set { policies[seat]!.tuning = newValue }
    }
}
