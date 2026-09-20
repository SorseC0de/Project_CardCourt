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
        // **Nothing on the floor beats him any more.** Taking a shot was his printed
        // clear; the one mechanic is his price, and it is paid out of the hand.
        let events = playDeclining(.shootAs(.layup), by: seat, &state)
        Check.that(!beat(events, CardLibrary.closeOut),
                   "Close-Out: shooting does not clear him")
    }
    do {
        // **Scoring over him beats him**, free, whatever his card asks for.
        var (state, seat, _) = openPossession(seed: 330, cards: [])
        state[seat].bag = (0..<4).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
        stand(CardLibrary.contest, on: seat, &state)
        state.shot = 100
        let events = playDeclining(.shootAs(.layup), by: seat, &state)
        Check.that(events.contains { if case .shotMade = $0 { return true }; return false },
                   "a make at a hundred goes in")
        Check.that(state[seat].clamps.isEmpty && beat(events, CardLibrary.contest),
                   "and scoring over him takes him off")
    }
    do {
        var (state, seat, _) = openPossession(seed: 320, cards: [])
        // Dealt a hand that can afford him: `openPossession` leaves room rather than a
        // full Bag, and a price is only interesting when it can be paid.
        state[seat].bag = (0..<4).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
        stand(CardLibrary.closeOut, on: seat, &state)
        let price = Rules.clearPrice(for: seat, in: state)
        Check.that(price == 2, "Close-Out asks for 2")
        let paying = Array(state[seat].bag.prefix(price ?? 0)).map(\.id)
        let held = state[seat].bag.count
        let events = Rules.apply(.clearClamp(paying: paying), by: seat, to: &state)
        Check.that(state[seat].clamps.isEmpty && beat(events, CardLibrary.closeOut),
                   "and retiring them beats him")
        Check.that(state[seat].bag.count == held - (price ?? 0), "at the price on his card")
        // What he was taking away, given back. Whether the Three is *offered* is the
        // hand's business — a three wants a fuller one than paying him off leaves.
        Check.that(!Rules.clampBlockedShotTypes(on: seat, in: state).contains(.three),
                   "and the Three is his to take away no longer")
    }
    do {
        // **A locked card still pays.** A lock stops you playing it, not spending it —
        // otherwise Triple-Team could price you out of getting rid of Triple-Team.
        var (state, seat, _) = openPossession(seed: 321, cards: [])
        state[seat].bag = (0..<4).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
        stand(CardLibrary.tripleTeam, on: seat, &state)
        // Locked by hand: `stand` puts him on the floor without the arrival that rolls
        // them, and what is being tested is that a locked card can still be spent.
        let locked = Array(state[seat].bag.prefix(3)).map(\.id)
        state[seat].clamps[0].locked = locked
        Check.that(Rules.lockedCards(state, for: seat).count == 3, "Triple-Team locks 3")
        let events = Rules.apply(.clearClamp(paying: locked), by: seat, to: &state)
        Check.that(state[seat].clamps.isEmpty && beat(events, CardLibrary.tripleTeam),
                   "and the three it locked are what beat it")
    }
    do {
        // Short of the price is no clear at all.
        var (state, seat, _) = openPossession(seed: 322, cards: [])
        state[seat].bag = (0..<4).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
        stand(CardLibrary.manToMan, on: seat, &state)
        let one = Array(state[seat].bag.prefix(1)).map(\.id)
        let events = Rules.apply(.clearClamp(paying: one), by: seat, to: &state)
        Check.that(events.isEmpty && state[seat].clamps.count == 1,
                   "Man-To-Man: two cards short of his three buys nothing")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 303, cards: [CardLibrary.swingLeft])
        stand(CardLibrary.trap, on: seat, &state)
        state[seat.left].clamps = []
        let events = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(!beat(events, CardLibrary.trap),
                   "Trap: a pass to an Open player no longer clears it")
    }
    do {
        var (state, seat, _) = openPossession(seed: 306, cards: [CardLibrary.swingLeft])
        stand(CardLibrary.baselineDenial, on: seat, &state)
        Check.that(!Rules.legalMoves(state, for: seat).contains { if case .play = $0 { return true }
                                                                  return false },
                   "Baseline Denial: no card can be played")
        var events: [GameEvent] = []
        Rules.stoppage(state: &state, events: &events)
        Check.that(!beat(events, CardLibrary.baselineDenial),
                   "Baseline Denial: a stoppage does not clear him")
        Check.that(Rules.clearPrice(for: seat, in: state) == 1,
                   "and he is the cheapest man on the floor to be rid of")
    }
    do {
        var (state, seat, _) = openPossession(seed: 307, cards: [])
        state[seat].bag = (0..<4).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
        stand(CardLibrary.crushingCenter, on: seat, &state)
        state.movesThisPossession = state.moveLimit(for: seat)
        // **The whole defender is out of his band, not half of him.** The sheet's own
        // note is "only bites at 2 cards or fewer" — so at four the dunk is there. This
        // asserted the opposite, which is the bug it was pinning in place.
        Check.that(Rules.legalMoves(state, for: seat).contains(.shootAs(.dunk)),
                   "Crushing Center: the Dunk is there outside his band")
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
        Check.that(!beat(events, CardLibrary.waitingWing),
                   "Waiting Wing: stepping out of his band is not beating him")
        Check.that(!state.shotModifiers(for: seat).debuffs.contains { $0.amount == -30 },
                   "though his SHOT comes off while you are out of it")
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

/// **A defender outside his band takes nothing away.**
///
/// Pressing Point only bites at four cards or more. Its SHOT debuff checked the band and
/// its blocked finish did not, so the layup stayed barred at a hand size the defender was
/// not even a problem at — and no amount of beating him took the ban off.
func bandTests() {
    print("Pace defenders")
    do {
        var (state, seat, _) = openPossession(seed: 601, cards: [])
        // Dealt rather than trimmed: `openPossession` leaves room in the hand, so a
        // `prefix(4)` of it can be three cards and the band never opens.
        state[seat].bag = (0..<4).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
        stand(CardLibrary.pressingPoint, on: seat, &state)
        Check.that(!Rules.legalMoves(state, for: seat).contains(.shootAs(.layup)),
                   "Pressing Point: no Layup inside his band")
        state[seat].bag = Array(state[seat].bag.prefix(3))
        Check.that(Rules.legalMoves(state, for: seat).contains(.shootAs(.layup)),
                   "Pressing Point: the Layup comes back outside it")
        Check.that(state[seat].clamps.count == 1,
                   "Pressing Point: and he is still standing there")
    }
    do {
        var (state, seat, _) = openPossession(seed: 602, cards: [])
        state[seat].bag = (0..<2).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
        stand(CardLibrary.crushingCenter, on: seat, &state)
        Check.that(state.shotModifiers(for: seat).debuffs.contains { $0.amount == -30 },
                   "Crushing Center: his SHOT inside his band")
        Check.that(!Rules.legalMoves(state, for: seat).contains(.shootAs(.dunk)),
                   "Crushing Center: and no Dunk")
        state[seat].bag += [matchCard(CardLibrary.drive, state.rules),
                            matchCard(CardLibrary.drive, state.rules)]
        Check.that(!state.shotModifiers(for: seat).debuffs.contains { $0.amount == -30 },
                   "Crushing Center: both come off together outside it")
    }
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

/// The one door into a Bag, and what a Bag over its limit does about it.
func bagTests() {
    print("Bags")
    do {
        var (state, seat, cards) = openPossession(seed: 331, cards: [CardLibrary.curlCut])
        stand(CardLibrary.contest, on: seat, &state)
        let receiver = seat.left
        state[receiver].bag = [matchCard(CardLibrary.dribble, state.rules)]
        // A full Bag, the Cut among it: played (-1), drawn back (+1), and his card on top.
        let limit = state.handLimit(for: seat)
        state[seat].bag = [cards[0]]
            + (1..<limit).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
        _ = cut(cards[0].id, by: seat, to: receiver, &state)
        var asked = false
        if case .awaitingGiveUp(let who, _, let count) = state.phase {
            asked = who == seat && count == 1
        }
        Check.that(asked, "a card forced into a full Bag asks its owner what goes")
        Check.that(state[seat].bag.count == limit + 1,
                   "and the Bag holds them all until it is answered")
        _ = Rules.resolveGiveUp([state[seat].bag[0].id], state: &state)
        Check.that(state[seat].bag.count == limit, "and comes back to the limit on the answer")
    }
}
