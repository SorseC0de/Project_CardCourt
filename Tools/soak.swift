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
    print(stalls == 0 ? "SOAK CLEAN" : "SOAK: \(stalls) problems")
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

/// Clear Out: the pass nobody threw.
///
/// Tanaka clamps and swings left; the man who catches it steps aside; the ball, the Clamp
/// and the credit all carry on to the next man along.
func probeClearOut() {
    var state = Rules.newGame(seed: 11, rules: .standard).0
    guard case .inbound(let inbounder) = state.phase else { return }
    Rules.apply(.inbound(to: inbounder.left), by: inbounder, to: &state)
    guard case .possession(let passer) = state.phase else { print("no possession"); return }

    // A Clamp out of the passer, then a swing to the man it lands on.
    let clamp = Card(CardLibrary.doubleTeam)
    state[passer].bag.append(clamp)
    Rules.apply(.play(clamp.id), by: passer, to: &state)
    let swing = Card(CardLibrary.swingLeft.resolved(passShotBonus: 5))
    state[passer].bag.append(swing)
    Rules.apply(.play(swing.id), by: passer, to: &state)
    guard case .possession(let caught) = state.phase else {
        print("no catch:", state.phase.label); return }
    print("passer \(passer) → \(caught) | clamps on him \(state[caught].clamps.count)",
          "| last passer \(String(describing: state.lastPasser))")

    let clear = Card(CardLibrary.clearOut)
    state[caught].bag.append(clear)
    print("legal:", Rules.legalMoves(state, for: caught).contains(.play(clear.id)),
          "| clears to", String(describing: Rules.clearsTo(caught, in: state)))
    let events = Rules.apply(.play(clear.id), by: caught, to: &state)
    print("APPLY:", events.map { "\($0)".prefix(while: { $0 != "(" }) })
    guard case .possession(let onward) = state.phase else {
        print("no onward:", state.phase.label); return }
    print("ball now \(onward) | clamps on him \(state[onward].clamps.count)",
          "| clamps left behind \(state[caught].clamps.count)",
          "| last passer \(String(describing: state.lastPasser))")
}
