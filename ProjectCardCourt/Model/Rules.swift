import Foundation

enum Rules {

    // MARK: - Setup

    static func newGame(seed: UInt64, rules: MatchRules = .classic) -> (GameState, [GameEvent]) {
        var state = GameState(
            rules: rules,
            players: Seat.allCases.map { PlayerState(seat: $0) },
            rng: SeededRNG(seed: seed))

        state.shot = rules.startingShot
        state.deck = state.shuffled(CardLibrary.buildDeck(pool: rules.cardPool,
                                                          passShotBonus: rules.passShotBonus))
        var events: [GameEvent] = []
        deal(to: Seat.allCases, count: rules.startingBagSize, state: &state, events: &events)

        state.inbounder = GameRules.debugFirstInbounder ?? state.pick(from: Seat.allCases)
        state.round = 1

        events.append(.gameBegan(firstInbounder: state.inbounder))
        beginRound(state: &state, events: &events)
        return (state, events)
    }

    // MARK: - Legality

    static func legalMoves(_ state: GameState, for seat: Seat) -> [Move] {
        switch state.phase {
        case .inbound(let inbounder) where inbounder == seat:
            return Seat.allCases.filter { $0 != seat }.map { Move.inbound(to: $0) }
        case .possession(let holder) where holder == seat:
            let playable = state[seat].bag.filter { card in
                guard let clock = card.descriptor.special?.onlyAtShotClock else { return true }
                return state.shotClock == clock
            }
            return [.shoot] + playable.map { Move.play($0.id) }
        default:
            return []
        }
    }

    /// A seat may bid anywhere from nothing up to its whole bag.
    static func legalReboundBid(_ state: GameState, for seat: Seat) -> ClosedRange<Int> {
        0...state[seat].bag.count
    }

    // MARK: - Applying moves

    @discardableResult
    static func apply(_ move: Move, by seat: Seat, to state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        switch move {
        case .inbound(let target):
            guard case .inbound(let inbounder) = state.phase, inbounder == seat, target != seat else { return [] }
            state.ball = target
            state.shotClock = state.rules.shotClockStart
            events.append(.inbounded(from: seat, to: target))
            events.append(.shotClockSet(state.rules.shotClockStart))
            // An inbound is not a pass: it grants no SHOT and no assist credit.
            beginPossession(target, tickClock: false, state: &state, events: &events)

        case .play(let cardID):
            guard case .possession(let holder) = state.phase, holder == seat,
                  let index = state[seat].bag.firstIndex(where: { $0.id == cardID })
            else { return [] }
            // Declared but not yet resolved — a Whistle gets to speak here.
            let declared = state[seat].bag[index]
            if let whistle = interceptor(of: .playCard(seat: seat, card: declared), in: state) {
                blow(whistle, on: .playCard(seat: seat, card: declared), state: &state, events: &events)
                return events
            }

            let card = state[seat].bag.remove(at: index)
            state.discard.append(card)
            let descriptor = card.descriptor

            var delta = descriptor.baseShotDelta
            let comboArmed = descriptor.comboAfter != nil
                && descriptor.comboAfter == state.lastPlayThisPossession
            if comboArmed { delta += descriptor.comboBonus }
            adjustShot(by: delta, state: &state)

            for _ in 0..<descriptor.drawCount { draw(seat, state: &state, events: &events) }

            if let special = descriptor.special {
                if let override = special.shotOverride {
                    state.pendingShotOverride = ShotOverride(
                        label: descriptor.name, amount: Double(override),
                        requiresAtLeast: special.overrideRequiresAtLeast)
                }
                if special.coinRunShot > 0 || special.coinRunDraw > 0 {
                    // Flip until tails, paying out per head.
                    var heads = 0
                    while state.roll(0...1) == 1 && heads < 12 { heads += 1 }
                    adjustShot(by: special.coinRunShot * heads, state: &state)
                    for _ in 0..<(special.coinRunDraw * heads) {
                        draw(seat, state: &state, events: &events)
                    }
                    events.append(.coinRun(seat: seat, card: descriptor, heads: heads))
                }
                if special.discardForShotBonus > 0 {
                    // Hand the choice back before the shot goes up.
                    state.phase = .awaitingDiscard(seat: seat, card: descriptor,
                                                   bonusEach: special.discardForShotBonus)
                    return events
                }
                if special.shootsImmediately {
                    // The card is a shot attempt in its own right, so a Whistle watching
                    // for one still gets its say.
                    if let whistle = interceptor(of: .shoot(seat: seat), in: state) {
                        blow(whistle, on: .shoot(seat: seat), state: &state, events: &events)
                        return events
                    }
                    resolveShot(by: seat, bonusPoints: special.bonusPointOnMake,
                                state: &state, events: &events)
                } else {
                    events.append(.movePlayed(seat: seat, card: descriptor, shot: state.shot))
                    state.lastPlayThisPossession = descriptor.id
                    state.movesThisPossession += 1
                }
            } else if let effect = descriptor.whistle {
                if effect.trigger == nil {
                    resolveImmediate(effect, playedBy: seat, state: &state, events: &events)
                } else {
                    // Whistles cancel each other out. The referee stays on the floor,
                    // but only the newest trigger is live.
                    let replaced = !state.armedWhistles.isEmpty
                    state.discard.append(contentsOf: state.armedWhistles.map(\.card))
                    state.armedWhistles = [ArmedWhistle(owner: seat, card: card)]
                    events.append(replaced ? .whistleRefocused : .whistleArmed(seat: seat))
                }
            } else if let clamp = descriptor.clamp {
                // Set down now, lands on whoever receives the ball next. The possession
                // continues, like a Move card.
                state.pendingClamps.append(ActiveClamp(card: descriptor, from: seat))
                _ = clamp
                events.append(.clampSet(seat: seat, card: descriptor))
            } else if let target = descriptor.passTarget {
                guard let receiver = resolve(target, from: seat, state: state) else {
                    // Behind-the-Back with nobody behind: a live-ball turnover.
                    state[seat].turnovers += 1
                    events.append(.failedReturn(seat: seat))
                    events.append(.turnover(seat))
                    endRound(state: &state, events: &events)
                    return events
                }
                state.lastPasser = seat
                events.append(.passed(card: descriptor, from: seat, to: receiver, shot: state.shot))
                beginPossession(receiver, tickClock: true, state: &state, events: &events)
            } else {
                events.append(.movePlayed(seat: seat, card: descriptor, shot: state.shot))
                if comboArmed {
                    events.append(.comboLanded(seat: seat, card: descriptor, bonus: descriptor.comboBonus))
                }
                state.lastPlayThisPossession = descriptor.id
                state.movesThisPossession += 1
                // A Move card keeps the ball, so the seat acts again unless its own
                // clock cost runs the possession out.
                if descriptor.clockDelta != 0 {
                    _ = tickClock(by: descriptor.clockDelta, holder: seat, state: &state, events: &events)
                }
            }

        case .shoot:
            guard case .possession(let holder) = state.phase, holder == seat else { return [] }
            if let whistle = interceptor(of: .shoot(seat: seat), in: state) {
                blow(whistle, on: .shoot(seat: seat), state: &state, events: &events)
                return events
            }
            resolveShot(by: seat, bonusPoints: 0, state: &state, events: &events)
        }
        return events
    }

    /// How many a seat may feed a Turnaround Three.
    static func legalDiscardForShot(_ state: GameState, for seat: Seat) -> ClosedRange<Int> {
        0...state[seat].bag.count
    }

    /// Spends the chosen cards, then takes the shot the card was always going to take.
    @discardableResult
    static func resolveDiscardForShot(_ ids: [Card.ID], state: inout GameState) -> [GameEvent] {
        guard case .awaitingDiscard(let seat, let card, let bonusEach) = state.phase else { return [] }
        var events: [GameEvent] = []

        let chosen = Set(ids)
        let spent = state[seat].bag.filter { chosen.contains($0.id) }
        state[seat].bag.removeAll { chosen.contains($0.id) }
        state.discard.append(contentsOf: spent)

        adjustShot(by: bonusEach * spent.count, state: &state)
        events.append(.discardedForShot(seat: seat, card: card, count: spent.count))

        state.phase = .possession(holder: seat)
        if let whistle = interceptor(of: .shoot(seat: seat), in: state) {
            blow(whistle, on: .shoot(seat: seat), state: &state, events: &events)
            return events
        }
        resolveShot(by: seat, bonusPoints: card.special?.bonusPointOnMake ?? 0,
                    state: &state, events: &events)
        return events
    }

    /// All four bids land at once. Every bid card is discarded whether or not it won.
    @discardableResult
    static func resolveRebound(bids: [Seat: [Card.ID]], state: inout GameState) -> [GameEvent] {
        guard case .awaitingRebound(let shooter) = state.phase else { return [] }
        var events: [GameEvent] = []

        var counts: [Seat: Int] = [:]
        for seat in Seat.allCases {
            let ids = Set(bids[seat] ?? [])
            let discarded = state[seat].bag.filter { ids.contains($0.id) }
            state[seat].bag.removeAll { ids.contains($0.id) }
            state.discard.append(contentsOf: discarded)
            counts[seat] = discarded.count
        }
        events.append(.reboundBids(bids: counts, order: shooter.clockwiseOrderFromHere))

        let highest = counts.values.max() ?? 0
        let contenders = highest == 0
            ? Seat.allCases
            : Seat.allCases.filter { counts[$0] == highest }
        let winner = state.pick(from: contenders)

        state[winner].rebounds += 1
        // A rebound is not a pass, so it carries no assist credit forward.
        state.lastPasser = nil
        events.append(.rebounded(winner))
        // SHOT carries over — only an inbound resets it.
        beginPossession(winner, tickClock: true, state: &state, events: &events)
        return events
    }

    /// Takes the shot. Shared by the free Shoot action and by Special Moves that shoot.
    private static func resolveShot(by seat: Seat, bonusPoints: Int,
                                    state: inout GameState, events: inout [GameEvent]) {
        let resolution = ShotMath.resolve(base: state.shot,
                                          modifiers: state.shotModifiers(for: seat),
                                          rules: state.rules)
        state.pendingShotOverride = nil
        let chance = resolution.chance
        events.append(.shotAttempted(seat: seat, chance: chance, breakdown: resolution))

        let roll = state.roll(1...100)
        if roll <= chance {
            let points = state.rules.madeShotPoints + bonusPoints
            state[seat].points += points
            state[seat].scoredThisRound = true
            events.append(.shotMade(seat: seat, points: points, roll: roll))
            if let passer = state.lastPasser, passer != seat {
                state[passer].assists += 1
                events.append(.assisted(passer))
            }
            endRound(state: &state, events: &events)
        } else {
            events.append(.shotMissed(seat: seat, roll: roll))
            state.phase = .awaitingRebound(shooter: seat)
        }
    }

    // MARK: - Interception

    /// Offers a declared action to any armed Whistle before it takes effect.
    ///
    /// Returns the Whistle that fires, if one does. Resolution is in arming order, which
    /// is what gives a Whistle-cancels-a-Whistle chain a defined winner.
    private static func interceptor(of action: PendingAction, in state: GameState) -> ArmedWhistle? {
        guard !state.whistlesSilenced else { return nil }
        return state.armedWhistles.first { whistle in
            whistle.owner != action.actor && whistle.trigger?.matches(action) == true
        }
    }

    /// Spends the Whistle, cancels what tripped it, and applies its effects.
    private static func blow(_ whistle: ArmedWhistle, on action: PendingAction,
                             state: inout GameState, events: inout [GameEvent]) {
        let effect = whistle.card.descriptor.whistle ?? WhistleEffect()
        let offender = action.actor

        state.armedWhistles.removeAll { $0.id == whistle.id }
        state.discard.append(whistle.card)

        var cancelled = "the play"
        if case .playCard(let seat, let card) = action {
            state[seat].bag.removeAll { $0.id == card.id }
            state.discard.append(card)
            cancelled = card.name
        } else if case .shoot = action {
            cancelled = "the shot"
        }
        events.append(.whistleBlew(owner: whistle.owner, card: whistle.card.descriptor,
                                   cancelled: cancelled))

        if effect.recoversTimeout,
           let index = state.discard.firstIndex(where: { $0.descriptor.id == "timeout" }) {
            state[whistle.owner].bag.append(state.discard.remove(at: index))
        }
        if effect.stripsIntangibles, !state[offender].intangibles.isEmpty {
            state[offender].intangibles.removeAll()
            events.append(.intangiblesStripped(seat: offender))
        }
        for _ in 0..<effect.offenderDiscards { discardAtRandom(from: offender, state: &state) }
        for _ in 0..<effect.offenderDraws { draw(offender, state: &state, events: &events) }
        if effect.pointsToVictim > 0 {
            state[whistle.owner].points += effect.pointsToVictim
            events.append(.shotMade(seat: whistle.owner, points: effect.pointsToVictim, roll: 0))
        }
        if effect.turnoverOnOffender {
            state[offender].turnovers += 1
            events.append(.turnover(offender))
        }

        if effect.endsRound {
            endRound(state: &state, events: &events)
        } else if effect.setterChoosesInbound {
            reinbound(by: whistle.owner, state: &state, events: &events)
        } else if effect.turnoverOnOffender {
            // A turnover costs the ball. The offender hands it back in, and the round
            // does not advance — only a made shot or a real clock expiry does that.
            reinbound(by: offender, state: &state, events: &events)
        }
    }

    /// Whistles that fire on being played rather than lying in wait.
    private static func resolveImmediate(_ effect: WhistleEffect, playedBy seat: Seat,
                                         state: inout GameState, events: inout [GameEvent]) {
        if effect.resetsShotClock {
            state.shotClock = state.rules.shotClockStart
            events.append(.shotClockSet(state.rules.shotClockStart))
        }
        for _ in 0..<effect.everyoneDraws {
            for other in Seat.allCases { draw(other, state: &state, events: &events) }
        }
        if effect.recoversTimeout,
           let index = state.discard.firstIndex(where: { $0.descriptor.id == "timeout" }) {
            state[seat].bag.append(state.discard.remove(at: index))
        }
    }

    private static func discardAtRandom(from seat: Seat, state: inout GameState) {
        guard !state[seat].bag.isEmpty else { return }
        let index = state.roll(0...(state[seat].bag.count - 1))
        state.discard.append(state[seat].bag.remove(at: index))
    }

    /// Hands the ball back in without advancing the round. Shot Clock Violation and
    /// Double Dribble both work this way, and so does any turnover a Whistle causes.
    private static func reinbound(by seat: Seat, state: inout GameState, events: inout [GameEvent]) {
        state.shot = state.rules.startingShot
        state.shotClock = nil
        state.ball = nil
        state.lastPasser = nil
        state.lastPlayThisPossession = nil
        state.pendingClamps = []
        for other in Seat.allCases { state[other].clamps = [] }
        state.phase = .inbound(inbounder: seat)
        events.append(.reinbound(seat: seat))
    }

    // MARK: - Flow

    private static func beginRound(state: inout GameState, events: inout [GameEvent]) {
        state.shot = state.rules.startingShot
        state.shotClock = nil
        state.ball = nil
        state.lastPasser = nil
        state.lastPlayThisPossession = nil
        state.pendingShotOverride = nil
        state.whistlesSilenced = false
        state.phase = .inbound(inbounder: state.inbounder)
        events.append(.roundBegan(round: state.round, inbounder: state.inbounder))
    }

    private static func beginPossession(_ seat: Seat, tickClock shouldTick: Bool,
                                        state: inout GameState, events: inout [GameEvent]) {
        state.ball = seat
        state.lastPlayThisPossession = nil
        state.movesThisPossession = 0

        // Clamps live for exactly one possession, so the board is cleared before the
        // pending ones land. Without the clear they stay on a player forever.
        for other in Seat.allCases { state[other].clamps = [] }
        state[seat].clamps = state.pendingClamps
        state.pendingClamps = []

        draw(seat, state: &state, events: &events)

        for clamp in state[seat].clamps {
            let count = min(clamp.card.clamp?.discardAtStart ?? 0, state[seat].bag.count)
            guard count > 0 else { continue }
            for _ in 0..<count {
                let index = state.roll(0...(state[seat].bag.count - 1))
                state.discard.append(state[seat].bag.remove(at: index))
            }
            events.append(.clampBit(seat: seat, card: clamp.card, discarded: count))
        }

        if shouldTick, tickClock(by: -1, holder: seat, state: &state, events: &events) { return }
        state.phase = .possession(holder: seat)
    }

    /// Returns true when the clock ran out and the round has already been ended.
    @discardableResult
    private static func tickClock(by amount: Int, holder: Seat,
                                  state: inout GameState, events: inout [GameEvent]) -> Bool {
        let remaining = (state.shotClock ?? state.rules.shotClockStart) + amount
        state.shotClock = remaining
        events.append(.shotClockTicked(remaining))
        guard remaining <= 0 else { return false }
        state[holder].turnovers += 1
        events.append(.turnover(holder))
        endRound(state: &state, events: &events)
        return true
    }

    private static func adjustShot(by delta: Int, state: inout GameState) {
        state.shot = max(state.rules.shotFloor, min(state.rules.shotCeiling, state.shot + delta))
    }

    private static func resolve(_ target: PassTarget, from seat: Seat, state: GameState) -> Seat? {
        if let geometric = seat.seat(inDirection: target) { return geometric }
        return state.lastPasser
    }

    private static func endRound(state: inout GameState, events: inout [GameEvent]) {
        events.append(.roundEnded(state.round))
        for seat in Seat.allCases {
            state[seat].scoredLastRound = state[seat].scoredThisRound
            state[seat].scoredThisRound = false
        }

        if state.round >= state.rules.roundsPerGame {
            state.phase = .gameOver
            state.ball = nil
            state.shotClock = nil
            events.append(.gameEnded(winners: winners(of: state)))
            return
        }
        if state.round == state.rules.roundsPerHalf {
            halftime(state: &state, events: &events)
        }
        state.round += 1
        // Rotation continues clockwise across halftime.
        state.inbounder = state.inbounder.clockwise
        beginRound(state: &state, events: &events)
    }

    private static func halftime(state: inout GameState, events: inout [GameEvent]) {
        var pool = state.deck + state.discard
        for seat in Seat.allCases {
            pool += state[seat].bag
            state[seat].bag.removeAll()
        }
        state.deck = state.shuffled(pool)
        state.discard.removeAll()
        deal(to: Seat.allCases, count: state.rules.startingBagSize, state: &state, events: &events)
        events.append(.halftime)
    }

    private static func deal(to seats: [Seat], count: Int,
                             state: inout GameState, events: inout [GameEvent]) {
        // Passives never land in a bag, so this deals to a hand size rather than a draw
        // count. Game Breaks are reshuffled away rather than fired, so nothing a deal
        // turns up can cut a player who has already been dealt.
        var sweeps = 0
        while sweeps < count * 8 {
            sweeps += 1
            guard let short = seats.first(where: { state[$0].bag.count < count }) else { return }
            let before = state[short].bag.count
            draw(short, state: &state, events: &events, duringDeal: true)
            if state[short].bag.count == before && state.deck.isEmpty && state.discard.isEmpty {
                return
            }
        }
    }

    private static func draw(_ seat: Seat, state: inout GameState, events: inout [GameEvent],
                             allowBonus: Bool = true, depth: Int = 0, duringDeal: Bool = false) {
        // A Game Break can draw, and what it draws can be another Game Break. Bounded so
        // a run of them cannot recurse without end. Dealing gets a longer rope because it
        // reshuffles past every Break it turns up.
        guard depth < (duringDeal ? 80 : 8) else { return }
        if state.deck.isEmpty {
            guard !state.discard.isEmpty else { return }
            state.deck = state.shuffled(state.discard)
            state.discard.removeAll()
            events.append(.deckReshuffled)
        }
        let card = state.deck.removeLast()

        // A Game Break drawn while a hand is being dealt does not fire. It goes back into
        // the deck, silently, and the deal tries again.
        if duringDeal, card.descriptor.gameBreak != nil {
            state.deck.append(card)
            state.deck = state.shuffled(state.deck)
            draw(seat, state: &state, events: &events,
                 allowBonus: allowBonus, depth: depth + 1, duringDeal: true)
            return
        }

        if card.descriptor.intangible != nil {
            // Passives never reach a bag — they are revealed and take a slot at once,
            // then replace themselves so slotting one never costs you a card.
            activate(card, for: seat, state: &state, events: &events)
            draw(seat, state: &state, events: &events,
                 allowBonus: false, depth: depth + 1, duringDeal: duringDeal)
        } else if let effect = card.descriptor.gameBreak {
            events.append(.gameBreakRevealed(seat: seat, card: card.descriptor))
            state.discard.append(card)
            resolveGameBreak(effect, drawnBy: seat, state: &state, events: &events, depth: depth)
        } else {
            state[seat].bag.append(card)
            events.append(.drew(seat: seat, card: card.descriptor))
        }

        // Shot Creator pulls extra on every draw. The bonus draw itself grants none,
        // or a second Shot Creator would never stop drawing.
        guard allowBonus else { return }
        let bonus = state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.bonusDraw ?? 0) }
        for _ in 0..<bonus {
            draw(seat, state: &state, events: &events,
                 allowBonus: false, depth: depth + 1, duringDeal: duringDeal)
        }
    }

    private static func resolveGameBreak(_ effect: GameBreakEffect, drawnBy seat: Seat,
                                         state: inout GameState, events: inout [GameEvent],
                                         depth: Int) {
        for _ in 0..<effect.discard { discardAtRandom(from: seat, state: &state) }

        if let limit = effect.everyoneDiscardsTo {
            for other in Seat.allCases where state[other].bag.count > limit {
                while state[other].bag.count > limit { discardAtRandom(from: other, state: &state) }
            }
        }
        if let target = effect.drawUpTo {
            while state[seat].bag.count < target {
                let before = state[seat].bag.count
                draw(seat, state: &state, events: &events, depth: depth + 1)
                if state[seat].bag.count == before { break }
            }
        }
        if effect.shotThisPossession != 0 {
            adjustShot(by: effect.shotThisPossession, state: &state)
        }
        if effect.silencesWhistles {
            state.whistlesSilenced = true
            // Anything that silences Whistles clears the armed one too — the referee
            // leaves the floor rather than standing there unable to call anything.
            if !state.armedWhistles.isEmpty {
                state.discard.append(contentsOf: state.armedWhistles.map(\.card))
                state.armedWhistles.removeAll()
                events.append(.whistlesDismissed)
            }
        }
        if effect.givesBallAway, let holder = state.ball {
            let target = state.pick(from: Seat.allCases.filter { $0 != holder })
            state.lastPasser = nil
            beginPossession(target, tickClock: false, state: &state, events: &events)
        }
    }

    /// Reveals a passive and slots it, pushing out the oldest when the slots are full.
    private static func activate(_ card: Card, for seat: Seat,
                                 state: inout GameState, events: inout [GameEvent]) {
        events.append(.intangibleRevealed(seat: seat, card: card.descriptor))
        state[seat].intangibles.append(card.descriptor)
        while state[seat].intangibles.count > state.rules.intangibleSlots {
            let displaced = state[seat].intangibles.removeFirst()
            events.append(.intangibleDisplaced(seat: seat, card: displaced))
        }
    }

    /// Dumps a hand and deals a fresh one, the way halftime does. Debug only.
    static func reshuffleHand(_ seat: Seat, state: inout GameState) {
        discardHand(seat, state: &state)
        var ignored: [GameEvent] = []
        deal(to: [seat], count: state.rules.startingBagSize, state: &state, events: &ignored)
    }

    /// Dumps a seat's whole hand to the discard. Debug only.
    static func discardHand(_ seat: Seat, state: inout GameState) {
        state.discard.append(contentsOf: state[seat].bag)
        state[seat].bag.removeAll()
    }

    /// Draws one card. Exposed only so the harness can exercise draw-time effects.
    static func testDraw(_ seat: Seat, state: inout GameState, events: inout [GameEvent]) {
        draw(seat, state: &state, events: &events)
    }

    static func winners(of state: GameState) -> [Seat] {
        let best = state.players.map(\.score).max() ?? 0
        return state.players.filter { $0.score == best }.map(\.seat)
    }
}
