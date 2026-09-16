import Foundation

/// **Where cards actually leave hands**, over a run of Standard games.
///
/// The question behind it: a floor thins every hand, nobody can bid for the board, and the
/// same man rebounds his own brick for ever. That is four or five effects compounding, and
/// which ones do the damage is not something a game can be watched hard enough to answer.
///
/// Counted from outside the rules, off the event stream, so nothing here can be wrong in a
/// way the game is not — see `Prompts.answer`, which hands its events back for exactly this.
///
/// **The card you played is not counted.** Playing one spends it by definition; what is
/// measured is everything *else* a hand loses.
func measureDiscards() {
    let games = 200

    var possessions = 0
    var fromRebound = 0
    var endedAtZero = 0
    var neverMoved = 0
    var draws = 0
    var losses = 0
    var reshuffles = 0
    var shotsTaken = 0
    var makes = 0

    /// Cards out of hands, by what took them.
    var bySource: [String: Int] = [:]
    /// Hand sizes, sampled as each possession opens.
    var handSamples: [Int] = []
    /// And the same samples, split by what floor and ball were out.
    var byCourt: [String: (sum: Int, count: Int)] = [:]
    var byBall: [String: (sum: Int, count: Int)] = [:]
    /// Boards won with no basket between them.
    var chains: [Int] = []

    func count(_ events: [GameEvent], context: String) {
        var cause = context
        for event in events {
            switch event {
            case .movePlayed(_, let card, _):      cause = "played \(card.name)"
            case .passed(let card, _, _, _, _):    cause = "played \(card.name)"
            case .clampSet(_, let card):           cause = "clamp \(card.name)"
            case .whistleBlew(_, let card, _, _, _): cause = "whistle \(card.name)"
            case .gameBreakRevealed(_, let card):  cause = card.name
            case .injuryRevealed(_, let card):     cause = "injury \(card.name)"
            case .intangibleRevealed(_, let card): cause = card.name

            case .clampBit(_, let card, let taken):
                bySource["clamp \(card.name)", default: 0] += taken
                losses += taken
            case .discardedForShot(_, let card, let fed):
                bySource["fed to \(card.name)", default: 0] += fed
                losses += fed
            case .discarded(_, let cards):
                bySource[cause, default: 0] += cards.count
                losses += cards.count

            case .drew:           draws += 1
            case .deckReshuffled: reshuffles += 1
            case .shotAttempted:  shotsTaken += 1
            default: break
            }
        }
    }

    /// What a question is charging, for the losses it takes before any event names a cause.
    func asking(_ phase: Phase) -> String {
        switch phase {
        case .awaitingGiveUp(_, let card, _):   return "toll \(card.name)"
        case .awaitingDiscard(_, let card, _):  return "fed to \(card.name)"
        case .awaitingCardFrom(_, let card, _): return "taken by \(card.name)"
        case .awaitingToll:                     return "toll"
        case .awaitingIntangibleDrop:           return "slots full"
        default:                                return phase.label
        }
    }

    for seed in UInt64(1)...UInt64(games) {
        var state = Rules.newGame(seed: seed, rules: .standard).0
        var ai = AITable(seed: seed)
        var guardCounter = 0
        var lastPhase = ""
        var same = 0

        var holder: Seat?
        var shotAtStart = 0
        var chain = 0

        func closePossession() {
            guard holder != nil else { return }
            if state.shot == 0 { endedAtZero += 1 }
            if state.shot == shotAtStart { neverMoved += 1 }
            holder = nil
        }

        while !state.isOver && guardCounter < 20000 {
            guardCounter += 1
            let now = "\(state.phase)"
            same = now == lastPhase ? same + 1 : 0
            lastPhase = now
            if same > 200 { break }

            if case .possession(let who) = state.phase {
                if holder != who {
                    closePossession()
                    holder = who
                    shotAtStart = state.shot
                    possessions += 1
                    // Every hand as the floor is handed over, and what was out at the time.
                    for seat in Seat.allCases {
                        let size = state[seat].bag.count
                        handSamples.append(size)
                        let court = state.currentCourt.name
                        byCourt[court, default: (0, 0)].sum += size
                        byCourt[court, default: (0, 0)].count += 1
                        let ball = state.currentBall?.name ?? "Regulation"
                        byBall[ball, default: (0, 0)].sum += size
                        byBall[ball, default: (0, 0)].count += 1
                    }
                }
            } else {
                closePossession()
            }

            if case .freeThrows = state.phase {
                count(stepFreeThrows(&state), context: "free throw")
                continue
            }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for seat in Seat.allCases { bids[seat] = ai.reboundBid(state, for: seat) }
                let spent = bids.values.reduce(0) { $0 + $1.count }
                bySource["rebound bid", default: 0] += spent
                losses += spent
                let events = Rules.resolveRebound(bids: bids, state: &state)
                for case .rebounded in events { fromRebound += 1; chain += 1 }
                count(events, context: "rebound")
                continue
            }
            let asked = asking(state.phase)
            if let answered = Prompts.answer(&state, &ai) {
                count(answered, context: asked)
                continue
            }
            guard let seat = state.phase.actingSeat, let move = ai.move(state, for: seat) else {
                break
            }
            let events = Rules.apply(move, by: seat, to: &state)
            for event in events {
                switch event {
                case .rebounded: fromRebound += 1; chain += 1
                case .shotMade:
                    makes += 1
                    if chain > 0 { chains.append(chain); chain = 0 }
                // **A run is one live sequence.** Counting boards since the last basket
                // instead ran straight through turnovers, inbounds and whole rounds, which
                // is how this reported a run of seventy that never happened — see
                // `measureBricks`, which walks the real ones.
                case .turnover, .inbounded, .roundEnded:
                    if chain > 0 { chains.append(chain); chain = 0 }
                default: break
                }
            }
            count(events, context: "played")
        }
        if chain > 0 { chains.append(chain) }
    }

    // MARK: What it found

    let hands = handSamples.count
    let mean = Double(handSamples.reduce(0, +)) / Double(max(1, hands))
    let empty = handSamples.filter { $0 == 0 }.count
    let thin = handSamples.filter { $0 <= 1 }.count
    let share = { (part: Int) in Double(part) * 100 / Double(max(1, hands)) }

    print("DISCARD AUDIT — \(games) Standard games")
    print(String(repeating: "=", count: 66))
    print(String(format: "possessions %d · shots %d · makes %d (%.0f%%) · boards %d",
                 possessions, shotsTaken, makes,
                 Double(makes) * 100 / Double(max(1, shotsTaken)), fromRebound))
    print(String(format: "draws %.2f a possession · cards lost %.2f a possession",
                 Double(draws) / Double(max(1, possessions)),
                 Double(losses) / Double(max(1, possessions))))
    print(String(format: "deck reshuffles %.2f a game", Double(reshuffles) / Double(games)))
    print("")
    print(String(format: "HANDS as a possession opens: mean %.2f · empty %.0f%% · one or none %.0f%%",
                 mean, share(empty), share(thin)))
    print(String(format: "possessions ending on SHOT 0: %.0f%% · SHOT never moved: %.0f%%",
                 Double(endedAtZero) * 100 / Double(max(1, possessions)),
                 Double(neverMoved) * 100 / Double(max(1, possessions))))
    let runs = chains.filter { $0 > 1 }
    print(String(format: "cards spent bidding: %.2f a board", 
                 Double(bySource["rebound bid"] ?? 0) / Double(max(1, fromRebound))))
    print(String(format: "boards with no basket between: longest %d · runs of 2+ %d (%.2f a game)",
                 chains.max() ?? 0, runs.count, Double(runs.count) / Double(games)))
    print("")
    print("WHERE CARDS GO (the played card itself is not counted)")
    print(String(repeating: "-", count: 66))
    let ranked = bySource.sorted { $0.value > $1.value }
    for (name, taken) in ranked.prefix(18) {
        print(String(format: "  %-34@ %6d  %5.1f%%  %.2f a possession",
                     name as NSString, taken, Double(taken) * 100 / Double(max(1, losses)),
                     Double(taken) / Double(max(1, possessions))))
    }
    let rest = ranked.dropFirst(18).reduce(0) { $0 + $1.value }
    if rest > 0 { print(String(format: "  %-34@ %6d", "everything else" as NSString, rest)) }
    print("")
    print("HANDS BY FLOOR (mean, as a possession opens)")
    print(String(repeating: "-", count: 66))
    func thinnest(_ tally: [String: (sum: Int, count: Int)]) -> [(String, (sum: Int, count: Int))] {
        tally.sorted { Double($0.value.sum) / Double(max(1, $0.value.count))
                       < Double($1.value.sum) / Double(max(1, $1.value.count)) }
    }
    for (name, tally) in thinnest(byCourt).prefix(10) {
        print(String(format: "  %-28@ %5.2f   (%d samples)", name as NSString,
                     Double(tally.sum) / Double(max(1, tally.count)), tally.count))
    }
    print("")
    print("HANDS BY BALL (mean, as a possession opens)")
    print(String(repeating: "-", count: 66))
    for (name, tally) in thinnest(byBall).prefix(10) {
        print(String(format: "  %-28@ %5.2f   (%d samples)", name as NSString,
                     Double(tally.sum) / Double(max(1, tally.count)), tally.count))
    }
}
