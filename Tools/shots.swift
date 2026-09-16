import Foundation

/// **Where the scoring is, and where it is thrown away.**
///
/// Every attempt over a run of games, banded by what it was actually worth. The question
/// behind it: a game with more baskets in it is not a game with a bigger SHOT — it is a
/// game that stops taking shots nobody could make.
func measureShots() {
    let games = 200
    let bands = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]

    var attempts = [Int](repeating: 0, count: bands.count)
    var makes = [Int](repeating: 0, count: bands.count)
    var forced = [Int](repeating: 0, count: bands.count)
    var points = 0
    var hadAPass = 0, hadARaise = 0, hadNeither = 0
    var passes = 0, shotSum = 0, passCopies = 0, clockOuts = 0
    var couldMoveIt = 0, firstLook = 0
    var endings: [String: Int] = [:]
    var lastThing = "nothing"
    var possessions = 0
    var rounds = 0

    func band(_ chance: Int) -> Int {
        if chance <= 0 { return 0 }
        return min(bands.count - 1, (chance - 1) / 10 + 1)
    }

    for seed in UInt64(1)...UInt64(games) {
        var state = Rules.newGame(seed: seed, rules: .standard).0
        var ai = AITable(seed: seed)
        var guardCounter = 0
        var lastPhase = ""
        var same = 0
        var holder: Seat?

        while !state.isOver && guardCounter < 20000 {
            guardCounter += 1
            let now = "\(state.phase)"
            same = now == lastPhase ? same + 1 : 0
            lastPhase = now
            if same > 200 { break }

            if case .possession(let who) = state.phase, holder != who {
                holder = who
                possessions += 1
                // Can the man holding it move it at all? The chain's own question.
                firstLook += 1
                if Rules.legalMoves(state, for: who).contains(where: { move in
                    guard case .play(let id) = move,
                          let card = state[who].bag.first(where: { $0.id == id })
                    else { return false }
                    return card.descriptor.isPass
                }) { couldMoveIt += 1 }
            }
            if case .freeThrows = state.phase { stepFreeThrows(&state); continue }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for seat in Seat.allCases { bids[seat] = ai.reboundBid(state, for: seat) }
                Rules.resolveRebound(bids: bids, state: &state)
                continue
            }
            if Prompts.step(&state, &ai) { continue }
            guard let seat = state.phase.actingSeat, let move = ai.move(state, for: seat) else { break }

            let legal = Rules.legalMoves(state, for: seat)
            let onlyShot = legal.count == 1 && legal.first == .shoot
            // What else was on the table when a hopeless shot went up.
            var couldPass = false, couldRaise = false
            for option in legal {
                guard case .play(let id) = option,
                      let card = state[seat].bag.first(where: { $0.id == id }) else { continue }
                if card.descriptor.isPass { couldPass = true }
                if (card.descriptor.shotEffect ?? 0) > 0 { couldRaise = true }
            }
            var at = -1
            for event in Rules.apply(move, by: seat, to: &state) {
                switch event {
                case .shotAttempted(_, let chance, _):
                    shotSum += chance
                    at = band(chance)
                    attempts[at] += 1
                    if onlyShot { forced[at] += 1 }
                    if chance == 0 {
                        if couldPass { hadAPass += 1 }
                        if couldRaise { hadARaise += 1 }
                        if !couldPass && !couldRaise && !onlyShot { hadNeither += 1 }
                    }
                case .shotMade(_, let scored, _, _):
                    if at >= 0 { makes[at] += 1 }
                    points += scored
                    lastThing = "a basket"
                case .freeThrowMade(_, let scored, _, _):
                    points += scored
                case .passed: passes += 1
                case .turnover(_, let cause) where cause != nil: clockOuts += 1
                case .turnover: lastThing = "a turnover"
                case .freeThrowMade: lastThing = "a free throw"
                case .halftime: lastThing = "halftime"
                case .roundEnded:
                    rounds += 1
                    endings[lastThing, default: 0] += 1
                    lastThing = "nothing"

                default: break
                }
            }
        }
    }

    let total = attempts.reduce(0, +)
    let scored = makes.reduce(0, +)
    print("SHOTS — \(games) Standard games")
    print(String(repeating: "=", count: 68))
    print(String(format: "%d attempts · %d makes (%.0f%%) · %.1f points a game · %.1f attempts a possession",
                 total, scored, Double(scored) * 100 / Double(max(1, total)),
                 Double(points) / Double(games),
                 Double(total) / Double(max(1, possessions))))
    print(String(format: "of the %d shots at 0%%: %d had a Pass in hand, %d had a card that raises SHOT, "
                 + "%d had neither but were not forced", attempts[0], hadAPass, hadARaise, hadNeither))
    passCopies = CardLibrary.standardPool.filter { $0.isPass }.reduce(0) { $0 + $1.numberInDeck }
    print(String(format: "the holder could move the ball at all: %.1f%% of possessions "
                 + "(it dies on him %.1f%%)",
                 Double(couldMoveIt) * 100 / Double(max(1, firstLook)),
                 100 - Double(couldMoveIt) * 100 / Double(max(1, firstLook))))
    print(String(format: "passes %.2f a possession (%d Pass cards in the deck) · mean SHOT at the attempt %.1f%% · whistled turnovers %d",
                 Double(passes) / Double(max(1, possessions)), passCopies,
                 Double(shotSum) / Double(max(1, total)), clockOuts))
    print(String(format: "rounds %.1f a game · %.1f makes a game · %.2f points a make",
                 Double(rounds) / Double(games), Double(scored) / Double(games),
                 Double(points) / Double(max(1, scored))))
    print("rounds end on: " + endings.sorted { $0.value > $1.value }
            .map { String(format: "%@ %.0f%%", $0.key as NSString,
                          Double($0.value) * 100 / Double(max(1, rounds))) }
            .joined(separator: " · "))
    print("")
    print("  worth        attempts   share    makes   of the game's points   was the only move")
    print(String(repeating: "-", count: 68))
    for (index, low) in bands.enumerated() {
        guard attempts[index] > 0 else { continue }
        let label = index == 0 ? "0%" : "\(low - 9)–\(low)%"
        print(String(format: "  %-10@ %8d  %5.1f%%  %7d   %14.1f%%   %14.0f%%",
                     label as NSString, attempts[index],
                     Double(attempts[index]) * 100 / Double(max(1, total)), makes[index],
                     Double(makes[index]) * 100 / Double(max(1, scored)),
                     Double(forced[index]) * 100 / Double(max(1, attempts[index]))))
    }
}
