import Foundation

/// The officials: what they do, shown and done to the right man.
func crewTests() {
    print("The crew")
    // A Move that is nothing but a Move — a card and ten per cent — so the only thing to
    // see is the crew.
    let plainMove = CardLibrary.drive
    do {
        var (state, seat, cards) = openPossession(seed: 401, cards: [plainMove])
        state.armedWhistles = [ArmedWhistle(owner: nil, card: matchCard(CardLibrary.travel, state.rules))]
        let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(events.contains { if case .refereeToss = $0 { return true }; return false },
                   "Traffic Cop's coin is thrown where it can be seen, heads or tails")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 402, cards: [CardLibrary.contest])
        state.armedWhistles = [ArmedWhistle(owner: nil,
                                            card: matchCard(CardLibrary.retiringOfficial, state.rules))]
        let held = state[seat].bag.count
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        let events = Rules.resolveTarget(seat.across, state: &state)
        Check.that(events.contains { if case .clampWavedOff = $0 { return true }; return false },
                   "the Retiring Official waves a Clamp off in the open")
        Check.that(state.discard.contains { $0.id == cards[0].id } && state[seat].bag.count == held,
                   "and the Clamp is gone for a card")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 403, cards: [plainMove])
        state.armedWhistles = []
        state.ballCard = Card(CardLibrary.medBall)
        state.shot = 49
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.shot <= 50, "Med Ball: base SHOT never goes over 50 (\(state.shot))")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 404, cards: [CardLibrary.flop])
        state[seat].clamps = []
        let crew = [CardLibrary.travel, CardLibrary.charge, CardLibrary.goaltending]
            .map { ArmedWhistle(owner: nil, card: matchCard($0, state.rules)) }
        state.armedWhistles = crew
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        var byRef = false
        if case .refereeInbound(_, let to) = state.phase { byRef = to != seat }
        Check.that(byRef, "a turnover with no call still goes back in from a referee, not to the man")
    }
    do {
        var (state, seat, _) = openPossession(seed: 405, cards: [])
        let crew = [CardLibrary.offensiveFoul, CardLibrary.crewChief, CardLibrary.travel]
            .map { ArmedWhistle(owner: nil, card: matchCard($0, state.rules)) }
        state.armedWhistles = crew
        let caller = crew[0].id
        Rules.apply(.shootAs(.layup), by: seat, to: &state)
        Check.that(state.armedWhistles.count == 3 && !state.armedWhistles.contains { $0.id == caller },
                   "Crew Chief: the caller goes and a new man comes out")
        Check.that(state.armedWhistles[1].id == crew[1].id && state.armedWhistles[2].id == crew[2].id,
                   "onto the caller's post — nobody else moves")
    }
    do {
        var (state, seat, _) = openPossession(seed: 406, cards: [])
        state[seat].intangibles = [CardLibrary.dirtyPlayer]
        var earlier = ArmedWhistle(owner: nil, card: matchCard(CardLibrary.travel, state.rules))
        earlier.stayed = true
        let caller = ArmedWhistle(owner: nil, card: matchCard(CardLibrary.offensiveFoul, state.rules))
        state.armedWhistles = [caller, earlier]
        Rules.apply(.shootAs(.layup), by: seat, to: &state)
        Check.that(!state.armedWhistles.contains { $0.id == caller.id }
                   && state.armedWhistles.contains { $0.id == earlier.id },
                   "Officially Infamous sends off the man who called it, not the last to call anything")
    }
    do {
        var (state, seat, _) = openPossession(seed: 407, cards: [])
        state[seat.across].intangibles = [CardLibrary.dirtyPlayer]
        state[seat].intangibles = []
        let caller = ArmedWhistle(owner: nil, card: matchCard(CardLibrary.offensiveFoul, state.rules))
        state.armedWhistles = [caller]
        Rules.apply(.shootAs(.layup), by: seat, to: &state)
        Check.that(state.armedWhistles.contains { $0.id == caller.id },
                   "and a call on somebody else costs nobody")
    }
    do {
        var (state, seat, _) = openPossession(seed: 409, cards: [])
        let cop = ArmedWhistle(owner: nil, card: matchCard(CardLibrary.travel, state.rules))
        state.armedWhistles = [cop]
        Check.that(Rules.wouldCall(cop, on: plainMove, by: seat, in: state),
                   "the floor can say a Traffic Cop is watching for the Move you are reading")
        Check.that(!Rules.wouldCall(cop, on: CardLibrary.bulletPass, by: seat, in: state),
                   "and that he has nothing to say about a Pass")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 408, cards: [plainMove])
        state.armedWhistles = [ArmedWhistle(owner: nil,
                                            card: matchCard(CardLibrary.rookieOfficial, state.rules))]
        state.discard = [matchCard(CardLibrary.contest, state.rules),
                         matchCard(CardLibrary.bulletPass, state.rules)]
        state[seat].bag = Array(state[seat].bag.suffix(2))
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        guard case .awaitingRetiredPick(let asked, _, let choices) = state.phase else {
            Check.that(false, "Rookie Official asks which card comes back out of Retirement")
            return
        }
        Check.that(asked == seat && !choices.isEmpty,
                   "Rookie Official asks which card comes back out of Retirement")
        let pick = choices[0]
        Rules.resolveRetiredPick(pick, state: &state)
        Check.that(state[seat].bag.contains { $0.id == pick }, "and the one picked is in the Bag")
    }
}
