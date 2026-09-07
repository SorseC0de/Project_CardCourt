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

    /// What a card has earned back off the clock it has watched run down.
    ///
    /// Only Dagger Three uses it. A dagger is a shot taken late: it starts as a bad look
    /// and pays for every tick already spent, so at the top of the clock it is the
    /// penalty on the card and at 01 it is the best shot on the table.
    static func clockBonus(_ special: SpecialMoveEffect?, in state: GameState) -> Int {
        guard let special, special.shotPerClockSpent != 0,
              let clock = state.shotClock else { return 0 }
        let spent = max(0, state.rules.shotClockStart - clock)
        return spent * special.shotPerClockSpent
    }

    static func legalMoves(_ state: GameState, for seat: Seat) -> [Move] {
        switch state.phase {
        case .inbound(let inbounder) where inbounder == seat:
            return Seat.allCases.filter { $0 != seat && $0 != state.inboundBarred }
                .map { Move.inbound(to: $0) }
        case .awaitingGiveUp, .awaitingMode, .awaitingCardFrom,
             .awaitingInjuryPick, .awaitingIntangibleDrop, .awaitingToll:
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
            let passOnly = state[seat].clamps.contains { $0.card.clamp?.passOnly == true }
            let playable = state[seat].bag.filter { card in
                if held.contains(card.id) { return false }
                if passOnly, card.descriptor.passTarget == nil { return false }
                // No Bag sits the Moves down; Fundamentalist sits the Special Moves down
                // and allows each Move once a turn.
                if card.descriptor.type == .move,
                   has(seat, in: state, { $0.blocksMoves }) { return false }
                if card.descriptor.type == .specialMove,
                   has(seat, in: state, { $0.blocksSpecialMoves }) { return false }
                if has(seat, in: state, { $0.oneOfEachMovePerTurn }),
                   card.descriptor.isMove,
                   state.movesPlayedThisPossession.contains(card.descriptor.id) { return false }
                // Triple Threat closes the book on Moves for the possession.
                if card.descriptor.isMove, state.movesClosed { return false }
                // Lob: the man it found has to put it up first.
                if state.mustShootFirst == seat { return false }
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
                // Give-and-Go: a clean look is one nobody has interfered with. Clamped, or
                // anything gone off this possession that you did not choose, and the
                // window has closed.
                if card.descriptor.special?.needsCleanLook == true {
                    if !state[seat].clamps.isEmpty { return false }
                    if state.possessionWasInterrupted { return false }
                }
                // Only so many referees will stand on one floor.
                if card.descriptor.whistle?.trigger != nil {
                    return state.armedWhistles.count < state.rules.refereeSlots
                }
                // And only so many defenders on one man. Counted against what is already
                // waiting rather than what has landed — Clamps are set down a possession
                // before they bite, so the pending pile is the whole stack.
                if card.descriptor.clamp != nil {
                    return state.pendingClamps.count < state.rules.clampSlots
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
            let barred = state.shotCeilingThisRound.map { state.shot >= $0 } ?? false
            return (barred ? [] : [.shoot]) + playable.map { Move.play($0.id) } + borrowing
        default:
            return []
        }
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
        guard case .possession(let holder) = state.phase,
              legalMoves(state, for: holder).isEmpty else { return }
        state[holder].turnovers += 1
        events.append(.turnover(holder, cause: "Shot Clock"))
        endRound(state: &state, events: &events)
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
    /// two types nobody may hold — a Break is an event and a Whistle is set, not held.
    static func downloadable(from state: GameState) -> [Card] {
        state.discard.reversed().filter {
            $0.descriptor.gameBreak == nil && $0.descriptor.type != .whistle
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
                draw(seat, state: &state, events: &events)
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
    static func clampsArriving(on seat: Seat, in state: GameState) -> [ActiveClamp] {
        clampLanding(seat, in: state) == seat ? state.pendingClamps : []
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
            offered += state[seat].bag.filter { $0.descriptor.clearsClamps }
        }
        // A card that does both is still one card.
        var seen: Set<Card.ID> = []
        return offered.filter { seen.insert($0.id).inserted }
    }


    /// Takes the first card on offer, or declines. **For callers with nothing to choose
    /// with** — the harness, and the AI, which does not yet weigh one answer against
    /// another. A player is asked properly; see `countersOnOffer`.
    @discardableResult
    static func resolveCounter(_ taken: Bool, state: inout GameState) -> [GameEvent] {
        guard case .awaitingCounter(let seat, _) = state.phase else { return [] }
        let first = taken ? countersOnOffer(to: seat, in: state).first?.id : nil
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
        guard case .awaitingCounter(let seat, _) = state.phase,
              let held = state.heldPossession else { return [] }
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
        events.append(.movePlayed(seat: seat, card: card.descriptor, shot: state.shot))
        if card.descriptor.clearsOut {
            clearOut(from: seat, state: &state, events: &events)
        } else {
            // **Taken out of the air, not off the player.** They never land, so they
            // never get to lock anything — and the possession opens on a clean board
            // before the card pays out on to it.
            let arriving = clampsArriving(on: seat, in: state)
            state.pendingClamps = []
            beginPossession(held.seat, tickClock: held.ticks, fromRebound: held.fromRebound,
                            fromOwnMiss: held.fromOwnMiss, offering: false,
                            alreadyDrew: held.drew, state: &state, events: &events)
            pay(card.descriptor, breaking: arriving, for: seat, state: &state, events: &events)
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
        adjustShot(by: descriptor.baseShotDelta, state: &state)
        drawBatch(seat, count: descriptor.drawCount, state: &state, events: &events)

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
            draw(seat, state: &state, events: &events)
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
            reinbound(by: passer, state: &state, events: &events)
            return
        }
        // Whatever was about to land on him lands on the man the ball went to. Asked
        // before they bit, so there is nothing on him to carry — only a pile still in the
        // air, and gravity takes it wherever the ball ends up.
        state.clampMagnet = onward
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
        let allowed = state[seat].injuries.compactMap { $0.gameBreak?.playableEachTurn }.min()
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
        state[seat].injuries.contains { $0.gameBreak?.playableEachTurn != nil }
    }

    /// Cards a Clamp is holding down: the ones it picked at random, plus everything a
    /// Trap forbids. Read by the hand so a held card looks held, and by nothing else —
    /// `legalMoves` refuses them on its own.
    static func lockedCards(_ state: GameState, for seat: Seat) -> Set<Card.ID> {
        var held = Set(state[seat].clamps.flatMap(\.locked))
        if state[seat].clamps.contains(where: { $0.card.clamp?.passOnly == true }) {
            held.formUnion(state[seat].bag.filter { $0.descriptor.passTarget == nil }
                .map(\.id))
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
            credit(seat, helping: target, state: &state, events: &events)
            events.append(.inbounded(from: seat, to: target))
            // A fresh round comes in with no clock and gets one. A throw-in inside a round
            // — a Whistle's, a turnover's — is handed a clock that is already running.
            if state.shotClock == nil {
                state.shotClock = state.rules.shotClockStart
                events.append(.shotClockSet(state.rules.shotClockStart))
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
            // Declared but not yet resolved — a Whistle gets to speak here.
            let declared = state[seat].bag[index]
            if let whistle = interceptor(of: .playCard(seat: seat, card: declared), in: state) {
                // Negating the effect, not the activation: the Clamp is allowed to be
                // played and to resolve. The Whistle waits for those defenders to try to
                // land, because until then there is no clamped player to name.
                if whistle.card.descriptor.whistle?.voidsClampOnLanding == true,
                   declared.descriptor.clamp != nil {
                    state.pendingClampVoid = whistle.id
                } else {
                    blow(whistle, on: .playCard(seat: seat, card: declared),
                         state: &state, events: &events)
                    return events
                }
            }

            let card = state[seat].bag.remove(at: index)
            let descriptor = card.descriptor
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
            if descriptor.whistle?.trigger == nil, !kept {
                state.discard.append(card)
            } else if kept {
                state[seat].bag.insert(card, at: min(index, state[seat].bag.count))
            }
            if descriptor.isMove { state.movesPlayedThisPossession.insert(descriptor.id) }
            if descriptor.blocksFurtherMoves { state.movesClosed = true }

            // Read before the card is played, because playing it may spend the tick it
            // is being priced against.
            var delta = descriptor.baseShotDelta
                + clockBonus(descriptor.special, in: state)
            // Ball Pounder: every Dribble costs a little more and pays a card.
            if descriptor.isDribble {
                delta += state[seat].intangibles.reduce(0) {
                    $0 + ($1.intangible?.dribbleShotPenalty ?? 0)
                }
            }
            // Fox-Like First Step: a Move that costs SHOT pays it instead.
            if descriptor.isMove, delta < 0,
               has(seat, in: state, { $0.invertsMoveDebuffs }) { delta = -delta }
            let comboArmed = (descriptor.comboAfter != nil
                              && descriptor.comboAfter == state.lastPlayThisPossession)
                || (descriptor.comboAfterDribble && lastPlayWasDribble(state))
            // A Kick-Out asks whether the Drive it followed was *itself* a combo — that
            // is a dribble drive, and a different play from a Drive on its own.
            let afterCombo = comboArmed && state.lastPlayWasCombo
            if comboArmed { delta += descriptor.comboBonus }
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
            let priced = descriptor.special?.shootsImmediately == true
            if !priced { adjustShot(by: delta, state: &state) }
            state.pendingShotBonus = priced ? delta : 0

            // Touch Pass: it only counts if it never stopped in your hands. Read before
            // the play is counted, or the card has already made itself late.
            var drawing = descriptor.drawCount + (comboArmed ? descriptor.comboDraw : 0)
            if descriptor.drawIfFirstAction > 0, isFirstAction(state) {
                drawing += descriptor.drawIfFirstAction
            }
            if afterCombo, descriptor.comboAssist > 0 {
                state[seat].assists += descriptor.comboAssist
                events.append(.assisted(seat))
            }
            if descriptor.isDribble {
                drawing += state[seat].intangibles.reduce(0) {
                    $0 + ($1.intangible?.dribbleBonusDraw ?? 0)
                }
            }
            drawBatch(seat, count: drawing, state: &state, events: &events)

            // Flop sells the contact: every Clamp on the player is a trip to the line,
            // and they all come off. Counted per Clamp card, so a Double-Team is one
            // foul with two bodies rather than two fouls.
            let standing = state[seat].clamps
            if descriptor.freeThrowsPerClamp > 0, let first = standing.first {
                awardFreeThrows(descriptor.freeThrowsPerClamp * standing.count,
                                to: seat, offender: first.from, source: descriptor.name,
                                state: &state, events: &events)
            }
            if descriptor.clearsClamps, !standing.isEmpty {
                // Paid per Clamp shaken off, before they are cleared — Spin Move and
                // Crossover turn being guarded into the reason they are good.
                let shaken = standing.count
                if descriptor.shotPerClamp != 0 {
                    adjustShot(by: descriptor.shotPerClamp * shaken, state: &state)
                }
                for _ in 0..<(descriptor.drawPerClamp * shaken) {
                    draw(seat, state: &state, events: &events)
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
                reinbound(by: seat, state: &state, events: &events)
                return events
            }

            if let special = descriptor.special {
                // A tip-in is only a tip-in off the glass. From anywhere else the card is
                // its ordinary self.
                let override = special.shotOverride
                    ?? (state.possessionFromRebound ? special.shotOverrideAfterRebound : nil)
                if let override {
                    state.pendingShotOverride = ShotOverride(
                        label: descriptor.name, amount: Double(override),
                        requiresAtLeast: special.overrideRequiresAtLeast)
                }
                if special.coinFlipShot != 0 {
                    // One flip, and it pays the same either way — the risk is the whole
                    // card.
                    let heads = state.roll(0...1) == 1
                    adjustShot(by: heads ? special.coinFlipShot : -special.coinFlipShot,
                               state: &state)
                    events.append(.coinRun(seat: seat, card: descriptor,
                                           heads: heads ? 1 : 0))
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
                if special.shotPerNamed > 0 {
                    // Named before the shot goes up, because who is owed changes what it
                    // is worth — and the answer is a list rather than one man.
                    state.pendingPlay = descriptor
                    state.pendingActor = seat
                    state.namedForAssist = []
                    state.phase = .awaitingNaming(seat: asker(instead: seat, in: state),
                                                  card: descriptor, named: [])
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
                                overClamps: special.ignoresClamps, card: descriptor,
                                state: &state, events: &events)
                } else {
                    events.append(.movePlayed(seat: seat, card: descriptor, shot: state.shot))
                    state.lastPlayThisPossession = descriptor.id
                    state.movesThisPossession += 1
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
            } else if let clamp = descriptor.clamp {
                // Set down now, lands on whoever receives the ball next. The possession
                // continues, like a Move card.
                // Belt and braces: `legalMoves` refuses a fourth, and anything reaching
                // here past that — a card whose effect sets one — still cannot exceed it.
                if state.pendingClamps.count < state.rules.clampSlots {
                    state.pendingClamps.append(ActiveClamp(card: descriptor, from: seat))
                }
                // Gravity: whoever it was aimed at, it lands on the man who draws
                // everybody. Set here so the possession that opens finds it waiting.
                if let magnet = Seat.allCases.first(where: {
                    has($0, in: state, { $0.attractsClamps })
                }) {
                    state.clampMagnet = magnet
                }
                _ = clamp
                events.append(.clampSet(seat: seat, card: descriptor))
            } else if let target = descriptor.passTarget {
                // Somebody has to name the man. Floor General names him for everybody,
                // which is the whole of what it does — so if it is on the floor, the ask
                // goes to them instead.
                if target == .choice || target == .leftOrRight {
                    state.pendingPlay = descriptor
                    state.phase = .awaitingTarget(seat: asker(instead: seat, in: state),
                                                  card: descriptor,
                                                  choices: passChoices(target, from: seat))
                    state.pendingActor = seat
                    return events
                }
                guard let receiver = resolve(target, from: seat, state: state) else {
                    // Behind-the-Back with nobody behind: a live-ball turnover.
                    state[seat].turnovers += 1
                    events.append(.failedReturn(seat: seat))
                    events.append(.turnover(seat, cause: descriptor.name))
                    endRound(state: &state, events: &events)
                    return events
                }
                // **The draw resolves before the ball moves.** Point God queues the pass
                // and pays first, so a Game Break turned up by that card plays out in
                // full — and lands on the man who passed, which is who earned it — before
                // anybody else has the ball.
                let earned = state[seat].intangibles.reduce(0) {
                    $0 + ($1.intangible?.drawAfterPass ?? 0)
                }
                if earned > 0 {
                    drawBatch(seat, count: earned, state: &state, events: &events)
                }
                // Read again: the draw may have turned up a Break that moved it.
                guard case .possession(let stillHolding) = state.phase,
                      stillHolding == seat else { return events }

                completePass(descriptor, from: seat, to: receiver,
                             state: &state, events: &events)
            } else if descriptor.clearsOut {
                events.append(.movePlayed(seat: seat, card: descriptor, shot: state.shot))
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
                return events
            } else if !descriptor.modes.isEmpty {
                state.pendingPlay = descriptor
                state.pendingActor = seat
                // **Asked of the man playing it.** Which branch of your own card you take
                // is not a target, so a Floor General does not name it — see
                // `aimsEveryTarget`. He was picking it, and `resolveMode` then acted as
                // him: his possession, his draw, his pass, his name in the log.
                state.phase = .awaitingMode(seat: seat, card: descriptor)
                return events
            } else {
                events.append(.movePlayed(seat: seat, card: descriptor, shot: state.shot))
                if comboArmed {
                    events.append(.comboLanded(seat: seat, card: descriptor, bonus: descriptor.comboBonus))
                }
                state.lastPlayThisPossession = descriptor.id
                state.lastPlayWasCombo = comboArmed
                state.movesThisPossession += 1
                // A Move card keeps the ball, so the seat acts again unless its own
                // clock cost runs the possession out.
                if descriptor.clockDelta != 0 {
                    _ = tickClock(by: descriptor.clockDelta, holder: seat, state: &state, events: &events)
                }
                // Stepback: the extra look is bought, and buying it is optional. Asked
                // with the same question Turnaround Three asks, capped at one card.
                // **Chosen, not taken.** A card that says discard without saying at
                // random means the player picks, and this was the one that did not ask.
                // Here rather than where the draw happens, because the rest of the play
                // has to land before the question can stand — a phase set mid-chain is a
                // phase the next line overwrites.
                if descriptor.selfDiscard > 0, !state[seat].bag.isEmpty,
                   case .possession = state.phase {
                    state.phase = .awaitingGiveUp(seat: seat, card: descriptor,
                                                  count: min(descriptor.selfDiscard,
                                                             state[seat].bag.count))
                    return events
                }
                if descriptor.optionalDiscardForShot > 0, !state[seat].bag.isEmpty,
                   case .possession = state.phase {
                    state.phase = .awaitingDiscard(seat: seat, card: descriptor,
                                                   bonusEach: descriptor.optionalDiscardForShot)
                    return events
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
                                        source: String,
                                        state: inout GameState, events: inout [GameEvent]) {
        guard count > 0 else { return }

        if var trip = state.pendingFreeThrows, trip.shooter == seat {
            // A second foul before the first has been shot just lengthens the trip.
            trip.remaining += count
            state.pendingFreeThrows = trip
            events.append(.freeThrowsAwarded(seat: seat, count: count, source: source))
            return
        }

        // Generational Whistle pays once per trip, not once per attempt.
        let bonus = state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.bonusFreeThrows ?? 0) }
        state.pendingFreeThrows = FreeThrowTrip(shooter: seat, offender: offender,
                                                source: source, remaining: count + bonus)
        events.append(.freeThrowsAwarded(seat: seat, count: count + bonus, source: source))
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
        guard let holder = state.pendingInbound, !state.isOver else { return }
        state.pendingInbound = nil
        // **A break in the loop.** Something has taken the ball off the floor and put it
        // back in — Benched hands it to whoever the benched man picks, and a Whistle can
        // do the same — and a Right Back still owed a return would drag it out of his
        // hands again the moment the possession opened. Whatever queued this outranks a
        // leg that was owed to a play the break has already interrupted.
        state.returnsTo = nil
        state.returnLeg = nil
        state.inbounder = holder
        state.phase = .inbound(inbounder: holder)
    }

    private static func takeTheLine(state: inout GameState, events: inout [GameEvent]) {
        guard let trip = state.pendingFreeThrows, !state.isOver else { return }
        state.pendingFreeThrows = nil
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
        }

        guard trip.remaining <= 0 else {
            state.phase = .freeThrows(trip: trip)
            return events
        }
        events.append(.freeThrowsEnded(seat: trip.shooter, made: trip.made, of: trip.total))

        // Every miss is a dead ball, so a trip never becomes a rebound. Whoever fouled
        // hands it back in, and the round does not advance.
        if let offender = trip.offender {
            reinbound(by: offender, state: &state, events: &events)
        } else if let holder = state.ball {
            // Nobody fouled — a Foul off the deck. Play picks up where it left off.
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
        // Stepback buys one extra look, not as many as the hand will pay for.
        if case .awaitingDiscard(_, let card, _) = state.phase, card.optionalDiscardForShot > 0 {
            most = min(most, 1)
        }
        return 0...most
    }

    /// Everything a pass does once its man is known.
    ///
    /// Shared, because a pass that names its target geometrically and one that had to be
    /// asked about are the same pass — only the question in front of them differs.
    private static func completePass(_ descriptor: CardDescriptor, from seat: Seat,
                                     to receiver: Seat, returning: Bool = false,
                                     state: inout GameState, events: inout [GameEvent]) {
        // Outlet Pass runs the clock the other way: it hands a tick back instead of
        // costing one, so the possession must not take its own.
        if descriptor.replacesClockTick {
            _ = tickClock(by: descriptor.clockDelta, holder: seat,
                          state: &state, events: &events)
        }
        if descriptor.upgradesToThree { state.pendingBonusPoint = 1 }
        state.lastPasser = seat
        state.arrivedBy = descriptor
        credit(seat, helping: receiver, state: &state, events: &events)
        events.append(.passed(card: descriptor, from: seat, to: receiver,
                              shot: state.shot, returning: returning))
        if descriptor.bonusAssistOnScore { state.dimeFrom = seat }
        if descriptor.forcesReceiverShot { state.mustShootFirst = receiver }
        if descriptor.forcesImmediateShot { state.shootsAtOnce = receiver }
        // **Only on the way out.** The return leg must not ask for another one, or the
        // ball never stops. Asked of the leg itself rather than of `returnLeg`, which
        // `settleHands` has already cleared by the time it sends the ball home — so the
        // guard was reading nil and arming a second trip every time.
        if descriptor.returnsImmediately, !returning {
            state.returnsTo = seat
            state.returnLeg = descriptor
        }
        beginPossession(receiver, tickClock: !descriptor.replacesClockTick,
                        state: &state, events: &events)

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
        if descriptor.stealsAlongPass > 0, !state[receiver].bag.isEmpty {
            state.stealTravelsTo = seat.seat(inDirection: .left) == receiver
                ? receiver.left : receiver.right
            state.pendingActor = seat
            state.phase = .awaitingCardFrom(seat: asker(instead: seat, in: state),
                                            card: descriptor, victim: receiver)
        } else if descriptor.receiverDiscards > 0 {
            // Bullet Pass: it goes in hard and something drops. **At random**, which the
            // sheet says and which asking somebody to pick blind out of a face-down hand
            // only dressed up — and a question about a hand another card may have emptied
            // in the meantime is a question with no answer.
            for _ in 0..<descriptor.receiverDiscards {
                discardAtRandom(from: receiver, state: &state)
            }
            events.append(.clampBit(seat: receiver, card: descriptor,
                                    discarded: descriptor.receiverDiscards))
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

        if let effect = descriptor.gameBreak, effect.healsChosenInjury {
            if let injury = state[target].injuries.first {
                state[target].injuries.removeFirst()
                state[target].injuryUnlocked = []
                state.discard.append(Card(injury))
                credit(actor, helping: target, state: &state, events: &events)
            }
            // Looking after somebody else is the half of it that pays.
            if target != actor {
                drawBatch(actor, count: effect.drawsForHealingAnother,
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
                events.append(.movePlayed(seat: actor, card: descriptor, shot: state.shot))
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
        if mode.draws > 0 { drawBatch(actor, count: mode.draws, state: &state, events: &events) }
        if let passes = mode.passes {
            state.pendingPlay = descriptor
            state.pendingActor = actor
            // The pass leaves his seat, and *that* is a target, so a Floor General names it.
            state.phase = .awaitingTarget(seat: asker(instead: actor, in: state),
                                          card: descriptor,
                                          choices: passChoices(passes, from: actor))
            return events
        }
        events.append(.movePlayed(seat: actor, card: descriptor, shot: state.shot))
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

        if let whistle = interceptor(of: .shoot(seat: shooter), in: state) {
            blow(whistle, on: .shoot(seat: shooter), state: &state, events: &events)
            state.namedForAssist = []
            return events
        }
        resolveShot(by: shooter, bonusPoints: special?.bonusPointOnMake ?? 0,
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
            rehome(lost, from: victim, state: &state, events: &events)
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
        events.append(.gameBreakRevealed(seat: seat, card: taken))
        state.phase = .possession(holder: state.ball ?? seat)
        settleHands(state: &state, events: &events)
        return events
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
            credit(actor, helping: onward, state: &state, events: &events)
            state.stealTravelsTo = nil
            state.phase = .possession(holder: state.ball ?? actor)
            return events
        }
        state.discard.append(taken)
        state.phase = .possession(holder: actor)
        events.append(.movePlayed(seat: actor, card: descriptor, shot: state.shot))
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
        if let injury = state[seat].injuries.first(where: { ($0.gameBreak?.discardsEachTurn ?? 0) > 0 }),
           injury.id == asking.id {
            events.append(.clampBit(seat: seat, card: injury, discarded: count))
        } else {
            events.append(.discarded(seat: seat, count: spent.count))
        }
        state.phase = .possession(holder: seat)
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
        let bought = bonusEach * spent.count
        adjustShot(by: bought, state: &state)
        events.append(.discardedForShot(seat: seat, card: card, count: spent.count))

        state.phase = .possession(holder: seat)
        // Stepback is a Move: what it bought stays on the ball, and the seat plays on.
        guard card.special?.shootsImmediately == true else {
            settleHands(state: &state, events: &events)
            return events
        }
        if let whistle = interceptor(of: .shoot(seat: seat), in: state) {
            blow(whistle, on: .shoot(seat: seat), state: &state, events: &events)
            adjustShot(by: -bought, state: &state)
            return events
        }
        let roundBefore = state.round
        resolveShot(by: seat, bonusPoints: card.special?.bonusPointOnMake ?? 0,
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
            counts[seat] = discarded.isEmpty ? 0 : discarded.count + reach
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
        return Dunk.ordinary(for: state[seat].position, roll: roll)
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
    private static func resolveShot(by seat: Seat, bonusPoints: Int,
                                    overClamps: Bool = false,
                                    card: CardDescriptor? = nil,
                                    state: inout GameState, events: inout [GameEvent]) {
        // What the card in hand was worth, spent on this attempt and gone.
        let priced = state.pendingShotBonus
        state.pendingShotBonus = 0
        // **Settled here, once.** Which finish this is has to be in the state everybody
        // is told about, or four devices would each roll their own and watch four
        // different dunks. Nothing about the scoring reads it.
        // Whatever put it up, or — for a plain shot — whatever was last played.
        let played = card ?? state.lastPlayThisPossession.flatMap { CardLibrary.byID[$0] }
        state.dunking = dunk(for: seat, card: played, state: &state)
        if state.dunking != nil { state[seat].dunks += 1 }
        state.shotsThisRound += 1
        state.mustShootFirst = nil
        let upgraded = state.pendingBonusPoint
        state.pendingBonusPoint = 0
        _ = upgraded
        // Unselfish, cashed in. Owed to the attempt rather than to the board, so passing
        // the ball away does not hand the bonus to whoever ends up shooting.
        let owed = state[seat].nextShotBonus
        state[seat].nextShotBonus = 0
        // Mic'd Up, spent on the attempt it was carried into.
        let carried = seat == state.ball ? state.holderShot : 0
        state.holderShot = 0
        // Gravity: a man who draws every defender is doing something on every attempt,
        // whoever takes it.
        for other in Seat.allCases where other != seat {
            if has(other, in: state, { $0.assistOnOthersShot }) {
                state[other].assists += 1
                events.append(.assisted(other))
            }
        }
        let resolution = ShotMath.resolve(base: state.shot + priced + owed + carried,
                                          modifiers: state.shotModifiers(
                                            for: seat, ignoringClamps: overClamps),
                                          rules: state.rules)
        state.pendingShotOverride = nil
        let chance = resolution.chance
        events.append(.shotAttempted(seat: seat, chance: chance, breakdown: resolution))

        // **The defenders' work is done the moment the ball is in the air.**
        //
        // One place, here, rather than at the top of the next possession: a shot is the
        // end of the possession however it lands, and a Clamp left standing through the
        // rebound was still on the man's chest in the scene after the one it belonged to.
        // `beginPossession` clears them again on its way in, which is what makes a Clamp
        // that never met a shot — a turnover, a Timeout — expire too.
        for other in Seat.allCases { state[other].clamps = [] }

        let roll = state.roll(1...100)
        if roll <= chance {
            // A kick-out is a three because of where it put him, not what he did with it.
            let points = state.rules.madeShotPoints + bonusPoints + upgraded
            state[seat].points += points
            state[seat].scoredThisRound = true
            state[seat].lastMake = Make(round: state.round, chance: chance)
            events.append(.shotMade(seat: seat, points: points, roll: roll, chance: chance))
            if state[seat].drawsOwedOnMake > 0 {
                let owed = state[seat].drawsOwedOnMake
                state[seat].drawsOwedOnMake = 0
                drawBatch(seat, count: owed, state: &state, events: &events)
            }
            // Wide-Open Three: everyone he named takes one, on top of whatever the pass
            // was already worth.
            for helper in state.namedForAssist where helper != seat {
                state[helper].assists += 1
                events.append(.assisted(helper))
            }
            if let passer = state.lastPasser, passer != seat {
                // Dime pays twice: the assist every pass earns, and its own.
                let extra = state.dimeFrom == passer ? 1 : 0
                state[passer].assists += 1 + extra
                events.append(.assisted(passer))
            }
            endRound(state: &state, events: &events)
        } else {
            events.append(.shotMissed(seat: seat, roll: roll, chance: chance))
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
        // Oldest first: a trap set earlier is the one lying in wait.
        //
        // No owner exemption. A Whistle catches whoever trips it, its own player included
        // — that is what stops a table being flooded with traps by someone immune to them.
        return state.armedWhistles.first { whistle in
            guard whistle.trigger?.matches(action) == true else { return false }
            // Clear Path Foul is a call on a defender, so there has to be one holding the
            // man down. Without the condition it fired on every clean look.
            if whistle.card.descriptor.whistle?.requiresShotDebuffClamp == true {
                return state[action.actor].clamps.contains { ($0.card.clamp?.shotDebuff ?? 0) != 0 }
            }
            return true
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
            state.armedWhistles.removeAll { $0.id == over.id || $0.id == whistle.id }
            state.discard.append(over.card)
            state.discard.append(whistle.card)
            // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
            state.possessionWasInterrupted = true
            events.append(.whistleBlew(owner: over.owner, card: over.card.descriptor,
                                       cancelled: whistle.card.name,
                                       cancelledCard: whistle.card.descriptor,
                                       against: whistle.owner))
            let effect = over.card.descriptor.whistle ?? WhistleEffect()
            for _ in 0..<effect.offenderDraws {
                draw(action.actor, state: &state, events: &events)
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
            state.armedWhistles.removeAll { $0.id == whistle.id }
            state.discard.append(whistle.card)
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
                                   against: action.actor))

        // Villainous Reputation: the referees have their eye on him, and it does not
        // matter whose call it was.
        for other in Seat.allCases {
            let toll = state[other].intangibles.reduce(0) {
                $0 + ($1.intangible?.discardOnAnyWhistle ?? 0)
            }
            for _ in 0..<toll { discardAtRandom(from: other, state: &state) }
        }

        if effect.recoversTimeout,
           let index = state.discard.firstIndex(where: { $0.descriptor.id == "timeout" }) {
            state[whistle.owner].bag.append(state.discard.remove(at: index))
        }
        if effect.stripsIntangibles, !state[offender].intangibles.isEmpty {
            let stripped = state[offender].intangibles
            state[offender].intangibles.removeAll()
            events.append(.intangiblesStripped(seat: offender))
            for card in stripped {
                rehome(card, from: offender, state: &state, events: &events)
            }
        }
        for _ in 0..<effect.offenderDiscards { discardAtRandom(from: offender, state: &state) }
        if effect.offenderDraws > 0 {
            drawBatch(offender, count: effect.offenderDraws, state: &state, events: &events)
            credit(whistle.owner, helping: offender, state: &state, events: &events)
        }
        if effect.offenderDiscardsBag {
            spendHand(of: offender, state: &state, events: &events)
        }
        if effect.pointsToVictim > 0 {
            state[whistle.owner].points += effect.pointsToVictim
            events.append(.shotMade(seat: whistle.owner, points: effect.pointsToVictim, roll: 0))
        }
        // The ball changes hands on the call rather than going back in: a review does not
        // stop the game, it decides where the ball was going.
        if effect.takesBall, whistle.owner != offender {
            beginPossession(whistle.owner, tickClock: false, state: &state, events: &events)
        }
        if effect.turnoverOnOffender {
            state[offender].turnovers += 1
            // The Whistle that was called, not the card it was called on.
            events.append(.turnover(offender, cause: whistle.card.name))
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
            let points = state.rules.madeShotPoints + pendingShotBonus(for: offender, in: state)
            state[offender].points += points
            state[offender].scoredThisRound = true
            credit(whistle.owner, helping: offender, state: &state, events: &events)
            events.append(.shotMade(seat: offender, points: points, roll: 0))
        }

        let earned = effect.freeThrowsToVictim
            + (calls > 1 ? effect.freeThrowsOnRepeatCall : 0)
        awardFreeThrows(earned, to: whistle.owner, offender: offender,
                        source: whistle.card.name, state: &state, events: &events)
        // The man who was fouled, which for a Clear Path is the man who tripped it.
        awardFreeThrows(effect.freeThrowsToOffender, to: offender, offender: nil,
                        source: whistle.card.name, state: &state, events: &events)

        if effect.endsRound {
            endRound(state: &state, events: &events)
        } else if effect.setterChoosesInbound {
            reinbound(by: whistle.owner, state: &state, events: &events)
        } else if effect.turnoverOnOffender || effect.offenderInbounds {
            // A turnover costs the ball. The offender hands it back in, and the round
            // does not advance — only a made shot or a real clock expiry does that.
            // Charge takes the ball the same way without charging the turnover.
            reinbound(by: offender, state: &state, events: &events)
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
        return card.special?.bonusPointOnMake ?? 0
    }

    /// Whistles that fire on being played rather than lying in wait.
    private static func resolveImmediate(_ effect: WhistleEffect, playedBy seat: Seat,
                                         state: inout GameState, events: inout [GameEvent]) {
        // A Timeout deals the whole table in, which is three people helped.
        if effect.everyoneDraws > 0 {
            for other in Seat.allCases {
                credit(seat, helping: other, state: &state, events: &events)
            }
        }
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
        events.append(.discarded(seat: seat, count: cards.count))
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
        state.discard.append(state[seat].bag.remove(at: index))
        events.append(.discarded(seat: seat, count: 1))
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
        // **Clamps are not cleared here.** `beginPossession` is the one place that ends
        // them, because ending a possession is the only thing that does — and a dead ball
        // clearing them early handed a cancelled card its effect for free: a Whistle that
        // stops a Spin Move charges a turnover, the turnover re-inbounds, and the man
        // walked away from the defenders the Spin Move had just been forbidden to shake.
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
        state.whistlesSilenced = false
        state.whistleCallsThisRound.removeAll()
        state.phase = .inbound(inbounder: state.inbounder)
        events.append(.roundBegan(round: state.round, inbounder: state.inbounder))
    }

    private static func beginPossession(_ seat: Seat, tickClock shouldTick: Bool,
                                        fromRebound: Bool = false, fromOwnMiss: Bool = false,
                                        offering: Bool = true, alreadyDrew: Bool = false,
                                        state: inout GameState, events: inout [GameEvent]) {
        state.ball = seat
        state.lastPlayThisPossession = nil
        state.lastPlayWasCombo = false
        state.movesThisPossession = 0
        state.movesPlayedThisPossession = []
        state.movesClosed = false
        state.possessionFromRebound = fromRebound
        state.possessionFromOwnRebound = fromOwnMiss
        state.possessionWasInterrupted = false
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
            // Fresh Ball: a ball nobody has broken in. The possession opens dry.
            if state.skipsNextDraw {
                state.skipsNextDraw = false
            } else {
                draw(seat, state: &state, events: &events)
            }
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

        // Clamps live for exactly one possession, so the board is cleared before the
        // pending ones land. Without the clear they stay on a player forever.
        for other in Seat.allCases { state[other].clamps = [] }
        // Gravity takes them all, wherever they were sent.
        let landing = clampLanding(seat, in: state)
        state[landing].clamps = state.pendingClamps
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
                state.armedWhistles.removeAll { $0.id == voided }
                state.discard.append(whistle.card)
                // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
                state.possessionWasInterrupted = true
                events.append(.whistleBlew(owner: whistle.owner, card: whistle.card.descriptor,
                                           cancelled: "the Clamp's effect",
                                           cancelledCard: voidedClamp, against: culprit))
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

        // Freethrow Merchant: being Clamped is itself the foul, so the defenders never
        // arrive — the trip to the line is what happens instead of them.
        let perClamp = state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.freeThrowPerClamp ?? 0) }
        if perClamp > 0, let first = state[seat].clamps.first {
            let waved = state[seat].clamps.count
            state[seat].clamps.removeAll()
            events.append(.clampVoided(seat: seat, card: CardLibrary.freethrowMerchant, count: waved))
            awardFreeThrows(perClamp * waved, to: seat, offender: first.from,
                            source: "Freethrow Merchant", state: &state, events: &events)
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
            let wanted = state[seat].clamps[index].card.clamp?.locksRandomCards ?? 0
            guard wanted > 0 else { continue }
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
        for clamp in state[seat].clamps {
            let count = min(clamp.card.clamp?.discardAtStart ?? 0, state[seat].bag.count)
            guard count > 0 else { continue }
            for _ in 0..<count {
                let index = state.roll(0...(state[seat].bag.count - 1))
                state.discard.append(state[seat].bag.remove(at: index))
            }
            events.append(.clampBit(seat: seat, card: clamp.card, discarded: count))
        }

        // A Clamp that does its work the moment it lands has nothing left to do, so it
        // does not stay on the floor. Only the ones that sit on your SHOT are defenders
        // in any lasting sense — the rest are one swipe and gone.
        //
        // **Last, and that is the whole of it.** Everything that answers a Clamp — a
        // Blocking Foul waiting to void one, Freethrow Merchant turning one into a trip
        // to the line — runs above this and has to find the Clamp still there. Dropping
        // it any earlier makes those cards quietly stop working on Full-Court Press,
        // which is the only one-off there is.
        state[seat].clamps.removeAll { $0.card.clamp?.isStanding == false }

        if shouldTick, tickClock(by: -1, holder: seat, state: &state, events: &events) { return }

        // Rolled after the draw, so a card that just arrived can be the one you are left
        // with rather than being dead the moment it lands.
        rollInjuryLock(seat, state: &state)

        // Bone Bruise takes its card at the top of the turn, after the draw — so the turn
        // opens with a choice rather than with a hand already one short.
        let toll = state[seat].injuries.reduce(0) { $0 + ($1.gameBreak?.discardsEachTurn ?? 0) }
        if toll > 0, let injury = state[seat].injuries.first(where: {
            ($0.gameBreak?.discardsEachTurn ?? 0) > 0 }), !state[seat].bag.isEmpty {
            state.phase = .awaitingGiveUp(seat: seat, card: injury,
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
        switch target {
        case .random:
            let others = Seat.allCases.filter { $0 != seat }
            var pool = state
            return others[pool.roll(0...(others.count - 1))]
        // Somebody has to say. `apply` asks before it gets here — see
        // `Phase.awaitingPassTarget` — so reaching this means nobody did.
        case .choice, .leftOrRight: return nil
        default: return state.lastPasser
        }
    }

    /// Who may be picked, when a card lets the passer choose.
    static func passChoices(_ target: PassTarget, from seat: Seat) -> [Seat] {
        switch target {
        case .leftOrRight: return [seat.left, seat.right]
        default: return Seat.allCases.filter { $0 != seat }
        }
    }

    /// Paid whenever one player does something for another.
    ///
    /// **The one place that decides what "positively affects another player" means.** The
    /// card is worded loosely on purpose, so this is the list rather than the text: the
    /// ball, a card, a point, a trip to the line, or something bad taken away. Every route
    /// that does one of those for somebody else calls this, and a new one that forgets is
    /// a card that quietly stops paying.
    ///
    /// Never for helping yourself, and never for a Game Break — a Break is an event that
    /// happened to the table, not a thing anybody did.
    private static func credit(_ helper: Seat, helping other: Seat,
                               state: inout GameState, events: inout [GameEvent]) {
        guard helper != other else { return }
        var cards = 0
        var shot = 0
        for passive in state[helper].intangibles {
            guard let effect = passive.intangible else { continue }
            cards += effect.drawOnHelping
            shot += effect.shotOnHelping
        }
        state[helper].nextShotBonus += shot
        if cards > 0 {
            drawBatch(helper, count: cards, state: &state, events: &events)
        }
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

    private static func endRound(state: inout GameState, events: inout [GameEvent]) {
        events.append(.roundEnded(state.round))
        state.shotsThisRound = 0
        state.shotCeilingThisRound = nil
        state.dimeFrom = nil
        state.mustShootFirst = nil
        state.inboundBarred = nil
        state.holderShot = 0
        // The orders still in flight go with it. A shot the round no longer has room for
        // must not go up inside halftime's deal, and a return leg has nowhere to land.
        state.shootsAtOnce = nil
        state.returnsTo = nil
        state.returnLeg = nil

        // The referees leave when the round does — a trap does not lie in wait across the
        // inbound that follows it — and the cards they were holding are spent.
        if !state.armedWhistles.isEmpty {
            state.discard.append(contentsOf: state.armedWhistles.map(\.card))
            state.armedWhistles.removeAll()
        }
        for seat in Seat.allCases {
            state[seat].scoredLastRound = state[seat].scoredThisRound
            state[seat].scoredThisRound = false
            // Off at the whistle and back into the pile, so halftime shuffles it in with
            // everything else. A Devastating one is not shed and so never returns.
            // The ones the sheet gives a round to, good and bad alike.
            let expired = state[seat].intangibles.filter { $0.intangible?.lastsRound == true }
            state[seat].intangibles.removeAll { $0.intangible?.lastsRound == true }
            state.discard.append(contentsOf: expired.map { Card($0) })
            let healed = state[seat].injuries.filter { $0.gameBreak?.injury == .round }
            state[seat].injuries.removeAll { $0.gameBreak?.injury == .round }
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
        var pool = state.deck + state.discard
        for seat in Seat.allCases {
            pool += state[seat].bag
            state[seat].bag.removeAll()
        }
        state.deck = state.shuffled(pool)
        state.discard.removeAll()
        deal(to: Seat.allCases, count: state.rules.startingBagSize, state: &state, events: &events)
        settleHands(state: &state, events: &events)
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

    /// Pays whatever a draw chain owes, now that it has finished.
    ///
    /// Called at the outermost edge of a deal or a draw rather than where the card landed,
    /// because "discard your hand" has to mean the hand you end up with.
    static func settleHands(state: inout GameState, events: inout [GameEvent]) {
        for seat in state.handsOwed where !state[seat].bag.isEmpty {
            spendHand(of: seat, state: &state, events: &events)
        }
        state.handsOwed.removeAll()

        // Right Back: home again, and paying its SHOT a second time. After the toll and
        // whatever else the trip cost him — that is the point of the card.
        // **Only once there is a possession to send it back from.** A toll at the far
        // end — Bone Bruise taking its card, a Game Break emptying a hand — leaves the
        // phase on a question rather than on a possession, and this used to find that,
        // throw the return away and clear it. The ball simply never came home: it sat
        // with the receiver until the clock ran out on him, which arrives as a shot-clock
        // violation nobody could see coming. Left owed instead, and `settleHands` runs
        // again at the edge of whatever answered the question.
        if let home = state.returnsTo, let leg = state.returnLeg,
           case .possession(let holder) = state.phase {
            state.returnsTo = nil
            state.returnLeg = nil
            if holder != home {
                adjustShot(by: leg.baseShotDelta, state: &state)
                completePass(leg, from: holder, to: home, returning: true,
                             state: &state, events: &events)
            }
        }

        // Alley-Oop: it goes up now, with whatever he drew still in his hands. Before the
        // board's question, because the shot is the possession and a passive changing
        // hands is not.
        // **Cleared inside the guard, not before it** — the same fault the return leg
        // above had and was fixed for. The clear ran unconditionally, so a chain that
        // ended on a question rather than in a possession — a toll, a give-up, a card
        // asked for, a full Intangible board — dropped the forced shot on the floor and
        // never re-armed it. `settleHands` runs again at the edge of whatever answers the
        // question, and the shot has to still be owed when it does.
        // **Cleared once the chain settles anywhere, spent only if it settled on him.**
        // Three shapes, and the middle one is easy to lose: while a question is still
        // open the shot is still *owed* and must survive; the moment there is a
        // possession the chain is over and it is either taken or gone. Guarding the clear
        // on `holder == shooter` as well left it armed for the rest of the round whenever
        // the chain came to rest on somebody else, and it fired on an unrelated
        // possession later. The return leg above clears on the possession and tests the
        // holder second for exactly this reason.
        if let shooter = state.shootsAtOnce, case .possession(let holder) = state.phase {
            state.shootsAtOnce = nil
            if holder == shooter {
                if let whistle = interceptor(of: .shoot(seat: shooter), in: state) {
                    blow(whistle, on: .shoot(seat: shooter), state: &state, events: &events)
                } else {
                    resolveShot(by: shooter, bonusPoints: 0, state: &state, events: &events)
                }
            }
        }

        // And the question a full board owes. One at a time: answering it can rehome a
        // passive onto another full board, which asks again.
        state.overflowing = state.overflowing.filter {
            state[$0].intangibles.count > state.rules.intangibleSlots
        }
        if let seat = state.overflowing.sorted(by: { $0.rawValue < $1.rawValue }).first {
            state.overflowing.remove(seat)
            state.phase = .awaitingIntangibleDrop(seat: seat,
                                                  offered: state[seat].intangibles)
            return
        }
        strandOut(state: &state, events: &events)
    }

    /// Draws several as **one batch**.
    ///
    /// Anything that pays per draw — Shot Creator — pays once for the lot rather than
    /// once a card. Drawing three off an All Star Selection is three cards and one bonus,
    /// which is four; card by card it was three bonuses and six, which is not what any of
    /// them say.
    private static func drawBatch(_ seat: Seat, count: Int,
                                  state: inout GameState, events: inout [GameEvent],
                                  depth: Int = 0) {
        guard count > 0 else { return }
        for _ in 0..<count {
            draw(seat, state: &state, events: &events, allowBonus: false, depth: depth)
        }
        let bonus = state[seat].intangibles.reduce(0) { $0 + ($1.intangible?.bonusDraw ?? 0) }
        for _ in 0..<bonus {
            draw(seat, state: &state, events: &events, allowBonus: false, depth: depth + 1)
        }
    }

    private static func draw(_ seat: Seat, state: inout GameState, events: inout [GameEvent],
                             allowBonus: Bool = true, depth: Int = 0, duringDeal: Bool = false,
                             wavingBreaks: Bool = false) {
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
            // Free Agent takes the whole hand, but not yet: turning it up second in an
            // opening deal should cost the hand you end up with rather than the one card
            // you happen to be holding. Settled by `settleHands`, once the chain is done.
            if card.descriptor.intangible?.playsFromOthers == true {
                state.handsOwed.insert(seat)
            }
            draw(seat, state: &state, events: &events,
                 allowBonus: false, depth: depth + 1, duringDeal: duringDeal)
        } else if let effect = card.descriptor.gameBreak {
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
                    state.armedWhistles.removeAll { $0.id == waved.id }
                    state.discard.append(waved.card)
                    // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
                    state.possessionWasInterrupted = true
                    events.append(.whistleBlew(owner: waved.owner,
                                               card: waved.card.descriptor,
                                               cancelled: card.name,
                                               cancelledCard: card.descriptor,
                                               against: seat))
                }
                state.discard.append(card)
                draw(seat, state: &state, events: &events, allowBonus: allowBonus,
                     depth: depth + 1, duringDeal: duringDeal, wavingBreaks: true)
                return
            }
            // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
            state.possessionWasInterrupted = true
            events.append(.gameBreakRevealed(seat: seat, card: card.descriptor))
            // An Injury is carried, not spent. See `PlayerState.injuries`.
            if effect.injury != nil {
                // Two ways it never lands: a passive that shrugs it off, and the one
                // Whistle the sheet wrote for exactly this.
                let shrugged = has(seat, in: state, { $0.shrugsOffInjuries })
                let waved = state.armedWhistles.first { $0.trigger == .injuryDrawn }
                if let waved, !shrugged {
                    state.armedWhistles.removeAll { $0.id == waved.id }
                    state.discard.append(waved.card)
                    state.discard.append(card)
                    // Nobody chose this. See `possessionWasInterrupted` — Give-and-Go asks.
                    state.possessionWasInterrupted = true
                    events.append(.whistleBlew(owner: waved.owner,
                                               card: waved.card.descriptor,
                                               cancelled: card.name,
                                               cancelledCard: card.descriptor,
                                               against: seat))
                } else if shrugged {
                    // Shaken off, and the draw is taken again — it cost nothing but the
                    // card that was never carried.
                    state.discard.append(card)
                    draw(seat, state: &state, events: &events,
                         allowBonus: false, depth: depth + 1, duringDeal: duringDeal)
                } else {
                    state[seat].injuries.append(card.descriptor)
                    rollInjuryLock(seat, state: &state)
                }
            } else {
                state.discard.append(card)
            }
            resolveGameBreak(effect, named: card.name, card: card.descriptor,
                             drawnBy: seat, state: &state, events: &events, depth: depth)
        } else {
            state[seat].bag.append(card)
            events.append(.drew(seat: seat, card: card.descriptor, id: card.id))
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
            state.handsOwed.formUnion(Seat.allCases)
        }
        // Everybody swung. Only with a referee out there does anybody get charged for it.
        if effect.turnoversIfReferee > 0, !state.armedWhistles.isEmpty {
            for other in Seat.allCases {
                state[other].turnovers += effect.turnoversIfReferee
                events.append(.turnover(other, cause: name))
            }
        }
        if effect.healsInjuries, !state[seat].injuries.isEmpty {
            // Straight to the pile, both sorts. A Devastating one is out of circulation
            // for the rest of the game unless a card puts it back — this is that card.
            state.discard.append(contentsOf: state[seat].injuries.map { Card($0) })
            state[seat].injuries.removeAll()
            state[seat].injuryUnlocked = []
        } else if effect.drawIfUninjured > 0 {
            drawBatch(seat, count: effect.drawIfUninjured, state: &state,
                      events: &events, depth: depth + 1)
        }
        if effect.draws > 0 {
            drawBatch(seat, count: effect.draws, state: &state, events: &events,
                      depth: depth + 1)
        }
        if effect.drawsOnNextMake > 0 {
            state[seat].drawsOwedOnMake += effect.drawsOnNextMake
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
        if effect.shotForHolder != 0 { state.holderShot += effect.shotForHolder }
        // In The Zone: a card for every 10% the ball is worth. A cold ball still pays one.
        if effect.drawsPerTenPercentShot {
            drawBatch(seat, count: max(1, state.shot / 10), state: &state, events: &events,
                      depth: depth + 1)
        }
        if effect.skipsNextDraw { state.skipsNextDraw = true }
        // Somebody has to call a timeout. With no referee on the floor there is nobody
        // to call it, and the card is a card for everybody instead.
        if effect.requiresReferee, state.armedWhistles.isEmpty {
            for other in Seat.allCases {
                drawBatch(other, count: effect.everyoneDrawsInstead, state: &state,
                          events: &events, depth: depth + 1)
            }
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
            for (other, count) in sizes {
                drawBatch(other, count: count, state: &state, events: &events,
                          depth: depth + 1)
            }
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
            let pool = state.discard.map(\.descriptor).filter { $0.gameBreak?.injury != nil }
            let inDeck = state.deck.map(\.descriptor).filter { $0.gameBreak?.injury != nil }
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
            for other in Seat.allCases { draw(other, state: &state, events: &events) }
        }
        // Role Player: everybody else eats. Batched, so a Shot Creator on one of them
        // pays once rather than once a card.
        if effect.othersDraw > 0 {
            for other in Seat.allCases where other != seat {
                drawBatch(other, count: effect.othersDraw, state: &state, events: &events,
                          depth: depth + 1)
            }
        }
        if effect.waivesBreaks > 0 { state.breaksWaived += effect.waivesBreaks }
        if effect.givesBallAway, let holder = state.ball {
            // Handed over, not taken away: whoever is benched decides where the ball
            // goes. Queued rather than set — see `pendingInbound`.
            state.lastPasser = nil
            state.arrivedBy = nil
            state.pendingInbound = holder
        }
    }

    /// Reveals a passive and slots it, pushing out the oldest when the slots are full.
    private static func activate(_ card: Card, for seat: Seat,
                                 state: inout GameState, events: inout [GameEvent]) {
        events.append(.intangibleRevealed(seat: seat, card: card.descriptor))
        state[seat].intangibles.append(card.descriptor)
        shedIntangibles(for: seat, state: &state, events: &events)
    }

    /// Notes a board that is over its slots. **Whose goes is the player's call**, so this
    /// only queues the question — `settleHands` asks it once the chain is done.
    private static func shedIntangibles(for seat: Seat, state: inout GameState,
                                        events: inout [GameEvent]) {
        if state[seat].intangibles.count > state.rules.intangibleSlots {
            state.overflowing.insert(seat)
        }
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
        state.phase = .possession(holder: state.ball ?? seat)
        rehome(displaced, from: seat, state: &state, events: &events)
        // Rehoming can overflow the board it lands on, and a board can be more than one
        // over if several arrived at once.
        settleHands(state: &state, events: &events)
        return events
    }

    /// A reputation does not go in the bin. It goes to somebody.
    ///
    /// Anybody, the man who just shed it included — you do not get to hand it on by
    /// choosing to. Called wherever a passive comes off a player, so Official Review
    /// clearing a board and a fourth pushing the oldest out both land the same way.
    private static func rehome(_ card: CardDescriptor, from seat: Seat,
                               state: inout GameState, events: inout [GameEvent]) {
        guard card.intangible?.reattachesOnDiscard == true else { return }
        let landing = state.pick(from: Seat.allCases)
        state[landing].intangibles.append(card)
        events.append(.intangibleRevealed(seat: landing, card: card))
        shedIntangibles(for: landing, state: &state, events: &events)
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
    static func testDraw(_ seat: Seat, state: inout GameState, events: inout [GameEvent]) {
        draw(seat, state: &state, events: &events)
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
