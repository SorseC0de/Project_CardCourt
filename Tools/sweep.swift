import Foundation

func sweepThresholds() {
    print("centre |  PTS   AST   REB   TOV | shots  made% | rounds ending in TOV")
    print(String(repeating: "-", count: 68))
    for threshold in [30, 35, 40, 45, 50, 55, 60] {
        var pts = 0, ast = 0, reb = 0, tov = 0, shots = 0, makes = 0, stuck = 0
        let games = 400
        for seed in UInt64(1)...UInt64(games) {
            var state = Rules.newGame(seed: seed).0
            var ai = AITable(seed: seed, tuning: { _ in
                var t = AITuning(); t.shootThreshold = threshold; return t
            })
            var guardCounter = 0
            while !state.isOver && guardCounter < 5000 {
                guardCounter += 1
                if case .awaitingDiscard(let who, _, _) = state.phase {
                    Rules.resolveDiscardForShot(ai.discardForShot(state, for: who), state: &state)
                    continue
                }
                if case .awaitingDiscard(let who, _, _) = state.phase {
                for e in Rules.resolveDiscardForShot(ai.discardForShot(state, for: who), state: &state) {
                    if case .shotAttempted = e { shots += 1 }
                    if case .shotMade = e { makes += 1 }
                }
                continue
            }
            if case .freeThrows = state.phase { stepFreeThrows(&state); continue }
            if case .awaitingRebound = state.phase {
                    var bids: [Seat: [Card.ID]] = [:]
                    for s in Seat.allCases { bids[s] = ai.reboundBid(state, for: s) }
                    Rules.resolveRebound(bids: bids, state: &state); continue
                }
                guard let seat = state.phase.actingSeat,
                      let m = ai.move(state, for: seat) else { break }
                for e in Rules.apply(m, by: seat, to: &state) {
                    if case .shotAttempted = e { shots += 1 }
                    if case .shotMade = e { makes += 1 }
                }
            }
            if !state.isOver { stuck += 1 }
            for p in state.players { pts += p.points; ast += p.assists; reb += p.rebounds; tov += p.turnovers }
        }
        let n = Double(games)
        let tovShare = 100 * Double(tov) / (n * Double(MatchRules.classic.roundsPerGame))
        print(String(format: "  %3d  | %5.2f %5.2f %5.2f %5.2f | %5.2f  %5.1f%% | %5.1f%%%@",
                     threshold, Double(pts)/n, Double(ast)/n, Double(reb)/n, Double(tov)/n,
                     Double(shots)/n, 100*Double(makes)/Double(max(shots,1)), tovShare,
                     stuck > 0 ? "  (\(stuck) unfinished!)" : "" as NSString))
    }
}
