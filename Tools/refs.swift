import Foundation

/// **What the crew actually does**, over a run of Standard games.
///
/// Three officials work every round now and none of them retires when called, so a card
/// written as a one-shot trap is a standing rule — and a standing rule that cancels a
/// whole class of play is a different card from the one that was printed. This counts what
/// each of them calls, how much of a round they eat, and what a game looks like with each
/// one held out.
func runRefAudit() {
    let games = 200
    var calls: [String: Int] = [:]
    var roundsWorked: [String: Int] = [:]
    var cancelled: [String: Int] = [:]
    var pointsWith: [String: (points: Int, games: Int)] = [:]

    var totalPoints = 0, totalShots = 0, totalMakes = 0, totalTurnovers = 0

    for seed in 0..<games {
        var (state, events) = Rules.newGame(seed: UInt64(seed), rules: .standard)
        var ai = AITable(seed: UInt64(seed))
        var guardCounter = 0
        var crewSeen: Set<String> = []

        func record(_ batch: [GameEvent]) {
            for event in batch {
                if case .crewAssigned(let cards) = event {
                    for card in cards {
                        roundsWorked[card.name, default: 0] += 1
                        crewSeen.insert(card.name)
                    }
                }
                if case .whistleBlew(_, let card, let what, _, _, _) = event {
                    calls[card.name, default: 0] += 1
                    if what != "the draw" && what != "the play" {
                        cancelled[card.name, default: 0] += 1
                    }
                }
                if case .shotAttempted = event { totalShots += 1 }
                if case .shotMade(_, let points, _, _) = event {
                    totalMakes += 1
                    totalPoints += points
                }
                if case .turnover = event { totalTurnovers += 1 }
            }
        }
        record(events)

        while !state.isOver, guardCounter < 20_000 {
            guardCounter += 1
            // The two the prompts do not own: a trip to the line, and everybody bidding.
            if case .freeThrows = state.phase { record(stepFreeThrows(&state)); continue }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for seat in Seat.allCases { bids[seat] = ai.reboundBid(state, for: seat) }
                record(Rules.resolveRebound(bids: bids, state: &state))
                continue
            }
            if let answered = Prompts.answer(&state, &ai) { record(answered); continue }
            guard let seat = state.phase.actingSeat, let move = ai.move(state, for: seat)
            else { break }
            record(Rules.apply(move, by: seat, to: &state))
        }
        let scored = Seat.allCases.reduce(0) { $0 + state[$1].points }
        for name in crewSeen {
            var row = pointsWith[name] ?? (0, 0)
            row.points += scored; row.games += 1
            pointsWith[name] = row
        }
    }

    print("THE CREW — \(games) Standard games")
    print(String(repeating: "=", count: 78))
    print("per game: \(f(totalPoints, games)) PTS · \(f(totalShots, games)) shots · "
          + "\(f(totalMakes, games)) makes · \(f(totalTurnovers, games)) TOV")
    print("")
    print(pad("referee", 26) + pad("rounds", 8) + pad("calls", 8) + pad("per round", 11)
          + pad("cancels", 9) + "PTS in games worked")
    print(String(repeating: "-", count: 78))

    var rate: [String: Double] = [:]
    for (name, worked) in roundsWorked {
        rate[name] = Double(calls[name] ?? 0) / Double(max(1, worked))
    }
    let ranked = roundsWorked.keys.sorted { (rate[$0] ?? 0) > (rate[$1] ?? 0) }
    for name in ranked {
        let worked = roundsWorked[name] ?? 0
        let made = calls[name] ?? 0
        let scoring = pointsWith[name].map { f($0.points, max(1, $0.games)) } ?? "—"
        print(pad(name, 26) + pad("\(worked)", 8) + pad("\(made)", 8)
              + pad(String(format: "%.2f", Double(made) / Double(max(1, worked))), 11)
              + pad("\(cancelled[name] ?? 0)", 9) + scoring)
    }
}

/// **One game, played out**, and what it came to.
private func playOut(seed: UInt64, rules: MatchRules) -> (points: Int, shots: Int,
                                                          makes: Int, turnovers: Int) {
    var (state, events) = Rules.newGame(seed: seed, rules: rules)
    var ai = AITable(seed: seed)
    var shots = 0, makes = 0, turnovers = 0
    var guardCounter = 0

    func count(_ batch: [GameEvent]) {
        for event in batch {
            if case .shotAttempted = event { shots += 1 }
            if case .shotMade = event { makes += 1 }
            if case .turnover = event { turnovers += 1 }
        }
    }
    count(events)

    while !state.isOver, guardCounter < 20_000 {
        guardCounter += 1
        if case .freeThrows = state.phase { count(stepFreeThrows(&state)); continue }
        if case .awaitingRebound = state.phase {
            var bids: [Seat: [Card.ID]] = [:]
            for seat in Seat.allCases { bids[seat] = ai.reboundBid(state, for: seat) }
            count(Rules.resolveRebound(bids: bids, state: &state))
            continue
        }
        if let answered = Prompts.answer(&state, &ai) { count(answered); continue }
        guard let seat = state.phase.actingSeat, let move = ai.move(state, for: seat)
        else { break }
        count(Rules.apply(move, by: seat, to: &state))
    }
    _ = events
    return (Seat.allCases.reduce(0) { $0 + state[$1].points }, shots, makes, turnovers)
}

/// **What the game looks like with one of them held out**, against the same games with the
/// whole crew available. The only honest way to read an official: everybody works nearly
/// every game, so a column of averages beside a full crew says nothing.
func runRefHoldOut() {
    let games = 80
    func average(_ pool: [CardDescriptor]) -> (points: Double, shots: Double, makes: Double,
                                               turnovers: Double) {
        var rules = MatchRules.standard
        rules.officialsPool = pool
        var points = 0, shots = 0, makes = 0, turnovers = 0
        for seed in 0..<games {
            let game = playOut(seed: UInt64(seed), rules: rules)
            points += game.points; shots += game.shots
            makes += game.makes; turnovers += game.turnovers
        }
        let over = Double(games)
        return (Double(points) / over, Double(shots) / over,
                Double(makes) / over, Double(turnovers) / over)
    }

    let whole = average(CardLibrary.officialsPool)
    print("")
    print("HELD OUT — \(games) games each, against the whole crew")
    print(String(repeating: "=", count: 78))
    print(String(format: "whole crew: %.2f PTS · %.2f shots · %.2f makes · %.2f TOV",
                 whole.points, whole.shots, whole.makes, whole.turnovers))
    print("")
    print(pad("held out", 26) + pad("PTS", 9) + pad("swing", 9) + pad("shots", 9)
          + pad("makes", 9) + "TOV")
    print(String(repeating: "-", count: 78))

    var rows: [(String, Double, Double, Double, Double)] = []
    for card in CardLibrary.officialsPool {
        let without = average(CardLibrary.officialsPool.filter { $0.id != card.id })
        rows.append((card.name, without.points, without.points - whole.points,
                     without.shots, without.turnovers))
    }
    for row in rows.sorted(by: { $0.2 > $1.2 }) {
        print(pad(row.0, 26)
              + pad(String(format: "%.2f", row.1), 9)
              + pad(String(format: "%+.2f", row.2), 9)
              + pad(String(format: "%.2f", row.3), 9)
              + pad("", 9)
              + String(format: "%.2f", row.4))
    }
}

private func pad(_ text: String, _ width: Int) -> String {
    text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
}

private func f(_ total: Int, _ over: Int) -> String {
    String(format: "%.2f", Double(total) / Double(max(1, over)))
}
