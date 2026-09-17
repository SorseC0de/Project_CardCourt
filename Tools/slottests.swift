import Foundation

/// Every event of a play, with any counter the arrival offered turned down.
func playDeclining(_ move: Move, by seat: Seat, _ state: inout GameState) -> [GameEvent] {
    var events = Rules.apply(move, by: seat, to: &state)
    while case .awaitingCounter = state.phase { events += Rules.resolveCounter(false, state: &state) }
    return events
}

func slotTests() {
    print("Varenas and Variaballs")
    do {
        var (state, seat, _) = openPossession(seed: 201, cards: [])
        state[seat].intangibles = []
        state.courtCard = Card(CardLibrary.primeParquet)
        Check.that(state.shotModifiers(for: seat).adds.contains { $0.amount == 20 },
                   "Prime Parquet: SHOT +20%")
        state.courtCard = Card(CardLibrary.lacktop)
        Check.that(state.shotModifiers(for: seat).adds.contains { $0.amount == -20 },
                   "Lacktop: SHOT -20%")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 202, cards: [CardLibrary.smacktop,
                                                                     CardLibrary.travel])
        state.armedWhistles = [ArmedWhistle(owner: seat.left,
                                            card: matchCard(CardLibrary.charge, state.rules))]
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.armedWhistles.isEmpty, "Smacktop clears the referees off the floor")
        Check.that(!Rules.legalMoves(state, for: seat).contains(.play(cards[1].id)),
                   "and no Whistle can be played on it")
        state[seat].clamps = [ActiveClamp(card: CardLibrary.contest, from: seat.left)]
        Check.that(state.shotModifiers(for: seat).debuffs.first?.amount == -35,
                   "and a Contest takes a step more")
    }
    do {
        var (state, seat, _) = openPossession(seed: 203, cards: [])
        state[seat].intangibles = []
        state.ballCard = Card(CardLibrary.medBall)
        Check.that(ShotMath.resolve(base: 90, modifiers: state.shotModifiers(for: seat),
                                    rules: state.rules).chance == 50,
                   "Med Ball: no shot goes past 50%")
        state[seat].intangibles = [CardLibrary.sniper]
        Check.that(ShotMath.resolve(base: 30,
                                    modifiers: state.shotModifiers(for: seat, fromThree: true),
                                    rules: state.rules).chance == 50,
                   "and holds an Intangible's Three bonus to it as well")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 204, cards: [CardLibrary.swingLeft])
        state.ballCard = Card(CardLibrary.dishcountBall)
        state.pendingClamps = [ActiveClamp(card: CardLibrary.fullCourtPress, from: seat)]
        state[seat.left].bag = (0..<4).map { _ in matchCard(CardLibrary.swingRight, state.rules) }
        let events = playDeclining(.play(cards[0].id), by: seat, &state)
        let bit = events.compactMap { event -> Int? in
            if case .clampBit(let who, _, let count) = event, who == seat.left { return count }
            return nil
        }.first
        Check.that(bit == 1, "Dishcount Ball: a Full-Court Press takes one fewer")
    }
    do {
        var (state, seat, _) = openPossession(seed: 205, cards: [])
        state.courtCard = Card(CardLibrary.boarderCourt)
        state.phase = .awaitingRebound(shooter: seat)
        for other in Seat.allCases {
            state[other].intangibles = []
            state[other].bag = [matchCard(CardLibrary.dribble, state.rules)]
        }
        let bids: [Seat: [Card.ID]] = [seat: [state[seat].bag[0].id],
                                       seat.left: [state[seat.left].bag[0].id]]
        let events = Rules.resolveRebound(bids: bids, state: &state)
        Check.that(events.contains { if case .rebounded(let who) = $0 { return who == seat }
                                     return false },
                   "Boarder Court: off his own miss, the shooter's bid counts one more")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 206, cards: [CardLibrary.swingLeft,
                                                                     CardLibrary.blightBall])
        state[seat].injuries = [CardLibrary.tornAchilles]
        state[seat].injuryUnlocked = state[seat].bag.map(\.id)
        Rules.apply(.play(cards[1].id), by: seat, to: &state)
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(state[seat].injuries.isEmpty
                   && state[seat.left].injuries.contains { $0.id == CardLibrary.tornAchilles.id },
                   "Blight Ball: the Injuries go with the ball")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 207, cards: [CardLibrary.dimDome])
        state.shot = 40
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.redacted(for: seat.left).shot == 0 && state.redacted(for: seat).shot == 40
                   && Rules.loggedShot(state) == -1,
                   "Dim Dome: only the ball holder reads SHOT")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 208, cards: [CardLibrary.triHardTiling])
        // Hands are trimmed to leave room for draws, so they have to be filled back up
        // before a card that cuts them down to three has anything to cut.
        for other in Seat.allCases {
            while state[other].bag.count < state.rules.handLimit {
                state[other].bag.append(matchCard(CardLibrary.swingLeft, state.rules))
            }
        }
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that({ if case .awaitingGiveUp(let who, _, let count) = state.phase {
                         return who == seat && count == state[seat].bag.count - 3 }
                     return false }(),
                   "Tri-hard Tiling: a hand over 3 is cut down to 3, its owner's pick")
        answerArrival(&state)
        Check.that(Seat.allCases.allSatisfy { state[$0].bag.count <= 3 }, "every hand")
        var events: [GameEvent] = []
        Rules.testDraw(seat, state: &state, events: &events)
        // A hand already at the floor's limit takes nothing more; the card pays SHOT.
        Check.that(state[seat].bag.count == 3, "and a draw into a hand of 3 is converted")
    }
    do {
        // **A call that always lands**, so the thing under test is Policeum rather than a
        // coin: Charge fires on a shot every time. Traffic Cop flips for his now.
        var (state, seat, _) = openPossession(seed: 209, cards: [])
        state.courtCard = Card(CardLibrary.policeum)
        state.armedWhistles = [ArmedWhistle(owner: nil,
                                            card: matchCard(CardLibrary.offensiveFoul, state.rules))]
        Rules.apply(.shootAs(.layup), by: seat, to: &state)
        Check.that(state.armedWhistles.first?.stayed == true,
                   "Policeum: a referee who calls one stays on the floor")
        var events: [GameEvent] = []
        Rules.testEndRound(state: &state, events: &events)
        Check.that(state.armedWhistles.count == 1, "through the end of the round")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 210, cards: [CardLibrary.threeBall,
                                                                     CardLibrary.kickOut])
        state.courtCard = Card(CardLibrary.kiddieCourt)
        let legal = Rules.legalMoves(state, for: seat)
        Check.that(!legal.contains(.play(cards[0].id)) && !legal.contains(.play(cards[1].id)),
                   "Kiddie Court: no threes, and nothing that makes one")
        state[seat].intangibles = []
        state[seat].clamps = []
        state.shot = 100
        var events: [GameEvent] = []
        Rules.testShot(by: seat, state: &state, events: &events)
        Check.that(events.contains { if case .shotMade(_, let points, _, _) = $0 { return points == 2 }
                                     return false },
                   "and a make counts 2")
    }
    do {
        // **Long Ball pays the finishes you have to work for.** A three is already three,
        // so it lifts the layup and the dunk and leaves the three alone.
        var (state, seat, _) = openPossession(seed: 211, cards: [])
        state.ballCard = Card(CardLibrary.benchBall)
        state.shot = 100
        var events: [GameEvent] = []
        Rules.testShot(by: seat, state: &state, events: &events)
        Check.that(events.contains { if case .shotMade(_, let points, _, _) = $0 { return points == 3 }
                                     return false },
                   "Long Ball: a layup counts 3")
        Check.that(Rules.longBallBonus(for: .three, in: state) == 0
                   && Rules.longBallBonus(for: .dunk, in: state) == 0,
                   "and the Three and the dunk are left where they were")
    }
    do {
        // **Foot On The Line takes the point, not the shot.** Its face says the three
        // scores two instead, and every other call on that trigger waves the attempt off
        // — so the one that does not has to be let through.
        var (state, seat, _) = openPossession(seed: 214, cards: [])
        state.armedWhistles = [ArmedWhistle(owner: nil,
                                            card: matchCard(CardLibrary.footOnTheLine,
                                                            state.rules))]
        state.shot = 100
        while state[seat].bag.count < state.handLimit {
            state[seat].bag.append(matchCard(CardLibrary.swingLeft, state.rules))
        }
        let events = Rules.apply(.shootAs(.three), by: seat, to: &state)
        Check.that(events.contains { if case .whistleBlew = $0 { return true }; return false },
                   "the call is made")
        Check.that(events.contains { if case .shotAttempted = $0 { return true }; return false },
                   "and the ball still goes up")
        var scored = 0
        for case .shotMade(_, let points, _, _) in events { scored = points }
        Check.that(scored == state.rules.madeShotPoints,
                   "for two, not three (got \(scored))")
    }

    do {
        // **Med Ball lifts the speed limit.** Travel is a coin on every Move card now, so
        // the loose case is counted over a spread of seeds rather than pinned to one —
        // the man carrying this ball can run all day either way, which is the half of the
        // card that makes picking it up a decision rather than a punishment.
        func travelCalls(carryingMedBall: Bool) -> Int {
            var called = 0
            for seed in UInt64(200)..<240 {
                var (state, seat, cards) = openPossession(seed: seed, cards: [CardLibrary.drive])
                if carryingMedBall { state.ballCard = Card(CardLibrary.medBall) }
                state.armedWhistles = [ArmedWhistle(
                    owner: nil, card: matchCard(CardLibrary.travel, state.rules))]
                let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
                if events.contains(where: {
                    if case .whistleBlew = $0 { return true }; return false
                }) { called += 1 }
            }
            return called
        }
        let loose = travelCalls(carryingMedBall: false)
        Check.that(loose > 0, "a Move travels on tails (\(loose) of 40)")
        Check.that(travelCalls(carryingMedBall: true) == 0,
                   "Med Ball: Move cards never Travel")
    }

    do {
        // **On the shot, not on the catch.** Taking the ball is free; putting it up is
        // what costs a card, and it is the shooter who pays.
        var (state, seat, cards) = openPossession(seed: 212, cards: [CardLibrary.swingLeft])
        state.ballCard = Card(CardLibrary.baldBall)
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that({ if case .awaitingGiveUp = state.phase { return false }
                     return true }(),
                   "Bald Ball: catching it costs nothing")
        let shooter = state.ball ?? seat.left
        Rules.apply(.shootAs(.layup), by: shooter, to: &state)
        Check.that({ if case .awaitingGiveUp(let who, _, 1) = state.phase { return who == shooter }
                     return false }(),
                   "Bald Ball: shooting it costs a card")
    }

    do {
        // **Dishtracting Ball gets the officials' attention, not the defence's.** The
        // pass stops to name one of the crew, he goes off with it, and somebody comes out
        // to take his place — then the ball carries on to where it was thrown.
        var (state, seat, cards) = openPossession(seed: 212, cards: [CardLibrary.swingLeft])
        state.ballCard = Card(CardLibrary.dishtractingBall)
        state.armedWhistles = [CardLibrary.travel, CardLibrary.charge, CardLibrary.blockingFoul]
            .map { ArmedWhistle(owner: nil, card: matchCard($0, state.rules)) }
        let crew = state.armedWhistles.count
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that({ if case .awaitingRetirement(let who, _, let choices) = state.phase {
                       return who == seat && choices.count == crew }
                     return false }(),
                   "Dishtracting Ball: the pass stops to name an official (\(crew) working)")
        let waved = state.armedWhistles[0].id
        let thrown = Rules.resolveRetirement(.official(waved), state: &state)
        Check.that(!state.armedWhistles.contains { $0.id == waved },
                   "the named official goes off")
        Check.that(state.armedWhistles.count == crew, "and a replacement comes out")
        Check.that(thrown.contains { if case .passed = $0 { return true }; return false },
                   "and the pass is thrown anyway")

        // Declining is an answer: the crew stands and the ball still goes.
        var (stands, passer, held) = openPossession(seed: 212, cards: [CardLibrary.swingLeft])
        stands.ballCard = Card(CardLibrary.dishtractingBall)
        stands.armedWhistles = [CardLibrary.travel, CardLibrary.charge, CardLibrary.blockingFoul]
            .map { ArmedWhistle(owner: nil, card: matchCard($0, stands.rules)) }
        let standing = stands.armedWhistles.map(\.id)
        Rules.apply(.play(held[0].id), by: passer, to: &stands)
        let kept = Rules.resolveRetirement(nil, state: &stands)
        Check.that(stands.armedWhistles.map(\.id) == standing, "declined: the crew stands")
        Check.that(kept.contains { if case .passed = $0 { return true }; return false },
                   "and the pass is thrown all the same")
    }

    do {
        // **Liar Ball says the first miss did not count.** One more attempt, and the
        // retake is taken at its word however it lands.
        var (state, seat, _) = openPossession(seed: 212, cards: [CardLibrary.swingLeft])
        state.ballCard = Card(CardLibrary.liarBall)
        state.phase = .freeThrows(trip: FreeThrowTrip(shooter: seat, offender: nil,
                                                      source: "Foul", remaining: 1))
        Rules.resolveFreeThrow(made: false, state: &state)
        Check.that({ if case .freeThrows(let trip) = state.phase { return trip.remaining == 1 }
                     return false }(),
                   "Liar Ball: a missed free throw is taken once more")
        Rules.resolveFreeThrow(made: false, state: &state)
        Check.that({ if case .freeThrows = state.phase { return false }; return true }(),
                   "and the retake is the end of it")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 213, cards: [CardLibrary.swingLeft])
        state.courtCard = Card(CardLibrary.rechargingResin)
        state[seat.left].bag = []
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        // The match says how big a hand is, not the card — see `MatchRules.startingBagSize`.
        Check.that(state[seat.left].bag.count == state.rules.startingBagSize,
                   "Recharging Resin: a possession opens on a full hand")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 214, cards: [CardLibrary.swingLeft])
        state.courtCard = Card(CardLibrary.contactCourt)
        state.pendingClamps = [ActiveClamp(card: CardLibrary.contest, from: seat)]
        let events = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(events.contains { if case .freeThrowsAwarded(let who, 1, _) = $0 { return who == seat.left }
                                     return false },
                   "Contact Court: being clamped is a trip to the line")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 215, cards: [CardLibrary.swingLeft,
                                                                     CardLibrary.handBall])
        Rules.apply(.play(cards[1].id), by: seat, to: &state)
        let mine = Set(state[seat].bag.map(\.id)).subtracting([cards[0].id])
        let theirs = Set(state[seat.left].bag.map(\.id))
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(Set(state[seat].bag.map(\.id)) == theirs
                   && mine.isSubset(of: Set(state[seat.left].bag.map(\.id))),
                   "Hand Ball: a pass swaps hands")
    }
    do {
        var (state, seat, _) = openPossession(seed: 216, cards: [])
        state.courtCard = Card(CardLibrary.polypaypylene)
        state[seat].intangibles = []
        state[seat].clamps = []
        state.shot = 100
        let before = state[seat].bag.count
        var events: [GameEvent] = []
        Rules.testShot(by: seat, state: &state, events: &events)
        Check.that(state[seat].bag.count == before + 3, "Polypaypylene: a make draws 3")
    }
}

func slotTestsTwo() {
    do {
        var (state, seat, cards) = openPossession(seed: 217, cards: [CardLibrary.swingLeft])
        state.ballCard = Card(CardLibrary.rechargeRock)
        let before = state[seat.left].bag.count
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(state[seat.left].bag.count == before + 2, "Recharge Rock: the draw for turn is doubled")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 218, cards: [CardLibrary.drive, CardLibrary.footBall])
        Rules.apply(.play(cards[1].id), by: seat, to: &state)
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state[seat].bag.contains { $0.id == cards[0].id }
                   && !Rules.legalMoves(state, for: seat).contains(.play(cards[0].id)),
                   "Foot Ball: a Move stays in the hand, locked")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 219, cards: [CardLibrary.recoverena])
        state[seat.left].injuries = [CardLibrary.tornAchilles]
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state[seat.left].injuries.isEmpty, "Recoverena: every Injury comes off")
        state.deck.append(matchCard(CardLibrary.boneBruise, state.rules))
        let before = state[seat].bag.count
        var events: [GameEvent] = []
        Rules.testDraw(seat, state: &state, events: &events)
        Check.that(state[seat].injuries.isEmpty && state[seat].bag.count == before + 1,
                   "and a new one is a card instead")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 220, cards: [CardLibrary.variaball])
        state.discard.append(matchCard(CardLibrary.brickBall, state.rules))
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.currentBall?.id == CardLibrary.brickBall.id
                   && state.discard.contains { $0.id == cards[0].id },
                   "Variaball: a discarded ball goes into play, and the card to the pile")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 221, cards: [CardLibrary.carouselCourt,
                                                                     CardLibrary.swingLeft])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that({ if case .awaitingTarget(let asked, _, let choices) = state.phase {
                         return asked == seat && choices == [seat.left, seat.right] }
                     return false }(),
                   "Carousel Court: its player declares the way round")
        Rules.resolveTarget(seat.left, state: &state)
        let travelling = Set(state[seat].bag.map(\.id)).subtracting([cards[1].id])
        _ = playDeclining(.play(cards[1].id), by: seat, &state)
        Check.that(travelling.isSubset(of: Set(state[seat.left].bag.map(\.id))),
                   "and every possession the hands move one seat that way")
    }
    do {
        var (state, seat, _) = openPossession(seed: 222, cards: [])
        state.courtCard = Card(CardLibrary.traderousTarmac)
        let clamp = ActiveClamp(card: CardLibrary.doubleTeam, from: seat.left)
        state[seat].clamps = [clamp]
        Rules.apply(.handOffClamp(clamp: clamp.id, to: seat.across), by: seat, to: &state)
        Check.that(state[seat].clamps.isEmpty && state[seat.across].clamps.first?.id == clamp.id,
                   "Traderous Tarmac: a Clamp on you goes to the player you pick")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 223, cards: [CardLibrary.swingLeft])
        state.courtCard = Card(CardLibrary.clearcoatCourt)
        state[seat.across].intangibles = [CardLibrary.hotHand]
        state[seat.across].injuries = [CardLibrary.tornAchilles]
        state.armedWhistles = [ArmedWhistle(owner: seat.across,
                                            card: matchCard(CardLibrary.charge, state.rules))]
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(state[seat.across].intangibles.isEmpty && state[seat.across].injuries.isEmpty
                   && state.armedWhistles.isEmpty,
                   "Clearcoat Court: every possession wipes the floor")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 224, cards: [CardLibrary.swingLeft])
        state.courtCard = Card(CardLibrary.malicePalace)
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(state[seat.left].bag.count == 1, "Malice Palace: the hand goes before the draw")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 225, cards: [CardLibrary.turnstileTile,
                                                                     CardLibrary.swingLeft])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        state[seat].intangibles = []
        Check.that(state.shotModifiers(for: seat).adds.contains { $0.amount == 25 },
                   "Turnstile Tile: +25% the possession it lands")
        _ = playDeclining(.play(cards[1].id), by: seat, &state)
        state[seat.left].intangibles = []
        Check.that(state.shotModifiers(for: seat.left).adds.contains { $0.amount == -25 },
                   "and -25% the next")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 226, cards: [CardLibrary.swingLeft])
        state.courtCard = Card(CardLibrary.roleplayerPolymer)
        let across = state[seat.across].bag.count
        let passer = state[seat].bag.count - 1
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(state[seat.across].bag.count == across + 1 && state[seat].bag.count == passer + 1,
                   "Roleplayer Polymer: everyone but the player with the ball draws 1")
    }
    do {
        let (state, seat, cards) = openPossession(seed: 227, cards: [CardLibrary.slamDunk])
        var floor = state
        floor.courtCard = Card(CardLibrary.graviGym)
        Check.that(!Rules.legalMoves(floor, for: seat).contains(.play(cards[0].id)),
                   "Gravi-Gym: no dunks")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 228, cards: [CardLibrary.vintageVarnish,
                                                                     CardLibrary.blazeBall])
        let oldBall = Card(CardLibrary.brickBall)
        state.ballCard = oldBall
        state[seat].intangibles = [CardLibrary.hotHand, CardLibrary.sniper]
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.ballCard == nil && state.discard.contains { $0.id == oldBall.id },
                   "Vintage Varnish: the ball in play is discarded")
        Check.that({ if case .awaitingIntangibleDrop(let who, _) = state.phase { return who == seat }
                     return false }(),
                   "a board over 1 Intangible drops to 1")
        answerArrival(&state)
        Check.that(!Rules.legalMoves(state, for: seat).contains(.play(cards[1].id))
                   && state.shotClockLength == 14,
                   "no Variaball can be played, on a 14 shot clock")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 229, cards: [CardLibrary.threeBall])
        state.courtCard = Card(CardLibrary.sellOutStadium)
        state[seat].intangibles = []
        state[seat].clamps = []
        state.shot = 50
        Check.that(Rules.legalMoves(state, for: seat).contains(.playAsTwo(cards[0].id)),
                   "S.O.S: a three can go up as a two")
        let events = Rules.apply(.playAsTwo(cards[0].id), by: seat, to: &state)
        let chance = events.compactMap { event -> Int? in
            if case .shotAttempted(_, let chance, _) = event { return chance }
            return nil
        }.first
        Check.that(chance == 80, "at double SHOT")
        Check.that(!events.contains { if case .shotMade(_, let points, _, _) = $0 { return points != 2 }
                                      return false },
                   "worth 2")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 230, cards: [CardLibrary.swingLeft])
        state.courtCard = Card(CardLibrary.grayvstone)
        let events = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(events.contains { if case .graveyardEmpty = $0 { return true }; return false },
                   "Grayvstone: no ball in the discards, and play goes on")
        state.discard.append(matchCard(CardLibrary.blazeBall, state.rules))
        let back = matchCard(CardLibrary.swingRight, state.rules)
        state[seat.left].bag.append(back)
        _ = playDeclining(.play(back.id), by: seat.left, &state)
        Check.that(state.currentBall?.id == CardLibrary.blazeBall.id,
                   "and with one there, it's the ball")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 231, cards: [CardLibrary.drive])
        state.courtCard = Card(CardLibrary.conCrete)
        state[seat].intangibles = []
        state[seat].clamps = []
        state.shot = 30
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.shot == 30, "Con-crete: a Move pays 10% less")
    }
    do {
        var (state, seat, _) = openPossession(seed: 232, cards: [])
        state.courtCard = Card(CardLibrary.spazzphalt)
        state[seat].intangibles = []
        var events: [GameEvent] = []
        Rules.testShot(by: seat, state: &state, events: &events)
        Check.that(events.contains { event in
            guard case .shotAttempted(_, let chance, let breakdown) = event else { return false }
            return chance % 5 == 0 && breakdown.steps.contains { $0.label == "Spazzphalt" }
        }, "Spazzphalt: SHOT is the floor's roll, in steps of 5")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 233, cards: [CardLibrary.drive])
        state.courtCard = Card(CardLibrary.frostbiteFinish)
        var alone = state
        alone[seat].bag = [cards[0]]
        Check.that(!Rules.legalMoves(alone, for: seat).contains(.play(cards[0].id)),
                   "Frostbite Finish: a Move that is your whole hand can't be paid for")
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that({ if case .awaitingGiveUp(let who, _, 1) = state.phase { return who == seat }
                     return false }(),
                   "and played, it costs another card")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 234, cards: [CardLibrary.drive])
        state.courtCard = Card(CardLibrary.tickTockTile)
        let clock = state.shotClock ?? 0
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.shotClock == clock - 1, "Tick-Tock Tile: a card played ticks the clock")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 235, cards: [CardLibrary.monsterBall,
                                                                     CardLibrary.blazeBall])
        state[seat.across].intangibles = [CardLibrary.hotHand]
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state[seat.across].intangibles.isEmpty
                   && state.monsterBallIntangibles.map(\.id) == [CardLibrary.hotHand.id],
                   "Monster Ball swallows every Intangible")
        state.playedVariaballThisPossession = false
        Rules.apply(.play(cards[1].id), by: seat, to: &state)
        Check.that(state.phase == .awaitingRebound(shooter: seat), "and gone, they're rebounded for")
        Rules.resolveRebound(bids: [seat.left: [state[seat.left].bag[0].id]], state: &state)
        Check.that(state[seat.left].intangibles.contains { $0.id == CardLibrary.hotHand.id }
                   && state.phase == .possession(holder: seat),
                   "one board at a time, and play picks up again")
    }
    do {
        var slipped = false
        for seed in UInt64(236)...UInt64(276) where !slipped {
            var (state, seat, _) = openPossession(seed: seed, cards: [])
            state.ballCard = Card(CardLibrary.brandNewBall)
            var events: [GameEvent] = []
            Rules.testShot(by: seat, state: &state, events: &events)
            slipped = events.contains { if case .turnover(_, let cause) = $0 {
                                            return cause == CardLibrary.brandNewBall.name }
                                        return false }
                && !events.contains { if case .shotAttempted = $0 { return true }; return false }
        }
        Check.that(slipped, "Brand New Ball: sometimes the shot is a turnover instead")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 277, cards: [CardLibrary.primeParquet])
        state.armedWhistles = [ArmedWhistle(owner: seat.left,
                                            card: matchCard(CardLibrary.tileTampering, state.rules))]
        let turnovers = state[seat].turnovers
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.courtCard == nil && state[seat].turnovers == turnovers + 1,
                   "Tile Tampering: a Varena played is cancelled, TOV +1")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 278, cards: [CardLibrary.lacktop,
                                                                     CardLibrary.primeParquet])
        state[seat].intangibles = [CardLibrary.varsitile]
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(Rules.legalMoves(state, for: seat).contains(.play(cards[1].id)),
                   "Varsitile: more than one Varena a turn")
        let buried = matchCard(CardLibrary.kiddieCourt, state.rules)
        state.discard.append(buried)
        Rules.apply(.exchangeSlots(court: buried.id, ball: nil), by: seat, to: &state)
        Check.that(state.courtCard?.id == buried.id
                   && Rules.exchangeOptions(state, for: seat).courts.isEmpty,
                   "and once a possession, a floor out of the discards")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 279, cards: [CardLibrary.blazeBall])
        state[seat].intangibles = [CardLibrary.brawlHandler, CardLibrary.baller]
        state[seat].clamps = [ActiveClamp(card: CardLibrary.contest, from: seat.left)]
        let before = state[seat].bag.count
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state[seat].clamps.isEmpty, "Brawl Handler: changing the ball takes your Clamps off")
        Check.that(state[seat].bag.count == before, "Baller: and draws you a card")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 280, cards: [CardLibrary.bagnBall])
        state[seat].intangibles = []
        let before = state[seat].bag.count
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state[seat].bag.count == before, "Bag'n Ball: draw 1 when it arrives")
        Check.that(state.shotModifiers(for: seat).override?.amount
                   == Double(min(100, state[seat].bag.count * 10)),
                   "and SHOT is 10% a card in hand")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 281, cards: [CardLibrary.swingLeft])
        state.ballCard = Card(CardLibrary.snowBall)
        state.shot = 50
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        // **Instead of the pass, not on top of it**: passing it is a straight loss, or the
        // ball breaks even for ever and never snowballs.
        Check.that(state.shot == 40, "Snow Ball: a pass is SHOT -10% and nothing else")
    }
    do {
        // **A feed worth more than the toll.** Hand-Off off a Dribble is ten printed and
        // ten for the combo; none of it lands, or the ball breaks even at twenty and the
        // thing never snowballs.
        var (state, seat, cards) = openPossession(seed: 291, cards: [CardLibrary.handOff])
        state.ballCard = Card(CardLibrary.snowBall)
        state.lastPlayThisPossession = CardLibrary.dribble.id
        state.shot = 50
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        if case .awaitingTarget(_, _, let choices) = state.phase, let pick = choices.first {
            _ = Rules.resolveTarget(pick, state: &state)
        }
        Check.that(state.shot == 40, "and a pass worth more than the toll is still -10%")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 282, cards: [CardLibrary.swingLeft])
        state.courtCard = Card(CardLibrary.mvpiquia)
        state[seat.left].points = 10
        state[seat.left].bag = []
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(state[seat.left].bag.count == state.rules.startingBagSize,
                   "MVPiquia: the leader refills to a full hand")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 283, cards: [CardLibrary.swingLeft])
        state.ballCard = Card(CardLibrary.shufflebagBall)
        let before = state[seat.left].bag.count
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(state[seat.left].bag.count == before + 1,
                   "Shufflebag Ball: the hand comes back out, then the draw for turn")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 284, cards: [CardLibrary.swingLeft])
        state.courtCard = Card(CardLibrary.variaballVinyl)
        let total = Seat.allCases.reduce(0) { $0 + state[$1].bag.count } - 1
        _ = playDeclining(.play(cards[0].id), by: seat, &state)
        Check.that(Seat.allCases.reduce(0) { $0 + state[$1].bag.count } == total + 1,
                   "Variaball Vinyl: the draw for turn goes to somebody")
    }
}

/// **A read-out, not a test**: how often the house puts each floor and ball down across a
/// run of Standard games, what the new events came to, and whether anything stalled.
func slotCoverage() {
    var played: [String: Int] = [:]
    var seen: [String: Int] = [:]
    var stalls = 0
    for seed in UInt64(1)...UInt64(200) {
        var state = Rules.newGame(seed: seed, rules: .standard).0
        var ai = AITable(seed: seed)
        var guardCounter = 0
        while !state.isOver && guardCounter < 20000 {
            guardCounter += 1
            var events: [GameEvent] = []
            if case .freeThrows = state.phase { stepFreeThrows(&state); continue }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for other in Seat.allCases { bids[other] = ai.reboundBid(state, for: other) }
                events = Rules.resolveRebound(bids: bids, state: &state)
            } else if Prompts.step(&state, &ai) {
                continue
            } else {
                guard let seat = state.phase.actingSeat, let move = ai.move(state, for: seat) else {
                    stalls += 1
                    print("  stalled seed \(seed) at \(state.phase.label)")
                    break
                }
                events = Rules.apply(move, by: seat, to: &state)
            }
            for event in events {
                if case .movePlayed(_, let card, _) = event, card.varena != nil || card.variaball != nil {
                    played[card.name, default: 0] += 1
                }
                seen[event.kind, default: 0] += 1
            }
        }
        if guardCounter >= 20000 { stalls += 1; print("  ran long seed \(seed)") }
    }
    let every = CardLibrary.varenas + CardLibrary.variaballs
    print("played across 200 Standard games:")
    for card in every { print("  \(played[card.name] ?? 0)\t\(card.name)") }
    let kinds = ["ballChanged", "graveyardEmpty", "benched", "handsRotated", "clampHandedOff",
                 "intangibleAbsorbed", "intangibleWon", "floorWiped", "injuriesMoved"]
    print("events: " + kinds.map { "\($0) \(seen[$0] ?? 0)" }.joined(separator: " · "))
    print("stalls: \(stalls)")
}

/// Kick-Out out of a Contest, with Southpaw Shooter on either end. Prints each shot's stack.
func probeSouthpaw() {
    for southpawOnPasser in [true, false] {
        var (state, seat, cards) = openPossession(seed: 301, cards: [CardLibrary.kickOut])
        for other in Seat.allCases {
            state[other].intangibles = []
            state[other].clamps = []
            state[other].bag.removeAll { $0.descriptor.clearsOut || $0.descriptor.clearsClamps }
        }
        state.shot = 55
        state[seat].clamps = [ActiveClamp(card: CardLibrary.contest, from: seat.right)]
        var events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        guard case .awaitingTarget(_, _, let choices) = state.phase,
              let receiver = choices.first(where: { $0 != seat }) else { print("no target"); continue }
        state[southpawOnPasser ? seat : receiver].intangibles = [CardLibrary.southpawShooter]
        events += Rules.resolveTarget(receiver, state: &state)
        for case .shotAttempted(_, let chance, let breakdown) in events {
            let stack = breakdown.steps.map { "\($0.label) → \($0.total)%" }.joined(separator: " · ")
            print("Southpaw on \(southpawOnPasser ? "passer" : "receiver"): SHOT 55 → shot at \(chance)%  [\(breakdown.base)% · \(stack)]")
        }
    }
}

func alleyOopTests() {
    print("Alley-Oop")
    do {
        var (state, seat, cards) = openPossession(seed: 310, cards: [CardLibrary.lob])
        state.shot = 30
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        guard case .awaitingTarget(_, _, let choices) = state.phase,
              let receiver = choices.first(where: { $0 != seat }) else {
            Check.that(false, "a Lob asks who it goes to")
            return
        }
        let dunk = matchCard(CardLibrary.slamDunk, state.rules)
        state[receiver].bag.append(dunk)
        for other in Seat.allCases {
            state[other].intangibles = []
            state[other].bag.removeAll { $0.descriptor.clearsOut || $0.descriptor.clearsClamps }
        }
        Rules.resolveTarget(receiver, state: &state)
        Check.that({ if case .awaitingCounter(let who, let offered) = state.phase {
                         return who == receiver && offered.contains { $0.id == dunk.id } }
                     return false }(),
                   "a Lob caught with a dunk in hand asks \"Dunk It?\"")
        let before = state.shot
        let events = Rules.resolveCounter(dunk.id, state: &state)
        Check.that(events.contains { event in
            guard case .comboLanded(let who, _, let opener, let bonus) = event else { return false }
            return who == receiver && opener == CardLibrary.lob.id && bonus == 10
        }, "and dunking it is the Alley-Oop combo, SHOT +10%")
        let chance = events.compactMap { event -> Int? in
            if case .shotAttempted(_, let chance, _) = event { return chance }
            return nil
        }.first
        let priced = before + CardLibrary.slamDunk.baseShotDelta + 10
        Check.that(chance == (priced >= 75 ? 100 : priced), "priced as the dunk plus the combo")
    }
    do {
        let lobbed = CardLibrary.standardPool.contains { $0.id == "alley-oop" }
        Check.that(!lobbed && Combo.all.contains { $0.name == "Alley-Oop" },
                   "Alley-Oop is a combo now, not a card")
    }
}

/// One soak game, with the last stretch of phases and events printed — for a seed that ran long.
func probeSeed(_ seed: UInt64) {
    var state = Rules.newGame(seed: seed, rules: .standard).0
    var ai = AITable(seed: seed)
    var trail: [String] = []
    var steps = 0
    while !state.isOver && steps < 20000 {
        steps += 1
        let before = state.phase.label
        var events: [GameEvent] = []
        if case .freeThrows = state.phase {
            events = stepFreeThrows(&state)
        } else if case .awaitingRebound = state.phase {
            var bids: [Seat: [Card.ID]] = [:]
            for other in Seat.allCases { bids[other] = ai.reboundBid(state, for: other) }
            events = Rules.resolveRebound(bids: bids, state: &state)
        } else if Prompts.step(&state, &ai) {
            trail.append("\(before) → prompt → \(state.phase.label)")
            continue
        } else if let seat = state.phase.actingSeat, let move = ai.move(state, for: seat) {
            events = Rules.apply(move, by: seat, to: &state)
            trail.append("\(before) \(seat.name) \(move) → \(state.phase.label)  [\(events.map(\.kind).joined(separator: " "))]")
            continue
        } else {
            trail.append("NO MOVE at \(before)")
            break
        }
        trail.append("\(before) → \(state.phase.label)  [\(events.map(\.kind).joined(separator: " "))]")
    }
    print("seed \(seed): \(steps) steps, over: \(state.isOver), round \(state.round), clock \(String(describing: state.shotClock)), court \(state.currentCourt.name), ball \(state.currentBall?.name ?? "regulation")")
    for line in trail.suffix(24) { print("  " + line) }
}
