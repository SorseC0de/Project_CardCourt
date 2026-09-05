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
