import Foundation

/// Runs full Standard games and reports anything that stops making progress.
func victimHand(_ state: GameState) -> String {
    if case .awaitingCardFrom(_, let card, let victim) = state.phase {
        return "\(victim) has \(state[victim].bag.count) (\(card.name))"
    }
    return "-"
}

func soak() {
    var stalls = 0
    /// **Nothing may be owed while a man is being asked to play.**
    ///
    /// The property the queue exists for: a step that could have been paid and was not is
    /// the shape of every bug it replaced — a return leg the ball never took, a forced
    /// shot dropped on the floor, a hand that never reached the pile. If one is still
    /// sitting there when the game hands the floor back, something returned early.
    var owed = 0
    var owedSeen: Set<String> = []
    for seed in UInt64(1)...UInt64(300) {
        var state = Rules.newGame(seed: seed, rules: .standard).0
        var ai = AITable(seed: seed)
        var guardCounter = 0
        var lastPhase = ""
        var last: [String] = []
        var same = 0
        while !state.isOver && guardCounter < 20000 {
            guardCounter += 1
            let now = "\(state.phase)"
            same = now == lastPhase ? same + 1 : 0
            lastPhase = now
            if same > 200 {
                print("STUCK seed \(seed): \(now)")
                stalls += 1
                break
            }
            if case .freeThrows = state.phase { stepFreeThrows(&state); continue }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for s in Seat.allCases { bids[s] = ai.reboundBid(state, for: s) }
                Rules.resolveRebound(bids: bids, state: &state); continue
            }
            if Prompts.step(&state, &ai) { continue }
            // The floor is about to be handed to a player. Whatever the play owed should
            // have been paid by now, and a possession is when every step is payable.
            // Only the three the drain owns. A trip to the line and a ball being handed
            // over are paid when a possession *ends*, and sitting through one is what
            // they are for.
            let due = state.pending.filter {
                $0.kind == .spendHand || $0.kind == .returnBall || $0.kind == .shootAtOnce
            }
            if case .possession = state.phase, !due.isEmpty {
                owed += 1
                let kinds = due.map(\.kind.rawValue).sorted().joined(separator: ",")
                if owedSeen.insert(kinds).inserted {
                    print("OWED seed \(seed): \(kinds) still pending at a possession")
                }
            }
            guard let seat = state.phase.actingSeat, let m = ai.move(state, for: seat) else {
                let who = state.phase.actingSeat ?? .north
                let held = Set(state[who].clamps.flatMap(\.locked))
                print("NO MOVE \(String(describing: ai.move(state, for: state.phase.actingSeat ?? .north))) seed \(seed): \(state.phase.label) hand=\(state[who].bag.count) held=\(held.count) shot=\(state.shot) ceiling=\(String(describing: state.shotCeilingThisRound)) clamps=\(state[who].clamps.count) victim=\(victimHand(state))ᐧ injuries=\(state[who].injuries.map(\.name)) intangibles=\(state[who].intangibles.map(\.name)) mustShoot=\(String(describing: state.mustShootFirst)) last=\(last.suffix(6))")
                stalls += 1
                break
            }
            last = Rules.apply(m, by: seat, to: &state).map { "\($0)".prefix(while: { $0 != "(" }).description }
        }
        if guardCounter >= 20000 { print("RAN LONG seed \(seed): \(state.phase)"); stalls += 1 }
    }
    if owed > 0 { print("SOAK: \(owed) possessions opened with a step still owed") }
    print(stalls == 0 && owed == 0 ? "SOAK CLEAN"
          : "SOAK: \(stalls + owed) problems")
}

/// What one card's play actually emits, in order.
func probeDime() {
    var state = Rules.newGame(seed: 7, rules: .standard).0
    guard case .inbound(let inbounder) = state.phase else { return }
    Rules.apply(.inbound(to: inbounder.left), by: inbounder, to: &state)
    guard case .possession(let holder) = state.phase else { print("no possession"); return }
    let dime = Card(CardLibrary.dime.resolved(passShotBonus: 5))
    state[holder].bag.append(dime)
    print("shot before:", state.shot)
    let first = Rules.apply(.play(dime.id), by: holder, to: &state)
    print("APPLY:", first.map { "\($0)".prefix(while: { $0 != "(" }) })
    print("phase:", state.phase.label, "shot:", state.shot)
    if case .awaitingTarget(_, _, let choices) = state.phase {
        let second = Rules.resolveTarget(choices[0], state: &state)
        print("RESOLVE:", second.map { "\($0)".prefix(while: { $0 != "(" }) })
    }
}

/// Clear Out: the question the ball asks on arrival.
///
/// Tanaka clamps and swings left; the man it is heading for is holding a Clear Out, so he
/// is asked before the defenders land. He steps aside — and the ball, the Clamps and the
/// credit all carry on to the next man along.
func probeClearOut() {
    var state = Rules.newGame(seed: 11, rules: .standard).0
    guard case .inbound(let inbounder) = state.phase else { return }
    Rules.apply(.inbound(to: inbounder.left), by: inbounder, to: &state)
    guard case .possession(let passer) = state.phase else { print("no possession"); return }

    // The man the swing is heading for, and the card in his hand before it gets there.
    let catcher = passer.left
    state[catcher].bag.append(Card(CardLibrary.clearOut))

    let clamp = Card(CardLibrary.doubleTeam)
    state[passer].bag.append(clamp)
    Rules.apply(.play(clamp.id), by: passer, to: &state)
    let swing = Card(CardLibrary.swingLeft.resolved(passShotBonus: 5))
    state[passer].bag.append(swing)
    Rules.apply(.play(swing.id), by: passer, to: &state)

    print("phase on arrival:", state.phase.label,
          "| pending clamps", state.pendingClamps.count,
          "| on him", state[catcher].clamps.count)
    guard case .awaitingCounter = state.phase else { print("not asked"); return }

    let events = Rules.resolveCounter(true, state: &state)
    print("TAKEN:", events.map { "\($0)".prefix(while: { $0 != "(" }) })
    guard case .possession(let onward) = state.phase else {
        print("no onward:", state.phase.label); return }
    print("ball now \(onward) | clamps on him \(state[onward].clamps.count)",
          "| on the man who stepped out \(state[catcher].clamps.count)",
          "| last passer \(String(describing: state.lastPasser))",
          "| card spent:", !state[catcher].bag.contains { $0.descriptor.clearsOut })
}

/// After a Hesi and after a Stepback: is the shot still on offer?
func probeShootButton() {
    for card in [CardLibrary.hesi, CardLibrary.stepback] {
        var state = Rules.newGame(seed: 5, rules: .standard).0
        guard case .inbound(let inbounder) = state.phase else { return }
        Rules.apply(.inbound(to: inbounder.left), by: inbounder, to: &state)
        guard case .possession(let holder) = state.phase else { continue }
        let played = Card(card)
        state[holder].bag.append(played)
        print("--", card.name, "| shoot before:",
              Rules.legalMoves(state, for: holder).contains(.shoot))
        Rules.apply(.play(played.id), by: holder, to: &state)
        print("   phase:", state.phase.label, "| clock", String(describing: state.shotClock))
        if case .awaitingDiscard(let seat, _, _) = state.phase {
            print("   asked to discard, range", Rules.legalDiscardForShot(state, for: seat))
            Rules.resolveDiscardForShot([], state: &state)
            print("   after declining:", state.phase.label)
        }
        if case .possession(let now) = state.phase {
            let legal = Rules.legalMoves(state, for: now)
            print("   shoot after:", legal.contains(.shoot), "| moves", legal.count,
                  "| ceiling", String(describing: state.shotCeilingThisRound),
                  "| mustShootFirst", String(describing: state.mustShootFirst))
        } else {
            print("   not a possession any more")
        }
    }
}
