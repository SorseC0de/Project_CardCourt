import Foundation

/// **What the play actually owes, over a season of games.**
///
/// The queue's whole claim is that an owed step is an item and the engine cannot finish
/// while one remains. That is a claim about behaviour, so it is worth being able to look
/// at: which steps get owed, how often, how long they wait, and whether any is still
/// sitting there when the game ends.
///
/// Read from outside the rules — the state carries the list, so nothing has to be
/// instrumented to watch it.
func stepReadout() {
    var owed: [String: Int] = [:]
    var waits: [String: [Int]] = [:]
    var strandedAtEnd: [String: Int] = [:]
    var games = 0
    /// How long each step has been sitting there, in moves.
    var since: [Step: Int] = [:]
    var moves = 0

    for seed in UInt64(1)...300 {
        var state = Rules.newGame(seed: seed, rules: .standard).0
        var ai = AITable(seed: seed)
        var guardCounter = 0
        games += 1
        since.removeAll()

        while !state.isOver && guardCounter < 20000 {
            guardCounter += 1
            let now = Set(state.pending)
            // Newly owed.
            for step in now where since[step] == nil {
                since[step] = moves
                owed[step.kind.rawValue, default: 0] += 1
            }
            // Paid since the last look.
            for (step, at) in since where !now.contains(step) {
                waits[step.kind.rawValue, default: []].append(moves - at)
                since[step] = nil
            }
            since = since.filter { now.contains($0.key) }

            if case .freeThrows = state.phase { stepFreeThrows(&state); continue }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for s in Seat.allCases { bids[s] = ai.reboundBid(state, for: s) }
                Rules.resolveRebound(bids: bids, state: &state); continue
            }
            if Prompts.step(&state, &ai) { continue }
            guard let seat = state.phase.actingSeat, let m = ai.move(state, for: seat) else {
                break
            }
            moves += 1
            _ = Rules.apply(m, by: seat, to: &state)
        }
        for step in state.pending {
            strandedAtEnd[step.kind.rawValue, default: 0] += 1
        }
    }

    print("\(games) games, \(moves) moves\n")
    print("step            owed   per game   waited (moves)      longest   left at the end")
    for kind in ["revealBreak", "spendHand", "handOverBall",
                 "returnBall", "shootAtOnce", "takeTheLine"] {
        let count = owed[kind] ?? 0
        guard count > 0 else {
            // A Break is owed and paid inside one `Rules.apply`, so nothing watching from
            // outside ever catches it on the list. Not never owed — never *seen* owed,
            // which is the mechanism working.
            let note = kind == "revealBreak"
                ? "owed and paid inside one play, so never seen from out here"
                : "never owed"
            print("  \(kind.padding(toLength: 14, withPad: " ", startingAt: 0))  \(note)")
            continue
        }
        let waited = waits[kind] ?? []
        let mean = waited.isEmpty ? 0
            : Double(waited.reduce(0, +)) / Double(waited.count)
        let longest = waited.max() ?? 0
        let left = strandedAtEnd[kind] ?? 0
        print("  \(kind.padding(toLength: 14, withPad: " ", startingAt: 0))"
              + "\(String(count).leftPadded(5))"
              + "\(String(format: "%.2f", Double(count) / Double(games)).leftPadded(11))"
              + "\(String(format: "%.2f", mean).leftPadded(17))"
              + "\(String(longest).leftPadded(13))"
              + "\(String(left).leftPadded(18))")
    }
    let stranded = strandedAtEnd.values.reduce(0, +)
    let verdict = stranded == 0
        ? "Nothing was left owed when a game ended."
        : "\(stranded) steps were still owed at a final whistle."
    print("\n" + verdict)
}

private extension String {
    func leftPadded(_ width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
