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
