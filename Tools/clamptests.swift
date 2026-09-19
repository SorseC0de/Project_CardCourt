import Foundation

/// A defender already standing on the ball-holder, as if he had bitten at the top of the
/// possession.
private func stand(_ card: CardDescriptor, on seat: Seat, _ state: inout GameState) {
    var clamp = ActiveClamp(card: card, from: seat.left)
    clamp.bitten = true
    state[seat].clamps.append(clamp)
}

private func beat(_ events: [GameEvent], _ card: CardDescriptor) -> Bool {
    events.contains { if case .clampBeaten(_, let beaten) = $0 { return beaten.id == card.id }
                      return false }
}

func clampTests() {
    print("Clamps")
    do {
        var (state, seat, _) = openPossession(seed: 301, cards: [])
        stand(CardLibrary.closeOut, on: seat, &state)
        Check.that(!Rules.legalMoves(state, for: seat).contains(.shootAs(.three)),
                   "Close-Out: no Three")
        let events = playDeclining(.shootAs(.layup), by: seat, &state)
        Check.that(beat(events, CardLibrary.closeOut), "Close-Out: cleared by attempting a Shot")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 302, cards: [CardLibrary.swingLeft])
        stand(CardLibrary.tripleTeam, on: seat, &state)
        state[seat].clamps[0].locked = []
        let events = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(beat(events, CardLibrary.tripleTeam), "Triple-Team: cleared by passing the ball")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 303, cards: [CardLibrary.swingLeft])
        stand(CardLibrary.trap, on: seat, &state)
        state[seat.left].clamps = [ActiveClamp(card: CardLibrary.contest, from: seat.right)]
        let events = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(!beat(events, CardLibrary.trap)
                   && state[seat].clamps.contains { $0.card.id == CardLibrary.trap.id },
                   "Trap: a pass to a guarded player does not clear it")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 304, cards: [CardLibrary.swingLeft])
        stand(CardLibrary.trap, on: seat, &state)
        state[seat.left].clamps = []
        let events = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(beat(events, CardLibrary.trap), "Trap: cleared by a pass to an Open player")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 305, cards: [CardLibrary.lethalShooter])
        state[seat].intangibles = []
        stand(CardLibrary.helpSideForward, on: seat, &state)
        let events = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(beat(events, CardLibrary.helpSideForward),
                   "Help-Side Forward: cleared by playing an Intangible")
    }
    do {
        var (state, seat, _) = openPossession(seed: 306, cards: [CardLibrary.swingLeft])
        stand(CardLibrary.baselineDenial, on: seat, &state)
        Check.that(!Rules.legalMoves(state, for: seat).contains { if case .play = $0 { return true }
                                                                  return false },
                   "Baseline Denial: no card can be played")
        var events: [GameEvent] = []
        Rules.stoppage(state: &state, events: &events)
        Check.that(beat(events, CardLibrary.baselineDenial),
                   "Baseline Denial: cleared by any stoppage of play")
    }
    do {
        var (state, seat, _) = openPossession(seed: 307, cards: [])
        state[seat].bag = (0..<4).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
        stand(CardLibrary.crushingCenter, on: seat, &state)
        state.movesThisPossession = state.moveLimit(for: seat)
        Check.that(!Rules.legalMoves(state, for: seat).contains(.shootAs(.dunk)),
                   "Crushing Center: no Dunk, even outside his band")
    }
    do {
        var (state, seat, _) = openPossession(seed: 308, cards: [])
        stand(CardLibrary.rimRunner, on: seat, &state)
        Check.that(!Rules.legalMoves(state, for: seat).contains(.shootAs(.layup)),
                   "Rim Runner: no Layup")
    }
    do {
        var (state, seat, _) = openPossession(seed: 309, cards: [])
        state[seat].bag = (0..<3).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
        stand(CardLibrary.waitingWing, on: seat, &state)
        Check.that(state.shotModifiers(for: seat).debuffs.contains { $0.amount == -30 },
                   "Waiting Wing: SHOT -30% at 3 cards")
        state[seat].bag = Array(state[seat].bag.prefix(1))
        var events: [GameEvent] = []
        Rules.settleClamps(state: &state, events: &events)
        Check.that(beat(events, CardLibrary.waitingWing), "Waiting Wing: cleared at 1 card")
    }
}

/// Plays a Cut to `target`, turning down anything the catch asks.
private func cut(_ id: UUID, by seat: Seat, to target: Seat, _ state: inout GameState) -> [GameEvent] {
    var events = playDeclining(.play(id), by: seat, &state)
    if case .awaitingTarget(_, _, let choices) = state.phase, choices.contains(target) {
        events += Rules.resolveTarget(target, state: &state)
    }
    if case .awaitingRetirement = state.phase { events += Rules.resolveRetirement(nil, state: &state) }
    while case .awaitingCounter = state.phase { events += Rules.resolveCounter(false, state: &state) }
    return events
}

func cutTests() {
    print("Cuts")
    do {
        var (state, seat, cards) = openPossession(seed: 312, cards: [CardLibrary.backdoorCut])
        state[seat].clamps = []
        Check.that(!Rules.legalMoves(state, for: seat).contains(.play(cards[0].id)),
                   "a Cut needs a Clamp on you")
        stand(CardLibrary.contest, on: seat, &state)
        let receiver = seat.left
        state[receiver].bag = [matchCard(CardLibrary.swingLeft, state.rules),
                               matchCard(CardLibrary.dribble, state.rules)]
        _ = cut(cards[0].id, by: seat, to: receiver, &state)
        Check.that(state.ball == receiver && state[seat].clamps.isEmpty
                   && state[receiver].clamps.contains { $0.card.id == CardLibrary.contest.id },
                   "Backdoor Cut: the ball and the Clamps go to the man named")
        let legal = Rules.legalMoves(state, for: receiver)
        let onlyPasses = legal.allSatisfy { move in
            guard case .play(let id) = move else { return false }
            return state[receiver].bag.first { $0.id == id }?.isPass == true
        }
        Check.that(!legal.isEmpty && onlyPasses, "and he must Pass first")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 313, cards: [CardLibrary.backdoorCut])
        stand(CardLibrary.contest, on: seat, &state)
        let receiver = seat.left
        state.deck.removeAll { $0.isPass }
        state[receiver].bag = [matchCard(CardLibrary.dribble, state.rules)]
        let before = state[receiver].turnovers
        _ = cut(cards[0].id, by: seat, to: receiver, &state)
        Check.that(state[receiver].turnovers == before + 1,
                   "Backdoor Cut: no Pass to play is a turnover")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 314, cards: [CardLibrary.flareCut])
        stand(CardLibrary.contest, on: seat, &state)
        _ = cut(cards[0].id, by: seat, to: seat.left, &state)
        Check.that(state.mustShootFirst == seat.left, "Flare Cut: he must Shoot first")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 315, cards: [CardLibrary.flashCut])
        stand(CardLibrary.contest, on: seat, &state)
        let receiver = seat.left
        state[receiver].bag = [matchCard(CardLibrary.swingLeft, state.rules),
                               matchCard(CardLibrary.dribble, state.rules)]
        _ = cut(cards[0].id, by: seat, to: receiver, &state)
        let legal = Rules.legalMoves(state, for: receiver)
        Check.that(!legal.isEmpty && legal.allSatisfy { move in
            guard case .play(let id) = move else { return false }
            return state[receiver].bag.first { $0.id == id }?.descriptor.isMove == true
        }, "Flash Cut: he must play a Move first")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 316, cards: [CardLibrary.curlCut])
        stand(CardLibrary.contest, on: seat, &state)
        let receiver = seat.left
        state[receiver].bag = [matchCard(CardLibrary.dribble, state.rules)]
        let mine = state[seat].bag.count
        _ = cut(cards[0].id, by: seat, to: receiver, &state)
        // Played the Cut (-1), drew 1, and took his card.
        Check.that(state[seat].bag.count == mine + 1
                   && state[seat].bag.contains { $0.descriptor.id == CardLibrary.dribble.id },
                   "Curl Cut: a card out of his Bag and into yours")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 317, cards: [CardLibrary.vCut])
        stand(CardLibrary.contest, on: seat, &state)
        let receiver = seat.left
        _ = cut(cards[0].id, by: seat, to: receiver, &state)
        Check.that(state.ball == seat && state[seat].clamps.isEmpty
                   && !state[receiver].clamps.isEmpty,
                   "V-Cut: the ball comes back and the Clamps stay with him")
        Check.that(state.nextThreeBonus == 30, "and a Three first is SHOT +30%")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 318, cards: [CardLibrary.lCut])
        stand(CardLibrary.contest, on: seat, &state)
        state.ballCard = Card(CardLibrary.blightBall)
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        if case .awaitingTarget = state.phase { _ = Rules.resolveTarget(seat.left, state: &state) }
        var asked = false
        if case .awaitingRetirement(_, _, let choices) = state.phase {
            asked = choices.contains(.ball)
            _ = Rules.resolveRetirement(.ball, state: &state)
        }
        while case .awaitingCounter = state.phase { _ = Rules.resolveCounter(false, state: &state) }
        Check.that(asked && state.ballCard == nil && state.ball == seat.left,
                   "L-Cut: may Retire the ball, then the ball goes")
    }
}

func retirementTests() {
    print("Retirement")
    do {
        var (state, seat, cards) = openPossession(seed: 321, cards: [CardLibrary.skyhook])
        state[seat].bag = Array(state[seat].bag.suffix(1))
        let wanted = matchCard(CardLibrary.slamDunk, state.rules)
        state.discard = [matchCard(CardLibrary.skyhook, state.rules), wanted]
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        var offered: [UUID] = []
        if case .awaitingRetiredPick(_, _, let choices) = state.phase { offered = choices }
        Check.that(offered == [wanted.id], "Skyhook: chooses from Retirement, never a Skyhook")
        let events = Rules.resolveRetiredPick(wanted.id, state: &state)
        Check.that(state[seat].bag.contains { $0.id == wanted.id }
                   && events.contains { if case .shotAttempted = $0 { return true }; return false },
                   "and the chosen card is taken before the shot goes up")
    }
    do {
        var (state, seat, _) = openPossession(seed: 322, cards: [])
        state[seat].intangibles = [CardLibrary.varsitile, CardLibrary.sniper]
        let buried = matchCard(CardLibrary.lethalShooter, state.rules)
        state.discard = [buried]
        Rules.apply(.exchangeWithRetirement, by: seat, to: &state)
        Rules.resolveRetiredPick(buried.id, state: &state)
        Rules.resolveRetirement(.intangible(seat: seat, id: CardLibrary.sniper.id), state: &state)
        Check.that(state[seat].intangibles.contains { $0.id == CardLibrary.lethalShooter.id }
                   && !state[seat].intangibles.contains { $0.id == CardLibrary.sniper.id }
                   && state.discard.contains { $0.descriptor.id == CardLibrary.sniper.id },
                   "Varsitile: an Intangible exchanged for one in Retirement")
    }
}

func aimTests() {
    print("Aiming")
    do {
        var (state, seat, cards) = openPossession(seed: 331, cards: [CardLibrary.bulletPass])
        let shot = state.shot
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        var asked = false
        if case .awaitingTarget = state.phase { asked = true }
        Check.that(asked && state[seat].bag.contains { $0.id == cards[0].id } && state.shot == shot,
                   "a Pass to a chosen man asks who before anything is played")
        Rules.cancelAim(state: &state)
        var back = false
        if case .possession(let holder) = state.phase { back = holder == seat }
        Check.that(back && state[seat].bag.contains { $0.id == cards[0].id },
                   "and cancelling leaves the card in the Bag, nothing done")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 332, cards: [CardLibrary.bulletPass])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Rules.resolveTarget(seat.across, state: &state)
        while case .awaitingCounter = state.phase { Rules.resolveCounter(false, state: &state) }
        Check.that(state.ball == seat.across, "and answering plays it at the man named")
    }
}

func randomnessTests() {
    print("The roll")
    // A plain three at 10%, over and over from fresh games: the make rate has to land
    // near 10%, or the dice are wrong.
    var makes = 0
    let tries = 2000
    for seed in 1...UInt64(tries) {
        var (state, seat, _) = openPossession(seed: 5000 + seed, cards: [])
        state[seat].intangibles = []
        state[seat].clamps = []
        state.ballCard = nil
        state.shot = 10
        let events = Rules.apply(.shootAs(.layup), by: seat, to: &state)
        guard let chance = events.compactMap({ event -> Int? in
            if case .shotAttempted(_, let chance, _) = event { return chance }
            return nil
        }).first, chance == 10 else { continue }
        if events.contains(where: { if case .shotMade = $0 { return true }; return false }) {
            makes += 1
        }
    }
    let rate = Double(makes) / Double(tries)
    Check.that(rate > 0.07 && rate < 0.13, "a 10% shot goes in about one time in ten (\(Int(rate * 100))%)")
}
