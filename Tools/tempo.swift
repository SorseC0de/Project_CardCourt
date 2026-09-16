import Foundation

/// **How fast it moves and how often people touch each other's turns.**
///
/// Points are not what a table remembers. What it remembers is the ball going round three
/// times in ten seconds, somebody getting whistled, a Clamp landing as the ball leaves.
/// So: swings, chains of them, dead possessions where nobody did anything, and every
/// moment one player reached into another's turn.
func measureTempo() {
    let games = 200
    var rounds = 0
    var possessions = 0
    var deadPossessions = 0
    var cardsPlayed = 0
    var passes = 0
    var chains: [Int] = []          // consecutive passes with no shot between
    var interactions = 0            // whistles, clamps, counters, tolls: one turn touching another
    var whistles = 0, clamps = 0, counters = 0, steals = 0
    var roundsWithABattle = 0       // a round holding a chain of three or more

    for seed in UInt64(1)...UInt64(games) {
        var state = Rules.newGame(seed: seed, rules: .standard).0
        var ai = AITable(seed: seed)
        var guardCounter = 0
        var lastPhase = ""
        var same = 0
        var holder: Seat?
        var playedThisPossession = 0
        var chain = 0
        var battleThisRound = false

        func endChain() {
            if chain > 0 { chains.append(chain) }
            if chain >= 3 { battleThisRound = true }
            chain = 0
        }

        while !state.isOver && guardCounter < 20000 {
            guardCounter += 1
            let now = "\(state.phase)"
            same = now == lastPhase ? same + 1 : 0
            lastPhase = now
            if same > 200 { break }

            if case .possession(let who) = state.phase, holder != who {
                if holder != nil, playedThisPossession == 0 { deadPossessions += 1 }
                holder = who
                playedThisPossession = 0
                possessions += 1
            }
            if case .freeThrows = state.phase { stepFreeThrows(&state); continue }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for seat in Seat.allCases { bids[seat] = ai.reboundBid(state, for: seat) }
                Rules.resolveRebound(bids: bids, state: &state)
                continue
            }
            if case .awaitingCounter = state.phase { counters += 1; interactions += 1 }
            if case .awaitingToll = state.phase { steals += 1; interactions += 1 }
            if Prompts.step(&state, &ai) { continue }
            guard let seat = state.phase.actingSeat, let move = ai.move(state, for: seat) else { break }

            for event in Rules.apply(move, by: seat, to: &state) {
                switch event {
                case .passed:
                    passes += 1; chain += 1
                    cardsPlayed += 1; playedThisPossession += 1
                case .movePlayed:
                    cardsPlayed += 1; playedThisPossession += 1
                case .clampSet:
                    clamps += 1; interactions += 1
                    cardsPlayed += 1; playedThisPossession += 1
                case .whistleBlew:
                    whistles += 1; interactions += 1
                    endChain()
                case .shotAttempted: endChain()
                case .turnover: endChain()
                case .roundEnded:
                    endChain()
                    rounds += 1
                    if battleThisRound { roundsWithABattle += 1 }
                    battleThisRound = false
                default: break
                }
            }
        }
    }

    let perRound = { (n: Int) in Double(n) / Double(max(1, rounds)) }
    print("TEMPO — \(games) Standard games")
    print(String(repeating: "=", count: 66))
    print(String(format: "rounds %.1f a game · %.1f possessions a round · %.1f cards played a round",
                 Double(rounds) / Double(games), perRound(possessions), perRound(cardsPlayed)))
    print(String(format: "dead possessions (nobody played anything): %.0f%%",
                 Double(deadPossessions) * 100 / Double(max(1, possessions))))
    print("")
    print(String(format: "THE BALL MOVING: %.2f passes a possession · %.2f a round",
                 Double(passes) / Double(max(1, possessions)), perRound(passes)))
    let battles = chains.filter { $0 >= 3 }.count
    print(String(format: "  swing chains: %d of them · mean %.2f · longest %d · %d ran to three or more",
                 chains.count,
                 Double(chains.reduce(0, +)) / Double(max(1, chains.count)),
                 chains.max() ?? 0, battles))
    print(String(format: "  rounds holding a battle of three or more swings: %.0f%%",
                 Double(roundsWithABattle) * 100 / Double(max(1, rounds))))
    print("")
    print(String(format: "REACHING INTO SOMEBODY'S TURN: %.2f a round", perRound(interactions)))
    print(String(format: "  whistles %.2f · clamps %.2f · counters offered %.2f · tolls %.2f",
                 perRound(whistles), perRound(clamps), perRound(counters), perRound(steals)))
}
