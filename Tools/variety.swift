import Foundation

/// **How much of the deck a player actually meets, and how much of it does the work.**
///
/// A flat deck teaches nothing: every card is a first sighting, and nothing repeats often
/// enough to become a pattern. So: how many different cards turn up in one game, how many
/// pass through one player's hands, and what share of everything played comes off the
/// handful of cards at the top.
func measureVariety() {
    let games = 200
    var seenPerGame: [Int] = []
    var heldPerGame: [Int] = []
    var playedBy: [String: Int] = [:]
    var totalPlays = 0
    var namesOf: [String: String] = [:]

    for seed in UInt64(1)...UInt64(games) {
        var state = Rules.newGame(seed: seed, rules: .standard).0
        var ai = AITable(seed: seed)
        var guardCounter = 0
        var lastPhase = ""
        var same = 0
        var seen: Set<String> = []
        var held: Set<String> = []
        let watcher = GameRules.localSeat
        for card in state[watcher].bag { held.insert(card.descriptor.id) }

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
                Rules.resolveRebound(bids: bids, state: &state)
                continue
            }
            if Prompts.step(&state, &ai) { continue }
            guard let seat = state.phase.actingSeat, let move = ai.move(state, for: seat) else { break }

            // Every card actually put down, whatever kind it is.
            if case .play(let id) = move,
               let card = state[seat].bag.first(where: { $0.id == id }) {
                let key = card.descriptor.id
                playedBy[key, default: 0] += 1
                namesOf[key] = card.descriptor.name
                totalPlays += 1
                seen.insert(key)
            }
            for case .drew(let who, let card, _) in Rules.apply(move, by: seat, to: &state) {
                if who == watcher { held.insert(card.id) }
                namesOf[card.id] = card.name
            }
        }
        seenPerGame.append(seen.count)
        heldPerGame.append(held.count)
    }

    let unique = CardLibrary.standardPool.filter { $0.numberInDeck > 0 }.count
    let copies = CardLibrary.standardPool.reduce(0) { $0 + $1.numberInDeck }
    let mean = { (xs: [Int]) in Double(xs.reduce(0, +)) / Double(max(1, xs.count)) }

    print("VARIETY — \(games) Standard games · \(unique) unique cards, \(copies) in the deck")
    print(String(repeating: "=", count: 68))
    print(String(format: "different cards played in one game: %.0f (%.0f%% of the deck's kinds)",
                 mean(seenPerGame), mean(seenPerGame) * 100 / Double(unique)))
    print(String(format: "different cards through one player's hands: %.0f (%.0f%%)",
                 mean(heldPerGame), mean(heldPerGame) * 100 / Double(unique)))
    print("")

    let ranked = playedBy.sorted { $0.value > $1.value }
    func share(_ n: Int) -> Double {
        Double(ranked.prefix(n).reduce(0) { $0 + $1.value }) * 100 / Double(max(1, totalPlays))
    }
    print(String(format: "the top 10 cards are %.0f%% of every card played", share(10)))
    print(String(format: "the top 20 cards are %.0f%% · the top 40 are %.0f%%", share(20), share(40)))
    var running = 0, needed = 0
    for entry in ranked {
        running += entry.value
        needed += 1
        if Double(running) >= Double(totalPlays) * 0.8 { break }
    }
    print(String(format: "%d cards account for 80%% of all plays — the other %d share the rest",
                 needed, unique - needed))
    let never = unique - ranked.count
    print("cards never played in any of the \(games) games: \(never)")
    print("")
    print("THE WORKHORSES")
    print(String(repeating: "-", count: 68))
    for (key, count) in ranked.prefix(12) {
        print(String(format: "  %-24@ %6d plays  %4.1f%%", (namesOf[key] ?? key) as NSString,
                     count, Double(count) * 100 / Double(max(1, totalPlays))))
    }
    print("")
    print("THE TAIL — least played, of the ones that ever were")
    print(String(repeating: "-", count: 68))
    for (key, count) in ranked.suffix(10) {
        print(String(format: "  %-24@ %6d plays over %d games", (namesOf[key] ?? key) as NSString,
                     count, games))
    }
}
