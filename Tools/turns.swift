import Foundation

/// How many separate decisions a game asks for — the unit of an async turn.
func measureTurns() {
    var decisions = 0, rebounds = 0, perSeat = [Seat: Int]()
    var longestRound = 0
    // A turn is a handover: consecutive decisions by the same seat are one visit.
    var handovers = 0, handoverPerSeat = [Seat: Int]()
    var lastActor: Seat?
    let games = 400

    for seed in UInt64(1)...UInt64(games) {
        var state = Rules.newGame(seed: seed).0
        var ai = AITable(seed: seed)
        var guardCounter = 0
        var roundDecisions = 0
        var round = state.round

        while !state.isOver && guardCounter < 5000 {
            guardCounter += 1
            if state.round != round { longestRound = max(longestRound, roundDecisions); roundDecisions = 0; round = state.round }

            if case .awaitingRebound = state.phase {
                // One phase, but it blocks on all four players at once.
                rebounds += 1
                handovers += Seat.allCases.count
                for s in Seat.allCases { handoverPerSeat[s, default: 0] += 1 }
                lastActor = nil
                decisions += Seat.allCases.count
                roundDecisions += Seat.allCases.count
                for s in Seat.allCases { perSeat[s, default: 0] += 1 }
                var bids: [Seat: [Card.ID]] = [:]
                for s in Seat.allCases { bids[s] = ai.reboundBid(state, for: s) }
                Rules.resolveRebound(bids: bids, state: &state)
                continue
            }
            guard let seat = state.phase.actingSeat, let m = ai.move(state, for: seat) else { break }
            if seat != lastActor { handovers += 1; handoverPerSeat[seat, default: 0] += 1; lastActor = seat }
            decisions += 1
            roundDecisions += 1
            perSeat[seat, default: 0] += 1
            Rules.apply(m, by: seat, to: &state)
        }
    }

    let n = Double(games)
    print(String(format: "decisions per game: %.1f  (of which %.1f are rebound bids)",
                 Double(decisions)/n, Double(rebounds * 4)/n))
    print(String(format: "simultaneous rebound phases per game: %.2f", Double(rebounds)/n))
    print("decisions per player: " + Seat.allCases.map {
        String(format: "%@ %.1f", $0.playerName, Double(perSeat[$0] ?? 0)/n) }.joined(separator: "  "))
    print("longest single round seen: \(longestRound) decisions")
    print(String(format: "\nASYNC TURNS (a handover, not a tap): %.1f per game", Double(handovers)/n))
    print("turns per player: " + Seat.allCases.map {
        String(format: "%@ %.1f", $0.playerName, Double(handoverPerSeat[$0] ?? 0)/n) }.joined(separator: "  "))
    print(String(format: "of those, %.1f per player are rebound bids (the blocking kind)",
                 Double(rebounds)/n))
}
