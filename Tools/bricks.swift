import Foundation

/// **Why a run of boards goes on for thirty possessions with nobody scoring.**
///
/// The discard audit said it happens; this says what it looks like from the inside. Every
/// possession inside a run is written down — the hand, SHOT, what the rules would take, what
/// was played, and what the shot was actually worth — so the reason is read rather than
/// guessed at.
func measureBricks() {
    let games = 200
    /// A run worth looking at.
    let longEnough = 10

    var runs: [Int] = []
    var worst: (length: Int, seed: UInt64, trace: [String]) = (0, 0, [])
    /// Inside runs of `longEnough` or more.
    var insideShots = 0
    var insideZeroShots = 0
    var insideChance = 0
    var insideHands: [Int] = []
    var forcedShots = 0
    var possessionsInside = 0
    var endings: [String: Int] = [:]

    for seed in UInt64(1)...UInt64(games) {
        var state = Rules.newGame(seed: seed, rules: .standard).0
        var ai = AITable(seed: seed)
        var guardCounter = 0
        var lastPhase = ""
        var same = 0

        var chain = 0
        var trace: [String] = []
        var handsThisRun: [Int] = []
        var shotsThisRun: [(chance: Int, forced: Bool)] = []

        func closeRun(_ how: String) {
            if chain > 0 { runs.append(chain) }
            if chain >= longEnough {
                endings[how, default: 0] += 1
                possessionsInside += chain
                insideHands += handsThisRun
                for shot in shotsThisRun {
                    insideShots += 1
                    insideChance += shot.chance
                    if shot.chance == 0 { insideZeroShots += 1 }
                    if shot.forced { forcedShots += 1 }
                }
                if chain > worst.length {
                    worst = (chain, seed, trace)
                }
            }
            chain = 0
            trace = []
            handsThisRun = []
            shotsThisRun = []
        }

        while !state.isOver && guardCounter < 20000 {
            guardCounter += 1
            let now = "\(state.phase)"
            same = now == lastPhase ? same + 1 : 0
            lastPhase = now
            if same > 200 { break }

            if case .freeThrows = state.phase { stepFreeThrows(&state); continue }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for seat in Seat.allCases { bids[seat] = ai.reboundBid(state, for: seat) }
                let spent = bids.mapValues(\.count).filter { $0.value > 0 }
                let events = Rules.resolveRebound(bids: bids, state: &state)
                for case .rebounded(let who) in events {
                    chain += 1
                    if chain >= longEnough || trace.count < 200 {
                        trace.append(String(format: "   board -> %@  bids %@",
                                            who.name as NSString,
                                            spent.isEmpty ? "none"
                                                : spent.map { "\($0.key.name):\($0.value)" }
                                                    .sorted().joined(separator: " ")))
                    }
                }
                continue
            }
            if Prompts.step(&state, &ai) { continue }
            guard let seat = state.phase.actingSeat, let move = ai.move(state, for: seat) else { break }

            let legal = Rules.legalMoves(state, for: seat)
            let onlyShot = legal.count == 1 && legal.first == .shoot
            let hand = state[seat].bag.count
            let shot = state.shot
            if case .possession = state.phase { handsThisRun.append(hand) }

            let events = Rules.apply(move, by: seat, to: &state)
            var line = String(format: "P%-3d %@ hand %d  SHOT %3d%%  legal %d  %@",
                              chain, seat.name as NSString, hand, shot, legal.count,
                              "\(move)".prefix(38).description as NSString)
            for event in events {
                switch event {
                case .shotAttempted(_, let chance, _):
                    line += "  -> \(chance)%"
                    shotsThisRun.append((chance, onlyShot))
                case .shotMade:
                    line += " MADE"
                    trace.append(line)
                    closeRun("a basket")
                    line = ""
                case .shotMissed:
                    line += " miss"
                case .turnover(_, let cause):
                    line += " TOV(\(cause ?? "-"))"
                    trace.append(line)
                    closeRun("a turnover")
                    line = ""
                case .inbounded:
                    if chain > 0 { trace.append(line); closeRun("an inbound"); line = "" }
                case .roundEnded:
                    if chain > 0 { trace.append(line); closeRun("the round ending"); line = "" }
                default: break
                }
            }
            if !line.isEmpty, chain > 0, trace.count < 200 {
                trace.append("     floor \(state.currentCourt.name) · ball "
                             + (state.currentBall?.name ?? "Regulation"))
                trace.append(line)
            }
        }
        closeRun("the game ending")
    }

    let long = runs.filter { $0 >= longEnough }
    print("BRICK RUNS — \(games) Standard games")
    print(String(repeating: "=", count: 70))
    print("runs of \(longEnough)+ boards with no basket: \(long.count)"
          + String(format: " (%.2f a game) · longest %d", Double(long.count) / Double(games),
                   runs.max() ?? 0))
    print(String(format: "inside those runs: %d possessions · hand %.2f · shots %d",
                 possessionsInside,
                 Double(insideHands.reduce(0, +)) / Double(max(1, insideHands.count)),
                 insideShots))
    print(String(format: "  shots at 0%%: %.0f%% · mean chance %.1f%% · shot was the only legal move: %.0f%%",
                 Double(insideZeroShots) * 100 / Double(max(1, insideShots)),
                 Double(insideChance) / Double(max(1, insideShots)),
                 Double(forcedShots) * 100 / Double(max(1, insideShots))))
    print("how they end: " + endings.sorted { $0.value > $1.value }
            .map { "\($0.key) \($0.value)" }.joined(separator: " · "))
    print("")
    print("THE WORST ONE — seed \(worst.seed), \(worst.length) boards")
    print(String(repeating: "-", count: 70))
    for line in worst.trace.prefix(70) { print(line) }
}
