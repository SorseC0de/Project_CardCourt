import Foundation

/// Shoots a waiting trip headlessly.
///
/// The mini-game does not exist out here, so every seat — South included — shoots the
/// opponent's roll. That makes the harness a check on the rules around free throws, not
/// on how well they can be shot.
@discardableResult
func stepFreeThrows(_ state: inout GameState) -> [GameEvent] {
    guard case .freeThrows = state.phase else { return [] }
    let made = Rules.rollFreeThrow(state: &state)
    return Rules.resolveFreeThrow(made: made, state: &state)
}

/// Where free throws actually come from over a run of Standard games, and what they are
/// worth once they arrive.
func measureFreeThrows() {
    var trips = 0, attempts = 0, makes = 0, games = 0, stuck = 0
    var bySource: [String: Int] = [:]
    var reachedTheLine = 0

    for seed in UInt64(1)...500 {
        var state = Rules.newGame(seed: seed, rules: .standard).0
        var ai = AITable(seed: seed)
        var sawOne = false
        var guardCounter = 0
        games += 1
        while !state.isOver && guardCounter < 6000 {
            guardCounter += 1
            if case .freeThrows = state.phase {
                for e in stepFreeThrows(&state) {
                    if case .freeThrowMade = e { makes += 1; attempts += 1 }
                    if case .freeThrowMissed = e { attempts += 1 }
                }
                continue
            }
            if case .awaitingDiscard(let who, _, _) = state.phase {
                Rules.resolveDiscardForShot(ai.discardForShot(state, for: who), state: &state)
                continue
            }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for s in Seat.allCases { bids[s] = ai.reboundBid(state, for: s) }
                Rules.resolveRebound(bids: bids, state: &state)
                continue
            }
            if Prompts.step(&state, &ai) { continue }
            guard let seat = state.phase.actingSeat, let m = ai.move(state, for: seat) else { break }
            for e in Rules.apply(m, by: seat, to: &state) {
                if case .freeThrowsAwarded(_, let n, let source) = e {
                    trips += 1
                    bySource[source, default: 0] += n
                    sawOne = true
                }
            }
        }
        if guardCounter >= 6000 { stuck += 1 }
        if sawOne { reachedTheLine += 1 }
    }

    print("Free throws over \(games) Standard games")
    print(String(repeating: "-", count: 52))
    print(String(format: "trips           %6d   (%.2f per game)", trips, Double(trips) / Double(games)))
    print(String(format: "attempts        %6d   (%.2f per game)", attempts, Double(attempts) / Double(games)))
    print(String(format: "made            %6d   (%.1f%%)", makes,
                 attempts == 0 ? 0 : 100 * Double(makes) / Double(attempts)))
    print(String(format: "games with any  %6d   (%.1f%%)", reachedTheLine,
                 100 * Double(reachedTheLine) / Double(games)))
    print("stuck            \(stuck)")
    print("\nawarded by card")
    for (source, count) in bySource.sorted(by: { $0.value > $1.value }) {
        print(String(format: "  %-24@ %5d", source as NSString, count))
    }
}
