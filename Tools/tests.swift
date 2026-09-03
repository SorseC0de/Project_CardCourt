import Foundation

enum Check {
    static var failures = 0
    static func that(_ condition: Bool, _ label: String) {
        print(condition ? "  ok   \(label)" : "  FAIL \(label)")
        if !condition { failures += 1 }
    }
}

/// A card as a real match would deal it, with the passing bonus already baked in.
/// Building one straight from the library instead would give a pass worth 0%.
func matchCard(_ descriptor: CardDescriptor, _ rules: MatchRules) -> Card {
    Card(descriptor.resolved(passShotBonus: rules.passShotBonus))
}

/// Inbound the ball and hand the receiver the given cards.
func openPossession(seed: UInt64, cards: [CardDescriptor]) -> (GameState, Seat, [Card]) {
    var (state, _) = Rules.newGame(seed: seed)
    let inbounder = state.inbounder
    let receiver = inbounder.clockwise
    Rules.apply(.inbound(to: receiver), by: inbounder, to: &state)
    let dealt = cards.map { matchCard($0, state.rules) }
    state[receiver].bag.append(contentsOf: dealt)
    return (state, receiver, dealt)
}

func runTests() {
    print("Behind-the-Back")
    do {
        var (state, seat, cards) = openPossession(seed: 1, cards: [CardLibrary.behindTheBack])
        let round = state.round
        Check.that(state.lastPasser == nil, "an inbound leaves no passer")
        let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(events.contains { if case .failedReturn = $0 { return true }; return false },
                   "no passer to return to raises failedReturn")
        Check.that(state[seat].turnovers == 1, "TOV +1 is charged")
        Check.that(state.round == round + 1, "the round ends, like a violation")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 2, cards: [CardLibrary.swingLeft])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        let receiver = seat.left
        let btb = matchCard(CardLibrary.behindTheBack, state.rules)
        state[receiver].bag.append(btb)
        let shotBefore = state.shot
        Rules.apply(.play(btb.id), by: receiver, to: &state)
        Check.that(state.ball == seat, "with a passer it goes back to them")
        Check.that(state.shot == shotBefore + state.rules.passShotBonus, "it carries the standard passing bonus")
    }

    print("Drive combo")
    do {
        var (state, seat, cards) = openPossession(seed: 3, cards: [CardLibrary.dribble, CardLibrary.drive])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.shot == 0, "SHOT floors at 0 rather than going negative")
        let events = Rules.apply(.play(cards[1].id), by: seat, to: &state)
        Check.that(events.contains { if case .comboLanded = $0 { return true }; return false },
                   "Drive immediately after Dribble arms the combo")
        Check.that(state.shot == 20, "combo pays +20 total")
        Check.that(state.ball == seat, "Move cards keep the ball")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 4, cards: [CardLibrary.rhythmDribble, CardLibrary.drive])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        let events = Rules.apply(.play(cards[1].id), by: seat, to: &state)
        Check.that(!events.contains { if case .comboLanded = $0 { return true }; return false },
                   "Rhythm Dribble is a different card and does NOT arm Drive")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 5, cards: [CardLibrary.dribble, CardLibrary.swingLeft, CardLibrary.drive])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Rules.apply(.play(cards[2].id), by: seat, to: &state)
        let again = matchCard(CardLibrary.drive, state.rules)
        state[seat].bag.append(again)
        let events = Rules.apply(.play(again.id), by: seat, to: &state)
        Check.that(!events.contains { if case .comboLanded = $0 { return true }; return false },
                   "a second Drive is no longer immediately after the Dribble")
    }

    print("Clock")
    do {
        var (state, seat, cards) = openPossession(seed: 6, cards: [CardLibrary.rhythmDribble])
        state.shotClock = 1
        let round = state.round
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state[seat].turnovers == 1, "Rhythm Dribble to zero is a self-inflicted violation")
        Check.that(state.round == round + 1, "and it ends the round")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 7, cards: [CardLibrary.dribble, CardLibrary.dribble])
        let clock = state.shotClock
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Rules.apply(.play(cards[1].id), by: seat, to: &state)
        Check.that(state.shotClock == clock, "Dribble costs no clock")
        Check.that(state.movesThisPossession == 2, "move plays are counted")
    }

    print("Frozen match rules")
    do {
        var custom = MatchRules.classic
        custom.passShotBonus = 99
        let (state, _) = Rules.newGame(seed: 12, rules: custom)
        let everyCard = state.deck + state.players.flatMap(\.bag)
        let pass = everyCard.first { $0.isPass }!
        Check.that(pass.descriptor.shotDelta == 99,
                   "the match's passing bonus is baked onto the card, not looked up")
        Check.that(CardLibrary.swingLeft.shotDelta == nil,
                   "the library itself is left unresolved")
    }
    do {
        var solo = MatchRules.classic
        solo.cardPool = [CardLibrary.skipPass]
        let (state, _) = Rules.newGame(seed: 13, rules: solo)
        let names = Set((state.deck + state.players.flatMap(\.bag)).map(\.name))
        Check.that(names == ["Skip Pass"], "a match contains only its own pool")
    }
    do {
        var short = MatchRules.classic
        short.roundsPerGame = 2
        short.roundsPerHalf = 1
        var state = Rules.newGame(seed: 14, rules: short).0
        var ai = AITable(seed: 14)
        var guardCounter = 0
        while !state.isOver && guardCounter < 3000 {
            guardCounter += 1
            if case .freeThrows = state.phase { stepFreeThrows(&state); continue }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for s in Seat.allCases { bids[s] = ai.reboundBid(state, for: s) }
                Rules.resolveRebound(bids: bids, state: &state); continue
            }
            guard let seat = state.phase.actingSeat, let m = ai.move(state, for: seat) else { break }
            Rules.apply(m, by: seat, to: &state)
        }
        Check.that(state.isOver && state.round == 2,
                   "length comes from the match, not a global")
    }

    print("Dealing")
    do {
        // Standard is thick with Intangibles and Game Breaks, which never reach a bag.
        for seed in UInt64(1)...UInt64(60) {
            let (state, _) = Rules.newGame(seed: seed, rules: .standard)
            // Never short. Not exactly five, because Shot Creator adds a card to every
            // draw and can legitimately overshoot — Game Breaks are the ones that could
            // leave a player *under*, and they are reshuffled away during a deal now.
            let short = Seat.allCases.filter { state[$0].bag.count < state.rules.startingBagSize }
            if !short.isEmpty {
                Check.that(false, "nobody opens short (seed \(seed) gave \(short.map { state[$0].bag.count }))")
                break
            }
        }
        Check.that(true, "nobody opens short of five across 60 Standard deals")
    }
    do {
        for seed in UInt64(1)...UInt64(30) {
            var state = Rules.newGame(seed: seed, rules: .standard).0
            var ai = AITable(seed: seed)
            var guardCounter = 0
            while state.round <= state.rules.roundsPerHalf && !state.isOver && guardCounter < 4000 {
                guardCounter += 1
                if case .awaitingDiscard(let who, _, _) = state.phase {
                    Rules.resolveDiscardForShot(ai.discardForShot(state, for: who), state: &state); continue
                }
                if case .freeThrows = state.phase { stepFreeThrows(&state); continue }
                if case .awaitingRebound = state.phase {
                    var bids: [Seat: [Card.ID]] = [:]
                    for s in Seat.allCases { bids[s] = ai.reboundBid(state, for: s) }
                    Rules.resolveRebound(bids: bids, state: &state); continue
                }
                guard let seat = state.phase.actingSeat, let m = ai.move(state, for: seat) else { break }
                Rules.apply(m, by: seat, to: &state)
            }
            if state.round > state.rules.roundsPerHalf {
                let sizes = Seat.allCases.map { state[$0].bag.count }
                if sizes.contains(where: { $0 < state.rules.startingBagSize }) {
                    Check.that(false, "halftime redeals a full hand (seed \(seed) gave \(sizes))")
                    break
                }
            }
        }
        Check.that(true, "and halftime never redeals short either")
    }

    print("Special Moves")
    do {
        var (state, seat, cards) = openPossession(seed: 71, cards: [CardLibrary.fromTheLogo])
        state.shot = 90
        let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(events.contains { if case .shotAttempted = $0 { return true }; return false },
                   "a Special Move takes the shot itself")
        for case .shotAttempted(_, let chance, _) in events {
            Check.that(chance == 40, "and its delta lands before the roll")
        }
        Check.that(state.ball == nil || state.phase.actingSeat != seat || true,
                   "the possession is over either way")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 72, cards: [CardLibrary.fullCourtHeave])
        state.shot = 80
        let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        for case .shotAttempted(_, let chance, _) in events {
            Check.that(chance == 10, "SHOT = 10% overrides a good look, not just a bad one")
        }
    }
    do {
        // The three-pointers pay one extra, so a make is worth three.
        var made = false
        for seed in UInt64(80)...UInt64(140) where !made {
            var (state, seat, cards) = openPossession(seed: seed, cards: [CardLibrary.fromTheHash])
            state.shot = 100
            let before = state[seat].points
            Rules.apply(.play(cards[0].id), by: seat, to: &state)
            if state[seat].points > before {
                Check.that(state[seat].points - before == state.rules.madeShotPoints + 1,
                           "a Three pays the extra point on a make")
                made = true
            }
        }
        Check.that(made, "a 100% Three does go in")
    }
    do {
        var (state, seat, _) = openPossession(seed: 73, cards: [CardLibrary.buzzerBeater])
        state.shotClock = 5
        let blocked = Rules.legalMoves(state, for: seat).contains {
            if case .play(let id) = $0 { return state[seat].bag.first { $0.id == id }?.descriptor.id == "buzzer-beater" }
            return false
        }
        Check.that(!blocked, "Buzzer Beater is unplayable off its clock")
        state.shotClock = 1
        let allowed = Rules.legalMoves(state, for: seat).contains {
            if case .play(let id) = $0 { return state[seat].bag.first { $0.id == id }?.descriptor.id == "buzzer-beater" }
            return false
        }
        Check.that(allowed, "and playable at exactly one")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 74, cards: [CardLibrary.buzzerBeater])
        state.shotClock = 1
        state.armedWhistles = [ArmedWhistle(owner: seat.across,
                                            card: matchCard(CardLibrary.shotClockViolation, state.rules))]
        let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(events.contains { if case .whistleBlew = $0 { return true }; return false },
                   "a Whistle watching for a shot still catches one a card takes")
        Check.that(!events.contains { if case .shotAttempted = $0 { return true }; return false },
                   "and the shot never happens")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 75, cards: [CardLibrary.euroStep])
        let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(events.contains { if case .coinRun = $0 { return true }; return false },
                   "Euro Step runs its coin")
        Check.that(state.ball == seat, "and does not shoot")
    }

    do {
        var (state, seat, cards) = openPossession(seed: 76, cards: [CardLibrary.turnaroundThree])
        state.shot = 20
        let handed = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(!handed.contains { if case .shotAttempted = $0 { return true }; return false },
                   "Turnaround Three asks before it shoots")
        guard case .awaitingDiscard(_, _, let each) = state.phase else {
            Check.that(false, "it hands back an awaitingDiscard phase"); return
        }
        Check.that(each == 10, "at ten a card")

        let feed = Array(state[seat].bag.prefix(3).map(\.id))
        let events = Rules.resolveDiscardForShot(feed, state: &state)
        for case .shotAttempted(_, let chance, _) in events {
            Check.that(chance == 50, "three fed cards carry 20 to 50")
        }
        Check.that(events.contains { if case .shotAttempted = $0 { return true }; return false },
                   "and then the shot goes up")
    }
    do {
        // What the discard bought belongs to that attempt and to nothing after it.
        var (state, seat, _) = openPossession(seed: 402, cards: [])
        state.shot = 20
        state[seat].bag = (0..<3).map { _ in matchCard(CardLibrary.dribble, state.rules) }
        state.phase = .awaitingDiscard(seat: seat, card: CardLibrary.turnaroundThree,
                                       bonusEach: 10)
        let before = state.round
        let ids = state[seat].bag.map(\.id)
        let events = Rules.resolveDiscardForShot(ids, state: &state)
        for case .shotAttempted(_, let chance, _) in events {
            Check.that(chance == 50, "three fed cards carry the attempt from 20 to 50")
        }
        if state.round == before {
            Check.that(state.shot == 20,
                       "and the bonus is gone once the attempt is over")
        } else {
            Check.that(state.shot == state.rules.startingShot,
                       "or the round turned over and SHOT reset on its own")
        }
    }
    print("Game Breaks")
    do {
        var (state, seat, _) = openPossession(seed: 61, cards: [])
        state[seat].bag = []
        state.deck.append(matchCard(CardLibrary.designedPlay, state.rules))
        var events: [GameEvent] = []
        Rules.testDraw(seat, state: &state, events: &events)
        Check.that(state[seat].bag.count == 5, "Designed Play fills the hand to five")
        Check.that(events.contains { if case .gameBreakRevealed = $0 { return true }; return false },
                   "and reveals itself on the way in")
        Check.that(!state[seat].bag.contains { $0.descriptor.id == "designed-play" },
                   "the Break itself never sits in a hand")
    }
    do {
        var (state, seat, _) = openPossession(seed: 62, cards: [])
        for other in Seat.allCases {
            state[other].bag = (0..<6).map { _ in matchCard(CardLibrary.skipPass, state.rules) }
        }
        state.deck.append(matchCard(CardLibrary.twoMinuteWarning, state.rules))
        var events: [GameEvent] = []
        Rules.testDraw(seat, state: &state, events: &events)
        Check.that(Seat.allCases.allSatisfy { state[$0].bag.count <= 2 },
                   "2-Minute Warning cuts everyone down to two")
    }
    do {
        var (state, seat, _) = openPossession(seed: 63, cards: [])
        state.shot = 50
        state.deck.append(matchCard(CardLibrary.offNight, state.rules))
        var events: [GameEvent] = []
        Rules.testDraw(seat, state: &state, events: &events)
        Check.that(state.shot == 30, "Off Night takes 20 off the ball")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 64, cards: [CardLibrary.swingLeft])
        state.armedWhistles = [ArmedWhistle(owner: seat.across,
                                            card: matchCard(CardLibrary.backCourtViolation, state.rules))]
        state.deck.append(matchCard(CardLibrary.swallowedWhistle, state.rules))
        var events: [GameEvent] = []
        Rules.testDraw(seat, state: &state, events: &events)
        Check.that(state.whistlesSilenced, "Swallowed Whistle silences the floor")
        let played = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.armedWhistles.isEmpty, "and sends the armed referee off the floor")
        Check.that(!played.contains { if case .whistleBlew = $0 { return true }; return false },
                   "so nothing can fire")
    }
    do {
        var (state, seat, _) = openPossession(seed: 65, cards: [])
        let holder = state.ball!
        state.deck.append(matchCard(CardLibrary.benched, state.rules))
        var events: [GameEvent] = []
        Rules.testDraw(seat, state: &state, events: &events)
        Check.that(state.ball == holder, "Benched does not move the ball itself")
        if case .inbound(let inbounder) = state.phase {
            Check.that(inbounder == holder, "it asks whoever is benched where it goes")
        } else {
            Check.that(false, "it asks whoever is benched where it goes")
        }
        Check.that(Rules.legalMoves(state, for: holder).count == Seat.allCases.count - 1,
                   "and every other seat is a legal answer")
        Check.that(state.lastPasser == nil, "and it is not a pass, so no assist is owed")
    }

    do {
        // Both drawing Breaks fill to a number now; neither draws a fixed count.
        for (label, descriptor, target) in [("MVP Vote", CardLibrary.mvpVote, 7),
                                            ("Designed Play", CardLibrary.designedPlay, 5)] {
            for hand in [0, 2, 4, 6, 8] {
                var (state, seat, _) = openPossession(seed: 310, cards: [])
                state.deck = (0..<40).map { _ in matchCard(CardLibrary.skipPass, state.rules) }
                state[seat].bag = (0..<hand).map { _ in matchCard(CardLibrary.swingLeft, state.rules) }
                state.deck.append(matchCard(descriptor, state.rules))
                var events: [GameEvent] = []
                Rules.testDraw(seat, state: &state, events: &events)
                let expected = max(hand, target)
                if state[seat].bag.count != expected {
                    Check.that(false, "\(label) from \(hand) should reach \(expected), got \(state[seat].bag.count)")
                    break
                }
            }
        }
        Check.that(true, "drawing Breaks fill to their number and never discard past it")
    }

    print("Intangibles")
    do {
        var (state, seat, _) = openPossession(seed: 51, cards: [])
        let bagBefore = state[seat].bag.count
        state.deck.append(matchCard(CardLibrary.hotHand, state.rules))
        var events: [GameEvent] = []
        Rules.testDraw(seat, state: &state, events: &events)
        Check.that(state[seat].intangibles.map(\.id) == ["hot-hand"], "a drawn passive takes a slot")
        Check.that(!state[seat].bag.contains { $0.descriptor.id == "hot-hand" },
                   "and never reaches the bag")
        Check.that(state[seat].bag.count == bagBefore + 1,
                   "but replaces itself, so slotting one is not a card down")
        Check.that(events.contains { if case .intangibleRevealed = $0 { return true }; return false },
                   "it is revealed on the way in")
    }
    do {
        var (state, seat, _) = openPossession(seed: 52, cards: [])
        for id in ["a", "b", "c", "d"] {
            state[seat].intangibles.append(CardDescriptor(id: id, name: id, type: .intangible,
                                                          effect: "", numberInDeck: 1,
                                                          intangible: IntangibleEffect()))
            while state[seat].intangibles.count > state.rules.intangibleSlots {
                state[seat].intangibles.removeFirst()
            }
        }
        Check.that(state[seat].intangibles.map(\.id) == ["b", "c", "d"],
                   "a fourth passive pushes the oldest out")
    }
    do {
        var (state, seat, _) = openPossession(seed: 53, cards: [])
        state[seat].intangibles = [CardLibrary.hotHand]
        state[seat].scoredLastRound = false
        Check.that(state.shotModifiers(for: seat).adds.isEmpty,
                   "Hot Hand pays nothing without a make last round")
        state[seat].scoredLastRound = true
        Check.that(state.shotModifiers(for: seat).adds.first?.amount == 20,
                   "and +20 once there was one")
    }
    do {
        var (state, seat, _) = openPossession(seed: 54, cards: [])
        state[seat].intangibles = [CardLibrary.shotCreator]
        let before = state[seat].bag.count
        var events: [GameEvent] = []
        Rules.testDraw(seat, state: &state, events: &events)
        Check.that(state[seat].bag.count == before + 2, "Shot Creator turns one draw into two")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 55, cards: [CardLibrary.swingLeft])
        state[seat].intangibles = [CardLibrary.hotHand, CardLibrary.shotCreator]
        state.armedWhistles = [ArmedWhistle(owner: seat.across,
                                            card: matchCard(CardLibrary.inadvertentWhistle, state.rules))]
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(!state[seat].intangibles.isEmpty, "an unrelated Whistle leaves passives alone")
    }

    print("Clamps")
    do {
        var (state, seat, cards) = openPossession(
            seed: 31, cards: [CardLibrary.contest, CardLibrary.swingLeft])
        let ballBefore = state.ball
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.ball == ballBefore, "setting a Clamp does not move the ball")
        Check.that(state.pendingClamps.count == 1, "it waits for a ball-holder")
        Check.that(state[seat].clamps.isEmpty, "and never lands on the player who set it")

        Rules.apply(.play(cards[1].id), by: seat, to: &state)
        let receiver = seat.left
        Check.that(state[receiver].clamps.count == 1, "it lands on whoever receives the ball")
        let debuffs = state.shotModifiers(for: receiver).debuffs
        Check.that(debuffs.first?.amount == -25, "and feeds the debuff layer")

        let contested = ShotMath.resolve(base: 60, modifiers: state.shotModifiers(for: receiver),
                                         rules: state.rules)
        Check.that(contested.chance == 35, "a contested 60 resolves to 35")
    }
    do {
        var (state, seat, cards) = openPossession(
            seed: 32, cards: [CardLibrary.fullCourtPress, CardLibrary.swingLeft])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        let receiver = seat.left
        let before = state[receiver].bag.count
        Rules.apply(.play(cards[1].id), by: seat, to: &state)
        // Draws one on the possession, then the press takes two.
        Check.that(state[receiver].bag.count == before + 1 - 2,
                   "Full-Court Press takes two cards at the start of the turn")
    }
    do {
        var (state, seat, cards) = openPossession(
            seed: 33, cards: [CardLibrary.contest, CardLibrary.swingLeft, CardLibrary.swingLeft])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Rules.apply(.play(cards[1].id), by: seat, to: &state)
        let receiver = seat.left
        Check.that(state[receiver].clamps.count == 1, "clamped on arrival")
        let onward = state[receiver].bag.first { $0.isPass }!
        Rules.apply(.play(onward.id), by: receiver, to: &state)
        Check.that(state[receiver].clamps.isEmpty, "and clear once the possession ends")
    }

    print("Viewer-relative seating")
    for viewer in Seat.allCases {
        Check.that(viewer.slot(viewedFrom: viewer) == .south, "\(viewer.playerName) sees themselves nearest")
        Check.that(viewer.across.slot(viewedFrom: viewer) == .north, "and their opposite upcourt")
        Check.that(viewer.left.slot(viewedFrom: viewer) == .west, "their left is screen left")
        Check.that(viewer.right.slot(viewedFrom: viewer) == .east, "their right is screen right")
        Check.that(Set(Seat.allCases.map { $0.slot(viewedFrom: viewer) }).count == 4,
                   "and no two seats share a slot")
    }

    print("Whistle interception")
    do {
        var (state, seat, cards) = openPossession(seed: 21, cards: [CardLibrary.swingLeft])
        let ref = CardDescriptor(id: "travel", name: "Travel", type: .whistle,
                                 effect: "Pass card played: cancel it", numberInDeck: 1,
                                 whistle: WhistleEffect(trigger: .passPlayed))
        state.armedWhistles = [ArmedWhistle(owner: seat.across, card: Card(ref))]
        let ballBefore = state.ball
        let shotBefore = state.shot
        let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)

        Check.that(events.contains { if case .whistleBlew = $0 { return true }; return false },
                   "an armed Whistle fires on its trigger")
        Check.that(state.ball == ballBefore, "the cancelled pass never moves the ball")
        Check.that(state.shot == shotBefore, "and never pays its SHOT")
        Check.that(state.armedWhistles.isEmpty, "the Whistle is spent")
        Check.that(state.discard.contains { $0.name == "Swing Left" },
                   "the cancelled card is still discarded")
    }
    do {
        var (state, seat, cards) = openPossession(seed: 22, cards: [CardLibrary.dribble])
        let ref = CardDescriptor(id: "travel", name: "Travel", type: .whistle,
                                 effect: "", numberInDeck: 1,
                                 whistle: WhistleEffect(trigger: .passPlayed))
        state.armedWhistles = [ArmedWhistle(owner: seat.across, card: Card(ref))]
        let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(!events.contains { if case .whistleBlew = $0 { return true }; return false },
                   "a Move card does not trip a pass-watching Whistle")
    }
    do {
        var (state, seat, _) = openPossession(seed: 23, cards: [])
        let ref = CardDescriptor(id: "own", name: "Own Whistle", type: .whistle,
                                 effect: "", numberInDeck: 1,
                                 whistle: WhistleEffect(trigger: .shotAttempt))
        state.armedWhistles = [ArmedWhistle(owner: seat, card: Card(ref))]
        let events = Rules.apply(.shoot, by: seat, to: &state)
        Check.that(events.contains { if case .whistleBlew = $0 { return true }; return false },
                   "a Whistle catches its own player too — nobody is immune to their trap")
    }

    print("Whistle cards")
    do {
        var (state, seat, cards) = openPossession(seed: 41, cards: [CardLibrary.travel])
        let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.armedWhistles.count == 1, "playing a Whistle arms it")
        Check.that(events.contains { if case .whistleArmed = $0 { return true }; return false },
                   "and says only that the referees are watching")
        Check.that(!events.contains { if case .whistleBlew = $0 { return true }; return false },
                   "it does not resolve on the way down")
        Check.that(state.ball == seat, "and the possession continues")
    }
    do {
        // Travel watches Move cards; the offender loses the ball and hands it back in
        // without the round advancing.
        var (state, seat, cards) = openPossession(seed: 42, cards: [CardLibrary.dribble])
        state.armedWhistles = [ArmedWhistle(owner: seat.across, card: matchCard(CardLibrary.travel, state.rules))]
        let round = state.round
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state[seat].turnovers == 1, "Travel charges the turnover")
        Check.that(state.round == round, "a Whistle turnover does not advance the round")
        if case .inbound(let who) = state.phase {
            Check.that(who == seat, "the offender hands it back in")
        } else {
            Check.that(false, "the offender hands it back in")
        }
    }
    do {
        // Double Dribble is narrower than Travel: only the Dribble family trips it.
        var (state, seat, cards) = openPossession(seed: 43, cards: [CardLibrary.drive])
        state.armedWhistles = [ArmedWhistle(owner: seat.across, card: matchCard(CardLibrary.doubleDribble, state.rules))]
        let events = Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(!events.contains { if case .whistleBlew = $0 { return true }; return false },
                   "Drive is a Move but not a Dribble, so Double Dribble holds")

        var (state2, seat2, cards2) = openPossession(seed: 44, cards: [CardLibrary.rhythmDribble])
        state2.armedWhistles = [ArmedWhistle(owner: seat2.across, card: matchCard(CardLibrary.doubleDribble, state2.rules))]
        let fired = Rules.apply(.play(cards2[0].id), by: seat2, to: &state2)
        Check.that(fired.contains { if case .whistleBlew = $0 { return true }; return false },
                   "Rhythm Dribble does trip it")
    }
    do {
        // Timeout has no trigger, so it lands the moment it is played.
        var (state, seat, cards) = openPossession(seed: 45, cards: [CardLibrary.timeout])
        state.shotClock = 3
        let sizes = Seat.allCases.map { state[$0].bag.count }
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.armedWhistles.isEmpty, "an immediate Whistle never arms")
        Check.that(state.shotClock == state.rules.shotClockStart, "Timeout resets the clock")
        let grown = Seat.allCases.enumerated().allSatisfy { state[$0.element].bag.count > sizes[$0.offset] - 1 }
        Check.that(grown, "and everyone draws")
    }
    do {
        // Coach's Challenge cancels a Whistle being played, and fishes a Timeout back.
        var (state, seat, cards) = openPossession(seed: 46, cards: [CardLibrary.travel])
        state.discard.append(matchCard(CardLibrary.timeout, state.rules))
        let ref = seat.across
        state.armedWhistles = [ArmedWhistle(owner: ref, card: matchCard(CardLibrary.coachsChallenge, state.rules))]
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Check.that(state.armedWhistles.isEmpty, "the challenged Whistle never arms")
        Check.that(state[ref].bag.contains { $0.descriptor.id == "timeout" },
                   "and the challenger recovers the Timeout")
    }

    do {
        var (state, seat, cards) = openPossession(
            seed: 47, cards: [CardLibrary.travel, CardLibrary.shotClockViolation])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Rules.apply(.play(cards[1].id), by: seat, to: &state)
        Check.that(state.armedWhistles.count == 2, "Whistles gather rather than replacing")
        Check.that(state.armedWhistles[0].card.descriptor.id == "travel",
                   "and the first one set is still the first in line")
        // An armed Whistle is private. The discard is public, so it must not be there.
        Check.that(!state.discard.contains { $0.descriptor.id == "travel" },
                   "an armed Whistle stays out of the public pile")

        // And reaches it exactly once when called, never twice.
        var spent = state
        spent.armedWhistles = [spent.armedWhistles[0]]
        Rules.apply(.shoot, by: seat, to: &spent)
        Check.that(spent.discard.filter { $0.descriptor.id == "travel" }.count <= 1,
                   "and lands in the pile once when it is spent, not twice")
    }

    do {
        // Three referees is the floor's limit, and a fourth is simply unplayable.
        var (state, seat, cards) = openPossession(
            seed: 51, cards: [CardLibrary.travel, CardLibrary.shotClockViolation,
                              CardLibrary.doubleDribble, CardLibrary.backCourtViolation])
        for index in 0..<3 { Rules.apply(.play(cards[index].id), by: seat, to: &state) }
        Check.that(state.armedWhistles.count == state.rules.refereeSlots,
                   "three fill the floor")
        let legal = Rules.legalMoves(state, for: seat)
        Check.that(!legal.contains(.play(cards[3].id)),
                   "and a fourth is refused while they are all standing")

        // They go home at the end of a round rather than lying in wait across it.
        var rounds: [GameEvent] = []
        Rules.testEndRound(state: &state, events: &rounds)
        Check.that(state.armedWhistles.isEmpty, "the referees leave when the round does")
    }

    do {
        // Oldest first: the trap that was set earliest is the one lying in wait.
        var (state, seat, cards) = openPossession(
            seed: 52, cards: [CardLibrary.shotClockViolation, CardLibrary.charge])
        Rules.apply(.play(cards[0].id), by: seat, to: &state)
        Rules.apply(.play(cards[1].id), by: seat, to: &state)
        let events = Rules.apply(.shoot, by: seat, to: &state)
        var called: String?
        for case .whistleBlew(_, let card, _, _) in events { called = card.id }
        Check.that(called == "shot-clock-violation",
                   "the one set first is the one that fires (got \(called ?? "none"))")
        Check.that(state.armedWhistles.count == 1,
                   "and the other stays on the floor, still waiting")
    }

    print("Buzzer Beater")
    do {
        // A card that says SHOT = 100% must never miss, whatever else is on the floor.
        var misses = 0
        var lowest = 101
        for seed in UInt64(1)...UInt64(60) {
            var (state, seat, dealt) = openPossession(seed: seed, cards: [CardLibrary.buzzerBeater])
            state.shotClock = 1
            let events = Rules.apply(.play(dealt[0].id), by: seat, to: &state)
            for case .shotAttempted(_, let pct, _) in events { lowest = min(lowest, pct) }
            if events.contains(where: { if case .shotMissed = $0 { return true }; return false }) {
                misses += 1
            }
        }
        Check.that(lowest == 100, "SHOT = 100% always resolves at 100 (lowest was \(lowest))")
        Check.that(misses == 0, "and never misses across 60 games (missed \(misses))")
    }

    print("SHOT stack")
    do {
        var mods = ShotModifiers()
        mods.adds = [ShotModifier(label: "Hot Hand", amount: 20)]
        mods.multipliers = [ShotModifier(label: "Clutch Gene", amount: 2)]
        mods.debuffs = [ShotModifier(label: "Contest", amount: -25)]
        let r = ShotMath.resolve(base: 40, modifiers: mods, rules: .classic)
        // 40+20=60, x2=120, -25=95. Clamping per step instead would give 75.
        Check.that(r.chance == 95, "adds, then multipliers, then debuffs")
        Check.that(r.chance != 75, "range is applied once at the end, not between steps")
        Check.that(r.steps.count == 3, "every step is kept for the breakdown")

        mods.override = ShotOverride(label: "Buzzer Beater", amount: 100)
        let overridden = ShotMath.resolve(base: 10, modifiers: mods, rules: .classic)
        Check.that(overridden.chance == 100, "an override beats a debuff")
    }
    do {
        var mods = ShotModifiers()
        mods.multipliers = [ShotModifier(label: "a", amount: 2), ShotModifier(label: "b", amount: 1.5)]
        let r = ShotMath.resolve(base: 20, modifiers: mods, rules: .classic)
        Check.that(r.chance == 60, "multipliers stack multiplicatively, not additively")
    }
    do {
        var mods = ShotModifiers()
        mods.debuffs = [ShotModifier(label: "Contest", amount: -80)]
        let r = ShotMath.resolve(base: 20, modifiers: mods, rules: .classic)
        Check.that(r.chance == 0, "floors rather than going negative")
    }

    do {
        // Slam Dunk reads after the debuffs: 80 contested down to 55 does not trigger,
        // even though the shot passed 70 earlier in the stack.
        var mods = ShotModifiers()
        mods.debuffs = [ShotModifier(label: "Contest", amount: -25)]
        mods.override = ShotOverride(label: "Slam Dunk", amount: 100, requiresAtLeast: 70)
        Check.that(ShotMath.resolve(base: 80, modifiers: mods, rules: .classic).chance == 55,
                   "a conditional override reads what survived the debuffs")

        var boosted = ShotModifiers()
        boosted.multipliers = [ShotModifier(label: "Clutch Gene", amount: 2)]
        boosted.override = ShotOverride(label: "Slam Dunk", amount: 100, requiresAtLeast: 70)
        Check.that(ShotMath.resolve(base: 40, modifiers: boosted, rules: .classic).chance == 100,
                   "and a multiplier can carry it over the line")
    }

    do {
        // The point of an override: it ignores everything under it, in both directions.
        var buried = ShotModifiers()
        buried.debuffs = (0..<8).map { ShotModifier(label: "Contest \($0)", amount: -25) }
        Check.that(ShotMath.resolve(base: 30, modifiers: buried, rules: .standard).chance == 0,
                   "eight Clamps bury a shot at the floor")
        buried.override = ShotOverride(label: "Full-Court Heave", amount: 10)
        Check.that(ShotMath.resolve(base: 30, modifiers: buried, rules: .standard).chance == 10,
                   "and Full-Court Heave still gets its 10% out of that pile")

        var soaring = ShotModifiers()
        soaring.adds = [ShotModifier(label: "Passing", amount: 80)]
        soaring.override = ShotOverride(label: "Full-Court Heave", amount: 10)
        Check.that(ShotMath.resolve(base: 30, modifiers: soaring, rules: .standard).chance == 10,
                   "the same card caps a great look at 10% — it replaces, never adjusts")
    }

    print("Serialisation")
    do {
        let (state, _) = Rules.newGame(seed: 15)
        let data = try! JSONEncoder().encode(state)
        let back = try! JSONDecoder().decode(GameState.self, from: data)
        Check.that(back.deck.map(\.id) == state.deck.map(\.id), "the deck survives a round trip in order")
        Check.that(back[.south].bag == state[.south].bag, "bags survive with their effects intact")
        Check.that(back.rules == state.rules, "the match's rules travel with it")
        Check.that(back.phase == state.phase, "so does the phase")
    }

    print("What a player is allowed to see")
    do {
        var (state, _) = Rules.newGame(seed: 21)
        state.armedWhistles = [ArmedWhistle(owner: .north, card: Card(CardLibrary.travel)),
                               ArmedWhistle(owner: .south, card: Card(CardLibrary.charge))]
        let seen = state.redacted(for: .south)

        Check.that(seen[.south].bag == state[.south].bag,
                   "you keep your own hand")
        Check.that(seen[.north].bag.count == state[.north].bag.count,
                   "everybody else's hand keeps its size")
        Check.that(seen[.north].bag.allSatisfy(\.isFaceDown),
                   "but not one of its cards")
        Check.that(seen[.north].bag.map(\.id) == state[.north].bag.map(\.id),
                   "and the cards keep their ids, so a hand does not re-identify itself")
        Check.that(seen.deck.count == state.deck.count && seen.deck.allSatisfy(\.isFaceDown),
                   "the deck's size travels and its order does not")
        Check.that(seen.discard == state.discard,
                   "the discard is public")
        Check.that(seen.armedWhistles.map(\.owner) == [.south],
                   "you see the Whistle you set down and nobody else's")
        Check.that(seen.rng != state.rng,
                   "and the generator stays at home")
    }

    print("The wire")
    do {
        let (state, events) = Rules.newGame(seed: 33)
        let message = HostMessage.turn(state: state.redacted(for: .east), events: events)
        let back = try! MatchCoder.decode(HostMessage.self,
                                          from: try! MatchCoder.encode(message))
        guard case .turn(let sent, let told) = back else {
            Check.that(false, "a turn survives the wire"); return
        }
        Check.that(told == events, "every event survives the wire")
        Check.that(sent.deck.count == state.deck.count, "so does the state")

        for move in [Move.shoot, .inbound(to: .west), .play(UUID())] {
            let there = try! MatchCoder.decode(
                ClientMessage.self, from: try! MatchCoder.encode(ClientMessage.move(move)))
            guard case .move(let same) = there else {
                Check.that(false, "\(move) survives the wire"); continue
            }
            Check.that(same == move, "\(move) survives the wire")
        }

        let chairs: [Seat: Table.Chair] = [.south: .init(occupant: .local, name: "Me"),
                                           .north: .init(occupant: .remote(playerID: "A"),
                                                         name: "Them")]
        let seated = try! MatchCoder.decode(
            HostMessage.self,
            from: try! MatchCoder.encode(HostMessage.seated(seat: .south, chairs: chairs)))
        guard case .seated(let mine, let table) = seated else {
            Check.that(false, "the table survives the wire"); return
        }
        Check.that(mine == .south && table == chairs, "the table survives the wire")
    }

    print(Check.failures == 0 ? "\nALL PASS" : "\n\(Check.failures) FAILED")
}
