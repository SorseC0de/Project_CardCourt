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
        // **Both decks are shuffled at the start of the game.** The crew deck is dealt from
        // at the top of every round and never mixes with the main pile.
        state.officials = state.shuffled(CardLibrary.buildDeck(pool: rules.officialsPool,
                                                               passShotBonus: rules.passShotBonus))
        var events: [GameEvent] = []
        deal(to: Seat.allCases, count: rules.startingBagSize, state: &state, events: &events)

        // Positions come off the same shuffle as everything else, so every device at the
        // table agrees about who finishes at the rim. The local seat's own is written over
        // this by whoever owns the kit — see `GameController.begin`.
        for seat in Seat.allCases {
            state[seat].position = Position.allCases[state.roll(0...(Position.allCases.count - 1))]
        }
        state.inbounder = GameRules.debugFirstInbounder ?? state.pick(from: Seat.allCases)
        state.round = 1

        events.append(.gameBegan(firstInbounder: state.inbounder))
        beginRound(state: &state, events: &events)
        return (state, events)
    }

    // MARK: - Legality

    /// What a card is worth against the Shot Clock as it reads right now.
    ///
    /// Only Dagger Three uses it: SHOT −10% for every tick still on the clock, on top of its
    /// own +60%, so at 01 it is the best shot on the table.
    static func clockBonus(_ special: SpecialMoveEffect?, in state: GameState) -> Int {
        guard let special, special.shotPerClockTick != 0 else { return 0 }
        let clock = state.shotClock ?? state.shotClockLength
        return max(0, clock) * special.shotPerClockTick
    }

    static func legalMoves(_ state: GameState, for seat: Seat) -> [Move] {
        switch state.phase {
        case .inbound(let inbounder) where inbounder == seat:
            return Seat.allCases.filter { $0 != seat && $0 != state.inboundBarred }
                .map { Move.inbound(to: $0) }
        case .awaitingGiveUp, .awaitingMode, .awaitingCardFrom,
             .awaitingInjuryPick, .awaitingIntangibleDrop, .awaitingToll, .awaitingOption:
            return []
        case .awaitingNaming(let asked, _, let named) where asked == seat:
            return Seat.allCases
                .filter { $0 != state.ball && !named.contains($0) }
                .map { Move.inbound(to: $0) }
        case .awaitingTarget(let asked, _, let choices) where asked == seat:
            return choices.map { Move.inbound(to: $0) }
        case .possession(let holder) where holder == seat:
            // A Clamp can hold cards down or allow nothing but passes. Both last the
            // possession, and both are read here rather than refused on play — a card you
            // cannot use should look like one.
            var held = Set(state[seat].clamps.flatMap(\.locked))
            // Torn Achilles is the other way round: everything is held *except* what the
            // roll left, so a card added mid-turn is held too.
            if handIsLocked(state, for: seat) {
                let free = Set(state[seat].injuryUnlocked)
                held.formUnion(state[seat].bag.map(\.id).filter { !free.contains($0) })
            }
            // Foot Ball: what was played this possession is still in the hand, locked.
            held.formUnion(state.footLocked)
            let floor = state.floorEffect
            let slotsFreely = has(seat, in: state, { $0.playsSlotsFreely })
            let passOnly = state[seat].clamps.contains { $0.card.clamp?.passOnly == true }
            let movesOnly = state[seat].clamps.contains { $0.card.clamp?.movesOnly == true }
            let shootOnly = state[seat].clamps.contains { $0.card.clamp?.shootOnly == true }
            let clampedFinishes = clampBlockedShotTypes(on: seat, in: state)
            let zoned = state[seat].clamps.contains { $0.card.clamp?.blocksShooting == true }
            let playable = state[seat].bag.filter { card in
                if held.contains(card.id) { return false }
                if shootOnly { return false }
                if passOnly, card.descriptor.passTarget == nil { return false }
                if movesOnly, !card.descriptor.isMove { return false }
                // Park Shark takes the threes away, a Clamp whichever finishes it names,
                // and Zone every shot.
                if has(seat, in: state, { $0.blocksThrees })
                    || injured(seat, in: state, { $0.blocksThrees }),
                   card.descriptor.isThree { return false }
                if let finish = card.descriptor.special?.shotType,
                   clampedFinishes.contains(finish) { return false }
                if zoned, card.descriptor.takesShot { return false }
                // Park Shark sits the Moves and Special Moves down; Fundamentalist the
                // Special Moves, and allows each Move once a turn.
                if card.descriptor.isMove,
                   has(seat, in: state, { $0.blocksMoves }) { return false }
                // Injuries: Torn ACL takes the Moves, and Torn Achilles the dunks and every
                // Move after the first each possession.
                if card.descriptor.isMove, injured(seat, in: state, { $0.blocksMoves }) {
                    return false
                }
                if card.descriptor.special?.dunks == true,
                   injured(seat, in: state, { $0.blocksDunks }) { return false }
                if card.descriptor.isMove,
                   let most = state[seat].injuries.compactMap({ $0.injury?.movesPerPossession }).min(),
                   state.moveCardsThisPossession >= most { return false }
                if card.descriptor.type == .specialMove,
                   has(seat, in: state, { $0.blocksSpecialMoves }) { return false }
                // Touch: no side to continue, no card. Greyed rather than refused.
                if card.descriptor.passTarget == .continuing,
                   continuation(from: seat, in: state) == nil { return false }
                // Rhythm Dribble has to follow one.
                if card.descriptor.requiresDribbleFirst,
                   state.lastPlayThisPossession.flatMap({ CardLibrary.byID[$0]?.isDribble }) != true {
                    return false
                }
                // **Flop is compulsory.** While it is in hand it is the only thing the
                // possession may open with — a flopper flops.
                if isFirstAction(state),
                   state[seat].bag.contains(where: { $0.descriptor.compulsoryFirstAction }),
                   !card.descriptor.compulsoryFirstAction { return false }
                if has(seat, in: state, { $0.oneOfEachMovePerTurn }),
                   card.descriptor.isMove,
                   state.movesPlayedThisPossession.contains(card.descriptor.id) { return false }
                // Triple Threat closes the book on Moves for the possession — the ones
                // before it as well as after, so it cannot follow a Move either.
                if card.descriptor.isMove, state.movesClosed { return false }
                if card.descriptor.blocksFurtherMoves,
                   !state.movesPlayedThisPossession.isEmpty { return false }
                // Lob: the man it found has to put it up first. A dunk is putting it up —
                // that is the Alley-Oop.
                if state.mustShootFirst == seat, card.descriptor.special?.dunks != true {
                    return false
                }
                // Backdoor Cut and Flash Cut: what the man it found has to do first.
                if state.mustPassFirst == seat,
                   !card.descriptor.isPass, card.descriptor.cut == nil { return false }
                if state.mustMoveFirst == seat, !card.descriptor.isMove { return false }
                // A Cut is only there to be played with a defender on you.
                if card.descriptor.cut != nil, state[seat].clamps.isEmpty { return false }
                // Clear Out: you step aside before the play starts, or not at all — and
                // only out of a ball that was going somewhere.
                if card.descriptor.firstActionOnly, !isFirstAction(state) { return false }
                // Clear Out is never played off the hand: it is offered the moment the
                // ball reaches you, before the defenders land, and that is the only way
                // in — see `beginPossession`. In the hand it reads as a card you cannot
                // play, which is exactly what it is once the question has been answered.
                if card.descriptor.clearsOut { return false }
                if let clock = card.descriptor.special?.onlyAtShotClock {
                    return state.shotClock == clock
                }
                // What the floor rules out: referees on Smacktop, threes on Kiddie Court
                // and Vintage Varnish, balls on Vintage Varnish, dunks on Gravi-Gym.
                if floor.barsWhistles, card.descriptor.type == .whistle { return false }
                if floor.barsThrees, card.descriptor.isThree || card.descriptor.upgradesToThree {
                    return false
                }
                if floor.barsVariaballs, card.descriptor.variaball != nil { return false }
                if floor.barsDunks, card.descriptor.special?.dunks == true { return false }
                // Frostbite Finish: a Move needs other cards to pay for it.
                if card.descriptor.isMove,
                   moveDiscardCost(in: state, for: seat) > state[seat].bag.count - 1 { return false }
                // Hero Ball: nobody passes it.
                if state.ballEffect.barsPasses, card.descriptor.isPass { return false }
                // One Intangible a possession, played by hand.
                if card.descriptor.intangible != nil {
                    return !state.playedIntangibleThisPossession
                }
                // One Varena and one Variaball a possession, unless Varsitile says otherwise.
                if card.descriptor.varena != nil {
                    return slotsFreely || !state.playedVarenaThisPossession
                }
                if card.descriptor.variaball != nil {
                    return slotsFreely || !state.playedVariaballThisPossession
                }
                // Only so many referees will stand on one floor.
                if card.descriptor.whistle?.trigger != nil {
                    return state.armedWhistles.count < state.rules.refereeSlots
                }
                // And only so many defenders on one man. Counted against what is already
                // waiting rather than what has landed — Clamps are set down a possession
                // before they bite, so the pending pile is the whole stack.
                // **One defender each.** A player may have the whole crowd on them, but
                // only one of them is yours — so a matchup is always readable by who set
                // it, and three opponents can never gang into a lock.
                if card.descriptor.clamp != nil {
                    guard !alreadyGuarding(seat, in: state) else { return false }
                    return !clampTargets(for: seat, in: state).isEmpty
                }
                return true
            }
            // Free Agent plays out of other people. His own draws are still his — that
            // is the divergence — so the two sets of options sit side by side.
            var borrowing: [Move] = []
            if has(seat, in: state, { $0.playsFromOthers }) {
                borrowing = Seat.allCases
                    .filter { $0 != seat && !state[$0].bag.isEmpty }
                    .map { Move.borrow(from: $0) }
            }
            // Rock Fight: nobody takes a good look. A bad one is still on offer.
            let barred = (state.shotCeilingThisRound.map { state.shot >= $0 } ?? false) || zoned
                || state.mustPassFirst == seat || state.mustMoveFirst == seat
            // **Three buttons, not one.** A layup is always there; a dunk wants the look
            // to be good already and a three wants a full hand. A defender who forces a
            // finish takes the other two away, which is the half of the matrix the crew is
            // waiting on — see `ShotType`.
            let forced = forcedShotType(on: seat, in: state)
            let finishes = ShotType.allCases.filter { type in
                if let forced, type != forced { return false }
                if clampedFinishes.contains(type) { return false }
                if has(seat, in: state, { $0.blocksThrees })
                    || injured(seat, in: state, { $0.blocksThrees }) || floor.barsThrees,
                   type == .three { return false }
                if floor.barsDunks || injured(seat, in: state, { $0.blocksDunks }),
                   type == .dunk { return false }
                return type.available(to: seat, in: state)
            }
            // Sixth Man's second button stands wherever the first does.
            let shots: [Move] = barred ? []
                : finishes.map { Move.shootAs($0) }
                    + (state.shotOffer(for: seat) != nil ? [.shootAtOffer] : [])
            // S.O.S: every three in hand can also go up as a two.
            let soldOut: [Move] = floor.threesAsDoubleTwos
                ? playable.filter(\.descriptor.isThree).map { Move.playAsTwo($0.id) } : []
            return shots + playable.map { Move.play($0.id) } + soldOut + borrowing
        default:
            return []
        }
    }

    /// **The only finish a player is allowed**, if a defender is walking them into one.
    /// Two defenders each naming a different one cancel out — a man being pushed two ways
    /// at once is a man nobody is really guarding.
    static func forcedShotType(on seat: Seat, in state: GameState) -> ShotType? {
        let forced = Set(state[seat].clamps.compactMap { clamp -> ShotType? in
            guard clampBites(clamp, on: seat, in: state) else { return nil }
            return clamp.card.clamp?.forcesShotType
        })
        return forced.count == 1 ? forced.first : nil
    }

    /// **The finishes the Clamps on this seat take away.**
    static func clampBlockedShotTypes(on seat: Seat, in state: GameState) -> Set<ShotType> {
        Set(state[seat].clamps.flatMap { $0.card.clamp?.blocksShotTypes ?? [] })
    }

    /// **Who a Clamp may be put on.** Anybody with room for another defender — yourself
    /// included, for what a Clamp on you sets up: a Cut, a Pump Fake, a Flop. Gravity makes
    /// it one man — "All Clamps must target you" — whoever is playing it.
    static func clampTargets(for seat: Seat, in state: GameState) -> [Seat] {
        if let magnet = gravityHolder(in: state) {
            return state[magnet].clamps.count < state.rules.clampSlots ? [magnet] : []
        }
        return Seat.allCases.filter { state[$0].clamps.count < state.rules.clampSlots }
    }

    /// Whether this seat already has a defender of their own out on somebody.

    static func alreadyGuarding(_ seat: Seat, in state: GameState) -> Bool {
        if state.pendingClamps.contains(where: { $0.from == seat }) { return true }
        return Seat.allCases.contains { state[$0].clamps.contains { $0.from == seat } }
    }

    /// **Whether a standing defender is a problem right now.**
    ///
    /// A pace defender only bites inside his band: the seven-footer does not see the
    /// five-two guard, and a player outside it shoots straight over him. He stays out
    /// there — the matchup comes back the moment the hand moves.
    static func clampBites(_ clamp: ActiveClamp, on seat: Seat, in state: GameState) -> Bool {
        guard let applies = clamp.card.clamp?.appliesWhen else { return true }
        return applies.met(by: seat, in: state)
    }

    /// A possession nobody can do anything with is a dead ball.
    ///
    /// Rock Fight bars the good look and a Lob says shoot first, so a man can be left with
    /// a hand he may not play and a shot he may not take. On a floor the clock would
    /// simply run out on him, and that is what happens here: a violation, and the ball.
    ///
    /// Checked at the edges of a chain rather than inside one, because a hand that is dead
    /// halfway through a draw is not dead — it is halfway through a draw.
    private static func strandOut(state: inout GameState, events: inout [GameEvent]) {
        // A round already on its way out is not a possession anybody is stuck in.
        guard !state.roundEnding else { return }
        guard case .possession(let holder) = state.phase else { return }
        // Traderous Tarmac: a man who can still hand his Clamps on has something to do.
        guard handOffTargets(state, for: holder).isEmpty else { return }
        let legal = legalMoves(state, for: holder)
        // Zone: left with no Pass to play, at any point in the possession, is the turnover.
        let zoned = state[holder].clamps.contains { $0.card.clamp?.turnoverWithoutAPass == true }
        let canPass = legal.contains { move in
            guard case .play(let id) = move else { return false }
            return state[holder].bag.first(where: { $0.id == id })?.isPass == true
        }
        guard legal.isEmpty || (zoned && !canPass) else { return }
        state[holder].turnovers += 1
        let owedByCut = state.mustPassFirst == holder || state.mustMoveFirst == holder
            || state.mustShootFirst == holder
        events.append(.turnover(holder, cause: zoned && !canPass ? CardLibrary.zone.name
                                : owedByCut ? (state.arrivedBy?.name ?? "Shot Clock") : "Shot Clock"))
        stoppage(state: &state, events: &events)
        endRound(state: &state, events: &events)
    }

    /// Traderous Tarmac: who a Clamp on this seat may be handed to. Anyone else with room.
    static func handOffTargets(_ state: GameState, for seat: Seat) -> [Seat] {
        guard state.floorEffect.clampsHandOff, case .possession(let holder) = state.phase,
              holder == seat, !state[seat].clamps.isEmpty else { return [] }
        return Seat.allCases.filter {
            $0 != seat && state[$0].clamps.count < state.rules.clampSlots
        }
    }

    /// **Varsitile: what Retirement could give for what you have in play**, once a
    /// possession — a Ball for the ball, an Intangible for one of yours. The Variaball card
    /// is never a ball, so it is never on offer.
    static func exchangeOptions(_ state: GameState, for seat: Seat) -> [Card] {
        guard has(seat, in: state, { $0.exchangesWithRetirement }),
              !state.slotsExchangedThisPossession,
              case .possession(let holder) = state.phase, holder == seat else { return [] }
        let balls = state.ballCard == nil || state.floorEffect.barsVariaballs ? [] : state.discard.filter {
            $0.descriptor.variaball != nil && $0.descriptor.variaball?.rollsFromDiscard != true
        }
        let passives = state[seat].intangibles.isEmpty ? [] : state.discard.filter {
            $0.descriptor.intangible != nil
        }
        return balls + passives
    }

    /// **Skyhook: the card it reaches for.** Anything but another Skyhook, while the Bag
    /// has room for it. True when the question is standing.
    private static func askForRetiredPick(_ descriptor: CardDescriptor, by seat: Seat,
                                          state: inout GameState) -> Bool {
        guard descriptor.takesFromRetirement > 0,
              state[seat].bag.count < state.handLimit(for: seat) else { return false }
        let choices = state.discard.filter { $0.descriptor.name != descriptor.name }.map(\.id)
        guard !choices.isEmpty else { return false }
        state.pendingPlay = descriptor
        state.pendingActor = seat
        state.phase = .awaitingRetiredPick(seat: seat, card: descriptor, choices: choices)
        return true
    }

    /// **A card out of Retirement, chosen** — or nil for none — and the play carried on.
    @discardableResult
    static func resolveRetiredPick(_ id: Card.ID?, state: inout GameState) -> [GameEvent] {
        guard case .awaitingRetiredPick(_, let card, let choices) = state.phase,
              let actor = state.pendingActor else { return [] }
        var events: [GameEvent] = []
        let descriptor = state.pendingPlay
        state.pendingPlay = nil
        state.pendingActor = nil
        state.phase = .possession(holder: actor)
        let taken = id.flatMap { id in choices.contains(id) ? state.discard.first { $0.id == id } : nil }

        // Varsitile: a ball for the ball, or an Intangible for one of yours.
        if card.intangible?.exchangesWithRetirement == true {
            guard let taken else {
                settleHands(state: &state, events: &events)
                return events
            }
            if taken.descriptor.variaball != nil {
                state.slotsExchangedThisPossession = true
                state.discard.removeAll { $0.id == taken.id }
                events.append(.slotsExchanged(seat: actor, cards: [taken.descriptor]))
                setBall(taken, by: actor, state: &state, events: &events)
                settleHands(state: &state, events: &events)
                return events
            }
            let mine = state[actor].intangibles
            if mine.count == 1, let only = mine.first {
                exchangeIntangible(only.id, for: taken, by: actor, state: &state, events: &events)
                settleHands(state: &state, events: &events)
                return events
            }
            // More than one on the board: which of them goes in its place.
            state.retiredPick = taken.id
            state.pendingActor = actor
            state.phase = .awaitingRetirement(seat: actor, card: card,
                                              choices: mine.map { .intangible(seat: actor, id: $0.id) })
            return events
        }

        // Skyhook: into the Bag, and then the shot it was holding goes up.
        if let taken {
            state.discard.removeAll { $0.id == taken.id }
            state[actor].bag.append(taken)
            events.append(.drewFromRetirement(seat: actor, card: taken.descriptor))
        }
        if let descriptor, descriptor.special?.shootsImmediately == true {
            _ = shootTheCard(descriptor, by: actor, state: &state, events: &events)
            return events
        }
        settleHands(state: &state, events: &events)
        return events
    }

    /// Varsitile: one of yours to Retirement, and the one chosen out of it in its place.
    private static func exchangeIntangible(_ givingID: String, for taken: Card, by seat: Seat,
                                           state: inout GameState, events: inout [GameEvent]) {
        guard let at = state[seat].intangibles.firstIndex(where: { $0.id == givingID }) else { return }
        let giving = state[seat].intangibles.remove(at: at)
        state.discard.removeAll { $0.id == taken.id }
        state.discard.append(Card(giving))
        state[seat].intangibles.insert(taken.descriptor, at: at)
        state.slotsExchangedThisPossession = true
        events.append(.slotsExchanged(seat: seat, cards: [taken.descriptor]))
    }

    /// A Move's price in other cards — Frostbite Finish's and Rolled Ankle's — after Dishcount
    /// Ball's discount.
    static func moveDiscardCost(in state: GameState, for seat: Seat) -> Int {
        let ankles = state[seat].injuries.reduce(0) { $0 + ($1.injury?.moveDiscardCost ?? 0) }
        return max(0, state.floorEffect.moveDiscardCost + ankles
                      - (state.ballEffect.discountsDiscards ? 1 : 0))
    }

    // MARK: - Swissh-Ups

    /// Whether a seat could pop one right now. One at a time, and only on your own turn.
    ///
    /// `Downloaded` is the one with a table condition: it swaps the hand for the same
    /// number off the discard pile, so the pile has to be able to pay.
    static func canPop(_ up: SwisshUp, by seat: Seat, in state: GameState) -> Bool {
        guard state[seat].swisshUp == nil else { return false }
        guard case .possession(let holder) = state.phase, holder == seat else { return false }
        guard up.takesFromDiscard else { return true }
        return downloadable(from: state).count >= state[seat].bag.count
    }

    /// What `Downloaded` may take: the discard pile from the top down, passing over the
    /// types nobody may hold — a Break and an Injury are events, and a Whistle is set.
    static func downloadable(from state: GameState) -> [Card] {
        state.discard.reversed().filter {
            $0.descriptor.gameBreak == nil && $0.descriptor.injury == nil
                && $0.descriptor.type != .whistle
        }
    }

    /// Pops one. The single acts happen here and are gone; the rest start their clock.
    @discardableResult
    static func popSwisshUp(_ up: SwisshUp, by seat: Seat,
                            state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        guard canPop(up, by: seat, in: state) else { return events }

        if let target = up.drawsUpTo {
            while state[seat].bag.count < target {
                let before = state[seat].bag.count
                drawOnce(seat, state: &state, events: &events)
                if state[seat].bag.count == before { break }
            }
        } else if up.takesFromDiscard {
            // The hand goes down first, so what it is replaced with can include what it
            // just put there — a table would deal off the pile it is looking at.
            let wanted = state[seat].bag.count
            spendHand(of: seat, state: &state, events: &events)
            var taken = 0
            for card in downloadable(from: state) where taken < wanted {
                state.discard.removeAll { $0.id == card.id }
                state[seat].bag.append(card)
                taken += 1
            }
        } else {
            // Three possessions, and the one it is popped on is the first — except for the
            // one that pays at the top of a turn, whose turn has already been paid.
            state[seat].swisshUp = ActiveSwisshUp(
                kind: up,
                left: up.startsNextPossession ? up.possessions : up.possessions - 1,
                waiting: up.startsNextPossession)
        }
        settleHands(state: &state, events: &events)
        return events
    }

    /// Runs a seat's Swissh-Up down by one, at the top of their own possession.
    ///
    /// Called from `beginPossession` once this is wired in. The one that was waiting for a
    /// possession of its own starts here instead of counting down.
    static func tickSwisshUp(_ seat: Seat, state: inout GameState) {
        guard var live = state[seat].swisshUp else { return }
        if live.waiting {
            live.waiting = false
            state[seat].swisshUp = live
            return
        }
        live.left -= 1
        state[seat].swisshUp = live.left > 0 ? live : nil
    }

    /// The Zone a seat is in, if it is doing anything yet.
    static func swisshUp(on seat: Seat, in state: GameState) -> SwisshUp? {
        guard let live = state[seat].swisshUp, !live.waiting else { return nil }
        return live.kind
    }

    /// Where a pile of Clamps still in the air is going to come down.
    static func clampLanding(_ seat: Seat, in state: GameState) -> Seat {
        state.clampMagnet ?? seat
    }

    /// The Clamps about to land on him, which is not the same question as the ones on him.
    /// **The defenders about to bite: the ones already waiting on him.** A Clamp is set on
    /// a man when it is played and bites when he next has the ball, so what arrives with
    /// the ball is whatever has been waiting — which is what Clear Out and Crossover answer.
    static func clampsArriving(on seat: Seat, in state: GameState) -> [ActiveClamp] {
        let waiting = state[seat].clamps.filter { !$0.bitten }
        return waiting + (clampLanding(seat, in: state) == seat ? state.pendingClamps : [])
    }

    /// The card he is offered as the possession arrives, before the defenders land.
    ///
    /// **Counterplay has to come before the thing it counters, or it does not come at
    /// all.** A Clamp that locks cards can lock the very card that would have shaken it
    /// off — so a hand's answer to being guarded is asked for while the pile is still in
    /// the air, whether or not the card says it must be played first. One card, picked in
    /// order: stepping out of the play entirely beats breaking what is coming.
    /// **Everything in the hand that answers this, not the first one found.**
    ///
    /// Two different fields let a card answer here — `clearsOut` steps away from a pass,
    /// `clearsClamps` takes the defenders out of the air — and a hand can hold both at
    /// once. It used to check for a clear-out first and return, so a man with Clear Out
    /// *and* Spin Move against an arriving Clamp was shown one of them and never told the
    /// other was possible. Which one you spend is the decision.
    static func countersOnOffer(to seat: Seat, in state: GameState) -> [Card] {
        var offered: [Card] = []
        // Stepping out of a ball aimed at you is a real choice on any pass, not only one
        // with a through-line — it just costs the man who threw it rather than sending
        // the ball on.
        if let passer = state.lastPasser, passer != seat {
            offered += state[seat].bag.filter { $0.descriptor.clearsOut }
        }
        if !clampsArriving(on: seat, in: state).isEmpty {
            // Clear Out takes the floor; Crossover and Outlet take the man in the way.
            offered += state[seat].bag.filter {
                $0.descriptor.clearsClamps || $0.descriptor.clearsTargetClamp
            }
        }
        // A card that does both is still one card.
        var seen: Set<Card.ID> = []
        return offered.filter { seen.insert($0.id).inserted }
    }


    // MARK: - Options

    /// **A pass card's "You may"**, asked before the ball leaves the hand. Lob's only when
    /// there is a Ball to take, Kick-Out's only when there are Clamps to send.
    private static func passOption(_ descriptor: CardDescriptor, from seat: Seat,
                                   in state: GameState) -> CardOption? {
        if descriptor.mayTakeBall, state.ballCard != nil { return .takeBall }
        if descriptor.mayFlipForDraw { return .flipForDraw }
        if descriptor.movesClampsToReceiver, !state[seat].clamps.isEmpty { return .assignClamps }
        return nil
    }

    /// What the house answers: anything that only helps. It keeps a ball it is holding.
    static func houseTakes(_ option: CardOption, for seat: Seat, in state: GameState) -> Bool {
        switch option {
        case .takeBall:
            return false
        case .resetShotClock:
            return (state.shotClock ?? state.shotClockLength) < state.shotClockLength
        case .flipForDraw, .assignClamps, .dumpHand, .ankleBreaker:
            return true
        }
    }

    /// **Everything a card can reach out and take off the table**, for whoever is being
    /// asked. Officials, the ball and passives are all face-up; a Clamp is here for the
    /// cards that move one instead. Empty means there is nothing to name, and a question
    /// with nothing to answer is never asked.
    static func retirementChoices(_ descriptor: CardDescriptor, by seat: Seat,
                                  in state: GameState) -> [RetirementTarget] {
        var choices: [RetirementTarget] = []
        // The ball asks through its own effect; everything else through the descriptor.
        if descriptor.retiresARef || descriptor.variaball?.retiresARef == true
            || descriptor.intangible?.retiresInPlayOnPass == true {
            choices += state.armedWhistles.map { .official($0.id) }
        }
        if descriptor.mayRetireTheBall || descriptor.intangible?.retiresInPlayOnPass == true,
           state.ballCard != nil {
            choices.append(.ball)
        }
        if descriptor.retiresAnIntangible || descriptor.intangible?.retiresInPlayOnPass == true {
            for other in Seat.allCases where other != seat {
                choices += state[other].intangibles.map { .intangible(seat: other, id: $0.id) }
            }
        }
        if descriptor.reassignsAClamp {
            choices += Seat.allCases.flatMap { who in state[who].clamps.map { RetirementTarget.clamp(id: $0.id) } }
        }
        return choices
    }

    /// **Takes it off the table.** One door for every card that names something in play,
    /// so an official leaving this way is the same leaving as a Challenge's.
    private static func retire(_ target: RetirementTarget, by seat: Seat,
                               card: CardDescriptor,
                               state: inout GameState, events: inout [GameEvent]) {
        switch target {
        case .official(let id):
            guard let at = state.armedWhistles.firstIndex(where: { $0.id == id }) else { return }
            let gone = sendOff(at, state: &state, events: &events)
            events.append(.officialDistracted(seat: seat, card: gone.descriptor))
            assignCrew(state: &state, events: &events)
        case .ball:
            setBall(nil, by: seat, state: &state, events: &events)
            events.append(.ballChanged(card: nil))
        case .intangible(let owner, let id):
            guard let at = state[owner].intangibles.firstIndex(where: { $0.id == id }) else { return }
            let gone = state[owner].intangibles.remove(at: at)
            events.append(.intangibleDisplaced(seat: owner, card: gone))
        case .clamp(let id):
            // **Reassigned, not Retired.** Spin Move puts the man on somebody else; the
            // defender who has just been moved has to bite again where he lands.
            guard let from = Seat.allCases.first(where: {
                state[$0].clamps.contains { $0.id == id }
            }), let at = state[from].clamps.firstIndex(where: { $0.id == id }) else { return }
            var moved = state[from].clamps.remove(at: at)
            moved.bitten = false
            moved.locked = []
            let to = clampVictim(in: state) ?? from
            state[to].clamps = Array((state[to].clamps + [moved]).suffix(state.rules.clampSlots))
            events.append(.clampSet(seat: to, card: card))
        }
    }

    /// **The official who made the last call, sent off for it.** Behind-the-Back goes
    /// behind his back; Officially Infamous does it to anybody who blows on him.
    private static func retireLastCaller(by seat: Seat, source: CardDescriptor,
                                         state: inout GameState, events: inout [GameEvent]) {
        guard let at = state.armedWhistles.lastIndex(where: { $0.stayed }) else { return }
        let gone = sendOff(at, state: &state, events: &events)
        events.append(.officialDistracted(seat: seat, card: gone.descriptor))
        assignCrew(state: &state, events: &events)
        _ = source
    }

    /// **Stops to ask what this card is taking off the table**, if it takes anything and
    /// there is anything to take. True when the play is now waiting on the answer.
    ///
    /// The forced half is paid here rather than asked about: Full-Court Heave and
    /// Fundamentalist say *Retire the Ball* flatly, so the ball is gone before the
    /// optional question is even put.
    @discardableResult
    private static func askForRetirement(_ descriptor: CardDescriptor, by seat: Seat,
                                         state: inout GameState) -> Bool {
        // **The forced half is simply paid.** "Retire the Ball" is not a question.
        if descriptor.retiresTheBall, state.ballCard != nil {
            var events: [GameEvent] = []
            setBall(nil, by: seat, state: &state, events: &events)
        }
        if descriptor.retiresLastCaller {
            var events: [GameEvent] = []
            retireLastCaller(by: seat, source: descriptor, state: &state, events: &events)
        }
        let choices = retirementChoices(descriptor, by: seat, in: state)
        guard !choices.isEmpty else { return false }
        state.pendingPlay = descriptor
        state.pendingActor = seat
        state.phase = .awaitingRetirement(seat: asker(instead: seat, in: state),
                                          card: descriptor, choices: choices)
        return true
    }

    /// **Rookie Official: the first card you spend in a possession buys one back.**
    ///
    /// Non-standing only — a Clamp, a passive or a ball stays on the table and was never
    /// Retired, so there is nothing to trade. And only the *first* card, or two Moves
    /// played back and forth would fish the same pair out of Retirement all night.
    private static func rookieSwap(_ spent: CardDescriptor, by seat: Seat,
                                   state: inout GameState, events: inout [GameEvent]) {
        guard state.armedWhistles.contains(where: {
            $0.card.descriptor.whistle?.swapsOnRetire == true
        }), state.rookieSwapped != seat, spent.isNonStanding else { return }
        state.rookieSwapped = seat
        guard state[seat].bag.count < state.handLimit(for: seat),
              let at = state.discard.lastIndex(where: { $0.name != spent.name })
        else { return }
        let taken = state.discard.remove(at: at)
        state[seat].bag.append(taken)
        events.append(.drewFromRetirement(seat: seat, card: taken.descriptor))
    }

    /// **Splash Ball, if the man going up for three is carrying the cousin.** The passive
    /// is spent putting it there, and the ball is what everybody has to deal with next.
    static func splashIn(by seat: Seat, state: inout GameState, events: inout [GameEvent]) {
        guard let at = state[seat].intangibles.firstIndex(where: {
            $0.intangible?.swapsBallForSplash == true
        }) else { return }
        let spent = state[seat].intangibles.remove(at: at)
        state.discard.append(Card(spent))
        events.append(.intangibleDisplaced(seat: seat, card: spent))
        setBall(Card(CardLibrary.splashBall), by: seat, state: &state, events: &events)
        events.append(.ballChanged(card: CardLibrary.splashBall))
    }

    /// **One more defender sold on the fake, or nil to stop.** Each one is paid as it is
    /// named, so a player can watch the clock come down and stop where they like.
    @discardableResult
    static func resolveClampNamed(_ id: UUID?, state: inout GameState) -> [GameEvent] {
        guard case .awaitingClampsNamed(let asked, let card, let named) = state.phase,
              let actor = state.pendingActor else { return [] }
        var events: [GameEvent] = []
        if let id, !named.contains(id), state[actor].clamps.contains(where: { $0.id == id }) {
            adjustShot(by: card.shotPerClampNamed, state: &state)
            if card.clockPerClampNamed != 0 {
                _ = tickClock(by: card.clockPerClampNamed, holder: actor,
                              state: &state, events: &events)
            }
            let more = named + [id]
            // Nothing left to name is the same as stopping.
            if state[actor].clamps.contains(where: { !more.contains($0.id) }),
               case .possession = state.phase {
                state.phase = .awaitingClampsNamed(seat: asked, card: card, named: more)
                return events
            }
        }
        state.pendingPlay = nil
        state.pendingActor = nil
        if case .awaitingClampsNamed = state.phase { state.phase = .possession(holder: actor) }
        settleHands(state: &state, events: &events)
        return events
    }

    /// **A named thing taken off the table, answered** — nil for none — and whatever the
    /// card was doing carried on from there.
    @discardableResult
    static func resolveRetirement(_ target: RetirementTarget?, state: inout GameState) -> [GameEvent] {
        guard case .awaitingRetirement(_, let card, _) = state.phase,
              let actor = state.pendingActor else { return [] }
        var events: [GameEvent] = []
        state.phase = .possession(holder: actor)
        // Varsitile's second question: which Intangible goes in exchange.
        if card.intangible?.exchangesWithRetirement == true {
            let pick = state.retiredPick
            state.retiredPick = nil
            state.pendingActor = nil
            if case .intangible(_, let id)? = target, let pick,
               let taken = state.discard.first(where: { $0.id == pick }) {
                exchangeIntangible(id, for: taken, by: actor, state: &state, events: &events)
            }
            settleHands(state: &state, events: &events)
            return events
        }
        if let target { retire(target, by: actor, card: card, state: &state, events: &events) }
        let descriptor = state.pendingPlay
        state.pendingPlay = nil
        state.pendingActor = nil
        // **"And/or" means it may reach twice.** From the Logo can take an official and
        // the ball, so once one is gone the rest of the table is offered again — and only
        // ever once more, because two kinds is all any card names.
        if let descriptor, target != nil, card.id == descriptor.id, descriptor.cut == nil,
           descriptor.retiresARef, descriptor.mayRetireTheBall {
            let again = retirementChoices(descriptor, by: actor, in: state)
                .filter { $0 != target }
            if !again.isEmpty, !state.reachedTwice {
                state.reachedTwice = true
                state.pendingPlay = descriptor
                state.pendingActor = actor
                state.phase = .awaitingRetirement(seat: asker(instead: actor, in: state),
                                                  card: descriptor, choices: again)
                return events
            }
        }
        state.reachedTwice = false
        guard let descriptor else { return events }
        if descriptor.cut != nil, let receiver = state.cutReceiver {
            state.cutReceiver = nil
            if case .possession(let holder) = state.phase, holder == actor {
                cutPass(descriptor, from: actor, to: receiver, state: &state, events: &events)
            }
            settleHands(state: &state, events: &events)
            return events
        }
        // A shot was held back so the card could reach first; now it goes up.
        if descriptor.special?.shootsImmediately == true {
            if let least = descriptor.special?.offersHandDumpAt, state[actor].bag.count >= least {
                state.pendingPlay = descriptor
                state.pendingActor = actor
                state.phase = .awaitingOption(seat: actor, option: .dumpHand)
                return events
            }
            _ = shootTheCard(descriptor, by: actor, state: &state, events: &events)
            return events
        }
        // A pass was paused mid-flight; a plain Move had already finished its business.
        guard let to = descriptor.passTarget else { return events }
        if let option = passOption(descriptor, from: actor, in: state) {
            state.pendingPlay = descriptor
            state.pendingActor = actor
            state.phase = .awaitingOption(seat: actor, option: option)
            return events
        }
        _ = throwPass(descriptor, target: to, from: actor, state: &state, events: &events)
        return events
    }

    /// A card's "You may", answered — and the play it paused carried on from there.
    @discardableResult
    static func resolveOption(_ taken: Bool, state: inout GameState) -> [GameEvent] {
        guard case .awaitingOption(let asked, let option) = state.phase else { return [] }
        var events: [GameEvent] = []
        switch option {
        case .takeBall, .flipForDraw, .assignClamps:
            guard let descriptor = state.pendingPlay, let actor = state.pendingActor,
                  let target = descriptor.passTarget else { return [] }
            state.pendingPlay = nil
            state.pendingActor = nil
            state.phase = .possession(holder: actor)
            state.passTakesBall = option == .takeBall && taken
            state.passFlipsCoin = option == .flipForDraw && taken
            state.passAssignsClamps = option == .assignClamps && taken
            if throwPass(descriptor, target: target, from: actor, state: &state, events: &events) {
                return events
            }
        case .resetShotClock:
            state.phase = .possession(holder: asked)
            if taken {
                state.shotClock = state.shotClockLength
                events.append(.shotClockSet(state.shotClockLength))
            }
        case .dumpHand:
            guard let descriptor = state.pendingPlay, let actor = state.pendingActor else { return [] }
            state.pendingPlay = nil
            state.pendingActor = nil
            state.phase = .possession(holder: actor)
            if taken {
                let hand = state[actor].bag
                state[actor].bag.removeAll()
                state.discard.append(contentsOf: hand)
                events.append(.discardedForShot(seat: actor, card: descriptor, count: hand.count))
                // **The hand buys an official, and a full hand buys the shot.** Three
                // cards is enough to send somebody off; only five is enough to make it.
                if descriptor.special?.handDumpRetiresARef == true {
                    retireLastCaller(by: actor, source: descriptor, state: &state, events: &events)
                    if state.armedWhistles.contains(where: { !$0.stayed }),
                       let at = state.armedWhistles.indices.last {
                        let gone = sendOff(at, state: &state, events: &events)
                        events.append(.officialDistracted(seat: actor, card: gone.descriptor))
                        assignCrew(state: &state, events: &events)
                    }
                }
                if let least = descriptor.special?.handDumpOverrideAt, hand.count >= least {
                    state.pendingShotOverride = ShotOverride(label: descriptor.name, amount: 100)
                }
            }
            if shootTheCard(descriptor, by: actor, state: &state, events: &events) {
                return events
            }
        case .ankleBreaker:
            guard let actor = state.pendingActor else { return [] }
            state.pendingActor = nil
            state.phase = .possession(holder: actor)
            let victims = Seat.allCases.filter { $0 != actor && !state[$0].bag.isEmpty }
            if taken, !victims.isEmpty {
                // Retired as a card, it is still the name the question goes out under.
                state.pendingPlay = CardLibrary.ankleBreaker
                state.pendingActor = actor
                state.phase = .awaitingTarget(seat: asker(instead: actor, in: state),
                                              card: CardLibrary.ankleBreaker, choices: victims)
                return events
            }
        }
        settleHands(state: &state, events: &events)
        return events
    }

    /// **A shooting Special Move putting its shot up.** The Future's four-point offer first,
    /// then any Whistle watching for a shot, then the attempt. True when the play stops here.
    @discardableResult
    private static func shootTheCard(_ descriptor: CardDescriptor, by seat: Seat,
                                     state: inout GameState, events: inout [GameEvent]) -> Bool {
        guard let special = descriptor.special else { return false }
        if descriptor.isThree, state.floorEffect.offersFourPointThree, !state.sellingOut,
           !state[seat].bag.isEmpty {
            // The fourth point costs the shot SHOT -10%.
            state.fourPointOffer = true
            state.phase = .awaitingDiscard(seat: seat, card: descriptor, bonusEach: -10)
            return true
        }
        // The card is a shot attempt in its own right, so a Whistle watching for one still
        // gets its say — and reads which finish this is, not the last one taken.
        state.shotType = special.shotType ?? .layup
        var downgraded = false
        if let whistle = interceptor(of: .shoot(seat: seat), in: &state) {
            downgraded = whistle.card.descriptor.whistle?.downgradesThree == true
            blow(whistle, on: .shoot(seat: seat), state: &state, events: &events)
            // Foot On The Line takes the point, not the shot.
            guard downgraded, case .possession(let still) = state.phase, still == seat
            else { return true }
        }
        resolveShot(by: seat, bonusPoints: extraPoint(for: special.shotType, downgraded: downgraded),
                    overClamps: special.ignoresClamps, card: descriptor,
                    state: &state, events: &events)
        return false
    }

    /// Takes the first card on offer, or declines. **For callers with nothing to choose
    /// with** — the harness, and the AI, which does not yet weigh one answer against
    /// another. A player is asked properly; see `countersOnOffer`.
    @discardableResult
    static func resolveCounter(_ taken: Bool, state: inout GameState) -> [GameEvent] {
        guard case .awaitingCounter(let seat, let offered) = state.phase else { return [] }
        // "Dunk It?" asks with the possession already open, so it has no held arrival.
        let first = taken
            ? (state.heldPossession == nil ? offered.first?.id
                                           : countersOnOffer(to: seat, in: state).first?.id)
            : nil
        return resolveCounter(first, state: &state)
    }

    /// Taken, or turned down.
    ///
    /// Turning it down picks the possession back up exactly where it was put down; taking
    /// it spends the card and sends the ball on, and the defenders that were about to land
    /// land on the next man instead — which is the whole reason the question is asked here
    /// rather than on his turn.
    ///
    /// - Parameter chosen: which of the offered cards is being spent, or nil to decline.
    @discardableResult
    static func resolveCounter(_ chosen: Card.ID?, state: inout GameState) -> [GameEvent] {
        guard case .awaitingCounter(let seat, let offered) = state.phase else { return [] }
        // **"Dunk It?"** The possession is open and the question is only whether the Lob is
        // finished with a dunk: yes plays it, no carries on with the possession.
        if state.heldPossession == nil {
            state.phase = .possession(holder: seat)
            guard let chosen, offered.contains(where: { $0.id == chosen }) else {
                var events: [GameEvent] = []
                settleHands(state: &state, events: &events)
                return events
            }
            return apply(.play(chosen), by: seat, to: &state)
        }
        guard let held = state.heldPossession else { return [] }
        var events: [GameEvent] = []
        state.heldPossession = nil

        // Only one of the cards actually on offer, and only if one was named.
        let card = chosen.flatMap { id in
            countersOnOffer(to: seat, in: state).first { $0.id == id }
        }
        guard let card else {
            beginPossession(held.seat, tickClock: held.ticks, fromRebound: held.fromRebound,
                            fromOwnMiss: held.fromOwnMiss, offering: false,
                            alreadyDrew: held.drew, state: &state, events: &events)
            // **Turning it down is still an answer.** A possession held on this question
            // has whatever the last one left owed still owed — a Right Back's return leg,
            // most of all — and `settleHands` is what pays it. Only the taken path came
            // through here, so declining stranded the ball with the receiver until the
            // clock ran out on him: a shot-clock violation nobody could see coming.
            settleHands(state: &state, events: &events)
            return events
        }

        state[seat].bag.removeAll { $0.id == card.id }
        state.discard.append(card)
        events.append(.movePlayed(seat: seat, card: card.descriptor, shot: loggedShot(state)))
        if card.descriptor.clearsOut {
            clearOut(from: seat, state: &state, events: &events)
        } else {
            // **Taken out of the air, not off the player.** They never land, so they
            // never get to lock anything — and the possession opens on a clean board
            // before the card pays out on to it.
            //
            // **The ones waiting on him, and one or all of them.** A Clamp sits on its
            // man until he has the ball, so what is broken here is what was waiting —
            // Clear Out takes the lot, Crossover and Outlet take the one worst placed.
            let arriving = clampsArriving(on: seat, in: state)
            let breaking: [ActiveClamp] = card.descriptor.clearsClamps
                ? arriving
                : Array(arriving.sorted {
                    ($0.card.clamp?.shotDebuff ?? 0) < ($1.card.clamp?.shotDebuff ?? 0)
                }.prefix(1))
            let broken = Set(breaking.map(\.id))
            state[seat].clamps.removeAll { broken.contains($0.id) }
            state.pendingClamps.removeAll { broken.contains($0.id) }
            beginPossession(held.seat, tickClock: held.ticks, fromRebound: held.fromRebound,
                            fromOwnMiss: held.fromOwnMiss, offering: false,
                            alreadyDrew: held.drew, state: &state, events: &events)
            pay(card.descriptor, breaking: breaking, for: seat, state: &state, events: &events)
            // **A trip is queued, not taken.** `awardFreeThrows` only puts one down —
            // the phase is set here, after the possession has finished settling, or the
            // line would be set on a phase about to be replaced. Flop broke the Clamps
            // before they landed and then nobody went to the line.
            takeTheLine(state: &state, events: &events)
        }
        settleHands(state: &state, events: &events)
        return events
    }

    /// What a Clamp-breaker pays when it is played at the arrival rather than on a turn.
    ///
    /// The same reckoning `apply` does for Clamps already standing — see there — against
    /// the ones that were on their way instead. Its own printed effect is paid too: the
    /// card was played, and half a card is not what it says on it.
    private static func pay(_ descriptor: CardDescriptor, breaking arriving: [ActiveClamp],
                            for seat: Seat, state: inout GameState,
                            events: inout [GameEvent]) {
        adjustShot(by: printedWorth(of: descriptor, in: state), state: &state)
        drawTogether([seat], count: descriptor.drawCount, state: &state, events: &events)

        guard !arriving.isEmpty else { return }
        let shaken = arriving.count
        if descriptor.freeThrowsPerClamp > 0, let first = arriving.first {
            awardFreeThrows(descriptor.freeThrowsPerClamp * shaken, to: seat,
                            offender: first.from, source: descriptor.name,
                            state: &state, events: &events)
        }
        if descriptor.shotPerClamp != 0 {
            adjustShot(by: descriptor.shotPerClamp * shaken, state: &state)
        }
        for _ in 0..<(descriptor.drawPerClamp * shaken) {
            drawOnce(seat, state: &state, events: &events)
        }
        if descriptor.clockPerClamp != 0 {
            _ = tickClock(by: descriptor.clockPerClamp * shaken, holder: seat,
                          state: &state, events: &events)
        }
        if descriptor.clamperDiscardsPerClamp > 0 {
            for clamp in arriving {
                for _ in 0..<descriptor.clamperDiscardsPerClamp {
                    discardAtRandom(from: clamp.from, state: &state)
                }
            }
        }
        events.append(.clampsShaken(seat: seat, card: descriptor, count: shaken))
    }

    /// **A Varena or a Variaball, onto its slot.** Playing one is an action, like playing any
    /// card. The Variaball card never sits in the slot: it rolls a ball out of the discards.
    private static func playOntoItsSlot(_ card: Card, by seat: Seat, state: inout GameState,
                                        events: inout [GameEvent]) {
        events.append(.movePlayed(seat: seat, card: card.descriptor, shot: loggedShot(state)))
        state.lastPlayThisPossession = card.descriptor.id
        state.lastPlayWasCombo = false
        state.movesThisPossession += 1
        // An Intangible, played by hand: into its slot now, one a possession.
        if card.descriptor.intangible != nil {
            state.playedIntangibleThisPossession = true
            activate(card, for: seat, state: &state, events: &events)
            // Free Agent takes the whole hand, once the chain it landed in is done.
            if card.descriptor.intangible?.playsFromOthers == true {
                state.owe(.spendHand(seat))
            }
            return
        }
        if card.descriptor.varena != nil {
            state.playedVarenaThisPossession = true
            setCourt(card, by: seat, state: &state, events: &events)
        } else {
            state.playedVariaballThisPossession = true
            if card.descriptor.variaball?.rollsFromDiscard == true {
                rollBall(card, by: seat, state: &state, events: &events)
            } else {
                setBall(card, by: seat, state: &state, events: &events)
            }
        }
    }

    /// **A new floor.** The old one goes to the pile with whatever it was holding up, and
    /// the new one does what it does the moment it lands. The table's own Cardwood is
    /// never a card, so it goes nowhere.
    private static func setCourt(_ card: Card, by seat: Seat?, state: inout GameState,
                                 events: inout [GameEvent]) {
        let leaving = state.floorEffect
        if let replaced = state.courtCard { state.discard.append(replaced) }
        // Policeum's referees were only staying because of the floor.
        if leaving.refereesStay {
            let stayed = state.armedWhistles.filter(\.stayed)
            state.armedWhistles.removeAll(where: \.stayed)
            state.discard.append(contentsOf: stayed.map(\.card))
            if !stayed.isEmpty { events.append(.whistlesDismissed) }
        }
        state.courtCard = card
        state.carouselClockwise = nil
        state.turnstileUp = true
        let arriving = state.floorEffect
        if arriving.clearsWhistlesOnArrival, !state.armedWhistles.isEmpty {
            state.discard.append(contentsOf: state.armedWhistles.map(\.card))
            state.armedWhistles.removeAll()
            events.append(.whistlesDismissed)
        }
        if arriving.healsInjuriesOnArrival {
            for other in Seat.allCases where !state[other].injuries.isEmpty {
                healInjuries(of: other, state: &state)
            }
        }
        if arriving.barsVariaballs, state.ballCard != nil {
            setBall(nil, by: nil, state: &state, events: &events)
            events.append(.ballChanged(card: nil))
        }
        // Tri-hard Tiling: every hand over the limit is cut down to it, its owner's pick.
        if let limit = arriving.handLimit {
            for other in (seat?.clockwiseOrderFromHere ?? Seat.allCases)
            where state[other].bag.count > limit {
                state.owe(.tax(seat: other, count: state[other].bag.count - limit,
                               card: card.descriptor))
            }
        }
        // Carousel Court: whoever played it names the way the hands go round.
        if arriving.rotatesHands, let seat {
            state.pendingActor = seat
            state.phase = .awaitingTarget(seat: seat, card: card.descriptor,
                                          choices: [seat.left, seat.right])
        }
    }

    /// **A new ball, or none.** The old one goes to the pile and takes what rides on it —
    /// Blight Ball's pile, Monster Ball's Intangibles. `by` is the player who changed it,
    /// when a player did: Baller and Brawl Handler answer to their own hand only.
    private static func setBall(_ card: Card?, by seat: Seat?, state: inout GameState,
                                events: inout [GameEvent]) {
        let leaving = state.ballEffect
        // Read before the ball changes: a Monster Ball arriving swallows them.
        let brawls = seat.map { has($0, in: state, { $0.clearsTargetClampOnBallChange }) } ?? false
        // **Any change of ball, by anybody.** The rock is a shared object: somebody else
        // swapping it is still a ball changing hands in front of him.
        let ballerSeats = Seat.allCases.filter { holder in
            state[holder].intangibles.contains {
                ($0.intangible?.drawsOnBallChange ?? 0) > 0
                    && ($0.intangible?.drawsOnAnyBallChange == true || holder == seat)
            }
        }
        // **Splash Ball leaves the game rather than Retiring.** Nothing shuffles it back
        // and nothing digs it out; Splash Cousin is the only thing that ever puts it in
        // play, so a table gets exactly as many of them as it has cousins.
        if let replaced = state.ballCard,
           replaced.descriptor.variaball?.removedFromPlayWhenRetired != true {
            state.discard.append(replaced)
        }
        // Blight Ball leaving: whoever last had it is left holding the TOVs.
        state.pileCarrier = nil
        if leaving.absorbsIntangibles, !state.monsterBallIntangibles.isEmpty {
            state.intangibleBoard += state.monsterBallIntangibles
            state.monsterBallIntangibles = []
            state.owe(.intangibleBoards)
        }
        state.ballCard = card
        if let seat {
            clampEvent(.playingAnIntangibleOrChangingTheBall, on: [seat], state: &state,
                       events: &events)
        }
        let arriving = state.ballEffect
        if arriving.turnoversTravel { state.pileCarrier = state.ball ?? seat }
        if arriving.absorbsIntangibles {
            for other in Seat.allCases where !state[other].intangibles.isEmpty {
                for passive in state[other].intangibles {
                    events.append(.intangibleAbsorbed(seat: other, card: passive))
                }
                state.monsterBallIntangibles += state[other].intangibles
                state[other].intangibles.removeAll()
                clockCatchesUp(other, state: &state, events: &events)
            }
        }
        if !ballerSeats.isEmpty {
            drawTogether(ballerSeats, count: 1, state: &state, events: &events)
        }
        guard let seat else { return }
        if arriving.drawsOnArrival > 0 {
            drawTogether([seat], count: arriving.drawsOnArrival, state: &state, events: &events)
        }
        // **Brawl Handler names one.** Clamps are assignments now, so shrugging the whole
        // floor off belongs to Clear Out — this takes the man who is actually in the way.
        if brawls, let worst = worstClamp(on: seat, in: state) {
            state[seat].clamps.removeAll { $0.id == worst.id }
            events.append(.clampsShaken(seat: seat, card: CardLibrary.brawlHandler, count: 1))
        }
    }

    /// **The defender worth taking off**, for the cards that name one rather than clearing
    /// the floor: the biggest SHOT cost first, then whoever has actually bitten, then
    /// simply the first man standing there.
    static func worstClamp(on seat: Seat, in state: GameState) -> ActiveClamp? {
        state[seat].clamps.max {
            (($0.card.clamp?.shotDebuff ?? 0) * -1, $0.bitten ? 1 : 0)
                < (($1.card.clamp?.shotDebuff ?? 0) * -1, $1.bitten ? 1 : 0)
        }
    }

    /// **The Variaball card.** A random ball from the discards — from the deck when the
    /// discards have none — goes into the slot, never the one already there, and the card
    /// itself goes to the pile.
    private static func rollBall(_ card: Card, by seat: Seat, state: inout GameState,
                                 events: inout [GameEvent]) {
        state.discard.append(card)
        let current = state.currentBall?.id
        func eligible(_ candidate: Card) -> Bool {
            guard let effect = candidate.descriptor.variaball else { return false }
            return !effect.rollsFromDiscard && candidate.descriptor.id != current
        }
        var pool = state.discard.filter(eligible)
        let fromDeck = pool.isEmpty
        if fromDeck { pool = state.deck.filter(eligible) }
        guard !pool.isEmpty else { return }
        let chosen = pool[state.roll(0...(pool.count - 1))]
        if fromDeck {
            state.deck.removeAll { $0.id == chosen.id }
        } else {
            state.discard.removeAll { $0.id == chosen.id }
        }
        events.append(.ballChanged(card: chosen.descriptor))
        setBall(chosen, by: seat, state: &state, events: &events)
    }

    /// Every Injury off a player and onto the pile.
    private static func healInjuries(of seat: Seat, state: inout GameState) {
        state.discard.append(contentsOf: state[seat].injuries.map { Card($0) })
        state[seat].injuries.removeAll()
        state[seat].injuryUnlocked = []
    }

    /// SHOT as the log is allowed to say it. Dim Dome hides it from everyone, marked
    /// negative — see `GameEvent.shotText`.
    static func loggedShot(_ state: GameState) -> Int {
        state.floorEffect.hidesShot ? -1 : state.shot
    }

    /// Clear Out: he steps out of the play and the ball carries on the way it was going.
    ///
    /// **A pass nobody threw.** He does not pass it — he is simply not there, so the ball
    /// runs past him to the next man along, and everything the pass was carrying goes with
    /// it: the defenders that landed on him, and the credit for the pass, which still
    /// belongs to whoever actually threw it. The man who cleared out has done nothing but
    /// get out of the way, and a card that let him hand out an assist for that would be a
    /// pass with the risk taken off it.
    private static func clearOut(from seat: Seat, state: inout GameState,
                                 events: inout [GameEvent]) {
        // **Nowhere to carry on to is a ball on the floor.** A pass thrown *at* him and
        // stepped out of is not a play that continues — it is a pass to nobody, and it
        // belongs to whoever threw it.
        guard let onward = clearsTo(seat, in: state) else {
            guard let passer = state.lastPasser else { return }
            events.append(.clearedOut(seat: seat, to: nil))
            state[passer].turnovers += 1
            events.append(.turnover(passer, cause: CardLibrary.clearOut.name))
            stoppage(state: &state, events: &events)
            reinbound(by: passer, state: &state, events: &events)
            return
        }
        // Whatever was about to land on him lands on the man the ball went to — unless
        // somebody holds Gravity, and then it lands on him wherever the ball goes. Asked
        // before they bit, so there is nothing on him to carry, only a pile in the air.
        state.clampMagnet = gravityHolder(in: state) ?? onward
        let passer = state.lastPasser
        events.append(.clearedOut(seat: seat, to: onward))
        beginPossession(onward, tickClock: true, state: &state, events: &events)
        // Untouched. The man who threw it is still the man who threw it.
        state.lastPasser = passer
    }

    /// Where the ball goes when he is not there: on past him, the way it was travelling.
    ///
    /// Nil when there is nothing to carry on from — a ball that arrived from the sideline
    /// or off the glass was not going anywhere in particular, and a Clear Out with no
    /// through-line is a man stepping out of a play that was not happening. `legalMoves`
    /// reads this too, so the card greys out rather than being played into nothing.
    static func clearsTo(_ seat: Seat, in state: GameState) -> Seat? {
        guard let passer = state.lastPasser, passer != seat else { return nil }
        // **The card has to have been going somewhere.** Geometry alone said a Lob had a
        // through-line whenever it happened to land on a neighbour, and the ball carried
        // on past a man it had been aimed at.
        guard state.arrivedBy?.movesInADirection == true else { return nil }
        if passer.left == seat { return seat.left }
        if passer.right == seat { return seat.right }
        // Straight over, and nobody past him. A direction all the same — see
        // `movesInADirection` — but one that runs out of floor.
        return nil
    }

    /// Nothing has happened yet this possession — no Move played, no card at all.
    static func isFirstAction(_ state: GameState) -> Bool {
        state.movesThisPossession == 0 && state.lastPlayThisPossession == nil
    }

    /// The cards a Torn Achilles leaves you, rolled fresh for the turn.
    ///
    /// Picked once and kept, for the same reason a Clamp's lock is: a hand that reshuffles
    /// which cards are dead every time it is looked at cannot be played around.
    private static func rollInjuryLock(_ seat: Seat, state: inout GameState) {
        let allowed = state[seat].injuries.compactMap { $0.injury?.playableEachTurn }.min()
        guard let allowed else { state[seat].injuryUnlocked = []; return }
        var pool = state[seat].bag.map(\.id)
        var kept: [UUID] = []
        for _ in 0..<min(allowed, pool.count) {
            kept.append(pool.remove(at: state.roll(0...(pool.count - 1))))
        }
        state[seat].injuryUnlocked = kept
    }

    /// Whether anything this player is carrying locks their hand down.
    private static func handIsLocked(_ state: GameState, for seat: Seat) -> Bool {
        state[seat].injuries.contains { $0.injury?.playableEachTurn != nil }
    }

    /// Cards a Clamp is holding down: the ones it picked at random, plus everything a
    /// Trap forbids. Read by the hand so a held card looks held, and by nothing else —
    /// `legalMoves` refuses them on its own.
    static func lockedCards(_ state: GameState, for seat: Seat) -> Set<Card.ID> {
        var held = Set(state[seat].clamps.flatMap(\.locked))
        let clamps = state[seat].clamps.compactMap(\.card.clamp)
        if clamps.contains(where: \.shootOnly) {
            held.formUnion(state[seat].bag.map(\.id))
        }
        if clamps.contains(where: \.passOnly) {
            held.formUnion(state[seat].bag.filter { $0.descriptor.passTarget == nil }
                .map(\.id))
        }
        if clamps.contains(where: \.movesOnly) {
            held.formUnion(state[seat].bag.filter { !$0.descriptor.isMove }.map(\.id))
        }
        return held
    }

    /// A seat may bid anywhere from nothing up to its whole bag.
    static func legalReboundBid(_ state: GameState, for seat: Seat) -> ClosedRange<Int> {
        // A Free Agent has nothing of his own to throw at a board. He is in on the ones
        // nobody contests and out of every other — which is the simplest honest answer to
        // a player whose hand is other people's.
        guard !has(seat, in: state, { $0.playsFromOthers }) else { return 0...0 }
        return 0...state[seat].bag.count
    }

    // MARK: - Applying moves

    @discardableResult
    static func apply(_ move: Move, by seat: Seat, to state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        switch move {
        case .inbound(let target):
            guard case .inbound(let inbounder) = state.phase, inbounder == seat,
                  target != seat, target != state.inboundBarred else { return [] }
            state.inboundBarred = nil
            state.ball = target
            events.append(.inbounded(from: seat, to: target))
            // A fresh round comes in with no clock and gets one. A throw-in inside a round
            // — a Whistle's, a turnover's — is handed a clock that is already running.
            if state.shotClock == nil {
                state.shotClock = state.shotClockLength
                events.append(.shotClockSet(state.shotClockLength))
            }
            // An inbound is not a pass: it grants no SHOT and no assist credit.
            beginPossession(target, tickClock: false, state: &state, events: &events)

        case .borrow(let owner):
            guard case .possession(let holder) = state.phase, holder == seat,
                  has(seat, in: state, { $0.playsFromOthers }) else { return [] }
            // A target, so Floor General aims it — and the hand is shuffled the moment it
            // is named, which is what makes taking one at random a real gamble rather
            // than a memory test.
            let aiming = asker(instead: seat, in: state)
            guard aiming == seat else {
                state.pendingActor = seat
                state.phase = .awaitingTarget(seat: aiming, card: CardLibrary.freeAgent,
                                              choices: Seat.allCases.filter { $0 != seat })
                return []
            }
            return borrow(from: owner, by: seat, state: &state)

        case .play(let cardID):
            guard case .possession(let holder) = state.phase, holder == seat,
                  let index = state[seat].bag.firstIndex(where: { $0.id == cardID })
            else { return [] }
            // **A Clamp says who it is on before anything else happens.** Asked first,
            // because the officials who judge a Clamp judge its victim — and the man
            // playing it is not him. Answering replays this with the target set.
            if state[seat].bag[index].descriptor.clamp != nil, state.clampTarget == nil,
               legalMoves(state, for: seat).contains(.play(cardID)) {
                let choices = clampTargets(for: seat, in: state)
                guard !choices.isEmpty else { return [] }
                state.assigningClamp = cardID
                state.pendingActor = seat
                state.phase = .awaitingTarget(seat: asker(instead: seat, in: state),
                                              card: state[seat].bag[index].descriptor,
                                              choices: choices)
                return []
            }
            // **A card that names a man asks for him first** — a Pass to a chosen player, a
            // Cut. Asked before anything happens, so it can be cancelled with nothing to
            // undo. Only the player's own question: Floor General's is asked where it
            // always was.
            if state.aimedCard != cardID, state.aimingCard == nil,
               asker(instead: seat, in: state) == seat,
               let choices = aimChoices(state[seat].bag[index].descriptor, by: seat),
               legalMoves(state, for: seat).contains(.play(cardID)) {
                guard !choices.isEmpty else { return [] }
                state.aimingCard = cardID
                state.pendingActor = seat
                state.phase = .awaitingTarget(seat: seat, card: state[seat].bag[index].descriptor,
                                              choices: choices)
                return []
            }
            // **The rules are the rules here, not only in the hand that draws them.**
            // `legalMoves` is what bars a card — a Clamp holding it down, Triple Threat
            // closing the book on Moves, a Lob owing a shot — and this took any card in
            // the bag on trust. The floor greys them out and a finger cannot reach one,
            // so nothing a player did ever showed it; the opponents ask for a card
            // without asking the rules, and they played straight through every one of
            // those bars. Lob forced nothing in three of every four it found.
            guard legalMoves(state, for: seat).contains(.play(cardID)) else { return [] }
            // Declared but not yet resolved — a Whistle gets to speak here.
            let declared = state[seat].bag[index]
            if let whistle = interceptor(of: .playCard(seat: seat, card: declared), in: &state) {
                // **His one challenge, offered before the call lands.** Only here and on a
                // shot: those are the two places a player is doing something and a call can
                // take it away, and the two where stopping to ask costs nothing because
                // the play already returns.
                if offerChallenge(whistle, on: .playCard(seat: seat, card: declared),
                                  state: &state) {
                    return events
                }
                // Negating the effect, not the activation: the Clamp is allowed to be
                // played and to resolve. The Whistle waits for those defenders to try to
                // land, because until then there is no clamped player to name.
                if whistle.card.descriptor.whistle?.voidsClampOnLanding == true,
                   declared.descriptor.clamp != nil {
                    state.pendingClampVoid = whistle.id
                } else {
                    let stands = whistle.card.descriptor.whistle?.cancelsCard == false
                    blow(whistle, on: .playCard(seat: seat, card: declared),
                         state: &state, events: &events)
                    // **A call that does not cancel lets the card carry on.** Technical
                    // Foul, Blocking Foul and a Flagrant II all penalise the play rather
                    // than stopping it, and returning here left the card in the hand with
                    // nothing resolved — so the opponent played it again, and again. Only
                    // carry on if the call left him with the ball and something to do.
                    guard stands, case .possession(let still) = state.phase, still == seat,
                          state[seat].bag.contains(where: { $0.id == declared.id })
                    else { return events }
                }
            }
            resolvePlay(cardID, by: seat, state: &state, events: &events)

        case .shoot:
            return apply(.shootAs(.layup), by: seat, to: &state)

        case .shootAs(let finish):
            guard case .possession(let holder) = state.phase, holder == seat else { return [] }
            // A defender walking him into one finish takes the others away.
            if let forced = forcedShotType(on: seat, in: state), forced != finish { return [] }
            guard finish.available(to: seat, in: state) else { return [] }
            state.shotType = finish
            // Rhythm Dribble's extra, when this shot is the very next thing.
            let carried = state.nextShotBonus + (finish == .three ? state.nextThreeBonus : 0)
            state.nextShotBonus = 0
            state.nextThreeBonus = 0
            // **Nothing left to hold, so he is already at the rim.** The one place being
            // broke pays: an empty hand puts a layup up at a look nobody else gets.
            let emptyHanded = finish == .layup && state[seat].bag.isEmpty
                ? ShotType.emptyHandedLayupBonus : 0
            // **A call that takes the point rather than the shot.** Foot On The Line says
            // the three scores two instead, so it is blown for the scene and the ball
            // still goes up — everything else on this trigger waves the attempt off, and
            // returning on all of them meant this one cancelled a shot its own face says
            // it allows.
            var downgraded = false
            if let whistle = interceptor(of: .shoot(seat: seat), in: &state) {
                if offerChallenge(whistle, on: .shoot(seat: seat), state: &state) {
                    return events
                }
                downgraded = whistle.card.descriptor.whistle?.downgradesThree == true
                blow(whistle, on: .shoot(seat: seat), state: &state, events: &events)
                guard downgraded, case .possession(let still) = state.phase, still == seat
                else { return events }
            }
            if finish == .three { splashIn(by: seat, state: &state, events: &events) }
            state.pendingShotBonus += carried + emptyHanded
            // **Dishtracting Ball: it costs a card to go up with.** Asked before the ball
            // leaves his hands, and the attempt is owed until he has answered — paying a
            // step is what puts it up, so nothing here re-enters this branch and asks
            // twice. See `Step.shootAtOnce`.
            if state.ballEffect.shooterDiscards > 0, !state[seat].bag.isEmpty,
               let ball = state.currentBall {
                state.pendingBonusPoint += extraPoint(for: finish, downgraded: downgraded)
                state.owe(.shootAtOnce(seat))
                state.phase = .awaitingGiveUp(seat: seat, card: ball,
                                              count: min(state.ballEffect.shooterDiscards,
                                                         state[seat].bag.count))
                return events
            }
            resolveShot(by: seat, bonusPoints: extraPoint(for: finish, downgraded: downgraded),
                        state: &state, events: &events)

        case .shootAtOffer:
            guard case .possession(let holder) = state.phase, holder == seat,
                  let offer = state.shotOffer(for: seat) else { return [] }
            let carried = state.nextShotBonus
            state.nextShotBonus = 0
            if let whistle = interceptor(of: .shoot(seat: seat), in: &state) {
                blow(whistle, on: .shoot(seat: seat), state: &state, events: &events)
                return events
            }
            state.passiveShotOverride = offer
            state.pendingShotBonus += carried
            // Equalizer is spent putting the shot up, and levels the points if it goes in.
            if let passive = state[seat].intangibles.first(where: { $0.name == offer.label }),
               let effect = passive.intangible {
                if effect.spentOnOffer {
                    state[seat].intangibles.removeAll { $0.id == passive.id }
                    state.discard.append(Card(passive))
                }
                if effect.levelsPointsOnMake { state.levelsPointsFor = seat }
            }
            resolveShot(by: seat, bonusPoints: 0, state: &state, events: &events)

        case .playAsTwo(let cardID):
            guard legalMoves(state, for: seat).contains(.playAsTwo(cardID)) else { return [] }
            // The card plays exactly as it would, and the shot it takes reads this.
            state.sellingOut = true
            let played = apply(.play(cardID), by: seat, to: &state)
            if played.isEmpty { state.sellingOut = false }
            return played

        case .handOffClamp(let clampID, let target):
            guard handOffTargets(state, for: seat).contains(target),
                  let at = state[seat].clamps.firstIndex(where: { $0.id == clampID })
            else { return [] }
            // On to him, and it bites when his possession opens — whatever it held down on
            // this man is his own again.
            var clamp = state[seat].clamps.remove(at: at)
            clamp.bitten = false
            clamp.locked = []
            state[target].clamps.append(clamp)
            events.append(.clampHandedOff(from: seat, to: target, card: clamp.card))

        case .exchangeWithRetirement:
            let options = exchangeOptions(state, for: seat)
            guard !options.isEmpty else { return [] }
            state.pendingActor = seat
            state.pendingPlay = nil
            state.phase = .awaitingRetiredPick(seat: seat, card: CardLibrary.varsitile,
                                               choices: options.map(\.id))
            return events
        }
        takeTheLine(state: &state, events: &events)
        // A card that draws can turn up a Game Break, and a Break can hand the ball over.
        // `beginPossession` catches the ones drawn at the top of a possession; this
        // catches the ones a play turned up mid-possession.
        handOverBall(state: &state, events: &events)
        // The outermost edge of the chain, which is where a queued hand is finally owed.
        settleHands(state: &state, events: &events)
        return events
    }

    // MARK: - Free throws

    /// Queues a trip to the line. Deliberately does not touch `phase`.
    ///
    /// A Foul is drawn from inside `draw`, which runs in the middle of `beginPossession`
    /// — any phase set there is overwritten the moment the draw returns. Queuing here and
    /// converting in `takeTheLine` is what keeps the two from fighting.
    private static func awardFreeThrows(_ count: Int, to seat: Seat, offender: Seat?,
                                        source: String, endsPossession: Bool = false,
                                        thenRebound: Seat? = nil,
                                        state: inout GameState, events: inout [GameEvent]) {
        guard count > 0 else { return }

        // A second foul before the first has been shot just lengthens the trip.
        if let at = state.pending.firstIndex(where: {
            if case .takeTheLine(let trip) = $0 { return trip.shooter == seat }
            return false
        }), case .takeTheLine(var trip) = state.pending[at] {
            trip.remaining += count
            // A called foul on top of a card's trip still ends the possession: the
            // whistle went, whatever else put him there first.
            trip.endsPossession = trip.endsPossession || endsPossession
            state.pending[at] = .takeTheLine(trip)
            events.append(.freeThrowsAwarded(seat: seat, count: count, source: source))
            stoppage(state: &state, events: &events)
            return
        }

        // Generational Whistle pays once per trip, not once per attempt.
        let bonus = state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.bonusFreeThrows ?? 0) }
        state.owe(.takeTheLine(FreeThrowTrip(shooter: seat, offender: offender,
                                             source: source,
                                             endsPossession: endsPossession,
                                             remaining: count + bonus,
                                             thenRebound: thenRebound)))
        events.append(.freeThrowsAwarded(seat: seat, count: count + bonus, source: source))
        stoppage(state: &state, events: &events)
        if bonus > 0, let card = state[seat].intangibles.first(where: {
            ($0.intangible?.bonusFreeThrows ?? 0) > 0
        }) {
            events.append(.freeThrowBonus(seat: seat, count: bonus, card: card))
        }
    }

    /// Hands the floor over to a waiting trip, once the phase has settled.
    /// Whatever a Game Break queued up while the possession was being built.
    ///
    /// Called after `beginPossession` has set the phase, for the same reason the trip to
    /// the line is: anything set from inside it is set on something about to be replaced.
    private static func handOverBall(state: inout GameState, events: inout [GameEvent]) {
        guard case .handOverBall(let holder)? = state.owes(.handOverBall),
              !state.isOver else { return }
        state.forget(.handOverBall)
        // **A break in the loop.** Something has taken the ball off the floor and put it
        // back in — Benched hands it to whoever the benched man picks, and a Whistle can
        // do the same — and a Right Back still owed a return would drag it out of his
        // hands again the moment the possession opened. Whatever queued this outranks a
        // leg that was owed to a play the break has already interrupted.
        state.forget(.returnBall)
        state.inbounder = holder
        state.phase = .inbound(inbounder: holder)
    }

    private static func takeTheLine(state: inout GameState, events: inout [GameEvent]) {
        guard case .takeTheLine(let trip)? = state.owes(.takeTheLine),
              !state.isOver else { return }
        state.forget(.takeTheLine)
        state.phase = .freeThrows(trip: trip)
    }

    /// What an opponent shoots. The player shoots theirs by hand.
    static func rollFreeThrow(state: inout GameState) -> Bool {
        state.roll(1...100) <= state.rules.freeThrowChance
    }

    /// Banks one attempt and, when the trip runs out, gives the ball back.
    @discardableResult
    static func resolveFreeThrow(made: Bool, state: inout GameState) -> [GameEvent] {
        guard case .freeThrows(var trip) = state.phase else { return [] }
        var events: [GameEvent] = []

        trip.attempted += 1
        trip.remaining -= 1
        if made {
            trip.made += 1
            let points = state.rules.freeThrowPoints
            state[trip.shooter].points += points
            state[trip.shooter].scoredThisRound = true
            events.append(.freeThrowMade(seat: trip.shooter, points: points,
                                         index: trip.attempted, of: trip.total))
        } else {
            events.append(.freeThrowMissed(seat: trip.shooter,
                                           index: trip.attempted, of: trip.total))
            // **Liar Ball: it says that one did not count.** `total` is `attempted +
            // remaining`, so handing the attempt back grows the trip on its own and the
            // banner reads 2 of 2 rather than a second 1 of 1.
            if state.ballEffect.retakesMissedFreeThrow, !trip.retaken {
                trip.retaken = true
                trip.remaining += 1
            }
        }

        guard trip.remaining <= 0 else {
            state.phase = .freeThrows(trip: trip)
            return events
        }
        events.append(.freeThrowsEnded(seat: trip.shooter, made: trip.made, of: trip.total))

        // Every miss is a dead ball, so a trip never becomes a rebound.
        //
        // **Whether it also ends the possession is the trip's own answer.** A called foul
        // does: the offender hands it back in and the round does not advance. A trip a
        // card handed out does not — play picks up where it left off, with two shots in
        // the middle of it. See `FreeThrowTrip.endsPossession`.
        // Make-or-Take Ball: the miss it followed is still waiting to be rebounded.
        if let shooter = trip.thenRebound {
            state.phase = .awaitingRebound(shooter: shooter)
            return events
        }
        if trip.endsPossession, let offender = trip.offender {
            reinbound(by: offender, state: &state, events: &events)
        } else if let holder = state.ball {
            state.phase = .possession(holder: holder)
        } else {
            reinbound(by: trip.shooter, state: &state, events: &events)
        }
        takeTheLine(state: &state, events: &events)
        settleHands(state: &state, events: &events)
        return events
    }

    /// How many a seat may feed a Turnaround Three.
    static func legalDiscardForShot(_ state: GameState, for seat: Seat) -> ClosedRange<Int> {
        var most = state[seat].bag.count
        guard case .awaitingDiscard(_, let card, _) = state.phase else { return 0...most }
        // Stepback buys one extra look, not as many as the hand will pay for.
        if card.optionalDiscardForShot > 0 { most = min(most, 1) }
        // The Future buys a three up to four with one card, no more.
        if state.fourPointOffer { most = min(most, 1) }
        // 2-Hand Jam: two, unless its bonus has opened up the rest of the hand.
        if let limit = card.special?.discardForShotLimit, !discardsPastLimit(card, in: state) {
            most = min(most, limit)
        }
        return 0...most
    }

    /// 2-Hand Jam's bonus: straight off your own board, as the first thing you do with it,
    /// any number of cards may go in past the limit.
    static func discardsPastLimit(_ card: CardDescriptor, in state: GameState) -> Bool {
        (card.special?.discardBeyondLimitBonus ?? 0) > 0
            && state.possessionFromOwnRebound && isFirstAction(state)
    }

    /// **What discarding this many buys**: the card's price for each up to its limit, and
    /// the beyond price past it. Dishcount Ball counts one card extra, free.
    static func shotBought(discarding count: Int, card: CardDescriptor, bonusEach: Int,
                           in state: GameState) -> Int {
        let paid = count + (state.ballEffect.discountsDiscards ? 1 : 0)
        guard let limit = card.special?.discardForShotLimit else { return bonusEach * paid }
        let beyond = card.special?.discardBeyondLimitBonus ?? 0
        return bonusEach * min(paid, limit) + beyond * max(0, paid - limit)
    }

    /// **The pass leaving the hand**, once anything the card asked first is answered: who it
    /// goes to — asked, or worked out — and then the pass itself. True when the play stops
    /// here: a question asked, or the ball gone some other way.
    private static func throwPass(_ descriptor: CardDescriptor, target: PassTarget,
                                  from seat: Seat,
                                  state: inout GameState, events: inout [GameEvent]) -> Bool {
        // Somebody has to name the man. Floor General names him for everybody,
        // which is the whole of what it does — so if it is on the floor, the ask
        // goes to them instead.
        var named: Seat?
        if target == .choice || target == .leftOrRight {
            // Named already, before the card was played — see `aimingCard`.
            if let aim = state.currentAim {
                state.currentAim = nil
                named = aim
            } else {
                state.pendingPlay = descriptor
                state.phase = .awaitingTarget(seat: asker(instead: seat, in: state),
                                              card: descriptor,
                                              choices: passChoices(target, from: seat,
                                                                   othersOnly: descriptor.passesToOthersOnly))
                state.pendingActor = seat
                return true
            }
        }
        guard let receiver = named ?? resolve(target, from: seat, state: state) else {
            // Behind-the-Back with nobody behind: a live-ball turnover.
            state[seat].turnovers += 1
            events.append(.failedReturn(seat: seat))
            events.append(.turnover(seat, cause: descriptor.name))
            stoppage(state: &state, events: &events)
            endRound(state: &state, events: &events)
            return true
        }
        // **The draw resolves before the ball moves.** Point God queues the pass
        // and pays first, so a Game Break turned up by that card plays out in
        // full — and lands on the man who passed, which is who earned it — before
        // anybody else has the ball.
        let earned = state[seat].intangibles.reduce(0) {
            $0 + ($1.intangible?.drawAfterPass ?? 0)
        }
        if earned > 0 {
            drawTogether([seat], count: earned, state: &state, events: &events)
        }
        // Read again: the draw may have turned up a Break that moved it.
        guard case .possession(let stillHolding) = state.phase,
              stillHolding == seat else { return true }

        completePass(descriptor, from: seat, to: receiver, state: &state, events: &events)
        return false
    }

    /// **A Cut with its man known.** L-Cut's "You may" is asked before the ball goes.
    private static func aimCut(_ descriptor: CardDescriptor, by actor: Seat, at target: Seat,
                               state: inout GameState, events: inout [GameEvent]) {
        let choices = retirementChoices(descriptor, by: actor, in: state)
        if !choices.isEmpty {
            state.cutReceiver = target
            state.pendingPlay = descriptor
            state.pendingActor = actor
            state.phase = .awaitingRetirement(seat: asker(instead: actor, in: state),
                                              card: descriptor, choices: choices)
            return
        }
        cutPass(descriptor, from: actor, to: target, state: &state, events: &events)
    }

    /// **The ball and the defenders, to the man named.** A pass in every way but the card.
    private static func cutPass(_ descriptor: CardDescriptor, from seat: Seat, to receiver: Seat,
                                state: inout GameState, events: inout [GameEvent]) {
        for clamp in state[seat].clamps {
            events.append(.clampHandedOff(from: seat, to: receiver, card: clamp.card))
        }
        state.passAssignsClamps = true
        completePass(descriptor, from: seat, to: receiver, state: &state, events: &events)
    }

    /// Everything a pass does once its man is known.
    ///
    /// Shared, because a pass that names its target geometrically and one that had to be
    /// asked about are the same pass — only the question in front of them differs.
    private static func completePass(_ descriptor: CardDescriptor, from seat: Seat,
                                     to receiver: Seat, returning: Bool = false,
                                     state: inout GameState, events: inout [GameEvent]) {
        // What the passer said yes to, spent on this pass and no other.
        let takesBall = state.passTakesBall
        let flipsCoin = state.passFlipsCoin
        let assignsClamps = state.passAssignsClamps
        state.passTakesBall = false
        state.passFlipsCoin = false
        state.passAssignsClamps = false
        // Outlet Pass runs the clock the other way: it hands a tick back instead of
        // costing one, so the possession must not take its own.
        if descriptor.replacesClockTick {
            _ = tickClock(by: descriptor.clockDelta, holder: seat,
                          state: &state, events: &events)
        }
        if descriptor.upgradesToThree { state.pendingBonusPoint = 1 }
        state.lastPasser = seat
        state.arrivedBy = descriptor
        // Blaze Ball and Snow Ball: every pass, on its own terms.
        if state.ballEffect.shotPerPass != 0 {
            adjustShot(by: state.ballEffect.shotPerPass, state: &state)
        }
        // The Future: passing costs.
        if state.floorEffect.shotPerPass != 0 {
            adjustShot(by: state.floorEffect.shotPerPass, state: &state)
        }
        // Lob: the Ball out of play and into the passer's hand, as it leaves him.
        if takesBall, let ball = state.ballCard {
            setBall(nil, by: seat, state: &state, events: &events)
            state.discard.removeAll { $0.id == ball.id }
            state[seat].bag.append(ball)
            events.append(.ballChanged(card: nil))
        }
        // No-Look: a coin as it goes. Heads is a card for the passer.
        if flipsCoin {
            let heads = state.roll(0...1) == 1
            events.append(.coinRun(seat: seat, card: descriptor, heads: heads ? 1 : 0))
            if heads {
                drawOnce(seat, state: &state, events: &events)
                guard case .possession(let stillHolding) = state.phase,
                      stillHolding == seat else { return }
            }
        }
        state.passesThisRound += 1
        events.append(.passed(card: descriptor, from: seat, to: receiver,
                              shot: loggedShot(state), returning: returning))
        // A Cut takes the defenders with it rather than beating them.
        if descriptor.cut == nil {
            clampEvent(.passingTheBall, on: [seat], passingTo: receiver, state: &state,
                       events: &events)
        }
        if !returning {
            switch descriptor.cut?.receiverMust {
            case .pass: state.mustPassFirst = receiver
            case .shoot: state.mustShootFirst = receiver
            case .move: state.mustMoveFirst = receiver
            case nil: break
            }
        }
        if returning, let bonus = descriptor.cut?.threeBonusOnReturn, bonus > 0 {
            state.nextThreeBonus = bonus
        }
        if descriptor.bonusAssistOnScore { state.dimeFrom = seat }
        if descriptor.offersClockReset, !returning { state[seat].mayResetShotClock = true }
        if descriptor.forcesReceiverShot { state.mustShootFirst = receiver }
        if descriptor.forcesImmediateShot { state.owe(.shootAtOnce(receiver)) }
        // **Only on the way out.** The return leg must not ask for another one, or the
        // ball never stops. Asked of the leg itself rather than of what is owed, which
        // the drain has already popped by the time it sends the ball home — so the guard
        // was reading nil and arming a second trip every time.
        if descriptor.returnsImmediately || descriptor.cut?.passedBack == true, !returning {
            state.owe(.returnBall(to: seat, leg: descriptor))
        }
        // **Off the glass and back to himself.** A new possession like any other — he
        // draws, the clock runs, the SHOT the card added stands. Unless it is Traveling,
        // which it is for everybody but the man who moves at his own pace, and which is
        // called before the possession opens rather than after he has been dealt into it.
        if receiver == seat, !has(seat, in: state, { $0.ignoresViolations }) {
            state[seat].turnovers += 1
            events.append(.turnover(seat, cause: CardLibrary.travel.name))
            stoppage(state: &state, events: &events)
            endRound(state: &state, events: &events)
            return
        }
        // Hand Ball: the hands swap with the ball.
        if state.ballEffect.swapsHandsOnPass {
            let passing = state[seat].bag
            state[seat].bag = state[receiver].bag
            state[receiver].bag = passing
            events.append(.handsTraded(seat: seat, with: receiver))
        }
        // Kick-Out: whoever was guarding the passer follows the ball, and bites again when the
        // receiver's possession opens.
        if assignsClamps, !state[seat].clamps.isEmpty {
            let following = state[seat].clamps.map { clamp -> ActiveClamp in
                var moved = clamp
                moved.bitten = false
                moved.locked = []
                return moved
            }
            state[seat].clamps.removeAll()
            state[receiver].clamps = Array((state[receiver].clamps + following)
                .suffix(state.rules.clampSlots))
        }
        // Bench Ball: caught off a pass, and straight to the inbound — no draw and no turn.
        // The Clamps in the air land on whoever he throws it to.
        if state.ballEffect.benchesReceiver {
            events.append(.benched(receiver))
            state.ball = nil
            state.lastPasser = nil
            state.arrivedBy = nil
            state.pendingBonusPoint = 0
            state.mustShootFirst = nil
            state.mustPassFirst = nil
            state.mustMoveFirst = nil
            state.forget(.returnBall, .shootAtOnce)
            state.inbounder = receiver
            state.phase = .inbound(inbounder: receiver)
            return
        }
        // Jammed Finger: the catch costs a card.
        let jammed = state[receiver].injuries.reduce(0) {
            $0 + ($1.injury?.discardsOnReceivingPass ?? 0)
        }
        if jammed > 0, let finger = state[receiver].injuries.first(where: {
            ($0.injury?.discardsOnReceivingPass ?? 0) > 0
        }) {
            for _ in 0..<jammed { discardAtRandom(from: receiver, state: &state) }
            events.append(.clampBit(seat: receiver, card: finger, discarded: jammed))
        }
        beginPossession(receiver, tickClock: !descriptor.replacesClockTick,
                        state: &state, events: &events)

        // **A question standing does not cancel what the pass still owes.** A Clamp
        // landing on the catch puts a counter up, and Bullet's card was simply never
        // taken — so the toll is owed and drained once the question is answered.
        if descriptor.receiverDiscards > 0 || descriptor.stealsAlongPass > 0 {
            let settled = { if case .possession(let who) = state.phase { return who == receiver }
                            return false }()
            if !settled, !state[receiver].bag.isEmpty {
                state.owe(.takeFromReceiver(passer: seat, receiver: receiver, card: descriptor))
            }
        }
        // Everything below is about the possession the pass opened. If the draw at the top
        // of it handed the ball on — or the clock ran out on a hand he cannot play — there
        // is no such possession to charge.
        guard case .possession(let landed) = state.phase, landed == receiver else { return }

        // Franchise Player: the man who took the pass gives something up for it. Asked
        // ahead of the other two, because it is the pass itself that costs him.
        if has(seat, in: state, { $0.passCostsTarget }),
           !state[receiver].bag.isEmpty || !state[receiver].intangibles.isEmpty {
            state.pendingActor = seat
            state.phase = .awaitingToll(seat: asker(instead: seat, in: state),
                                        victim: receiver)
            return
        }

        // Asked after the possession opens, so the card he was just dealt is in the hand
        // being picked from — a hand that changed size between the question and the
        // answer is a hand the picker was lied to about.
        // Misdirection knocks one loose as the ball goes past, the way Nutmeg does.
        let forcing = descriptor.stealsAlongPass > 0 || state.misdirected
        state.misdirected = false
        if forcing, !state[receiver].bag.isEmpty {
            // Curl Cut: it comes back to the man who cut.
            state.stealTravelsTo = descriptor.cut?.forcesToPasser == true
                ? seat
                : seat.seat(inDirection: .left) == receiver ? receiver.left : receiver.right
            state.pendingActor = seat
            state.phase = .awaitingCardFrom(seat: asker(instead: seat, in: state),
                                            card: descriptor, victim: receiver)
            forceAtRandom(descriptor, from: receiver, state: &state, events: &events)
        } else if descriptor.receiverDiscards > 0, !state[receiver].bag.isEmpty {
            // Bullet Pass: it goes in hard and something drops — **the passer's pick**, face
            // down (2026-09-14). Asked after the possession opens, like Nutmeg's.
            state.pendingActor = seat
            state.phase = .awaitingCardFrom(seat: asker(instead: seat, in: state),
                                            card: descriptor, victim: receiver)
        }
    }

    /// The man named, and the card that asked doing what it does with him.
    @discardableResult
    static func resolveTarget(_ target: Seat, state: inout GameState) -> [GameEvent] {
        guard case .awaitingTarget(_, let descriptor, let choices) = state.phase,
              let actor = state.pendingActor, choices.contains(target) else { return [] }
        var events: [GameEvent] = []
        state.pendingPlay = nil
        state.pendingActor = nil
        state.phase = .possession(holder: actor)

        // **A Clamp being assigned**: the man is named, and the card is played with him
        // known — so the crew judges the right person. It stays on him, waiting, until he
        // next has the ball; pass to him to set it off now, or to anybody else and leave
        // it for later.
        if let clampCard = state.assigningClamp {
            state.assigningClamp = nil
            state.clampTarget = target
            let played = apply(.play(clampCard), by: actor, to: &state)
            state.clampTarget = nil
            return played
        }

        // **A card aimed before it was played**: now it is played, at him.
        if let aiming = state.aimingCard {
            state.aimingCard = nil
            state.aimedCard = aiming
            state.aimedTarget = target
            return apply(.play(aiming), by: actor, to: &state)
        }

        // **A Cut, with its man named.**
        if descriptor.cut != nil {
            aimCut(descriptor, by: actor, at: target, state: &state, events: &events)
            settleHands(state: &state, events: &events)
            return events
        }

        // Carousel Court: the way round, declared by whoever played it.
        if descriptor.varena?.rotatesHands == true {
            state.carouselClockwise = target == actor.left
            settleHands(state: &state, events: &events)
            return events
        }
        if let effect = descriptor.gameBreak, effect.healsChosenInjury {
            if let injury = state[target].injuries.first {
                state[target].injuries.removeFirst()
                state[target].injuryUnlocked = []
                state.discard.append(Card(injury))
            }
            // Looking after somebody else is the half of it that pays.
            if target != actor {
                drawTogether([actor], count: effect.drawsForHealingAnother,
                          state: &state, events: &events)
            }
            state.phase = .possession(holder: state.ball ?? actor)
            settleHands(state: &state, events: &events)
            return events
        }
        if descriptor.gameBreak?.rotatesHands == true {
            rotate(towards: target, from: actor, state: &state, events: &events)
            return events
        }
        if descriptor.gameBreak?.fightsChosenPlayer == true {
            // Both men lose something in it, and the ball goes back in to somebody else.
            discardAtRandom(from: actor, state: &state)
            discardAtRandom(from: target, state: &state)
            reinbound(by: actor, state: &state, events: &events)
            state.inboundBarred = target
            return events
        }
        if descriptor.targetDiscards > 0 {
            guard !state[target].bag.isEmpty else {
                events.append(.movePlayed(seat: actor, card: descriptor, shot: loggedShot(state)))
                state.lastPlayThisPossession = descriptor.id
                state.movesThisPossession += 1
                return events
            }
            state.pendingPlay = descriptor
            state.pendingActor = actor
            state.phase = .awaitingCardFrom(seat: asker(instead: actor, in: state),
                                           card: descriptor, victim: target)
            return events
        }
        completePass(descriptor, from: actor, to: target, state: &state, events: &events)
        settleHands(state: &state, events: &events)
        return events
    }

    /// The branch chosen, and the card resolving as that branch.
    @discardableResult
    static func resolveMode(_ index: Int, state: inout GameState) -> [GameEvent] {
        // Bounds-checked by hand: the `safe:` subscript lives in the view layer, and the
        // rules module deliberately imports none of it.
        guard case .awaitingMode(let asked, let descriptor) = state.phase,
              index >= 0, index < descriptor.modes.count else { return [] }
        let mode = descriptor.modes[index]
        // **Whoever played it, not whoever answered.** These are two different seats the
        // moment anything speaks for somebody else, and this read the answering one for
        // all of it — so a card played out of one hand drew for another man, passed from
        // his seat, handed him the ball and went into the log under his name.
        let actor = state.pendingActor ?? asked
        var events: [GameEvent] = []
        state.pendingPlay = nil
        state.pendingActor = nil
        state.phase = .possession(holder: actor)

        if mode.shotDelta != 0 { adjustShot(by: mode.shotDelta, state: &state) }
        if mode.draws > 0 { drawTogether([actor], count: mode.draws, state: &state, events: &events) }
        if let passes = mode.passes {
            state.pendingPlay = descriptor
            state.pendingActor = actor
            // The pass leaves his seat, and *that* is a target, so a Floor General names it.
            state.phase = .awaitingTarget(seat: asker(instead: actor, in: state),
                                          card: descriptor,
                                          choices: passChoices(passes, from: actor,
                                                               othersOnly: descriptor.passesToOthersOnly))
            return events
        }
        events.append(.movePlayed(seat: actor, card: descriptor, shot: loggedShot(state)))
        state.lastPlayThisPossession = descriptor.id
        state.movesThisPossession += 1
        settleHands(state: &state, events: &events)
        return events
    }

    /// One card out of somebody else's bag, played, and handed back.
    ///
    /// **It goes back.** The card is theirs; the Free Agent has no bag to spend from and
    /// nothing of his own to lose, so borrowing costs its owner nothing but the tempo. It
    /// is the one card in the game that is not spent when it is played.
    private static func borrow(from owner: Seat, by seat: Seat,
                               state: inout GameState) -> [GameEvent] {
        guard !state[owner].bag.isEmpty else { return [] }
        state[owner].bag = state.shuffled(state[owner].bag)
        let taken = state[owner].bag.removeFirst()
        // Lent into his hands so the ordinary play path can run, and put back after.
        state[seat].bag.append(taken)
        var events = apply(.play(taken.id), by: seat, to: &state)
        state[seat].bag.removeAll { $0.id == taken.id }
        state.discard.removeAll { $0.id == taken.id }
        state[owner].bag.append(taken)
        events.append(.drew(seat: owner, card: taken.descriptor, id: taken.id))
        return events
    }

    /// The rotation, once a direction has been named.
    ///
    /// Everything moves one seat that way — every bag, and the ball with it. The bags go
    /// first so the man the ball lands on is holding the hand that came with it.
    private static func rotate(towards target: Seat, from seat: Seat,
                               state: inout GameState, events: inout [GameEvent]) {
        let clockwise = seat.left == target
        var bags: [Seat: [Card]] = [:]
        for other in Seat.allCases {
            let onward = clockwise ? other.left : other.right
            bags[onward] = state[other].bag
        }
        for (owner, cards) in bags { state[owner].bag = cards }
        if let ball = state.ball {
            let onward = clockwise ? ball.left : ball.right
            state.ball = onward
            state.phase = .possession(holder: onward)
            events.append(.turnover(ball, cause: "Trade Deadline"))
            stoppage(state: &state, events: &events)
        }
    }

    /// One more man named, or the naming closed and the shot going up.
    ///
    /// Each is worth SHOT and each is owed an assist, so the two halves of the card are
    /// the same list read twice — once now and once if it drops.
    @discardableResult
    static func resolveNaming(_ named: Seat?, state: inout GameState) -> [GameEvent] {
        guard case .awaitingNaming(let asked, let descriptor, let sofar) = state.phase,
              let shooter = state.pendingActor else { return [] }
        var events: [GameEvent] = []

        if let named, named != shooter, !sofar.contains(named) {
            let now = sofar + [named]
            state.namedForAssist = now
            state.phase = .awaitingNaming(seat: asked, card: descriptor, named: now)
            return events
        }

        // Nobody else. The shot is worth what the list came to.
        state.pendingPlay = nil
        state.pendingActor = nil
        state.phase = .possession(holder: shooter)
        let special = descriptor.special
        state.pendingShotBonus += (special?.shotPerNamed ?? 0) * state.namedForAssist.count

        if let whistle = interceptor(of: .shoot(seat: shooter), in: &state) {
            blow(whistle, on: .shoot(seat: shooter), state: &state, events: &events)
            state.namedForAssist = []
            return events
        }
        resolveShot(by: shooter, bonusPoints: extraPoint(for: special?.shotType),
                    overClamps: special?.ignoresClamps ?? false, card: descriptor,
                    state: &state, events: &events)
        state.namedForAssist = []
        settleHands(state: &state, events: &events)
        return events
    }

    /// What the pass cost him: a passive by name, or a card by where it sits.
    ///
    /// Two kinds of card in one question, so the answer says which — his board is face up
    /// and his hand is not, and picking a position out of a hand you cannot read is the
    /// same guess Nutmeg asks for.
    @discardableResult
    static func resolveToll(_ pick: CardPick?, state: inout GameState) -> [GameEvent] {
        guard case .awaitingToll(_, let victim) = state.phase else { return [] }
        var events: [GameEvent] = []
        state.pendingActor = nil
        state.phase = .possession(holder: state.ball ?? victim)

        // Waving it off is an answer. "You *can* choose" — so sometimes you do not.
        guard let pick else {
            settleHands(state: &state, events: &events)
            return events
        }
        switch pick {
        case .named(let id):
            guard let index = state[victim].intangibles.firstIndex(where: { $0.id == id })
            else { return events }
            let lost = state[victim].intangibles.remove(at: index)
            events.append(.intangibleDisplaced(seat: victim, card: lost))
            clockCatchesUp(victim, state: &state, events: &events)
        case .position(let slot):
            guard state[victim].bag.indices.contains(slot) else { return events }
            spend([state[victim].bag.remove(at: slot)], from: victim,
                  state: &state, events: &events)
        }
        settleHands(state: &state, events: &events)
        return events
    }

    /// One of the Injuries on the table, taken.
    @discardableResult
    static func resolveInjuryPick(_ id: String, state: inout GameState) -> [GameEvent] {
        guard case .awaitingInjuryPick(let seat, _) = state.phase,
              let taken = state.injuriesOffered.first(where: { $0.id == id })
        else { return [] }
        var events: [GameEvent] = []
        state.injuriesOffered = []
        state.injuriesHidden = []
        state.pendingActor = nil

        // Out of wherever it was standing, and onto the man who found the wet spot.
        state.discard.removeAll { $0.descriptor.id == id }
        if let index = state.deck.firstIndex(where: { $0.descriptor.id == id }) {
            state.deck.remove(at: index)
        }
        state[seat].injuries.append(taken)
        rollInjuryLock(seat, state: &state)
        // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
        state.possessionWasInterrupted = true
        events.append(.injuryRevealed(seat: seat, card: taken))
        state.phase = .possession(holder: state.ball ?? seat)
        settleHands(state: &state, events: &events)
        return events
    }

    /// **Curl Cut: nobody picks.** The card comes out of his Bag at random.
    private static func forceAtRandom(_ descriptor: CardDescriptor, from victim: Seat,
                                      state: inout GameState, events: inout [GameEvent]) {
        guard descriptor.cut?.forcesToPasser == true, !state[victim].bag.isEmpty else { return }
        let taken = state[victim].bag[state.roll(0...(state[victim].bag.count - 1))]
        events += resolveCardFrom(taken.id, state: &state)
    }

    /// The card picked out of somebody's hand.
    ///
    /// Face down when it was chosen, so this is where the guess is settled. Nutmeg passes
    /// it along; everything else spends it.
    @discardableResult
    static func resolveCardFrom(_ id: Card.ID, state: inout GameState) -> [GameEvent] {
        guard case .awaitingCardFrom(_, let descriptor, let victim) = state.phase,
              let actor = state.pendingActor else { return [] }
        var events: [GameEvent] = []
        // A hand can empty between the question and the answer — a Free Agent settling,
        // an Altercation clearing the floor. Nothing there is a legal answer, and the
        // question closes rather than standing forever.
        guard let index = state[victim].bag.firstIndex(where: { $0.id == id })
                ?? (state[victim].bag.isEmpty ? nil : Optional(0)) else {
            state.pendingPlay = nil
            state.pendingActor = nil
            state.stealTravelsTo = nil
            state.phase = .possession(holder: state.ball ?? actor)
            return events
        }
        let taken = state[victim].bag.remove(at: index)
        state.pendingPlay = nil
        state.pendingActor = nil

        if let onward = state.stealTravelsTo {
            state[onward].bag.append(taken)
            state.stealTravelsTo = nil
            state.phase = .possession(holder: state.ball ?? actor)
            settleHands(state: &state, events: &events)
            return events
        }
        // Bullet Pass and the Ankle Breaker combo: the card is spent, and the play that
        // asked for it has already been counted.
        if descriptor.receiverDiscards > 0 || descriptor.id == CardLibrary.ankleBreaker.id {
            state.discard.append(taken)
            state.phase = .possession(holder: state.ball ?? actor)
            events.append(.clampBit(seat: victim, card: descriptor, discarded: 1))
            settleHands(state: &state, events: &events)
            return events
        }
        state.discard.append(taken)
        state.phase = .possession(holder: actor)
        events.append(.movePlayed(seat: actor, card: descriptor, shot: loggedShot(state)))
        state.lastPlayThisPossession = descriptor.id
        state.movesThisPossession += 1
        settleHands(state: &state, events: &events)
        return events
    }

    /// The Injury's toll, paid. Whatever was chosen goes, and the turn starts properly.
    @discardableResult
    static func resolveGiveUp(_ ids: [Card.ID], state: inout GameState) -> [GameEvent] {
        guard case .awaitingGiveUp(let seat, let asking, let count) = state.phase else { return [] }
        var events: [GameEvent] = []

        let chosen = Set(ids.prefix(count))
        let spent = state[seat].bag.filter { chosen.contains($0.id) }
        state[seat].bag.removeAll { chosen.contains($0.id) }
        state.discard.append(contentsOf: spent)

        // Short of the toll — an absent player, or a hand that emptied — is made up at
        // random. The card is owed either way.
        for _ in spent.count..<count where !state[seat].bag.isEmpty {
            discardAtRandom(from: seat, state: &state)
        }
        // An Injury's toll is the Injury biting, and reads as one. Anything else asking
        // is just a hand losing cards, and says so.
        if let injury = state[seat].injuries.first(where: { ($0.injury?.discardsEachTurn ?? 0) > 0 }),
           injury.id == asking.id {
            events.append(.clampBit(seat: seat, card: injury, discarded: count))
        } else {
            events.append(.discarded(seat: seat, cards: spent.map(\.descriptor)))
        }
        // The holder's, which is not always the man who paid — Frostbite Finish and
        // Tri-hard Tiling ask whoever owes.
        state.phase = .possession(holder: state.ball ?? seat)
        settleHands(state: &state, events: &events)
        return events
    }

    /// Spends the chosen cards, then takes the shot the card was always going to take.
    @discardableResult
    static func resolveDiscardForShot(_ ids: [Card.ID], state: inout GameState) -> [GameEvent] {
        guard case .awaitingDiscard(let seat, let card, let bonusEach) = state.phase else { return [] }
        var events: [GameEvent] = []

        let chosen = Set(ids.prefix(legalDiscardForShot(state, for: seat).upperBound))
        let spent = state[seat].bag.filter { chosen.contains($0.id) }
        state[seat].bag.removeAll { chosen.contains($0.id) }
        state.discard.append(contentsOf: spent)

        // What the cards bought, and only for the shot they bought it for. Feeding a
        // Turnaround Three is a price paid for *that* attempt; letting it stay in SHOT
        // meant a miss handed the whole bonus to whoever took the rebound.
        // Dishcount Ball: the first card's worth comes free.
        // The Future: the one card buys a fourth point and costs SHOT.
        let fourPoints = state.fourPointOffer
        state.fourPointOffer = false
        let bought = fourPoints
            ? bonusEach * spent.count
            : shotBought(discarding: spent.count, card: card, bonusEach: bonusEach, in: state)
        let extraPointOwed = fourPoints && !spent.isEmpty ? 1 : 0
        adjustShot(by: bought, state: &state)
        events.append(.discardedForShot(seat: seat, card: card, count: spent.count))

        state.phase = .possession(holder: seat)
        // Stepback is a Move: what it bought stays on the ball, and the seat plays on.
        guard card.special?.shootsImmediately == true else {
            settleHands(state: &state, events: &events)
            return events
        }
        if let whistle = interceptor(of: .shoot(seat: seat), in: &state) {
            blow(whistle, on: .shoot(seat: seat), state: &state, events: &events)
            adjustShot(by: -bought, state: &state)
            return events
        }
        let roundBefore = state.round
        resolveShot(by: seat, bonusPoints: extraPoint(for: card.special?.shotType) + extraPointOwed,
                    overClamps: card.special?.ignoresClamps ?? false,
                    card: card, state: &state, events: &events)
        // Only when the round is still running. A round that turned over has already had
        // SHOT reset, and taking the bonus back out of a fresh number would go negative.
        if state.round == roundBefore { adjustShot(by: -bought, state: &state) }
        settleHands(state: &state, events: &events)
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
            // Roswell Reach: what he put in, plus the reach. Nought stays nought —
            // a man who did not go up for it is not on the board at all.
            let reach = state[seat].intangibles
                .compactMap(\.intangible).reduce(0) { $0 + $1.reboundBidBonus }
            // Boarder Court: off his own miss, the shooter reaches one further.
            let boarder = seat == shooter && state.intangibleBoard.isEmpty
                ? state.floorEffect.shooterReboundBonus : 0
            // Sprained Hamstring: a bid reaches one short.
            let hamstring = state[seat].injuries.reduce(0) { $0 + ($1.injury?.reboundBidPenalty ?? 0) }
            counts[seat] = discarded.isEmpty ? 0
                : max(0, discarded.count + reach + boarder - hamstring)
        }
        // Built in the order it is read out — see `GameEvent.reboundBids`, which is a
        // list rather than a dictionary because a dictionary does not write the same
        // bytes twice.
        let order = shooter.clockwiseOrderFromHere
        events.append(.reboundBids(bids: order.map {
            GameEvent.SeatBid(seat: $0, count: counts[$0] ?? 0)
        }, order: order))

        let highest = counts.values.max() ?? 0
        var contenders = highest == 0
            ? Seat.allCases
            : Seat.allCases.filter { counts[$0] == highest }
        // A board nobody wanted goes to the man with nothing to bid. He is out of every
        // contested one — see `legalReboundBid` — so the uncontested ones are his.
        if highest == 0,
           let free = contenders.first(where: { has($0, in: state, { $0.playsFromOthers }) }) {
            contenders = [free]
        }
        let winner = state.pick(from: contenders)

        // **Monster Ball's board.** Nobody missed: what comes down is an Intangible it had
        // swallowed. The winner takes it, the next goes up, and after the last the
        // possession it interrupted picks up where it was.
        if !state.intangibleBoard.isEmpty {
            let prize = state.intangibleBoard.removeFirst()
            events.append(.intangibleWon(seat: winner, card: prize))
            activate(Card(prize), for: winner, state: &state, events: &events)
            if state.intangibleBoard.isEmpty {
                state.phase = .possession(holder: state.ball ?? shooter)
                settleHands(state: &state, events: &events)
            }
            return events
        }

        state[winner].rebounds += 1
        // A rebound is not a pass, so it carries no assist credit forward.
        state.lastPasser = nil
        state.arrivedBy = nil
        events.append(.rebounded(winner))
        // SHOT carries over — only an inbound resets it.
        beginPossession(winner, tickClock: true, fromRebound: true,
                        fromOwnMiss: winner == shooter,
                        state: &state, events: &events)
        settleHands(state: &state, events: &events)
        return events
    }

    /// Takes the shot. Shared by the free Shoot action and by Special Moves that shoot.
    /// Whether this attempt is finished at the rim, and how.
    ///
    /// **Cosmetic, and still the rules'.** Nothing about a dunk scores differently — it is
    /// the same attempt — but which one happens has to be settled once, in the state
    /// everybody is told about, or four devices would each roll their own.
    static func dunk(for seat: Seat, card: CardDescriptor?, state: inout GameState) -> Dunk? {
        let roll = state.roll(0...999)
        // A card that calls for one gets any of the three; a plain possession gets what
        // the man's position throws down, and never a whirlwind.
        if let special = card?.special {
            // **A card that is plainly a jump shot never becomes a dunk.** A Special Move
            // says whether it finishes at the rim; one that does not — a Turnaround
            // Three, a Fadeaway, a heave from the logo — is the whole of what happened,
            // and falling through to "what would this man throw down anyway" put a centre
            // on the rim off a shot taken from the arc.
            guard special.dunks else { return nil }
            // A card that names one gets that one; a card that only asks for a dunk gets
            // any of the three.
            return special.dunkKind ?? Dunk.allCases[roll % Dunk.allCases.count]
        }
        // **The button says what it is.** Only a Dunk is ever finished at the rim; the
        // man's position only picks which of the plain two he throws down.
        guard state.shotType == .dunk else { return nil }
        return Dunk.ordinary(for: state[seat].position, roll: roll)
            ?? (roll.isMultiple(of: 2) ? .oneHand : .reverse)
    }

    /// - Parameter card: what put this shot up, when something did.
    ///
    ///   **Passed rather than looked up.** It used to be read back out of
    ///   `lastPlayThisPossession`, which a Special Move that shoots the moment it is
    ///   played never writes — only the branch for one that *doesn't* shoot does. So
    ///   every dunk card resolved its shot with the card unknown and fell through to
    ///   "what would this man throw down on an ordinary possession", which for a guard is
    ///   nothing: Slam Dunk, 2-Hand Jam, Give-and-Go and Tomahawk never once played a
    ///   dunk. Worse than nothing, in fact — where an earlier card *had* written that
    ///   field, the finish was chosen off the wrong card.
    /// **Ball Pounder's trade, or nil when there is nothing to trade with.** Three ticks
    /// of the clock for a card and ten per cent, offered on every Dribble — and simply not
    /// there when the clock cannot pay, which is what makes pounding it late a bad idea.
    static func poundingTrade(for seat: Seat, in state: GameState)
        -> (cost: Int, draw: Int, shot: Int)? {
        let cost = state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.dribbleClockTradeCost ?? 0) }
        guard cost > 0, let clock = state.shotClock, clock > cost else { return nil }
        return (cost,
                state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.dribbleClockTradeDraw ?? 0) },
                state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.dribbleClockTradeShot ?? 0) })
    }

    /// **The Regulation ball's identity for a scoring run.** It is the absence of a card
    /// rather than a card, so it needs a stand-in for Hot Hand to key off.
    static let regulationBallRun = UUID()

    /// **What a three is worth over a two**, for whichever way it was taken. A Special
    /// Move that names `.three` is a three, so Foot On The Line takes its extra point the
    /// same way it takes the button's — the card and the button are one thing now.
    static func extraPoint(for type: ShotType?, downgraded: Bool = false) -> Int {
        type == .three && !downgraded ? 1 : 0
    }

    /// **Long Ball: a layup is taken from three and paid like one.** Still a layup for
    /// every other purpose — the official watching layups still has it, and an empty hand
    /// still pays its bonus. Only the distance and the points change.
    static func longBallBonus(for type: ShotType?, in state: GameState) -> Int {
        state.ballEffect.layupsShootAsThrees && type == .layup ? 1 : 0
    }

    private static func resolveShot(by seat: Seat, bonusPoints: Int,
                                    overClamps: Bool = false,
                                    card: CardDescriptor? = nil,
                                    state: inout GameState, events: inout [GameEvent]) {
        // Spent by the attempt it bought, however that attempt turns out.
        state.threeDiscount = 0
        // **Long Ball, paid here rather than at each caller.** Six different places put a
        // shot up; the ball is a property of the attempt, not of how it was called for.
        let bonusPoints = bonusPoints
            + longBallBonus(for: card?.special?.shotType ?? state.shotType, in: state)
        // Brand New Ball: slick out of the box. The shot never goes up, and the round is over.
        if state.ballEffect.turnoverChance > 0,
           state.roll(1...100) <= state.ballEffect.turnoverChance {
            state.pendingShotBonus = 0
            state.pendingBonusPoint = 0
            state.pendingShotOverride = nil
            state.passiveShotOverride = nil
            state.levelsPointsFor = nil
            state.sellingOut = false
            state.mustShootFirst = nil
            state.mustPassFirst = nil
            state.mustMoveFirst = nil
            state[seat].turnovers += 1
            events.append(.turnover(seat, cause: CardLibrary.brandNewBall.name))
            stoppage(state: &state, events: &events)
            endRound(state: &state, events: &events)
            return
        }
        // What the card in hand was worth, spent on this attempt and gone.
        let priced = state.pendingShotBonus
        state.pendingShotBonus = 0
        // **Settled here, once.** Which finish this is has to be in the state everybody
        // is told about, or four devices would each roll their own and watch four
        // different dunks. Nothing about the scoring reads it.
        // Whatever card put it up; a plain shot is read off the button that was pressed.
        // Gravi-Gym: nothing is finished at the rim.
        state.dunking = state.floorEffect.barsDunks ? nil : dunk(for: seat, card: card, state: &state)
        if state.dunking != nil { state[seat].dunks += 1 }
        state.shotsThisRound += 1
        state.mustShootFirst = nil
        state.mustPassFirst = nil
        state.mustMoveFirst = nil
        let upgraded = state.pendingBonusPoint
        state.pendingBonusPoint = 0
        _ = upgraded
        // Mic'd Up, spent on the attempt it was carried into.
        let carried = seat == state.ball ? state.holderShot : 0
        state.holderShot = 0
        // Gravity: a man who draws every defender is doing something on every attempt,
        // whoever takes it.
        for other in Seat.allCases where other != seat {
            if has(other, in: state, { $0.assistOnOthersScore }) {
                state[other].assists += 1
                events.append(.assisted(other))
            }
        }
        // Spazzphalt: the floor names its own number, fresh for every shot.
        if state.floorEffect.randomShotOverride { state.courtShotRoll = state.roll(0...20) * 5 }
        let resolution = ShotMath.resolve(base: state.shot + priced + carried,
                                          modifiers: state.shotModifiers(
                                            for: seat, ignoringClamps: overClamps),
                                          rules: state.rules)
        let soldOut = state.sellingOut
        state.sellingOut = false
        state.courtShotRoll = nil
        state.pendingShotOverride = nil
        state.passiveShotOverride = nil
        let levelsPoints = state.levelsPointsFor == seat
        state.levelsPointsFor = nil
        let chance = resolution.chance
        events.append(.shotAttempted(seat: seat, chance: chance, breakdown: resolution))
        clampEvent(.attemptingAShot, on: [seat], state: &state, events: &events)

        // **The defenders stay.** A shot does not shake your man off — only beating him
        // does, and every Clamp prints what beating him takes. That is the assignment: a
        // little game inside the game that a player is working on all the way through
        // somebody else's possession. See `settleClamps`.
        //
        // The ones that have done their work and have nothing left to stand for — a Clamp
        // that only takes cards — leave the way they always did.
        for other in Seat.allCases {
            state[other].clamps.removeAll { $0.bitten && !($0.card.clamp?.isStanding ?? false) }
        }

        let roll = state.roll(1...100)
        if roll <= chance {
            // A kick-out is a three because of where it put him, not what he did with it.
            // Kiddie Court counts every basket the same; S.O.S sold the three for a two.
            let points = state.floorEffect.makesCount
                ?? (state.rules.madeShotPoints + (soldOut ? 0 : bonusPoints + upgraded))
            state[seat].points += points
            // Equalizer: every player's points become the shooter's new total.
            if levelsPoints {
                for other in Seat.allCases where other != seat {
                    state[other].points = state[seat].points
                }
            }
            state[seat].scoredThisRound = true
            // Hot Hand: the run belongs to this ball. nil is the Regulation ball, which
            // is a ball like any other as far as a streak is concerned.
            state[seat].scoredWithBall = state.ballCard?.id ?? Self.regulationBallRun
            state[seat].lastMake = Make(round: state.round, chance: chance)
            events.append(.shotMade(seat: seat, points: points, roll: roll, chance: chance))
            stoppage(state: &state, events: &events)
            if state[seat].drawsOwedOnMake > 0 {
                let owed = state[seat].drawsOwedOnMake
                state[seat].drawsOwedOnMake = 0
                drawTogether([seat], count: owed, state: &state, events: &events)
            }
            // Polypaypylene: a make pays in cards.
            if state.floorEffect.drawsOnMake > 0 {
                drawTogether([seat], count: state.floorEffect.drawsOnMake,
                             state: &state, events: &events)
            }
            // Wide-Open Three: everyone he named takes one, on top of whatever the pass
            // was already worth.
            // Hero Ball: a make is nobody else's.
            for helper in state.namedForAssist where helper != seat && !state.ballEffect.noAssists {
                state[helper].assists += 1
                events.append(.assisted(helper))
            }
            if let passer = state.lastPasser, passer != seat, !state.ballEffect.noAssists {
                // Dime pays twice: the assist every pass earns, and its own.
                let extra = state.dimeFrom == passer ? 1 : 0
                state[passer].assists += 1 + extra
                events.append(.assisted(passer))
            }
            endRound(state: &state, events: &events)
        } else {
            events.append(.shotMissed(seat: seat, roll: roll, chance: chance))
            // **Off the Backboard: he called it, so it comes back to him.** No bid and
            // no scramble — the board is his, and the card is spent taking it.
            if let called = state.freeRebound.removeValue(forKey: seat) {
                state[seat].rebounds += 1
                // **The card says so again, as it pays.** A Break drawn a possession ago
                // and then quietly honoured is a possession nobody can account for.
                events.append(.calledGlass(seat: seat, card: called))
                events.append(.rebounded(seat))
                beginPossession(seat, tickClock: false, fromRebound: true,
                                fromOwnMiss: true, state: &state, events: &events)
            } else {
                state.phase = .awaitingRebound(shooter: seat)
                // Make-or-Take Ball: a miss still goes to the line, before anybody goes up.
                let owed = state.ballEffect.freeThrowsOnMiss
                if owed > 0 {
                    awardFreeThrows(owed, to: seat, offender: nil,
                                    source: state.currentBall?.name ?? "", thenRebound: seat,
                                    state: &state, events: &events)
                    takeTheLine(state: &state, events: &events)
                }
            }
        }
    }

    // MARK: - Interception

    /// Offers a declared action to any armed Whistle before it takes effect.
    ///
    /// Returns the Whistle that fires, if one does. Resolution is in arming order, which
    /// is what gives a Whistle-cancels-a-Whistle chain a defined winner.
    ///
    /// **Takes the state to write to**, because some calls are a coin toss and a toss has
    /// to be rolled somewhere. Matching stays a pure read; the roll happens once, here,
    /// when a referee has otherwise decided to speak.
    private static func interceptor(of action: PendingAction,
                                    in state: inout GameState) -> ArmedWhistle? {
        guard !state.whistlesSilenced else { return nil }
        // **Fadeaway Three and Full-Court Heave are taken from too far out to argue with.**
        // Nobody is close enough to have a view, so nothing the crew is watching for
        // applies to the attempt.
        if case .playCard(_, let card) = action, card.descriptor.special?.ignoresRefs == true {
            return nil
        }
        // Oldest first: a trap set earlier is the one lying in wait.
        //
        // No owner exemption. A Whistle catches whoever trips it, its own player included
        // — that is what stops a table being flooded with traps by someone immune to them.
        let reading = state
        guard let speaking = state.armedWhistles.first(where: {
            !reading.callsAnswered.contains($0.id) && passes($0, action, in: reading)
        }) else { return nil }
        return tossed(speaking, state: &state) ? speaking : nil
    }

    /// **Whether this official has anything to say about this play.**
    ///
    /// A referee calls as often as his condition is met, all round — they stand for the
    /// whole of it and retire at the end. What holds the rate down is the cards themselves:
    /// coin tosses where a blanket cancel used to be, and conditions where there used to be
    /// none. Crew Chief is the one that spends a caller, and he does it by retiring him.
    private static func passes(_ whistle: ArmedWhistle, _ action: PendingAction,
                               in state: GameState) -> Bool {
        guard let effect = whistle.card.descriptor.whistle else { return false }

        // Double Dribble, read literally: the same Move card twice running. Settled here
        // rather than on the trigger, because it is a question about the possession.
        if whistle.trigger == .sameMoveTwice {
            guard case .playCard(_, let card) = action, card.descriptor.isMove,
                  state.lastPlayThisPossession == card.descriptor.id else { return false }
            return true
        }
        // Med Ball: the man carrying it can run all day.
        if whistle.card.descriptor.id == CardLibrary.travel.id, state.ballEffect.ignoresTravel {
            return false
        }
        guard whistle.trigger?.matches(action) == true else { return false }

        // **Each of the three watches one finish.** Declared on the cards since the
        // triangle went in and never once read, so Charge was waving off layups, Palming
        // was waving off dunks, and a crew holding all three cancelled every shot in the
        // game — which is most of what the call rate was. A shot is named by the time the
        // crew is consulted; a card being *played* is not a shot and never matches.
        if let watched = effect.requiresShotType {
            guard case .shoot = action else { return false }
            guard state.shotType == watched else { return false }
        }
        if effect.requiresShotDebuffClamp {
            return state[action.actor].clamps.contains { ($0.card.clamp?.shotDebuff ?? 0) != 0 }
        }
        // Goaltending: a shot taken with a defender on him, which is what the call is.
        if effect.requiresShotOverClamp {
            return !state[action.actor].clamps.isEmpty
        }
        // The three that read the Clamp being played rather than the man playing it.
        if case .playCard(_, let card) = action, card.descriptor.clamp != nil {
            let victim = clampVictim(in: state)
            if effect.requiresClampOnClamped {
                return victim.map { !state[$0].clamps.isEmpty } ?? false
            }
            if effect.requiresDefencelessVictim {
                return state.shot == 0 || (victim.map { state[$0].bag.isEmpty } ?? false)
            }
        }
        return true
    }

    /// **Some calls are a coin toss.** Travel and Back Court Violation watch a whole class
    /// of play, which as a certainty is a cancelled card in nearly every round they work —
    /// so they are a chance of one instead. Rolled where the call is made, not where it is
    /// matched, because matching has to stay a pure read.
    private static func tossed(_ whistle: ArmedWhistle, state: inout GameState) -> Bool {
        guard whistle.card.descriptor.whistle?.coinFlip == true else { return true }
        return state.roll(1...2) == 1
    }

    /// A Whistle waiting on the draw itself, if one is set.
    ///
    /// Its own reader rather than `interceptor`, which only ever sees a `PendingAction` —
    /// and a card reaching a hand is not something anybody did.
    private static func drawInterceptor(in state: GameState) -> ArmedWhistle? {
        guard !state.whistlesSilenced else { return nil }
        return state.armedWhistles.first { $0.trigger == .cardDrawn }
    }

    /// Blows one called on a draw. **It ends the possession where it stands** and throws
    /// the rest of the chain away — see `WhistleEffect.endsPossession`.
    private static func blowOnDraw(_ whistle: ArmedWhistle, against seat: Seat,
                                   state: inout GameState, events: inout [GameEvent]) {
        spendWhistle(whistle.id, state: &state, events: &events)
        // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
        state.possessionWasInterrupted = true
        // Nothing was cancelled — the card reached the hand and stays there. What is
        // called is the draw itself, so that is what the log says.
        events.append(.whistleBlew(owner: whistle.owner, card: whistle.card.descriptor,
                                   cancelled: "the draw", cancelledCard: nil,
                                   against: seat))
        stoppage(state: &state, events: &events)
        guard whistle.card.descriptor.whistle?.endsPossession == true else { return }
        state.chainBroken = true
        reinbound(by: seat, state: &state, events: &events)
    }

    /// **The travel call.**
    ///
    /// Blown through the same path a referee's call takes, so the scene, the cancel, the
    /// turnover and the side-out are the ones every other call gets — but the card it is
    /// announced with is the rule's rather than one standing on the floor. Where the
    /// Travel official *is* working, it is his: the camera goes to him.
    private static func travel(on action: PendingAction,
                               state: inout GameState, events: inout [GameEvent]) {
        // **Any of them can blow it, and which one is a coin toss.** Traveling is not one
        // official's brief — it is the rule they are all working to — so the call goes to
        // whoever on the crew happens to see it, and the camera goes to him.
        let crew = state.armedWhistles
        let caller = crew.isEmpty ? nil : crew[state.roll(0...(crew.count - 1))]
        // His card, but the rule's words: whoever makes the call, it is a travel.
        let announced = Card(CardLibrary.travel)
        let called = ArmedWhistle(owner: nil, card: announced, id: caller?.id ?? UUID())
        blow(called, on: action, state: &state, events: &events)
    }


    /// **The second half of playing a card**: everything after the officials have had
    /// their say.
    ///
    /// Separate from the declaration because a call can stop the game to ask a question —
    /// a challenge — and the play has to be picked up again on the answer, whichever way
    /// it goes. A challenge taken means the call never happened, so the card resolves as
    /// though nobody had spoken; one turned down lets the call land and then, if the card
    /// survived it, resolves that too. See `Rules.resolveChallenge`.
    private static func resolvePlay(_ cardID: Card.ID, by seat: Seat,
                                    state: inout GameState, events: inout [GameEvent]) {
        // **"Immediately after" means the very next thing.** Stepback's discount is spent
        // by whatever happens next, whether that is the Three it bought or an unrelated
        // card — so it is cleared here and set again only if this play is another
        // Stepback. Left standing it made every Three in the round cheap.
        state.threeDiscount = 0
        // **Found again, after the call.** A call that lets the play stand can still
        // take cards off the same hand — a Flagrant II takes two — so the position the
        // card was at before the whistle is not the position it is at now.
        guard let index = state[seat].bag.firstIndex(where: { $0.id == cardID }) else {
            return
        }
        let card = state[seat].bag.remove(at: index)
        // Named before it was played — carried through the play until it is spent.
        state.currentAim = state.aimedCard == card.id ? state.aimedTarget : nil
        state.aimedCard = nil
        state.aimedTarget = nil
        // The play has landed; whatever was kept quiet for it is free again.
        state.callsAnswered = []
        let descriptor = card.descriptor
        // **The Retiring Official.** A defender put out in front of him is waved off
        // before it lands and the man who played it draws instead — which is why
        // players are glad to see him.
        if descriptor.clamp != nil, state.armedWhistles.contains(where: {
            $0.card.descriptor.whistle?.clampsDrawInstead == true
        }) {
            state.discard.append(card)
            events.append(.discarded(seat: seat, cards: [descriptor]))
            drawTogether([seat], count: 1, state: &state, events: &events)
            settleHands(state: &state, events: &events)
            return
        }
        // Rhythm Dribble: its extra belongs to the next action, and only if that is a shot.
        // V-Cut's the same, for a Three.
        let carriedShotBonus = state.nextShotBonus
            + (descriptor.isThree ? state.nextThreeBonus : 0)
        state.nextShotBonus = 0
        state.nextThreeBonus = 0
        // The Cut's demand is met by whatever the man plays first — legalMoves only let
        // him play what it asked for.
        if state.mustPassFirst == seat { state.mustPassFirst = nil }
        if state.mustMoveFirst == seat { state.mustMoveFirst = nil }
        // Hip Contusion: throwing a pass costs a card.
        if descriptor.isPass {
            let hip = state[seat].injuries.reduce(0) { $0 + ($1.injury?.discardsOnPlayingPass ?? 0) }
            if hip > 0, let injury = state[seat].injuries.first(where: {
                ($0.injury?.discardsOnPlayingPass ?? 0) > 0
            }) {
                for _ in 0..<hip { discardAtRandom(from: seat, state: &state) }
                events.append(.clampBit(seat: seat, card: injury, discarded: hip))
            }
        }
        // Everything is spent the moment it is played — except a Whistle being armed,
        // which is **private** until it is called. The discard is public, so a card
        // put there names the trap, and the whole point of arming one is that nobody
        // knows what is waiting. It is held in `armedWhistles` and reaches the pile
        // when it blows, is silenced, or the referees go home at the round's end.
        //
        // Fundamentalist is the exception to the exception: the plainest cards in the
        // game go back in the bag, because a fundamentalist's game is those four
        // things over and over.
        let kept = state[seat].intangibles.contains {
            $0.intangible?.keepsOnPlay.contains(descriptor.id) == true
        }
        // A Varena or a Variaball is not spent: it goes onto its slot, below.
        let takesASlot = descriptor.varena != nil || descriptor.variaball != nil
            || descriptor.intangible != nil
        // Foot Ball: a Move or a Pass stays in the hand, locked until the possession ends.
        let footLocks = state.ballEffect.locksInsteadOfSpending
            && (descriptor.isMove || descriptor.isPass)
        if descriptor.whistle?.trigger == nil, !kept, !takesASlot, !footLocks {
            state.discard.append(card)
        } else if kept || footLocks {
            state[seat].bag.insert(card, at: min(index, state[seat].bag.count))
            if footLocks { state.footLocked.append(card.id) }
        }
        // Tick-Tock Tile: the tick is paid once the card has done what it does.
        if state.floorEffect.cardsTickClock { state.clockTicksOwed += 1 }
        // Frostbite Finish: a Move is paid for in other cards, owner's pick.
        if descriptor.isMove, moveDiscardCost(in: state, for: seat) > 0 {
            // Named for whatever is charging it: the floor, or the ankle.
            let charging = state.floorEffect.moveDiscardCost > 0 ? state.currentCourt
                : (state[seat].injuries.first { ($0.injury?.moveDiscardCost ?? 0) > 0 }
                   ?? state.currentCourt)
            state.owe(.tax(seat: seat, count: moveDiscardCost(in: state, for: seat),
                           card: charging))
        }
        if descriptor.isMove {
            state.movesPlayedThisPossession.insert(descriptor.id)
            state.moveCardsThisPossession += 1
        }
        if descriptor.blocksFurtherMoves { state.movesClosed = true }
        if descriptor.nextShotBonus != 0 { state.nextShotBonus = descriptor.nextShotBonus }
        if descriptor.threeWithFewerCards > 0 { state.threeDiscount = descriptor.threeWithFewerCards }
        rookieSwap(descriptor, by: seat, state: &state, events: &events)

        // Read before the card is played, because playing it may spend the tick it
        // is being priced against.
        var delta = printedWorth(of: descriptor, in: state)
            + clockBonus(descriptor.special, in: state)
        // **Ball Pounder: a Dribble may buy a card and ten per cent** for three ticks of
        // the clock. Taken whenever there is clock to spend — the AI and the table both
        // want the cards, and a Dribble played at 03 or less simply does not offer it.
        if descriptor.isDribble, let trade = poundingTrade(for: seat, in: state) {
            delta += trade.shot
        }
        // Con-crete: hard on the joints.
        if descriptor.isMove { delta += state.floorEffect.shotPerMovePlayed }
        // **Nothing pays a bonus while Delay-of-Game works.** He makes no call and
        // says nothing; he just stops them — combos included, which is where most of
        // a good possession's extra comes from. See `GameState.bonusesPaid`.
        let comboArmed = state.bonusesPaid
            && ((descriptor.comboAfter != nil
                 && descriptor.comboAfter == state.lastPlayThisPossession)
                || (descriptor.comboAfterDribble && lastPlayWasDribble(state)))
        // A Kick-Out asks whether the Drive it followed was *itself* a combo — that
        // is a dribble drive, and a different play from a Drive on its own.
        let afterCombo = comboArmed && state.lastPlayWasCombo
        if comboArmed { delta += descriptor.comboBonus }
        // Alley-Oop: a Lob, dunked as the first thing done with it.
        let alleyOop = descriptor.special?.dunks == true && isFirstAction(state)
            && state.lastPasser != nil && state.arrivedBy?.id == CardLibrary.lob.id
        if alleyOop { delta += CardLibrary.alleyOopBonus }
        // **Tomahawk pays either way.** What it is worth is read against the SHOT it
        // is played on rather than fixed on the card: under the mark it costs, at or
        // over it pays. Read here, before the attempt is priced, so it is the board
        // as it stands that decides.
        if let swing = descriptor.special?.shotSwing {
            delta += swing.delta(on: state.shot)
        }
        // Straight off your own board, and only as the first thing you do with it.
        if let extra = descriptor.special?.bonusOffOwnRebound, extra != 0,
           state.possessionFromOwnRebound, isFirstAction(state) {
            delta += extra
        }

        // **A shooting Special Move does not move SHOT; it prices its own shot.**
        //
        // Its number belongs to the attempt, the way a damage-step boost belongs to
        // the attack — so a Whistle that cancels the shot leaves the board where it
        // was, rather than handing whoever rebounds a −60% look off a cancelled
        // Dagger Three. Euro Step is the exception because it does not shoot: it is
        // a Move card wearing a Special Move's coat, and its SHOT is the board's.
        // Man-To-Man: every card played while guarded costs SHOT.
        delta += state[seat].clamps.reduce(0) { $0 + ($1.card.clamp?.shotPerCardPlayed ?? 0) }
        // **Snow Ball: none of what the pass is worth lands** — its number, its combo,
        // the clock, the lot. What is charged for playing a card at all still does.
        if overridesPassGain(descriptor, in: state) { delta = min(delta, 0) }
        // Southpaw Shooter: every gain is a loss and every loss a gain.
        if has(seat, in: state, { $0.reversesShotChanges }) { delta = -delta }
        let priced = descriptor.special?.shootsImmediately == true
        if !priced { adjustShot(by: delta, state: &state) }
        state.pendingShotBonus = priced ? delta + carriedShotBonus : 0

        // Touch Pass: it only counts if it never stopped in your hands. Read before
        // the play is counted, or the card has already made itself late.
        var drawing = descriptor.drawCount + (comboArmed ? descriptor.comboDraw : 0)
        // The Future: every Move played draws.
        if descriptor.isMove { drawing += state.floorEffect.drawsPerMovePlayed }
        // Fundamentalist: fundamentals pay. Every Move is a card extra.
        if descriptor.isMove {
            drawing += state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.extraDrawPerMove ?? 0) }
        }
        // Ball Pounder: the card half of the trade priced above.
        if descriptor.isDribble, let trade = poundingTrade(for: seat, in: state) {
            drawing += trade.draw
        }
        if descriptor.drawIfFirstAction > 0, isFirstAction(state) {
            drawing += descriptor.drawIfFirstAction
        }
        if afterCombo, descriptor.comboAssist > 0 {
            state[seat].assists += descriptor.comboAssist
            events.append(.assisted(seat))
        }
        drawTogether([seat], count: drawing, state: &state, events: &events)

        // Flop sells the contact: every Clamp on the player is a trip to the line,
        // and they all come off. Counted per Clamp card, so a Double-Team is one
        // foul with two bodies rather than two fouls.
        let standing = state[seat].clamps
        if descriptor.freeThrowsPerClamp > 0, let first = standing.first {
            awardFreeThrows(descriptor.freeThrowsPerClamp * standing.count,
                            to: seat, offender: first.from, source: descriptor.name,
                            state: &state, events: &events)
        }
        // **Pump Fake: named one at a time, until you stop.** Each one is SHOT and clock,
        // and they all stay standing — you did not lose them, you got them in the air.
        if descriptor.shotPerClampNamed != 0 || descriptor.clockPerClampNamed != 0,
           !state[seat].clamps.isEmpty {
            state.pendingPlay = descriptor
            state.pendingActor = seat
            state.phase = .awaitingClampsNamed(seat: asker(instead: seat, in: state),
                                               card: descriptor, named: [])
            return
        }
        // **Crossover and Outlet take one man off**, and not necessarily one of yours:
        // a defender is an assignment now, so taking the right one off the right player
        // is a play rather than a shrug.
        if descriptor.clearsTargetClamp {
            let hunting = Seat.allCases
                .flatMap { who in state[who].clamps.map { (who, $0) } }
                .max { lhs, rhs in
                    (lhs.0 == seat ? 1 : 0, -(lhs.1.card.clamp?.shotDebuff ?? 0))
                        < (rhs.0 == seat ? 1 : 0, -(rhs.1.card.clamp?.shotDebuff ?? 0))
                }
            if let (owner, taken) = hunting {
                state[owner].clamps.removeAll { $0.id == taken.id }
                events.append(.clampsShaken(seat: owner, card: descriptor, count: 1))
            }
        }
        // Pump Fake: the clock it costs per Clamp, paid with the card's own tick below.
        var clampTicks = 0
        if descriptor.clearsClamps, !standing.isEmpty {
            // Paid per Clamp shaken off, before they are cleared — Spin Move and
            // Crossover turn being guarded into the reason they are good.
            let shaken = standing.count
            clampTicks = descriptor.clockPerClamp * shaken
            if descriptor.shotPerClamp != 0 {
                adjustShot(by: descriptor.shotPerClamp * shaken, state: &state)
            }
            for _ in 0..<(descriptor.drawPerClamp * shaken) {
                drawOnce(seat, state: &state, events: &events)
            }
            if descriptor.clamperDiscardsPerClamp > 0 {
                for clamp in standing {
                    for _ in 0..<descriptor.clamperDiscardsPerClamp {
                        discardAtRandom(from: clamp.from, state: &state)
                    }
                }
            }
            state[seat].clamps.removeAll()
            events.append(.clampsShaken(seat: seat, card: descriptor, count: shaken))
        }
        if descriptor.turnoverIfNoClamps, standing.isEmpty {
            // Thrown yourself down on an empty floor. Costs the ball, not the round.
            state[seat].turnovers += 1
            events.append(.turnover(seat, cause: descriptor.name))
            stoppage(state: &state, events: &events)
            reinbound(by: seat, state: &state, events: &events)
            return
        }

        if takesASlot {
            playOntoItsSlot(card, by: seat, state: &state, events: &events)
        } else if let special = descriptor.special {
            // A tip-in is only a tip-in off the glass, and only as the first thing done
            // with the board. From anywhere else the card is its ordinary self.
            let tipIn = state.possessionFromRebound && isFirstAction(state)
            // Wide-Open Three: every other player has had the ball this round.
            let wideOpen = Seat.allCases.allSatisfy {
                $0 == seat || state.possessedThisRound.contains($0)
            }
            // **Open Three pays for the ball having moved.** Two passes in the round is
            // a floor that has been swung, which is what a wide-open look is made of.
            if special.shotPerPassesThisRound != 0,
               state.passesThisRound >= special.passesRequired {
                adjustShot(by: special.shotPerPassesThisRound, state: &state)
            }
            let override = special.shotOverride
                ?? (tipIn ? special.shotOverrideAfterRebound : nil)
                ?? (wideOpen ? special.shotOverrideOnceAllHaveHadBall : nil)
            if let override {
                state.pendingShotOverride = ShotOverride(
                    label: descriptor.name, amount: Double(override),
                    requiresAtLeast: special.overrideRequiresAtLeast)
            }
            // **Skyhook reaches into Retirement**, which is the homage: the shot nobody
            // could block, and a card nobody could get back.
            // **Splash Cousin cashes itself in on a Three.** The ball it brings cannot
            // miss one — and it stays in play until somebody gets rid of it, which is the
            // scramble the card is really for.
            if special.shotType == .three { splashIn(by: seat, state: &state, events: &events) }
            // Floater: one defender simply does not matter, and it picks the worst one.
            if special.ignoresATargetClamp, let man = worstClamp(on: seat, in: state) {
                state.ignoredClamps.insert(man.id)
            }
            if special.coinFlipShot != 0 {
                // One flip, and it pays the same either way — the risk is the whole
                // card.
                let heads = state.roll(0...1) == 1
                adjustShot(by: heads ? special.coinFlipShot : -special.coinFlipShot,
                           state: &state)
                events.append(.coinRun(seat: seat, card: descriptor,
                                       heads: heads ? 1 : 0))
                if heads, special.headsIgnoresAClamp, let man = worstClamp(on: seat, in: state) {
                    state.ignoredClamps.insert(man.id)
                } else if !heads, special.tailsDraw > 0 {
                    drawTogether([seat], count: special.tailsDraw, state: &state, events: &events)
                }
            }
            if special.coinRunFlips > 0 {
                // A fixed number of coins, paying out per head. Every one of them Heads
                // is a Travel — unless the man cannot be called for one.
                let flips = special.coinRunFlips
                var heads = 0
                for _ in 0..<flips {
                    if state.roll(0...1) == 1 { heads += 1 }
                }
                events.append(.coinRun(seat: seat, card: descriptor, heads: heads))
                if heads < flips {
                    adjustShot(by: special.coinRunShot * heads, state: &state)
                    for _ in 0..<(special.coinRunDraw * heads) {
                        drawOnce(seat, state: &state, events: &events)
                    }
                    // **Every Heads is a step.** The meter is the Travel line and the
                    // dunk's gate in one number, so a good Euro Step both risks the call
                    // and walks you to the rim.
                    state.movesThisPossession += special.coinRunMoves * heads
                } else if !has(seat, in: state, { $0.ignoresViolations }) {
                    state[seat].turnovers += 1
                    events.append(.turnover(seat, cause: "Travel"))
                    stoppage(state: &state, events: &events)
                    reinbound(by: seat, state: &state, events: &events)
                    return
                }
            }
            // **2-Hand Jam only asks off a board.** The Retire-any-number half is its
            // bonus now, not its body, so on an ordinary possession it is simply a dunk
            // with a draw and twenty-five per cent.
            if special.discardForShotBonus > 0,
               !special.discardsOnlyAfterRebound || discardsPastLimit(descriptor, in: state) {
                // Hand the choice back before the shot goes up.
                state.phase = .awaitingDiscard(seat: seat, card: descriptor,
                                               bonusEach: special.discardForShotBonus)
                return
            }
            if special.shotPerNamed > 0 {
                // Named before the shot goes up, because who is owed changes what it
                // is worth — and the answer is a list rather than one man.
                state.pendingPlay = descriptor
                state.pendingActor = seat
                state.namedForAssist = []
                state.phase = .awaitingNaming(seat: asker(instead: seat, in: state),
                                              card: descriptor, named: [])
                return
            }
            if alleyOop {
                events.append(.comboLanded(seat: seat, card: descriptor,
                                           opener: CardLibrary.lob.id,
                                           bonus: CardLibrary.alleyOopBonus))
            }
            if special.shootsImmediately {
                // **Asked before the ball goes up.** The shot ends the possession, so a
                // card that reaches for the table has to reach first — see
                // `resolveRetirement`, which puts the attempt up once it is answered.
                if askForRetirement(descriptor, by: seat, state: &state) { return }
                // Skyhook: a card out of Retirement, chosen, before the ball goes up.
                if askForRetiredPick(descriptor, by: seat, state: &state) { return }
                // Turnaround Three: a hand big enough may all go in, for a sure thing.
                if let least = special.offersHandDumpAt, state[seat].bag.count >= least {
                    state.pendingPlay = descriptor
                    state.pendingActor = seat
                    state.phase = .awaitingOption(seat: seat, option: .dumpHand)
                    return
                }
                if shootTheCard(descriptor, by: seat, state: &state, events: &events) {
                    return
                }
            } else {
                events.append(.movePlayed(seat: seat, card: descriptor, shot: loggedShot(state)))
                state.lastPlayThisPossession = descriptor.id
                state.movesThisPossession += 1
                _ = askForRetirement(descriptor, by: seat, state: &state)
            }
        } else if let effect = descriptor.whistle {
            if effect.trigger == nil {
                events.append(.whistleUsed(seat: seat, card: descriptor))
                resolveImmediate(effect, playedBy: seat, state: &state, events: &events)
            } else {
                // Up to three on the floor at once, and they accumulate rather than
                // replacing one another. A fourth is simply not playable — see
                // `legalMoves`, which refuses it before it gets here.
                state.armedWhistles.append(ArmedWhistle(owner: seat, card: card))
                events.append(.whistleArmed(seat: seat))
            }
        } else if descriptor.clamp != nil {
            // **On the man it was aimed at, waiting.** Not tied to the pass any more: it
            // sits on him until he next has the ball and bites then. The possession carries
            // on, like a Move card. Belt and braces on the slots, since a card that sets
            // one could still reach here past `legalMoves`.
            let victim = state.clampTarget ?? gravityHolder(in: state)
                ?? clampTargets(for: seat, in: state).first
            if let victim, state[victim].clamps.count < state.rules.clampSlots {
                var waiting = ActiveClamp(card: descriptor, from: seat)
                waiting.bitten = false
                state[victim].clamps.append(waiting)
                events.append(.clampSet(seat: victim, card: descriptor))
            }
        } else if descriptor.cut != nil {
            // **A Cut: the ball goes without a Pass card**, and the defenders with it.
            events.append(.movePlayed(seat: seat, card: descriptor, shot: loggedShot(state)))
            state.lastPlayThisPossession = descriptor.id
            state.lastPlayWasCombo = false
            state.movesThisPossession += 1
            guard case .possession(let holder) = state.phase, holder == seat else { return }
            if let aim = state.currentAim {
                state.currentAim = nil
                aimCut(descriptor, by: seat, at: aim, state: &state, events: &events)
                return
            }
            state.pendingPlay = descriptor
            state.pendingActor = seat
            state.phase = .awaitingTarget(seat: asker(instead: seat, in: state), card: descriptor,
                                          choices: Seat.allCases.filter { $0 != seat })
            return
        } else if var target = descriptor.passTarget {
            // **Misdirection.** A Crossover sells one direction; the swing after it goes
            // the other, and takes a card off whoever it passes on the way.
            if comboArmed, descriptor.comboReversesPass {
                target = target == .left ? .right : target == .right ? .left : target
                state.misdirected = true
            }
            // Hand-Off's combo is already paid above with the rest of the play's worth.
            // This only says so, for the log and the record of combos done.
            if comboArmed {
                events.append(.comboLanded(seat: seat, card: descriptor,
                                           opener: state.lastPlayThisPossession,
                                           bonus: descriptor.comboBonus))
            }
            // **Dishtracting Ball: the crew is what it distracts.** Asked before the
            // ball leaves like every other "you may" on a pass, and named by whoever
            // names targets — which is what the word is printed on the card for.
            // **Dishtracting Ball and Franchise Player both reach out while passing.**
            // One question, whichever of them is asking — see `retirementChoices`.
            let asking = state.ballEffect.retiresARef ? CardLibrary.dishtractingBall
                : has(seat, in: state, { $0.retiresInPlayOnPass }) ? CardLibrary.franchisePlayer
                : nil
            if let asking {
                let choices = retirementChoices(asking, by: seat, in: state)
                if !choices.isEmpty {
                    state.pendingPlay = descriptor
                    state.pendingActor = seat
                    state.phase = .awaitingRetirement(seat: asker(instead: seat, in: state),
                                                      card: asking, choices: choices)
                    return
                }
            }
            // A card's "You may" is asked before the ball leaves — see `passOption`.
            if let option = passOption(descriptor, from: seat, in: state) {
                state.pendingPlay = descriptor
                state.pendingActor = seat
                state.phase = .awaitingOption(seat: seat, option: option)
                return
            }
            if throwPass(descriptor, target: target, from: seat,
                         state: &state, events: &events) {
                return
            }
        } else if descriptor.clearsOut {
            events.append(.movePlayed(seat: seat, card: descriptor, shot: loggedShot(state)))
            state.lastPlayThisPossession = descriptor.id
            state.lastPlayWasCombo = false
            state.movesThisPossession += 1
            clearOut(from: seat, state: &state, events: &events)
        } else if descriptor.targetDiscards > 0 {
            state.pendingPlay = descriptor
            state.pendingActor = seat
            state.phase = .awaitingTarget(seat: asker(instead: seat, in: state),
                                          card: descriptor,
                                          choices: Seat.allCases.filter { $0 != seat })
            return
        } else if !descriptor.modes.isEmpty {
            state.pendingPlay = descriptor
            state.pendingActor = seat
            // **Asked of the man playing it.** Which branch of your own card you take
            // is not a target, so a Floor General does not name it — see
            // `aimsEveryTarget`. He was picking it, and `resolveMode` then acted as
            // him: his possession, his draw, his pass, his name in the log.
            state.phase = .awaitingMode(seat: seat, card: descriptor)
            return
        } else {
            events.append(.movePlayed(seat: seat, card: descriptor, shot: loggedShot(state)))
            if comboArmed {
                events.append(.comboLanded(seat: seat, card: descriptor,
                                           opener: state.lastPlayThisPossession,
                                           bonus: descriptor.comboBonus))
            }
            state.lastPlayThisPossession = descriptor.id
            state.lastPlayWasCombo = comboArmed
            state.movesThisPossession += 1
            // A Move card keeps the ball, so the seat acts again unless its own
            // clock cost runs the possession out.
            // Ball Pounder: every Dribble also runs the clock down. One tick, so a clock the
            // card already ran out is not run out twice.
            let pounded = descriptor.isDribble
                ? -(poundingTrade(for: seat, in: state)?.cost ?? 0)
                : 0
            if descriptor.clockDelta + pounded + clampTicks != 0 {
                _ = tickClock(by: descriptor.clockDelta + pounded + clampTicks, holder: seat,
                              state: &state, events: &events)
            }
            // Stepback: the extra look is bought, and buying it is optional. Asked
            // with the same question Turnaround Three asks, capped at one card.
            // **Chosen, not taken.** A card that says discard without saying at
            // random means the player picks, and this was the one that did not ask.
            // Here rather than where the draw happens, because the rest of the play
            // has to land before the question can stand — a phase set mid-chain is a
            // phase the next line overwrites.
            // Dishcount Ball: one fewer.
            let selfDiscard = max(0, descriptor.selfDiscard
                                  - (state.ballEffect.discountsDiscards ? 1 : 0))
            if selfDiscard > 0, !state[seat].bag.isEmpty,
               case .possession = state.phase {
                state.phase = .awaitingGiveUp(seat: seat, card: descriptor,
                                              count: min(selfDiscard,
                                                         state[seat].bag.count))
                return
            }
            // Dishcount Ball: Stepback's card is free, so there is nothing to ask.
            if descriptor.optionalDiscardForShot > 0, state.ballEffect.discountsDiscards {
                adjustShot(by: descriptor.optionalDiscardForShot, state: &state)
            } else if descriptor.optionalDiscardForShot > 0, !state[seat].bag.isEmpty,
               case .possession = state.phase {
                state.phase = .awaitingDiscard(seat: seat, card: descriptor,
                                               bonusEach: descriptor.optionalDiscardForShot)
                return
            }
            // The Ankle Breaker combo: a card out of somebody else's hand, if wanted.
            if comboArmed, descriptor.id == CardLibrary.crossover.id,
               case .possession(let holder) = state.phase, holder == seat,
               Seat.allCases.contains(where: { $0 != seat && !state[$0].bag.isEmpty }) {
                state.pendingActor = seat
                state.phase = .awaitingOption(seat: seat, option: .ankleBreaker)
                return
            }
        }

    }

    /// **Offers the call to the man it is against before it is made.**
    ///
    /// Once a game he may throw it out, and the official who made it goes off with it. The
    /// call has not happened yet when the question is asked, so taking the challenge means
    /// it never happened rather than being undone — which is the only version of this that
    /// does not have to unpick free throws and turnovers after the fact.
    private static func offerChallenge(_ whistle: ArmedWhistle, on action: PendingAction,
                                       state: inout GameState) -> Bool {
        let man = action.actor
        guard !state[man].challenged, state.challengedCall == nil,
              !state.callsAnswered.contains(whistle.id) else { return false }
        state.challengedCall = GameState.PendingCall(whistle: whistle.id, action: action)
        state.phase = .awaitingChallenge(seat: man, card: whistle.card.descriptor)
        return true
    }

    /// **Thrown out, or taken.**
    @discardableResult
    static func resolveChallenge(_ challenging: Bool, state: inout GameState) -> [GameEvent] {
        guard case .awaitingChallenge(let seat, _) = state.phase else { return [] }
        var events: [GameEvent] = []
        let pending = state.challengedCall
        state.challengedCall = nil
        state.phase = .possession(holder: state.ball ?? seat)
        // **Always answerable.** A question that can be asked and not answered is a game
        // that stops: the official could have gone off between the asking and the answer —
        // Crew Chief retires whoever calls — and there is then nothing to throw out.
        guard let pending,
              let whistle = state.armedWhistles.first(where: { $0.id == pending.whistle })
        else {
            settleHands(state: &state, events: &events)
            return events
        }

        // **The official has already spoken for this play**, whichever way this goes —
        // so he does not speak again when it is picked up.
        state.callsAnswered.insert(whistle.id)

        guard challenging else {
            blow(whistle, on: pending.action, state: &state, events: &events)
            // The call landed. If the card survived it, the play still has to happen.
            resume(pending.action, state: &state, events: &events)
            settleHands(state: &state, events: &events)
            return events
        }
        // **Spent, and the official with it.** One a game whether it helps or not.
        state[seat].challenged = true
        if let at = state.armedWhistles.firstIndex(where: { $0.id == whistle.id }) {
            sendOff(at, state: &state, events: &events)
        }
        events.append(.challenged(seat: seat, card: whistle.card.descriptor))
        assignCrew(state: &state, events: &events)
        // **The call never happened**, so what he was doing happens. That is the whole of
        // what a challenge is worth: not the official going off, but the play going on.
        resume(pending.action, state: &state, events: &events)
        settleHands(state: &state, events: &events)
        return events
    }

    /// **Picks a play back up** after the question that stopped it has been answered.
    ///
    /// A card is resolved where it left off; a shot is simply taken again. Either way the
    /// officials who have already spoken for it stay quiet — see `GameState.callsAnswered`.
    private static func resume(_ action: PendingAction,
                               state: inout GameState, events: inout [GameEvent]) {
        guard case .possession(let holder) = state.phase else { return }
        switch action {
        case .playCard(let who, let card):
            guard holder == who, state[who].bag.contains(where: { $0.id == card.id }) else {
                return
            }
            resolvePlay(card.id, by: who, state: &state, events: &events)
        case .shoot(let who):
            guard holder == who else { return }
            events += apply(.shootAs(state.shotType), by: who, to: &state)
        case .inbound:
            return
        }
    }

    /// Spends the Whistle, cancels what tripped it, and applies its effects.
    private static func blow(_ whistle: ArmedWhistle, on action: PendingAction,
                             state: inout GameState, events: inout [GameEvent]) {
        // **Blown over the top.** Inadvertent Whistle does not wait for a play, it waits
        // for a *call* — so it is checked here rather than in `interceptor`, which only
        // ever sees actions. The call it cancels never happens: the card that tripped the
        // first Whistle stands, and the Whistle that was about to fire is spent for
        // nothing.
        if whistle.trigger != .whistleFired,
           let over = state.armedWhistles.first(where: {
               $0.id != whistle.id && $0.trigger == .whistleFired
           }) {
            spendWhistle(over.id, state: &state, events: &events)
            spendWhistle(whistle.id, state: &state, events: &events)
            // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
            state.possessionWasInterrupted = true
            events.append(.whistleBlew(owner: over.owner, card: over.card.descriptor,
                                       cancelled: whistle.card.name,
                                       cancelledCard: whistle.card.descriptor,
                                       against: whistle.owner))
            stoppage(state: &state, events: &events)
            let effect = over.card.descriptor.whistle ?? WhistleEffect()
            for _ in 0..<effect.offenderDraws {
                drawOnce(action.actor, state: &state, events: &events)
            }
            return
        }

        let effect = whistle.card.descriptor.whistle ?? WhistleEffect()
        let offender = action.actor

        let calls = (state.whistleCallsThisRound[whistle.card.descriptor.id] ?? 0) + 1
        state.whistleCallsThisRound[whistle.card.descriptor.id] = calls

        // Most Whistles are spent by being called. Delay-of-Game stays on the floor for
        // its first call — the warning — and is spent by the second, which is the foul.
        // Without the second half it fouls at every possession for the rest of the round.
        // Called, so it is public now — and only now does it reach the pile.
        if !effect.staysArmed || calls > 1 {
            spendWhistle(whistle.id, state: &state, events: &events)
        }

        var cancelled = "the play"
        var cancelledCard: CardDescriptor?
        if case .playCard(let seat, let card) = action {
            // Nearly always taken back. A Shot Clock Violation is the exception: the card
            // did what it said and the *clock* is the offence, so the play stands and the
            // ball goes out.
            if effect.cancelsCard {
                state[seat].bag.removeAll { $0.id == card.id }
                state.discard.append(card)
            }
            cancelled = card.name
            cancelledCard = card.descriptor
        } else if case .shoot = action {
            cancelled = "the shot"
        }
        // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
        state.possessionWasInterrupted = true
        events.append(.whistleBlew(owner: whistle.owner, card: whistle.card.descriptor,
                                   cancelled: cancelled, cancelledCard: cancelledCard,
                                   against: action.actor, caller: whistle.id))
        stoppage(state: &state, events: &events)

        // **Officially Infamous: the call stands and the official does not.** He blows it,
        // it lands, and then he is gone — which is why the card is worth carrying against
        // a crew you cannot play around.
        defer { infamy(against: action.actor, state: &state, events: &events) }

        if effect.recoversTimeout, let owner = whistle.owner,
           let index = state.discard.firstIndex(where: { $0.descriptor.id == "timeout" }) {
            state[owner].bag.append(state.discard.remove(at: index))
        }
        if effect.stripsIntangibles {
            stripIntangibles(from: offender, state: &state, events: &events)
        }
        for _ in 0..<effect.offenderDiscards { discardAtRandom(from: offender, state: &state) }
        if effect.offenderDraws > 0 {
            drawTogether([offender], count: effect.offenderDraws, state: &state, events: &events)
        }
        if effect.offenderDiscardsBag {
            spendHand(of: offender, state: &state, events: &events)
        }
        // **Paid to whoever the call was made for.** With nobody holding the Whistle that
        // is the man the play was being run at — the clamped player — and with no such man
        // it is not paid at all. An official does not score.
        if effect.pointsToVictim > 0, let beneficiary = whistle.owner ?? clampVictim(in: state) {
            state[beneficiary].points += effect.pointsToVictim
            events.append(.shotMade(seat: beneficiary, points: effect.pointsToVictim, roll: 0))
            stoppage(state: &state, events: &events)
        }
        // The ball changes hands on the call rather than going back in: a review does not
        // stop the game, it decides where the ball was going.
        if effect.takesBall, let owner = whistle.owner, owner != offender {
            beginPossession(owner, tickClock: false, state: &state, events: &events)
        }
        if effect.turnoverOnOffender {
            state[offender].turnovers += 1
            // The Whistle that was called, not the card it was called on.
            events.append(.turnover(offender, cause: whistle.card.name))
            stoppage(state: &state, events: &events)
        }
        if effect.keepsClockCost, case .playCard(let seat, let card) = action,
           card.descriptor.clockDelta < 0 {
            tickClock(by: card.descriptor.clockDelta, holder: seat,
                      state: &state, events: &events)
        }
        if effect.clearsShotDebuffClamps {
            let cleared = state[offender].clamps.filter { ($0.card.clamp?.shotDebuff ?? 0) != 0 }
            state[offender].clamps.removeAll { ($0.card.clamp?.shotDebuff ?? 0) != 0 }
            if let first = cleared.first {
                events.append(.clampVoided(seat: offender, card: first.card,
                                           count: cleared.count))
            }
        }
        if effect.awardsShotValueToOffender, case .shoot = action {
            // What the shot was worth, not a flat two: a Special Move that pays an extra
            // point on a make is a three, and a foul on one is worth three.
            let points = state.floorEffect.makesCount
                ?? (state.rules.madeShotPoints + pendingShotBonus(for: offender, in: state))
            state[offender].points += points
            state[offender].scoredThisRound = true
            events.append(.shotMade(seat: offender, points: points, roll: 0))
            stoppage(state: &state, events: &events)
        }

        let earned = effect.freeThrowsToVictim
            + (calls > 1 ? effect.freeThrowsOnRepeatCall : 0)
        // **The one kind of trip that ends a possession.** A Whistle blew: it is a dead
        // ball, the offender inbounds, and whatever was being played is over.
        if let beneficiary = whistle.owner {
            awardFreeThrows(earned, to: beneficiary, offender: offender,
                            source: whistle.card.name, endsPossession: true,
                            state: &state, events: &events)
        }
        // The man who was fouled, which for a Clear Path is the man who tripped it.
        awardFreeThrows(effect.freeThrowsToOffender, to: offender, offender: nil,
                        source: whistle.card.name, endsPossession: true,
                        state: &state, events: &events)

        if effect.endsRound {
            endRound(state: &state, events: &events)
        } else if effect.setterChoosesInbound || effect.turnoverOnOffender
                    || effect.offenderInbounds {
            // **The official who called it puts it back in**, to anybody but the man it
            // was called on. The round does not advance — only a made shot or a real clock
            // expiry does that. Charge takes the ball the same way without charging the
            // turnover.
            refereeReinbound(caller: whistle.id, offender: offender,
                             state: &state, events: &events)
        } else {
            // **A call the man plays on from.** His card was waved off and he still has
            // the ball — but the card that was going to free him may have been the one
            // cancelled, and a man with nothing left to do is a man the clock runs out
            // on. Checked here because a call is not a play and never reaches the drain.
            strandOut(state: &state, events: &events)
        }
    }

    /// What the shot in flight is worth beyond an ordinary basket.
    ///
    /// Read off the Special Move that started it. A card cancelled at the moment it shoots
    /// has already been discarded, so this looks at what is standing rather than at the
    /// bag: `pendingShotBonus` is only ever asked during a shot attempt.
    private static func pendingShotBonus(for seat: Seat, in state: GameState) -> Int {
        guard let id = state.lastPlayThisPossession,
              let card = state.rules.cardPool.first(where: { $0.id == id }) else { return 0 }
        return extraPoint(for: card.special?.shotType)
    }

    /// Whistles that fire on being played rather than lying in wait.
    private static func resolveImmediate(_ effect: WhistleEffect, playedBy seat: Seat,
                                         state: inout GameState, events: inout [GameEvent]) {
        if effect.resetsShotClock {
            state.shotClock = state.shotClockLength
            events.append(.shotClockSet(state.shotClockLength))
        }
        drawTogether(Seat.allCases, count: effect.everyoneDraws,
                     state: &state, events: &events)
        if effect.recoversTimeout,
           let index = state.discard.firstIndex(where: { $0.descriptor.id == "timeout" }) {
            state[seat].bag.append(state.discard.remove(at: index))
        }
        // Last, so the fresh clock and the fresh cards are already there when the ball
        // goes back in. A timeout is called and then play restarts, in that order.
        if effect.ownerInbounds {
            reinbound(by: seat, state: &state, events: &events)
        }
    }

    /// Cards off a hand and onto the pile, **said out loud**.
    ///
    /// Twenty-odd places put cards on the discard pile and exactly one of them said so,
    /// which is why nothing a player gave up ever reached the log. This is the way a hand
    /// loses cards that has no better word for itself — anything that already has its own
    /// event keeps it and does not come through here: a card played is a play, cards fed
    /// to a shot are the shot, a Clamp's bite is the Clamp, a bid is a bid.
    private static func spend(_ cards: [Card], from seat: Seat,
                              state: inout GameState, events: inout [GameEvent]) {
        guard !cards.isEmpty else { return }
        state.discard.append(contentsOf: cards)
        events.append(.discarded(seat: seat, cards: cards.map(\.descriptor)))
    }

    /// The whole hand, down.
    private static func spendHand(of seat: Seat, state: inout GameState,
                                  events: inout [GameEvent]) {
        let hand = state[seat].bag
        state[seat].bag.removeAll()
        spend(hand, from: seat, state: &state, events: &events)
    }

    private static func discardAtRandom(from seat: Seat, state: inout GameState) {
        var ignored: [GameEvent] = []
        discardAtRandom(from: seat, state: &state, events: &ignored)
    }

    /// The one place a card is taken off a hand at random — and the one place that says so.
    private static func discardAtRandom(from seat: Seat, state: inout GameState,
                                        events: inout [GameEvent]) {
        guard !state[seat].bag.isEmpty else { return }
        let index = state.roll(0...(state[seat].bag.count - 1))
        let taken = state[seat].bag.remove(at: index)
        state.discard.append(taken)
        events.append(.discarded(seat: seat, cards: [taken.descriptor]))
    }

    /// Hands the ball back in without advancing the round. Shot Clock Violation and
    /// Double Dribble both work this way, and so does any turnover a Whistle causes.
    private static func reinbound(by seat: Seat, state: inout GameState, events: inout [GameEvent]) {
        // **SHOT and the clock are the round's, not the throw-in's.** A Whistle that sends
        // the ball back in has not ended anything — the round holds, and so does what the
        // ball is worth and how long is left on it. Only `beginRound` starts either over.
        state.ball = nil
        state.lastPasser = nil
        state.arrivedBy = nil
        state.lastPlayThisPossession = nil
        state.pendingClamps = []
        // The play a Lob owed a shot to is over. Carrying it into the throw-in leaves a
        // man barred from his own hand for a possession the pass never reached.
        state.mustShootFirst = nil
        state.mustPassFirst = nil
        state.mustMoveFirst = nil
        state.nextThreeBonus = 0
        state.sellingOut = false
        // **And so is anything else the play still owed.** A dead ball ends the play, so
        // a Right Back's second leg and a forced shot go with it — a Clear Out charging
        // the passer a turnover and then the ball flying home anyway is the return leg
        // outliving the pass that owed it. `endRound` already did this; a throw-in that
        // does not advance the round has exactly the same claim.
        state.forget(.shootAtOnce, .returnBall)
        // **Clamps are not cleared here.** `beginPossession` is the one place that ends
        // them, because ending a possession is the only thing that does — and a dead ball
        // clearing them early handed a cancelled card its effect for free: a Whistle that
        // stops a Spin Move charges a turnover, the turnover re-inbounds, and the man
        // walked away from the defenders the Spin Move had just been forbidden to shake.
        // **A violation costs time.** Nothing else in a call → turnover → throw-in cycle
        // does: the clock is set once at the top of a round and a re-inbound never moved
        // it, so a referee who calls every time his condition is met had nothing to run
        // him out. Rounds end on shots, and the clock is what closes one nobody can score
        // in — so it has to actually run.
        if let clock = state.shotClock, clock > 0 {
            state.shotClock = clock - 1
            events.append(.shotClockTicked(clock - 1))
        }
        state.phase = .inbound(inbounder: seat)
        events.append(.reinbound(seat: seat))
    }

    // MARK: - Flow

    private static func beginRound(state: inout GameState, events: inout [GameEvent]) {
        state.shot = state.rules.startingShot
        state.shotClock = nil
        state.ball = nil
        state.lastPasser = nil
        state.arrivedBy = nil
        state.lastPlayThisPossession = nil
        state.pendingShotOverride = nil
        state.passiveShotOverride = nil
        state.whistlesSilenced = false
        state.whistleCallsThisRound.removeAll()
        // **The Ref deck is shuffled every round**, retired officials and all.
        state.officials = state.shuffled(state.officials)
        assignCrew(state: &state, events: &events)
        events.append(.roundBegan(round: state.round, inbounder: state.inbounder))
        // **A referee inbounds it.** The round opens on the officials rather than on
        // whoever happened to hold it last. With no crew out — a match that fields none —
        // it falls back to the player, as it always did.
        if let official = state.armedWhistles.first?.id {
            // **To each player in turn**, round by round — the rotation the inbound has
            // always gone round, clockwise, from whoever opened the game.
            state.phase = .refereeInbound(official: official, to: state.inbounder)
        } else {
            state.phase = .inbound(inbounder: state.inbounder)
        }
    }

    /// **The ball arriving from a referee**, once the floor has shown him holding it and
    /// throwing it. The same arrival a player's inbound makes: a fresh round is handed a
    /// clock and one inside a round keeps the one it had, and it is not a pass — no SHOT,
    /// no assist.
    @discardableResult
    static func completeRefereeInbound(state: inout GameState) -> [GameEvent] {
        guard case .refereeInbound(_, let target) = state.phase else { return [] }
        var events: [GameEvent] = []
        state.inboundBarred = nil
        state.ball = target
        events.append(.refereeInbounded(to: target))
        if state.shotClock == nil {
            state.shotClock = state.shotClockLength
            events.append(.shotClockSet(state.shotClockLength))
        }
        beginPossession(target, tickClock: false, state: &state, events: &events)
        settleHands(state: &state, events: &events)
        return events
    }

    /// **The official who made the call puts it back in**, to anybody but the man it was
    /// called on. If he has already gone — Crew Chief and Officially Infamous both send a
    /// caller off — whoever is still working takes it.
    private static func refereeReinbound(caller: UUID, offender: Seat,
                                         state: inout GameState, events: inout [GameEvent]) {
        reinbound(by: offender, state: &state, events: &events)
        let official = state.armedWhistles.contains(where: { $0.id == caller })
            ? caller : state.armedWhistles.first?.id
        guard let official else { return }
        let to = state.pick(from: Seat.allCases.filter { $0 != offender })
        state.phase = .refereeInbound(official: official, to: to)
    }

    /// **The three officials working this round**, turned face-up off the officials deck.
    ///
    /// They belong to nobody and nobody played them: everyone can read what the crew is
    /// watching for and plays under it. A referee who stayed on from the round before
    /// keeps his place and the rest of the crew is filled in around him.
    private static func assignCrew(state: inout GameState, events: inout [GameEvent]) {
        let slots = state.rules.refereeSlots - state.armedWhistles.count
        guard slots > 0 else { return }
        var assigned: [CardDescriptor] = []
        for _ in 0..<slots {
            guard !state.officials.isEmpty else { break }
            let card = state.officials.removeLast()
            state.armedWhistles.append(ArmedWhistle(owner: nil, card: card))
            assigned.append(card.descriptor)
        }
        guard !assigned.isEmpty else { return }
        events.append(.crewAssigned(cards: assigned))
    }

    /// **One official off the floor, with everything his leaving is worth.**
    ///
    /// Three cards send a man off one at a time — a Challenge, the Crew Chief's own
    /// calls, and Dishtracting Ball — and the Retiring Official's parting gift has to
    /// land on all three, not only on the round ending under him. A replacement is not
    /// drawn here: the caller says whether the crew fills back up, because a Challenge
    /// wants the new man out immediately and the end of a round does not.
    @discardableResult
    private static func sendOff(_ at: Int, state: inout GameState,
                                events: inout [GameEvent]) -> Card {
        let leaving = state.armedWhistles.remove(at: at)
        // "When he leaves: Retirement is shuffled into the deck." However he leaves.
        if leaving.card.descriptor.whistle?.shufflesRetirementOnLeaving == true,
           !state.discard.isEmpty {
            state.deck = state.shuffled(state.deck + state.discard)
            state.discard.removeAll()
            events.append(.deckReshuffled)
        }
        // Retired officials go to the bottom of the Ref deck, never to Retirement — except
        // The Equalizer, which leaves the game.
        if leaving.card.descriptor.whistle?.neverReturns != true {
            state.officials.insert(leaving.card, at: 0)
        }
        return leaving.card
    }

    /// Who a Clamp on its way is heading for: Gravity's magnet if one is out, otherwise
    /// whoever has the ball. Read by a call that pays the man being guarded.
    private static func clampVictim(in state: GameState) -> Seat? {
        state.clampTarget ?? state.clampMagnet ?? state.ball
    }

    private static func beginPossession(_ seat: Seat, tickClock shouldTick: Bool,
                                        fromRebound: Bool = false, fromOwnMiss: Bool = false,
                                        offering: Bool = true, alreadyDrew: Bool = false,
                                        state: inout GameState, events: inout [GameEvent]) {
        state.ball = seat
        state.callsAnswered = []
        state.currentAim = nil
        state.aimedCard = nil
        state.aimedTarget = nil
        state.lastPlayThisPossession = nil
        state.lastPlayWasCombo = false
        state.movesThisPossession = 0
        state.movesPlayedThisPossession = []
        state.movesClosed = false
        state.playedVarenaThisPossession = false
        state.playedVariaballThisPossession = false
        state.possessionFromRebound = fromRebound
        state.possessionFromOwnRebound = fromOwnMiss
        state.possessionWasInterrupted = false
        state.footLocked = []
        state.dunkOffered = false
        state.slotsExchangedThisPossession = false
        state.sellingOut = false
        state.nextShotBonus = 0
        state.moveCardsThisPossession = 0
        state.playedIntangibleThisPossession = false
        state.possessedThisRound.insert(seat)
        // Blight Ball: the TOVs come with the ball, whoever it came from.
        if state.ballEffect.turnoversTravel {
            if let carrier = state.pileCarrier, carrier != seat, state[carrier].turnovers > 0 {
                let pile = state[carrier].turnovers
                state[carrier].turnovers = 0
                state[seat].turnovers += pile
                events.append(.turnoversMoved(from: carrier, to: seat, count: pile))
            }
            state.pileCarrier = seat
        }
        // Mic'd Up ends where the possession does. Cleared before the draw, so one turned
        // up by this possession's own card is the one that stands.
        state.holderShot = 0

        // **Draw, then the defenders.**
        //
        // The card comes off the pile before anything is allowed to act on it — a Clamp
        // is still in the air at draw time, so the card just drawn is a card you can
        // answer it with, and it is in the hand a lock picks from. Landing them first
        // meant a Contest that arrived on the pass and a Pump Fake drawn a moment later
        // could never meet, which is the whole of "drawing the out".
        if !alreadyDrew {
            openingEffects(for: seat, state: &state, events: &events)
            // Fresh Ball: a ball nobody has broken in. The possession opens dry.
            if state.skipsNextDraw {
                state.skipsNextDraw = false
            } else {
                // **The possession's own card.** Marked, so Discontinued Dribble knows
                // not to call a dribble on a ball nobody has put down yet. Recharge Rock
                // doubles it, and Variaball Vinyl hands it to anybody.
                let count = max(1, state.ballEffect.turnDrawMultiplier)
                let drawer = state.floorEffect.turnDrawToRandomPlayer
                    ? state.pick(from: Seat.allCases) : seat
                drawTogether([drawer], count: count, state: &state, events: &events,
                             opening: true)
                // Hero Ball: a board pays a card of its own. A game of nothing but misses
                // and rebounds still puts cards in hands, so the hands cannot run down to
                // nothing with the ball stuck at the rim.
                if fromRebound, state.ballEffect.drawsOnRebound > 0 {
                    drawTogether([seat], count: state.ballEffect.drawsOnRebound,
                                 state: &state, events: &events, opening: true)
                }
            }
            refills(for: seat, state: &state, events: &events)
        }

        // **And now the question, with the pile still in the air.** A man who steps out
        // of the play is not there for the defenders either, and they land immediately
        // below — so this is the last moment it can be asked. The whole opening is held
        // and run again on the answer, which is what `drew` is for.
        let offers = offering ? countersOnOffer(to: seat, in: state) : []
        if !offers.isEmpty {
            state.heldPossession = GameState.HeldPossession(seat: seat, ticks: shouldTick,
                                                            fromRebound: fromRebound,
                                                            fromOwnMiss: fromOwnMiss,
                                                            drew: true)
            state.phase = .awaitingCounter(seat: seat, cards: offers)
            return
        }

        // **A defender is an assignment, and it lasts until it is beaten.** He bites on his
        // man's possession and he is still there on the next one: what sends him off is the
        // condition printed on his own card — see `settleClamps`. The one-swipe Clamps,
        // which have done their work the moment they land, still go.
        for other in Seat.allCases {
            state[other].clamps.removeAll { $0.bitten && !($0.card.clamp?.isStanding ?? false) }
        }
        for index in state[seat].clamps.indices {
            state[seat].clamps[index].bitten = true
        }
        // Gravity takes them all, wherever they were sent — added to whatever he is already
        // carrying, up to the slots one pile may fill.
        let landing = clampLanding(seat, in: state)
        let arriving = state.pendingClamps.map { pending -> ActiveClamp in
            var clamp = pending
            clamp.bitten = landing == seat
            return clamp
        }
        state[landing].clamps = Array((state[landing].clamps + arriving)
            .suffix(state.rules.clampSlots))
        state.clampMagnet = nil
        state.pendingClamps = []


        // A Whistle that was waiting for these defenders to land. This is the first
        // moment the clamped player exists, which is the whole reason it waited.
        if let voided = state.pendingClampVoid {
            state.pendingClampVoid = nil
            if let whistle = state.armedWhistles.first(where: { $0.id == voided }),
               let effect = whistle.card.descriptor.whistle, !state[seat].clamps.isEmpty {
                let culprit = state[seat].clamps.first?.from
                // Captured before the board is cleared — the scene holds this card up.
                let voidedClamp = state[seat].clamps.first?.card
                let waved = state[seat].clamps.count
                state[seat].clamps.removeAll()
                spendWhistle(voided, state: &state, events: &events)
                // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
                state.possessionWasInterrupted = true
                events.append(.whistleBlew(owner: whistle.owner, card: whistle.card.descriptor,
                                           cancelled: "the Clamp's effect",
                                           cancelledCard: voidedClamp, against: culprit))
                stoppage(state: &state, events: &events)
                events.append(.clampVoided(seat: seat, card: whistle.card.descriptor, count: waved))

                if let culprit, effect.offenderDiscardsBag {
                    spendHand(of: culprit, state: &state, events: &events)
                }
                if let culprit {
                    for _ in 0..<effect.offenderDiscards { discardAtRandom(from: culprit, state: &state) }
                }
                // A Flagrant leaves the ball where it is; anything milder still costs the
                // clamped player the possession they were starting.
                awardFreeThrows(effect.freeThrowsToClampVictim, to: seat,
                                offender: effect.victimKeepsBall ? nil : culprit,
                                source: whistle.card.name, state: &state, events: &events)
            }
        }

        // Contact Court: being clamped is a trip to the line, and the Clamp still lands.
        if state.floorEffect.freeThrowsWhenClamped > 0,
           let first = state[seat].clamps.first(where: \.bitten),
           !has(seat, in: state, { $0.freeThrowWhenClamped > 0 }) {
            awardFreeThrows(state.floorEffect.freeThrowsWhenClamped, to: seat,
                            offender: first.from, source: state.currentCourt.name,
                            state: &state, events: &events)
        }

        // **Freethrow Merchant: a trip every time a man picks him up.** It no longer
        // blanks the Clamp — the defender arrives and does his job, and the merchant is
        // paid for the contact on the way. Only for the ones that have just bitten, so
        // standing there is not a free throw a possession.
        let perClamp = state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.freeThrowWhenClamped ?? 0) }
        if perClamp > 0 {
            let arriving = state[seat].clamps.filter(\.bitten)
            if let first = arriving.first {
                awardFreeThrows(perClamp * arriving.count, to: seat, offender: first.from,
                                source: "Freethrow Merchant", state: &state, events: &events)
            }
        }

        // **Last of all, and only what survived.** Everything above can cancel a Clamp
        // before it bites: a Blocking Foul voiding it, Freethrow Merchant replacing it
        // with a trip to the line. Taking the cards first and cancelling afterwards left
        // a player robbed by a Clamp the rules had already thrown out.
        //
        // This is why the void waits for the landing at all — the card owes a free throw
        // to *the clamped player*, and at the moment it is played there is nobody to
        // name. Waiting costs nothing now that the bite happens after the waiting.
        // Named before the one-offs bite and leave: what is announced is everything that
        // landed on him, not what is still standing a moment later.
        if !state[seat].clamps.isEmpty {
            events.append(.clampedPossession(seat: seat,
                                             clamps: state[seat].clamps.map(\.brief)))
        }

        // Picked once, here, and then fixed for the possession.
        for index in state[seat].clamps.indices {
            var wanted = state[seat].clamps[index].card.clamp?.locksRandomCards ?? 0
            guard wanted > 0 else { continue }
            // Smacktop: one more card held.
            if state.floorEffect.enhancesClamps { wanted += 1 }
            var pool = state[seat].bag.map(\.id)
            var chosen: [UUID] = []
            for _ in 0..<min(wanted, pool.count) {
                chosen.append(pool.remove(at: state.roll(0...(pool.count - 1))))
            }
            state[seat].clamps[index].locked = chosen
        }

        // Dirty Player: whoever sent it goes after the knee.
        if !state[seat].injuries.isEmpty {
            for clamp in state[seat].clamps {
                let toll = state[clamp.from].intangibles.reduce(0) {
                    $0 + ($1.intangible?.clampCostsInjured ?? 0)
                }
                for _ in 0..<toll { discardAtRandom(from: seat, state: &state) }
            }
        }

        // A Clamp that does its work the moment it lands has nothing left to do, so it
        // does not stay on the floor. Only the ones that sit on your SHOT are defenders
        // in any lasting sense — the rest are one swipe and gone.
        //
        // **Last, and that is the whole of it.** Everything that answers a Clamp — a
        // Blocking Foul waiting to void one, Freethrow Merchant turning one into a trip
        // to the line — runs above this and has to find the Clamp still there.
        state[seat].clamps.removeAll { $0.card.clamp?.isStanding == false }

        if shouldTick, tickClock(by: -1, holder: seat, state: &state, events: &events) { return }

        // Rolled after the draw, so a card that just arrived can be the one you are left
        // with rather than being dead the moment it lands.
        rollInjuryLock(seat, state: &state)

        // Bone Bruise takes its card at the top of the turn, after the draw — so the turn
        // opens with a choice rather than with a hand already one short.
        // Dishtracting Ball asks the same question, after the same draw.
        let toll = state[seat].injuries.reduce(0) { $0 + ($1.injury?.discardsEachTurn ?? 0) }
        let asking = state[seat].injuries.first(where: { ($0.injury?.discardsEachTurn ?? 0) > 0 })
        if toll > 0, let asking, !state[seat].bag.isEmpty {
            state.phase = .awaitingGiveUp(seat: seat, card: asking,
                                          count: min(toll, state[seat].bag.count))
            return
        }
        state.phase = .possession(holder: seat)
        takeTheLine(state: &state, events: &events)
        handOverBall(state: &state, events: &events)
        // Huge Altercation can empty a hand between the question and the answer. Nothing
        // to take means nothing is taken, rather than a question nobody can answer.
        if case .awaitingCardFrom(_, _, let victim) = state.phase, state[victim].bag.isEmpty {
            state.phase = .possession(holder: state.ball ?? victim)
            state.pendingPlay = nil
            state.pendingActor = nil
        }
        strandOut(state: &state, events: &events)
    }

    /// **What the floor and the ball do as a possession opens**, before its draw.
    private static func openingEffects(for seat: Seat, state: inout GameState,
                                       events: inout [GameEvent]) {
        let floor = state.floorEffect
        // Clearcoat Court: everything standing, gone.
        if floor.wipesEachPossession {
            state.discard.append(contentsOf: state.armedWhistles.map(\.card))
            state.armedWhistles.removeAll()
            for other in Seat.allCases {
                state[other].clamps.removeAll()
                healInjuries(of: other, state: &state)
                state.discard.append(contentsOf: state[other].intangibles.map { Card($0) })
                state[other].intangibles.removeAll()
            }
            events.append(.floorWiped)
        }
        // Grayvstone: the ball is whichever went in the pile last.
        if floor.ballFromDiscard {
            if let raised = state.discard.last(where: {
                $0.descriptor.variaball != nil && $0.descriptor.variaball?.rollsFromDiscard != true
            }) {
                state.discard.removeAll { $0.id == raised.id }
                events.append(.ballChanged(card: raised.descriptor))
                setBall(raised, by: nil, state: &state, events: &events)
            } else {
                events.append(.graveyardEmpty)
            }
        }
        // Carousel Court: every hand one seat round, the way it was declared.
        if floor.rotatesHands, let clockwise = state.carouselClockwise {
            var bags: [Seat: [Card]] = [:]
            for other in Seat.allCases {
                bags[clockwise ? other.left : other.right] = state[other].bag
            }
            for (owner, cards) in bags { state[owner].bag = cards }
            events.append(.handsRotated(clockwise: clockwise))
        }
        // Turnstile Tile: the other way from last possession.
        if floor.turnstileSwing != 0 { state.turnstileUp.toggle() }
        // Malice Palace: the hand goes before the draw.
        if floor.discardsHandBeforeDraw {
            spendHand(of: seat, state: &state, events: &events)
        }
        // Shufflebag Ball: the hand back into the deck, and as many out again.
        if state.ballEffect.reshufflesHandEachPossession, !state[seat].bag.isEmpty {
            let count = state[seat].bag.count
            state.deck += state[seat].bag
            state[seat].bag.removeAll()
            state.deck = state.shuffled(state.deck)
            drawTogether([seat], count: count, state: &state, events: &events, opening: true)
        }
    }

    /// **After the draw for turn**: Recharging Resin and MVPiquia fill a hand, and
    /// Roleplayer Polymer feeds everyone else.
    private static func refills(for seat: Seat, state: inout GameState,
                                events: inout [GameEvent]) {
        let floor = state.floorEffect
        // **A full hand is whatever the match deals**, not a number printed on the floor.
        let hand = state.rules.startingBagSize
        var target: Int? = floor.refillsToHand ? hand : nil
        if floor.leaderRefillsToHand,
           state[seat].score == (state.players.map(\.score).max() ?? 0) {
            target = hand
        }
        if let target {
            while state[seat].bag.count < target {
                let before = state[seat].bag.count
                drawOnce(seat, state: &state, events: &events, opening: true)
                if state[seat].bag.count == before { break }
            }
        }
        if floor.othersDrawEachPossession > 0 {
            drawTogether(Seat.allCases.filter { $0 != seat },
                         count: floor.othersDrawEachPossession,
                         state: &state, events: &events, opening: true)
        }
    }

    /// Whether the card played immediately before was a dribble of any kind.
    ///
    /// Read back out of the library rather than kept on the state: the id is already
    /// there, the library already knows what it is, and a second field saying the same
    /// thing is a second field to keep in step across the wire.
    private static func lastPlayWasDribble(_ state: GameState) -> Bool {
        guard let last = state.lastPlayThisPossession else { return false }
        return CardLibrary.byID[last]?.isDribble ?? false
    }

    /// Returns true when the clock ran out and the round has already been ended.
    @discardableResult
    private static func tickClock(by amount: Int, holder: Seat,
                                  state: inout GameState, events: inout [GameEvent]) -> Bool {
        let remaining = (state.shotClock ?? state.shotClockLength) + amount
        state.shotClock = remaining
        events.append(.shotClockTicked(remaining))
        guard remaining <= 0 else { return false }
        // **Moves At Own Pace plays at nought.** Not forgiven, held: `clockCatchesUp`
        // calls it the moment the passive leaves him.
        guard !has(holder, in: state, { $0.ignoresViolations }) else { return false }
        state[holder].turnovers += 1
        events.append(.turnover(holder))
        stoppage(state: &state, events: &events)
        endRound(state: &state, events: &events)
        return true
    }

    /// The clock catching up with a man who had been ignoring it.
    ///
    /// **Called wherever a passive comes off a player**, because that is the only moment
    /// a violation he has been sitting on becomes callable. A man on 00 who loses Moves
    /// At Own Pace loses the ball with it.
    private static func clockCatchesUp(_ seat: Seat, state: inout GameState,
                                       events: inout [GameEvent]) {
        guard state.ball == seat, let clock = state.shotClock, clock <= 0,
              !has(seat, in: state, { $0.ignoresViolations }) else { return }
        state[seat].turnovers += 1
        events.append(.turnover(seat, cause: CardLibrary.shotClockViolation.name))
        stoppage(state: &state, events: &events)
        endRound(state: &state, events: &events)
    }

    /// **What a card is worth on the board in front of it**, before combos, clocks and
    /// passives have their say.
    ///
    /// Nearly always the number printed on it. Behind-the-Back is the one card priced off
    /// the ball instead: it is worth whatever the pass that found you was worth, so a
    /// good feed sent straight back is a good feed twice and a swing sent back is only a
    /// swing. Read before the play resolves, because completing the pass makes *this*
    /// card the one the ball arrived by.
    private static func printedWorth(of descriptor: CardDescriptor,
                                     in state: GameState) -> Int {
        if overridesPassGain(descriptor, in: state) { return 0 }
        guard descriptor.matchesArrivingPass else { return descriptor.baseShotDelta }
        return state.arrivedBy?.baseShotDelta ?? 0
    }

    /// **Snow Ball: passing pays nothing, whatever the pass was worth.** The ball's own
    /// −10% is the whole of what a pass does to SHOT — a feed worth more than that would
    /// otherwise cancel the toll out and leave the ball breaking even for ever, which is
    /// the opposite of snowballing. See `VariaballEffect.overridesPassShot`.
    private static func overridesPassGain(_ descriptor: CardDescriptor,
                                          in state: GameState) -> Bool {
        descriptor.isPass && state.ballEffect.overridesPassShot
    }

    private static func adjustShot(by delta: Int, state: inout GameState) {
        state.shot = max(state.rules.shotFloor, min(state.rules.shotCeiling, state.shot + delta))
    }

    private static func resolve(_ target: PassTarget, from seat: Seat, state: GameState) -> Seat? {
        if let geometric = seat.seat(inDirection: target) { return geometric }
        switch target {
        case .random:
            let others = Seat.allCases.filter { $0 != seat }
            var pool = state
            return others[pool.roll(0...(others.count - 1))]
        // Somebody has to say. `apply` asks before it gets here — see
        // `Phase.awaitingPassTarget` — so reaching this means nobody did.
        case .choice, .leftOrRight: return nil
        // **Touch keeps it going the way it came.** Left or right only, which is what the
        // legality check below already guarantees — an Across arrival has no side to
        // continue and the card cannot be played at all.
        case .continuing: return continuation(from: seat, in: state)
        default: return state.lastPasser
        }
    }

    /// **Where a Touch sends it**, or nil when the ball did not arrive from a neighbour.
    ///
    /// The direction of travel is the side the last passer is on: a ball that came from
    /// your left carries on to your right, and one that came from across came from no
    /// side at all.
    static func continuation(from seat: Seat, in state: GameState) -> Seat? {
        guard let came = state.lastPasser else { return nil }
        if came == seat.left { return seat.right }
        if came == seat.right { return seat.left }
        return nil
    }

    /// Who may be picked, when a card lets the passer choose.
    /// Who a pass may be thrown to.
    ///
    /// **His own seat is on the list.** People throw it off the glass and take it back,
    /// and the sheet only says *another* player where the card means it — see
    /// `CardDescriptor.passesToOthersOnly`. Left-or-right is geometry and never includes
    /// him. What happens when he does name himself is `completePass`'s business: it is
    /// Traveling, unless he moves at his own pace.
    /// **Who a card may be aimed at before it is played**, or nil for a card that does not
    /// name anybody. See `aimingCard`.
    static func aimChoices(_ descriptor: CardDescriptor, by seat: Seat) -> [Seat]? {
        if descriptor.cut != nil { return Seat.allCases.filter { $0 != seat } }
        guard let target = descriptor.passTarget, target == .choice || target == .leftOrRight
        else { return nil }
        return passChoices(target, from: seat, othersOnly: descriptor.passesToOthersOnly)
    }

    /// Whether the question standing is a card asking who, before it has been played —
    /// the one kind of question that can simply be taken back.
    static func canCancelAim(_ state: GameState) -> Bool {
        guard case .awaitingTarget = state.phase else { return false }
        return state.aimingCard != nil || state.assigningClamp != nil
    }

    /// **Taken back.** The card goes back to being a card in the hand; nothing it would
    /// have done has happened.
    @discardableResult
    static func cancelAim(state: inout GameState) -> [GameEvent] {
        guard canCancelAim(state), let actor = state.pendingActor else { return [] }
        state.aimingCard = nil
        state.assigningClamp = nil
        state.pendingActor = nil
        state.phase = .possession(holder: actor)
        return []
    }

    static func passChoices(_ target: PassTarget, from seat: Seat,
                            othersOnly: Bool = false) -> [Seat] {
        switch target {
        case .leftOrRight: return [seat.left, seat.right]
        default:
            return othersOnly ? Seat.allCases.filter { $0 != seat } : Seat.allCases
        }
    }

    /// The targets worth naming, out of the ones that are legal.
    ///
    /// **A man may name himself, and almost never should.** Passing to yourself is
    /// Traveling for everybody but the one holding Moves At Own Pace — so it is a legal
    /// choice and a terrible one, and an AI picking uniformly out of the legal list threw
    /// the ball away one throw in four. One owner, because the floor's opponents and the
    /// harness's have to make the same judgement.
    static func sensibleTargets(_ choices: [Seat], for actor: Seat,
                                in state: GameState) -> [Seat] {
        // A Clamp on yourself is a play the AI does not know how to make yet.
        guard !has(actor, in: state, { $0.ignoresViolations }) || state.assigningClamp != nil
        else { return choices }
        let others = choices.filter { $0 != actor }
        return others.isEmpty ? choices : others
    }

    /// Who names a target right now.
    ///
    /// A Floor General names every one of them, whoever is playing the card — which is
    /// the whole of what the card does. Asked in one place so a new prompt cannot forget.
    static func asker(instead of: Seat, in state: GameState) -> Seat {
        Seat.allCases.first { has($0, in: state, { $0.aimsEveryTarget }) } ?? of
    }

    /// Whether a passive is standing on this seat.
    static func has(_ seat: Seat, in state: GameState,
                    _ test: (IntangibleEffect) -> Bool) -> Bool {
        state[seat].intangibles.contains { $0.intangible.map(test) ?? false }
    }

    /// Whether an Injury this player is carrying says so.
    static func injured(_ seat: Seat, in state: GameState,
                        _ test: (InjuryEffect) -> Bool) -> Bool {
        state[seat].injuries.contains { $0.injury.map(test) ?? false }
    }

    /// Whoever holds Gravity, if anybody — the man every Clamp lands on.
    static func gravityHolder(in state: GameState) -> Seat? {
        Seat.allCases.first { has($0, in: state, { $0.attractsClamps }) }
    }

    /// **A round ends on a shot.** A turnover hands the ball back in and play carries on,
    /// which keeps the one way a round closes the one everybody can see coming — and is
    /// what the officials handing out turnovers everywhere is paid for.
    private static func endRound(state: inout GameState, events: inout [GameEvent]) {
        state.roundEnding = true
        defer { state.roundEnding = false }
        // **A hand owed to the pile goes before the round does.** Huge Altercation queues
        // every hand to the edge of its chain, and a free throw in that chain can end the
        // round first — at the half it was then paid out of the five halftime had dealt.
        while let owed = state.owes(.spendHand) { pay(owed, state: &state, events: &events) }
        events.append(.roundEnded(state.round))
        stoppage(state: &state, events: &events)
        state.shotsThisRound = 0
        state.possessedThisRound = []
        state.shotCeilingThisRound = nil
        state.dimeFrom = nil
        state.mustShootFirst = nil
        state.mustPassFirst = nil
        state.mustMoveFirst = nil
        state.nextThreeBonus = 0
        state.inboundBarred = nil
        state.holderShot = 0
        // The orders still in flight go with it. A shot the round no longer has room for
        // must not go up inside halftime's deal, and a return leg has nowhere to land.
        state.forget(.shootAtOnce, .returnBall)

        // **The crew changes at the end of the round, and only there.** Three officials
        // work the whole of it whatever they call; the round turning over is what sends
        // them off and brings three more out — see `assignCrew`.
        //
        // **What a leaving official takes with him.** The Retiring Official puts
        // Retirement back into the deck on his way out.
        if state.armedWhistles.contains(where: {
            $0.card.descriptor.whistle?.shufflesRetirementOnLeaving == true
        }), !state.discard.isEmpty {
            state.deck = state.shuffled(state.deck + state.discard)
            state.discard.removeAll()
            events.append(.deckReshuffled)
        }
        // To the bottom of the Ref deck, never the main discard.
        state.officials.insert(contentsOf: state.armedWhistles.map(\.card), at: 0)
        state.armedWhistles = []
        state.clockTicksOwed = 0
        state.threeDiscount = 0
        state.rookieSwapped = nil
        state.passesThisRound = 0
        state.ignoredClamps = []
        state.sellingOut = false
        state.courtShotRoll = nil
        for seat in Seat.allCases {
            state[seat].scoredLastRound = state[seat].scoredThisRound
            state[seat].scoredThisRound = false
            // Off at the whistle and back into the pile, so halftime shuffles it in with
            // everything else. A Devastating one is not shed and so never returns.
            // The ones the sheet gives a round to, good and bad alike.
            let expired = state[seat].intangibles.filter { $0.intangible?.lastsRound == true }
            state[seat].intangibles.removeAll { $0.intangible?.lastsRound == true }
            state.discard.append(contentsOf: expired.map { Card($0) })
            let healed = state[seat].injuries.filter { $0.injury?.lasts == .round }
            state[seat].injuries.removeAll { $0.injury?.lasts == .round }
            state.discard.append(contentsOf: healed.map { Card($0) })
            state[seat].injuryUnlocked = []
        }

        if state.round >= state.rules.roundsPerGame {
            state.phase = .gameOver
            state.ball = nil
            state.shotClock = nil
            events.append(.gameEnded(winners: winners(of: state)))
            return
        }
        if state.round == state.rules.roundsPerHalf {
            // Halftime already puts everything back, so recalling would be doing it twice.
            halftime(state: &state, events: &events)
        } else {
            recallWhistles(state: &state, events: &events)
        }
        state.round += 1
        // Rotation continues clockwise across halftime.
        state.inbounder = state.inbounder.clockwise
        beginRound(state: &state, events: &events)
    }

    /// Spent Whistles go back into the deck at the end of every round.
    ///
    /// There is one of each, so without this you meet a Whistle once and never again —
    /// and the cards that answer them, Coach's Challenge and Cleared to Play, would spend
    /// most of a game as dead weight. Only spent ones return: a Whistle still in a hand
    /// stays there, which is what a table would do.
    private static func recallWhistles(state: inout GameState, events: inout [GameEvent]) {
        let returning = state.discard.filter { $0.descriptor.type == .whistle }
        guard !returning.isEmpty else { return }
        state.discard.removeAll { $0.descriptor.type == .whistle }
        state.deck = state.shuffled(state.deck + returning)
        events.append(.whistlesRecalled(count: returning.count))
    }

    private static func halftime(state: inout GameState, events: inout [GameEvent]) {
        // **Nothing goes back into the deck.** The hands are spent into the discard and
        // the new ones dealt out of whatever is left, so a game works its way down one
        // deck instead of meeting the same cards again after the break. The deck still
        // comes back off the discard when it finally runs out — see `draw`.
        for seat in Seat.allCases {
            state.discard.append(contentsOf: state[seat].bag)
            state[seat].bag.removeAll()
        }
        // **Called before it deals.** The half is the moment; the deal is what the half
        // does. Appended after the cards, it read as twenty cards arriving from nowhere
        // and *then* being explained.
        events.append(.halftime)
        deal(to: Seat.allCases, count: state.rules.startingBagSize, state: &state, events: &events)
        settleHands(state: &state, events: &events)
    }

    private static func deal(to seats: [Seat], count: Int,
                             state: inout GameState, events: inout [GameEvent]) {
        // Passives never land in a bag, so this deals to a hand size rather than a draw
        // count. Game Breaks are reshuffled away rather than fired, so nothing a deal
        // turns up can cut a player who has already been dealt.
        // Tri-hard Tiling: nobody is dealt past the limit.
        let count = min(count, state.handLimit)
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

    /// Pays whatever a draw chain owes, now that it has finished.
    ///
    /// Called at the outermost edge of a deal or a draw rather than where the card landed,
    /// because "discard your hand" has to mean the hand you end up with.
    static func settleHands(state: inout GameState, events: inout [GameEvent]) {
        drain(state: &state, events: &events)
        settleClamps(state: &state, events: &events)
        // **Last of all.** The drain has its own check, but the defenders settle after it
        // — and a man left with a forced finish he cannot take and no card he may play is
        // a man the clock runs out on. See `strandOut`.
        strandOut(state: &state, events: &events)
    }

    // MARK: - Assignments

    /// **Reads every standing defender against what is printed on his own card.**
    ///
    /// Two things can send one off. A man who has given up the ball has nobody left to
    /// guard, so his defender simply leaves — that is the floor under the whole system,
    /// and it is why no player can ever be stuck with a Clamp they cannot answer. And a
    /// man who has met the counter printed on the card has *beaten* him, which pays.
    ///
    /// Run wherever hands settle, so the moment a hand, a clock or a SHOT crosses the
    /// line printed on a defender's face, he is off — there is nothing to remember and
    /// nothing to claim.
    static func settleClamps(state: inout GameState, events: inout [GameEvent]) {
        // Nobody to guard. Quiet, and no payoff: you did not beat him, he left.
        for seat in Seat.allCases where state.ball != seat {
            let idle = state[seat].clamps.filter {
                $0.bitten && ($0.card.clamp?.clearedBy ?? .givingUpTheBall) == .givingUpTheBall
            }
            guard !idle.isEmpty else { continue }
            state[seat].clamps.removeAll { idle.contains($0) }
            state.discard.append(contentsOf: idle.map { Card($0.card) })
            events.append(.clampExpired(seat: seat, cards: idle.map(\.card)))
        }

        // **Beaten.** Every standing defender whose printed line the ball-holder has
        // crossed goes to Retirement. Nothing is paid for it: the reward is being rid
        // of him.
        guard case .possession(let holder) = state.phase, state.pending.isEmpty else { return }
        let beaten = state[holder].clamps.filter { clamp in
            guard clamp.bitten, clamp.card.clamp?.isStanding == true,
                  let counter = clamp.card.clamp?.clearedBy, counter != .givingUpTheBall
            else { return false }
            return counter.met(by: holder, in: state)
        }
        guard !beaten.isEmpty else {
            // **Checked again here.** A defender forcing a finish the man cannot take can
            // leave him with nothing legal at all, and this runs *after* the drain — so
            // the drain's own check has already been and gone. A man with nothing to do
            // is a man the clock runs out on.
            strandOut(state: &state, events: &events)
            return
        }
        retireBeaten(beaten, on: holder, state: &state, events: &events)
    }

    /// **A Clamp cleared by something happening** rather than by a line being crossed:
    /// a pass, a shot, an Intangible, a change of ball, a stoppage. Read at the moment it
    /// happens, because by the next settle it is already over.
    static func clampEvent(_ counter: ClampCounter, on seats: [Seat], passingTo receiver: Seat? = nil,
                           state: inout GameState, events: inout [GameEvent]) {
        for seat in seats {
            let beaten = state[seat].clamps.filter { clamp in
                guard clamp.bitten, let cleared = clamp.card.clamp?.clearedBy else { return false }
                if cleared == counter { return true }
                // Trap: only a pass to somebody nobody is guarding.
                if cleared == .passingToAnOpenPlayer, counter == .passingTheBall,
                   let receiver { return isOpen(receiver, in: state) }
                return false
            }
            guard !beaten.isEmpty else { continue }
            retireBeaten(beaten, on: seat, state: &state, events: &events)
        }
    }

    /// **Any stoppage of play**: a call, a turnover, a basket, free throws, the end of a
    /// round — anything where the players stop running.
    static func stoppage(state: inout GameState, events: inout [GameEvent]) {
        clampEvent(.stoppageOfPlay, on: Seat.allCases, state: &state, events: &events)
    }

    /// **Open**: a player with no Clamps on them.
    static func isOpen(_ seat: Seat, in state: GameState) -> Bool {
        state[seat].clamps.isEmpty
    }

    private static func retireBeaten(_ beaten: [ActiveClamp], on seat: Seat,
                                     state: inout GameState, events: inout [GameEvent]) {
        state[seat].clamps.removeAll { beaten.contains($0) }
        for clamp in beaten {
            state.discard.append(Card(clamp.card))
            events.append(.clampBeaten(seat: seat, card: clamp.card))
        }
    }

    /// **Pays whatever the play owes, one step at a time, until nothing payable is left.**
    ///
    /// Every step that can be paid is paid before the drain ends, and one that cannot be
    /// paid *stays owed* — the return leg needs a possession to send the ball home from,
    /// and a chain that ended on a question does not have one yet. The drain runs again
    /// at the edge of whatever answers the question, and the step is still there.
    ///
    /// **Nothing else may clear a step.** That is the whole of it: five fields each held
    /// one owed thing, and every bug of a certain shape was one of them cleared before it
    /// was paid, paid twice, or never paid at all because a call site returned early. See
    /// `Step`, which lists them.
    ///
    /// Paying a step can owe another — a forced shot ends a round, which lands a trip on
    /// the line — so this loops rather than passing once. Bounded because a rule that
    /// owes itself forever is a hang rather than a wrong answer.
    static func drain(state: inout GameState, events: inout [GameEvent]) {
        var passes = 0
        while passes < 32 {
            passes += 1
            guard let step = payable(in: state) else { break }
            pay(step, state: &state, events: &events)
        }
        // Tick-Tock Tile: the cards played have resolved, so their ticks come off now.
        if state.clockTicksOwed > 0, case .possession(let holder) = state.phase {
            let owed = state.clockTicksOwed
            state.clockTicksOwed = 0
            if tickClock(by: -owed, holder: holder, state: &state, events: &events) { return }
        }
        // A step that has just asked a question leaves the floor to it.
        switch state.phase {
        case .awaitingGiveUp, .awaitingRebound: return
        default: break
        }
        // Outlet Pass: the man who threw it may put the clock back to the top as his next
        // possession opens.
        if case .possession(let holder) = state.phase, state[holder].mayResetShotClock,
           isFirstAction(state) {
            state[holder].mayResetShotClock = false
            state.phase = .awaitingOption(seat: holder, option: .resetShotClock)
            return
        }
        // **"Dunk It?"** Caught off a Lob with a dunk in hand: asked once, before anything
        // else is done with the ball.
        if case .possession(let holder) = state.phase, state.mustShootFirst == holder,
           !state.dunkOffered, isFirstAction(state) {
            state.dunkOffered = true
            let dunks = legalMoves(state, for: holder).compactMap { move -> Card? in
                guard case .play(let id) = move,
                      let card = state[holder].bag.first(where: { $0.id == id }),
                      card.descriptor.special?.dunks == true else { return nil }
                return card
            }
            if !dunks.isEmpty {
                state.phase = .awaitingCounter(seat: holder, cards: dunks)
                return
            }
        }

        // And the question a full board owes. **Read off the boards, never remembered**:
        // being over the slots is a fact about the board rather than something to keep in
        // step, so it is not a step. One at a time — answering it can rehome a passive
        // onto another full board, which asks again.
        let over = Seat.allCases
            .filter { state[$0].intangibles.count > state.intangibleSlotLimit }
            .sorted { $0.rawValue < $1.rawValue }
        state.overflowing = Set(over)
        if let seat = over.first {
            state.phase = .awaitingIntangibleDrop(seat: seat,
                                                  offered: state[seat].intangibles)
            return
        }
        strandOut(state: &state, events: &events)
    }

    /// The next step that can actually be paid, in the order the five have always been
    /// paid in — see `Step.rank`. Nil when the list is empty or nothing on it is ready.
    private static func payable(in state: GameState) -> Step? {
        state.pending
            .filter { ready($0, in: state) }
            .min { $0.rank < $1.rank }
    }

    /// Whether the floor is in a state where this step means anything yet.
    private static func ready(_ step: Step, in state: GameState) -> Bool {
        switch step {
        // **Always.** A hand with nothing in it is a debt already settled, not one still
        // owed — leaving it on the list would have Free Agent's toll follow a man into
        // the next hand he is dealt.
        case .spendHand:
            return true
        // **Both need a possession to happen from.** A chain that ended on a question —
        // a toll, a give-up, a card asked for, a full board — has none yet, and finding
        // that and throwing the step away is exactly the bug this exists to stop.
        case .returnBall, .shootAtOnce, .tax, .intangibleBoards, .takeFromReceiver:
            if case .possession = state.phase { return true }
            return false
        // **Not the settle's to pay.** A Break waits for the draw that turned it up to
        // finish, which is a different edge — `drainBreaks` runs them, in the order they
        // came off the deck, while it holds the chain open. They sit on the one list so
        // there is no second place for an owed thing to live.
        case .revealBreak:
            return false

        // **Not the drain's to pay.** These two take the floor itself — one puts the
        // ball back in play, the other sends a man to the line — and they are paid at the
        // end of a possession rather than at the edge of a chain, which is a different
        // moment. They sit on the list so nothing can quietly clear one; `handOverBall`
        // and `takeTheLine` pop their own.
        case .handOverBall, .takeTheLine:
            return false
        }
    }

    private static func pay(_ step: Step, state: inout GameState,
                            events: inout [GameEvent]) {
        state.pending.removeAll { $0 == step }
        switch step {
        case .spendHand(let seat):
            guard !state[seat].bag.isEmpty else { return }
            spendHand(of: seat, state: &state, events: &events)

        // Right Back: home again, and paying its SHOT a second time. After the toll and
        // whatever else the trip cost him — that is the point of the card.
        case .returnBall(let home, let leg):
            guard case .possession(let holder) = state.phase, holder != home else { return }
            // Priced the way any pass is, so a ball that overrides what passing pays
            // covers the leg home too.
            adjustShot(by: printedWorth(of: leg, in: state), state: &state)
            completePass(leg, from: holder, to: home, returning: true,
                         state: &state, events: &events)

        // Alley-Oop: it goes up now, with whatever he drew still in his hands. Spent only
        // if the chain came to rest on him — it is his shot, and a chain that settled on
        // somebody else has taken it away rather than moved it.
        case .shootAtOnce(let shooter):
            guard case .possession(let holder) = state.phase, holder == shooter else {
                return
            }
            // Close-Out: a three owed to a player who cannot take one is not shot, and the
            // pass that owed it was only ever a pass. Zone: no owed shot is taken at all.
            let guarding = state[shooter].clamps.compactMap(\.card.clamp)
            if guarding.contains(where: \.blocksShooting)
                || (state.pendingBonusPoint > 0
                    && (guarding.contains(where: { $0.blocksShotTypes.contains(.three) })
                        || has(shooter, in: state, { $0.blocksThrees })
                        || injured(shooter, in: state, { $0.blocksThrees }))) {
                state.pendingBonusPoint = 0
                return
            }
            if let whistle = interceptor(of: .shoot(seat: shooter), in: &state) {
                blow(whistle, on: .shoot(seat: shooter), state: &state, events: &events)
            } else {
                resolveShot(by: shooter, bonusPoints: 0, state: &state, events: &events)
            }

        case .handOverBall(let holder):
            // Whatever queued this outranks a leg owed to a play it has interrupted.
            state.forget(.returnBall)
            state.inbounder = holder
            state.phase = .inbound(inbounder: holder)

        case .takeTheLine(let trip):
            state.phase = .freeThrows(trip: trip)

        // Frostbite Finish and Tri-hard Tiling: cards owed, and their owner picks which.
        case .tax(let seat, let count, let card):
            let owed = min(count, state[seat].bag.count)
            guard owed > 0 else { return }
            state.phase = .awaitingGiveUp(seat: seat, card: card, count: owed)

        // **Bullet's card, taken late.** The catch asked its own question first; this is
        // the pass finishing what it started once that was answered.
        case .takeFromReceiver(let passer, let receiver, let card):
            guard !state[receiver].bag.isEmpty,
                  case .possession(let holding) = state.phase, holding == receiver else { return }
            state.pendingActor = passer
            if card.cut?.forcesToPasser == true { state.stealTravelsTo = passer }
            state.phase = .awaitingCardFrom(seat: asker(instead: passer, in: state),
                                            card: card, victim: receiver)
            forceAtRandom(card, from: receiver, state: &state, events: &events)

        // Monster Ball's Intangibles go up, one board at a time, from the man with the ball.
        case .intangibleBoards:
            guard !state.intangibleBoard.isEmpty, case .possession(let holder) = state.phase
            else { return }
            state.phase = .awaitingRebound(shooter: holder)

        // Never reached: `ready` keeps these off the settle, because `drainBreaks` runs
        // them in deck order while it holds the draw chain open. Spelled out rather than
        // defaulted, so a new step cannot be added and quietly ignored.
        case .revealBreak(let held):
            revealBreak(held, state: &state, events: &events)
        }
    }


    /// One held Game Break, run.
    ///
    /// **Everything that used to happen the instant it came off the deck.** Whether it
    /// lands at all, what it does to whoever drew it, and the replacement draw a waved
    /// one earns — all of it after the draw that turned it up has finished.
    private static func revealBreak(_ pending: PendingBreak,
                                    state: inout GameState, events: inout [GameEvent]) {
        let seat = pending.seat
        let card = pending.card
        let depth = pending.depth
        let wavingBreaks = pending.waving
        // **An Injury is not a Break.** Nothing waves one off but what answers an Injury.
        if card.descriptor.injury != nil {
            landInjury(card, on: seat, depth: depth, state: &state, events: &events)
            return
        }
        guard let effect = card.descriptor.gameBreak else { return }
        // **Waved off before it is announced.** Two things do it — a run left by
        // Back-and-Forth Game, and an armed Play-On — and both mean the same thing:
        // this Break does not land, and the draw is taken again. One place, so a
        // third of them is a line rather than another branch through the reveal.
        if state.breaksWaived > 0 || (!wavingBreaks
            && state.armedWhistles.contains { $0.trigger == .gameBreakDrawn }) {
            if state.breaksWaived > 0 {
                state.breaksWaived -= 1
            } else if let waved = state.armedWhistles.first(where: {
                $0.trigger == .gameBreakDrawn
            }) {
                // Play-On is spent on the first one and the run carries on without
                // it: "until a non-Game Break card is drawn" is the card's own text.
                spendWhistle(waved.id, state: &state, events: &events)
                // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
                state.possessionWasInterrupted = true
                events.append(.whistleBlew(owner: waved.owner,
                                           card: waved.card.descriptor,
                                           cancelled: card.name,
                                           cancelledCard: card.descriptor,
                                           against: seat))
                stoppage(state: &state, events: &events)
            }
            state.discard.append(card)
            // The replacement belongs to the act the waved one was drawn in, so it takes
            // no bonus of its own — `drawCards` already paid that once for the batch.
            draw(seat, state: &state, events: &events, allowBonus: false,
                 depth: depth + 1, wavingBreaks: true)
            return
        }
        // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
        state.possessionWasInterrupted = true
        events.append(.gameBreakRevealed(seat: seat, card: card.descriptor))
        state.discard.append(card)
        resolveGameBreak(effect, named: card.name, card: card.descriptor,
                         drawnBy: seat, state: &state, events: &events, depth: depth)
    }

    /// **An Injury off the top of the deck**, run once the draw that turned it up is done.
    /// Carried, not spent — see `PlayerState.injuries`.
    private static func landInjury(_ card: Card, on seat: Seat, depth: Int,
                                   state: inout GameState, events: inout [GameEvent]) {
        // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
        state.possessionWasInterrupted = true
        events.append(.injuryRevealed(seat: seat, card: card.descriptor))
        // Two ways it never lands: a passive that shrugs it off, and the one Whistle the
        // sheet wrote for exactly this.
        // Recoverena turns a new one into a card the same way.
        let shrugged = has(seat, in: state, { $0.shrugsOffInjuries })
            || state.floorEffect.injuriesBecomeDraws
        let waved = state.armedWhistles.first { $0.trigger == .injuryDrawn }
        if let waved, !shrugged {
            spendWhistle(waved.id, state: &state, events: &events)
            state.discard.append(card)
            events.append(.whistleBlew(owner: waved.owner,
                                       card: waved.card.descriptor,
                                       cancelled: card.name,
                                       cancelledCard: card.descriptor,
                                       against: seat))
            stoppage(state: &state, events: &events)
        } else if shrugged {
            // Shaken off, and the draw is taken again — it cost nothing but the card that
            // was never carried.
            state.discard.append(card)
            draw(seat, state: &state, events: &events, allowBonus: false, depth: depth + 1)
        } else if state[seat].injuries.contains(where: { $0.injury?.lasts == .game }) {
            // Devastated already: a new Injury is discarded.
            state.discard.append(card)
        } else {
            // A Devastating Injury discards every other Injury as it lands.
            if card.descriptor.injury?.lasts == .game, !state[seat].injuries.isEmpty {
                healInjuries(of: seat, state: &state)
            }
            state[seat].injuries.append(card.descriptor)
            rollInjuryLock(seat, state: &state)
        }
    }

    /// Everything a draw turned up, run in the order it came off the deck.
    ///
    /// **The queue stays open while it runs.** Resolving a Break can draw again, and what
    /// those draws turn up belongs behind what is already waiting rather than in front of
    /// it — so the chain is held while the loop empties, and anything new joins the back.
    private static func drainBreaks(state: inout GameState, events: inout [GameEvent]) {
        state.drawChain += 1
        while let next = state.owes(.revealBreak) {
            // **A broken chain throws the rest away.** Something has ended the possession
            // the draws belonged to — a Whistle that stops the dribble, a Break that hands
            // the ball to somebody else — and the cards still queued were being drawn for
            // a possession that no longer exists.
            if state.chainBroken {
                for case .revealBreak(let held) in state.pending {
                    state.discard.append(held.card)
                }
                state.forget(.revealBreak)
                break
            }
            guard case .revealBreak(let held) = next else { break }
            state.pending.removeAll { $0 == next }
            revealBreak(held, state: &state, events: &events)
        }
        state.chainBroken = false
        state.drawChain -= 1
    }

    /// Draws for one seat as **one act**, and runs whatever it turned up once it is done.
    ///
    /// A card that draws two draws twice and then deals with both, rather than dealing
    /// with the first before the second is off the deck.
    private static func drawOnce(_ seat: Seat, state: inout GameState,
                                 events: inout [GameEvent], depth: Int = 0,
                                 opening: Bool = false) {
        drawTogether([seat], count: 1, state: &state, events: &events, depth: depth,
                     opening: opening)
    }

    /// Draws for several seats as one act. **"Everyone draws 1" is a draw, not four** —
    /// nothing any of them turns up may land while somebody is still owed a card.
    private static func drawTogether(_ seats: [Seat], count: Int, state: inout GameState,
                                     events: inout [GameEvent], depth: Int = 0,
                                     opening: Bool = false) {
        guard count > 0, !seats.isEmpty else { return }
        state.drawChain += 1
        for seat in seats {
            // **A broken chain stops dealing.** Discontinued Dribble ends the possession
            // on the card that tripped it, so the cards still owed are cards for a
            // possession that no longer exists — and Benched hands the ball away the
            // same way. Nobody after that point gets one.
            guard !state.chainBroken else { break }
            drawCards(seat, count: count, state: &state, events: &events, depth: depth,
                      opening: opening)
        }
        state.drawChain -= 1
        guard state.drawChain == 0 else { return }
        drainBreaks(state: &state, events: &events)
    }

    /// Draws several as **one batch**.
    ///
    /// Anything that pays per draw — Shot Creator — pays once for the lot rather than
    /// once a card. Drawing three off an All Star Selection is three cards and one bonus,
    /// which is four; card by card it was three bonuses and six, which is not what any of
    /// them say.
    private static func drawCards(_ seat: Seat, count: Int,
                                  state: inout GameState, events: inout [GameEvent],
                                  depth: Int = 0, opening: Bool = false) {
        guard count > 0 else { return }
        for _ in 0..<count {
            guard !state.chainBroken else { return }
            draw(seat, state: &state, events: &events, allowBonus: false, depth: depth,
                 opening: opening)
        }
        guard !state.chainBroken else { return }
        let bonus = state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.bonusDraw ?? 0) }
        for _ in 0..<bonus {
            guard !state.chainBroken else { return }
            draw(seat, state: &state, events: &events, allowBonus: false, depth: depth + 1)
        }
    }

    private static func draw(_ seat: Seat, state: inout GameState, events: inout [GameEvent],
                             allowBonus: Bool = true, depth: Int = 0, duringDeal: Bool = false,
                             wavingBreaks: Bool = false, opening: Bool = false) {
        // A Game Break can draw, and what it draws can be another Game Break. Bounded so
        // a run of them cannot recurse without end. Dealing gets a longer rope because it
        // reshuffles past every Break it turns up.
        guard depth < (duringDeal ? 80 : 8) else { return }
        // Patellar Tendon Tear: nothing comes in but the draws that open a possession.
        if !opening, !duringDeal,
           injured(seat, in: state, { $0.drawsOnlyAtPossessionStart }) { return }
        if state.deck.isEmpty {
            guard !state.discard.isEmpty else { return }
            state.deck = state.shuffled(state.discard)
            state.discard.removeAll()
            events.append(.deckReshuffled)
        }
        let card = state.deck.removeLast()

        // A Game Break or an Injury drawn while a hand is being dealt does not fire. It goes
        // back into the deck, silently, and the deal tries again.
        if duringDeal, card.descriptor.gameBreak != nil || card.descriptor.injury != nil {
            state.deck.append(card)
            state.deck = state.shuffled(state.deck)
            draw(seat, state: &state, events: &events,
                 allowBonus: allowBonus, depth: depth + 1, duringDeal: true)
            return
        }

        // An Intangible is an ordinary card in the hand now (2026-09-15): played by hand,
        // one a possession — see `playOntoItsSlot`.
        if card.descriptor.gameBreak != nil || card.descriptor.injury != nil {
            // **Held, not fired.** A draw is one act however many cards it moves, and a
            // Break that resolved the moment it came off the deck moved SHOT under the
            // rest of the draws, took the ball off a man still owed cards, and asked
            // about a full board before the card that filled it had arrived. It goes in
            // the queue and the draw carries on; `drainBreaks` runs the lot in order once
            // the last card is in a hand.
            state.owe(.revealBreak(PendingBreak(seat: seat, card: card, depth: depth,
                                                waving: wavingBreaks)))
        } else if state[seat].bag.count >= state.handLimit(for: seat) {
            // **A full hand takes nothing more, and the card is not wasted.** Drawing is
            // moving with the ball; a card there is no room for is the same movement
            // without it, so it pays SHOT instead — see `MatchRules.overflowShot`. The
            // card itself goes to the pile, which is where a spent card always goes.
            state.discard.append(card)
            let paid = state.rules.overflowShot
            adjustShot(by: paid, state: &state)
            events.append(.drawConverted(seat: seat, card: card.descriptor, shot: paid))
        } else {
            state[seat].bag.append(card)
            events.append(.drew(seat: seat, card: card.descriptor, id: card.id))
            // **The one call that does not wait for the chain.** Discontinued Dribble is
            // called on the draw itself, so it fires here rather than in the queue — and
            // it takes the queue with it: whatever else was coming was being drawn for a
            // possession that has just ended. See `drainBreaks`.
            //
            // **Not on the draw a possession opens with.** That card is owed to whoever
            // has the ball before they have done anything, and calling a dribble on it is
            // calling one before the ball has been put down. What it is for is a card
            // pulled *mid-possession* — off a Move, off a pass, off a passive.
            // **And never on a card being dealt.** A hand arriving at the top of a round
            // is not somebody dribbling: a call there ends a possession nobody has begun
            // and cuts the deal short, which left three players holding nothing. Game
            // Breaks are held out of a deal for the same reason, just above.
            if !opening, !duringDeal, let whistle = drawInterceptor(in: state) {
                blowOnDraw(whistle, against: seat, state: &state, events: &events)
            }
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

    private static func resolveGameBreak(_ effect: GameBreakEffect, named name: String,
                                         card rotatingCard: CardDescriptor,
                                         drawnBy seat: Seat,
                                         state: inout GameState, events: inout [GameEvent],
                                         depth: Int) {
        for _ in 0..<effect.discard { discardAtRandom(from: seat, state: &state) }

        if let limit = effect.everyoneDiscardsTo {
            for other in Seat.allCases where state[other].bag.count > limit {
                while state[other].bag.count > limit { discardAtRandom(from: other, state: &state) }
            }
        }
        if effect.everyoneDiscardsHands {
            // Queued to the edge of the chain, like every other card that takes a hand:
            // the hand you lose is the one you end up with.
            for seat in Seat.allCases { state.owe(.spendHand(seat)) }
        }
        // Everybody swung. Only with a referee out there does anybody get charged for it.
        if effect.turnoversIfReferee > 0, !state.armedWhistles.isEmpty {
            for other in Seat.allCases {
                state[other].turnovers += effect.turnoversIfReferee
                events.append(.turnover(other, cause: name))
                stoppage(state: &state, events: &events)
            }
        }
        if effect.healsInjuries, !state[seat].injuries.isEmpty {
            // Straight to the pile, both sorts. A Devastating one is out of circulation
            // for the rest of the game unless a card puts it back — this is that card.
            state.discard.append(contentsOf: state[seat].injuries.map { Card($0) })
            state[seat].injuries.removeAll()
            state[seat].injuryUnlocked = []
        } else if effect.drawIfUninjured > 0 {
            drawTogether([seat], count: effect.drawIfUninjured, state: &state,
                      events: &events, depth: depth + 1)
        }
        if effect.draws > 0 {
            drawTogether([seat], count: effect.draws, state: &state, events: &events,
                      depth: depth + 1)
        }
        if effect.drawsOnNextMake > 0 {
            state[seat].drawsOwedOnMake += effect.drawsOnNextMake
        }
        if let target = effect.drawUpTo {
            while state[seat].bag.count < target {
                let before = state[seat].bag.count
                drawOnce(seat, state: &state, events: &events, depth: depth + 1)
                if state[seat].bag.count == before { break }
            }
        }
        if effect.shotThisPossession != 0 {
            adjustShot(by: effect.shotThisPossession, state: &state)
        }
        if effect.shotForHolder != 0 { state.holderShot += effect.shotForHolder }
        // In The Zone: a card for every 10% the ball is worth. A cold ball still pays one.
        if effect.drawsPerTenPercentShot {
            drawTogether([seat], count: max(1, state.shot / 10), state: &state, events: &events,
                      depth: depth + 1)
        }
        if effect.skipsNextDraw { state.skipsNextDraw = true }
        // Somebody has to call a timeout. With no referee on the floor there is nobody
        // to call it, and the card is a card for everybody instead.
        if effect.requiresReferee, state.armedWhistles.isEmpty {
            drawTogether(Seat.allCases, count: effect.everyoneDrawsInstead,
                         state: &state, events: &events, depth: depth + 1)
        } else {
            if effect.healsAllInjuries {
                for other in Seat.allCases where !state[other].injuries.isEmpty {
                    state.discard.append(contentsOf: state[other].injuries.map { Card($0) })
                    state[other].injuries.removeAll()
                    state[other].injuryUnlocked = []
                }
            }
            if effect.clearsReferees, !state.armedWhistles.isEmpty {
                state.discard.append(contentsOf: state.armedWhistles.map(\.card))
                state.armedWhistles.removeAll()
                events.append(.whistlesDismissed)
            }
        }
        if effect.everyoneRedraws {
            // Sizes first, then the shuffle, then the deal — or the man dealt to first
            // would be drawing out of a deck the others had not gone into yet.
            let sizes = Seat.allCases.map { ($0, state[$0].bag.count) }
            for (other, _) in sizes {
                state.deck.append(contentsOf: state[other].bag)
                state[other].bag.removeAll()
            }
            state.deck = state.shuffled(state.deck)
            state.drawChain += 1
            for (other, count) in sizes where !state.chainBroken {
                drawCards(other, count: count, state: &state, events: &events,
                          depth: depth + 1)
            }
            state.drawChain -= 1
            if state.drawChain == 0 { drainBreaks(state: &state, events: &events) }
        }
        if effect.swapsHandsAtRandom {
            // Somebody else, and the deal is done where they stand: two bags change
            // owner and nothing else moves. Whatever is standing on either man stays
            // standing on him — it was him it was called on, not his cards.
            let others = Seat.allCases.filter { $0 != seat }
            let partner = state.pick(from: others)
            let mine = state[seat].bag
            state[seat].bag = state[partner].bag
            state[partner].bag = mine
            events.append(.handsTraded(seat: seat, with: partner))
        }
        if effect.rotatesHands {
            // Which way is the drawer's call, and the two seats either side are the two
            // answers — the same question the floor already knows how to ask.
            state.pendingActor = seat
            state.phase = .awaitingTarget(seat: seat, card: rotatingCard,
                                          choices: [seat.left, seat.right])
            return
        }
        if effect.healsChosenInjury {
            // Only the hurt are worth choosing between. With a clean floor there is
            // nothing for a doctor to do.
            let hurt = Seat.allCases.filter { !state[$0].injuries.isEmpty }
            guard !hurt.isEmpty else { return }
            state.pendingActor = seat
            state.phase = .awaitingTarget(seat: asker(instead: seat, in: state),
                                          card: rotatingCard, choices: hurt)
            return
        }
        if effect.fightsChosenPlayer {
            state.pendingActor = seat
            state.phase = .awaitingTarget(seat: asker(instead: seat, in: state),
                                          card: rotatingCard,
                                          choices: Seat.allCases.filter { $0 != seat })
            return
        }
        if effect.offersInjuries {
            let pool = state.discard.map(\.descriptor).filter { $0.injury != nil }
            let inDeck = state.deck.map(\.descriptor).filter { $0.injury != nil }
            guard !(pool.isEmpty && inDeck.isEmpty) else { return }
            state.injuriesOffered = pool + inDeck
            // What is still in the deck is face down. Knowing an Injury is in there is
            // not the same as knowing which.
            state.injuriesHidden = Set(inDeck.map(\.id))
            state.pendingActor = seat
            state.phase = .awaitingInjuryPick(seat: seat, card: rotatingCard)
            return
        }
        if let ceiling = effect.blocksShotAtOrAbove {
            state.shotCeilingThisRound = ceiling
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
        // Nobody fouled them, so nobody owes them the ball back afterwards.
        if effect.freeThrows > 0 {
            awardFreeThrows(effect.freeThrows, to: seat, offender: nil, source: name,
                            state: &state, events: &events)
        }
        for _ in 0..<effect.everyoneDraws {
            drawTogether(Seat.allCases, count: 1, state: &state, events: &events)
        }
        // Role Player: everybody else eats. Batched, so a Shot Creator on one of them
        // pays once rather than once a card.
        if effect.othersDraw > 0 {
            drawTogether(Seat.allCases.filter { $0 != seat }, count: effect.othersDraw,
                         state: &state, events: &events, depth: depth + 1)
        }
        if effect.reboundsNextMiss { state.freeRebound[seat] = rotatingCard }
        if effect.waivesBreaks > 0 { state.breaksWaived += effect.waivesBreaks }
        if effect.givesBallAway, let holder = state.ball {
            // Handed over, not taken away: whoever is benched decides where the ball
            // goes. Owed rather than set — see `Step.handOverBall`.
            state.lastPasser = nil
            state.arrivedBy = nil
            state.owe(.handOverBall(holder))
            // The possession the rest of the draws belonged to is over — see
            // `drainBreaks`. Benched and Discontinued Dribble end one the same way.
            state.chainBroken = true
        }
    }

    /// Reveals a passive and slots it, pushing out the oldest when the slots are full.
    private static func activate(_ card: Card, for seat: Seat,
                                 state: inout GameState, events: inout [GameEvent]) {
        // Monster Ball: swallowed as it arrives, and it does nothing at all.
        if state.ballEffect.absorbsIntangibles {
            state.monsterBallIntangibles.append(card.descriptor)
            events.append(.intangibleAbsorbed(seat: seat, card: card.descriptor))
            return
        }
        events.append(.intangibleRevealed(seat: seat, card: card.descriptor))
        clampEvent(.playingAnIntangibleOrChangingTheBall, on: [seat], state: &state, events: &events)
        state[seat].intangibles.append(card.descriptor)
        // Great Conditioning also sends off the Injuries already carried.
        if card.descriptor.intangible?.shrugsOffInjuries == true, !state[seat].injuries.isEmpty {
            state.discard.append(contentsOf: state[seat].injuries.map { Card($0) })
            state[seat].injuries.removeAll()
            state[seat].injuryUnlocked = []
        }
        // Fundamentalist: the ball goes back to Regulation.
        if card.descriptor.intangible?.retiresBallOnActivation == true, let ball = state.ballCard {
            state.discard.append(ball)
            state.ballCard = nil
        }

        // **The one Whistle that waits for a passive**, blown here rather than by
        // `interceptor` — an Intangible is never *played*, so there was no action to
        // match and Official Review sat armed for the whole game.
        //
        // It lands before the board is cleared: "all theirs" is all of them, the one that
        // tripped it included.
        guard let called = intangibleInterceptor(in: state) else { return }
        spendWhistle(called.id, state: &state, events: &events)
        // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
        state.possessionWasInterrupted = true
        events.append(.whistleBlew(owner: called.owner, card: called.card.descriptor,
                                   cancelled: card.descriptor.name,
                                   cancelledCard: card.descriptor, against: seat))
        stoppage(state: &state, events: &events)
        if called.card.descriptor.whistle?.stripsIntangibles == true {
            stripIntangibles(from: seat, state: &state, events: &events)
        }
    }

    /// **A referee who has made his call.** He leaves the floor and his card goes to the pile
    /// — unless the floor is Policeum, where he stays standing there.
    /// **A referee who makes a call does not leave the floor.**
    ///
    /// He is not a trap that has been sprung: there are always three officials working,
    /// and the only thing that ever changes them is the round turning over. Marking him
    /// as having called is all this does now — the scene reads it to know who blew the
    /// whistle, and a card that asks whether a call has been made reads it too.
    private static func spendWhistle(_ id: UUID, state: inout GameState,
                                     events: inout [GameEvent]) {
        guard let at = state.armedWhistles.firstIndex(where: { $0.id == id }) else { return }
        state.armedWhistles[at].stayed = true
        // **Crew Chief: a call spends the man who made it.** He retires where he stands and
        // a replacement comes out, so the stage churns as it is used — and while he is
        // working, every other official is back to one call apiece.
        guard state.armedWhistles.contains(where: {
            $0.card.descriptor.whistle?.retiresCaller == true
        }) else { return }
        sendOff(at, state: &state, events: &events)
    }

    /// **Officially Infamous: a call against him sends the official off with it.** Read
    /// after the call has landed, so the whistle still does what it came to do — he just
    /// does not get to do it twice.
    private static func infamy(against seat: Seat?, state: inout GameState,
                               events: inout [GameEvent]) {
        guard let seat, has(seat, in: state, { $0.retiresCallerAgainstYou }) else { return }
        retireLastCaller(by: seat, source: CardLibrary.dirtyPlayer, state: &state, events: &events)
    }

    /// A Whistle waiting on a passive landing, if one is set. Its own reader for the same
    /// reason `drawInterceptor` is: a card arriving is not something anybody did.
    private static func intangibleInterceptor(in state: GameState) -> ArmedWhistle? {
        guard !state.whistlesSilenced else { return nil }
        return state.armedWhistles.first { $0.trigger == .intangibleRevealed }
    }

    /// Everything off a board.
    private static func stripIntangibles(from seat: Seat, state: inout GameState,
                                         events: inout [GameEvent]) {
        guard !state[seat].intangibles.isEmpty else { return }
        state[seat].intangibles.removeAll()
        events.append(.intangiblesStripped(seat: seat))
        clockCatchesUp(seat, state: &state, events: &events)
    }

    /// One passive off a full board, chosen. Taking the one that just arrived is a
    /// legitimate answer — sometimes the fourth is the one you do not want.
    @discardableResult
    static func resolveIntangibleDrop(_ id: String, state: inout GameState) -> [GameEvent] {
        guard case .awaitingIntangibleDrop(let seat, _) = state.phase,
              let index = state[seat].intangibles.firstIndex(where: { $0.id == id })
        else { return [] }
        var events: [GameEvent] = []
        let displaced = state[seat].intangibles.remove(at: index)
        events.append(.intangibleDisplaced(seat: seat, card: displaced))
        clockCatchesUp(seat, state: &state, events: &events)
        state.phase = .possession(holder: state.ball ?? seat)
        settleHands(state: &state, events: &events)
        return events
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

    /// Puts a seat on the line without waiting to be fouled. Debug and harness only.
    @discardableResult
    static func debugAwardFreeThrows(_ count: Int, to seat: Seat,
                                     state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        awardFreeThrows(count, to: seat, offender: nil, source: "Foul",
                        state: &state, events: &events)
        takeTheLine(state: &state, events: &events)
        return events
    }

    /// Ends the round. Exposed only so the harness can check what a round turning over
    /// clears up after itself.
    static func testEndRound(state: inout GameState, events: inout [GameEvent]) {
        endRound(state: &state, events: &events)
    }

    /// Draws one card. Exposed only so the harness can exercise draw-time effects.
    /// Deals several in at once, the way a Timeout does, so a test can watch the order a
    /// draw and what it turns up come out in.
    static func testDrawAll(_ seats: [Seat], count: Int,
                            state: inout GameState, events: inout [GameEvent]) {
        drawTogether(seats, count: count, state: &state, events: &events)
        handOverBall(state: &state, events: &events)
    }

    /// The clock, run down by hand, so a test can watch who it is called on.
    static func testTick(by amount: Int, holder: Seat,
                         state: inout GameState, events: inout [GameEvent]) {
        _ = tickClock(by: amount, holder: holder, state: &state, events: &events)
    }

    /// A board cleared, which is what makes a held violation callable.
    static func testStripIntangibles(_ seat: Seat, state: inout GameState,
                                     events: inout [GameEvent]) {
        state[seat].intangibles.removeAll()
        events.append(.intangiblesStripped(seat: seat))
        clockCatchesUp(seat, state: &state, events: &events)
    }

    /// A shot taken straight, for watching what the miss does.
    static func testShot(by seat: Seat, state: inout GameState, events: inout [GameEvent]) {
        resolveShot(by: seat, bonusPoints: 0, state: &state, events: &events)
    }

    static func testDraw(_ seat: Seat, state: inout GameState, events: inout [GameEvent]) {
        drawOnce(seat, state: &state, events: &events)
        // Play resolves what a draw queued; a test drawing straight into the deck has to
        // do the same or it is testing a state the game never sits in.
        handOverBall(state: &state, events: &events)
    }

    /// True when a card is playable, or already in play, and yet does nothing at all.
    ///
    /// Deliberately narrower than "unavailable". A card the rules refuse — Buzzer Beater
    /// off its clock — is not dormant, it is illegal, and the refusal already says so in
    /// red. Grey is reserved for a card that will happily be played and change nothing.
    ///
    /// Also deliberately narrower than "partly wasted". Drive without a Dribble behind it
    /// still pays its own +10%, Coach's Challenge with no Timeout in the pile still
    /// cancels, and Turnaround Three on an empty bag still takes the shot. Greying those
    /// would claim they do nothing, which is worse than saying nothing.
    static func isDormant(_ descriptor: CardDescriptor, for seat: Seat,
                          in state: GameState) -> Bool {
        // Armed, and unable to ever fire while the floor is silenced.
        if descriptor.whistle?.trigger != nil, state.whistlesSilenced { return true }

        // A passive whose condition is not met pays nothing at all.
        if let passive = descriptor.intangible {
            if passive.requiresScoredLastRound, !state[seat].scoredLastRound { return true }
        }

        // Nobody to give it back to: the pass cannot happen, only the turnover.
        if descriptor.passTarget == .backToPasser, state.lastPasser == nil { return true }

        // **A Cut with nobody guarding you** is dead whoever has the ball — dimmed the
        // whole time, not only while it is your possession.
        if descriptor.cut != nil, state[seat].clamps.isEmpty { return true }

        // Its whole effect is a SHOT change, and SHOT is already pinned where it would
        // push it — a debuff at the floor, or a boost at the ceiling.
        let delta = descriptor.baseShotDelta
        if delta != 0, descriptor.drawCount == 0, descriptor.clockDelta == 0,
           descriptor.passTarget == nil, descriptor.special == nil,
           descriptor.clamp == nil, descriptor.whistle == nil, descriptor.gameBreak == nil {
            if delta < 0 && state.shot <= state.rules.shotFloor { return true }
            if delta > 0 && state.shot >= state.rules.shotCeiling { return true }
        }

        return false
    }

    static func winners(of state: GameState) -> [Seat] {
        let best = state.players.map(\.score).max() ?? 0
        return state.players.filter { $0.score == best }.map(\.seat)
    }
}
