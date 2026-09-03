import Foundation

let human = GameRules.localSeat
/// How many trailing log lines to show; --log N overrides.
let logTail: Int = {
    guard let i = CommandLine.arguments.firstIndex(of: "--log"),
          i + 1 < CommandLine.arguments.count, let n = Int(CommandLine.arguments[i + 1]) else { return 10 }
    return n
}()

func statLine(_ p: PlayerState, ball: Seat?) -> String {
    let mark = p.seat == ball ? "*" : " "
    let who = p.seat == human ? "\(p.seat.name) (you)" : p.seat.name
    return String(format: "%@ %-12@  PTS %2d  AST %2d  REB %2d  TOV %2d   = %3d",
                  mark, who as NSString, p.points, p.assists, p.rebounds, p.turnovers, p.score)
}

func board(_ s: GameState) -> String {
    let clock = s.shotClock.map(String.init) ?? "--"
    var out = ""
    out += "ROUND \(s.round)/\(s.rules.roundsPerGame)   HALF \(s.half)   SHOT \(s.shot)%   CLOCK \(clock)\n"
    out += String(repeating: "-", count: 58) + "\n"
    func node(_ seat: Seat) -> String {
        let ball = s.ball == seat ? " (*)" : ""
        return "\(seat.name)\(ball)"
    }
    out += "                    \(node(.north))\n"
    out += "          \(node(.west))            \(node(.east))\n"
    out += "                    \(node(.south))\n"
    out += String(repeating: "-", count: 58) + "\n"
    for p in s.players { out += statLine(p, ball: s.ball) + "\n" }
    out += String(repeating: "-", count: 58) + "\n"
    let bag = s[human].bag.enumerated().map { "[\($0.offset)] \($0.element.name)" }
    out += "YOUR BAG (\(s[human].bag.count)):  " + (bag.isEmpty ? "empty" : bag.joined(separator: "   ")) + "\n"
    out += "deck \(s.deck.count) · discard \(s.discard.count)\n"
    return out
}

/// Replays a game from `seed`, feeding queued human choices in order, and stops at
/// the first decision the human owes with no queued answer left.
func play(seed: UInt64, moves: [String]) {
    var (state, events) = Rules.newGame(seed: seed)
    var ai = AITable(seed: seed)
    var queue = moves
    var lines = events.filter(\.isLoggable).map(\.logLine)

    func aiStep() -> Bool {
        if case .freeThrows = state.phase {
            lines += stepFreeThrows(&state).filter(\.isLoggable).map(\.logLine)
            return true
        }
        if case .awaitingRebound = state.phase { return false }
        if case .awaitingDiscard(let who, _, _) = state.phase {
            guard who != human else { return false }
            lines += Rules.resolveDiscardForShot(ai.discardForShot(state, for: who), state: &state)
                .filter(\.isLoggable).map(\.logLine)
            return true
        }
        guard let seat = state.phase.actingSeat, seat != human else { return false }
        guard let move = ai.move(state, for: seat) else { return false }
        lines += Rules.apply(move, by: seat, to: &state).filter(\.isLoggable).map(\.logLine)
        return true
    }

    while !state.isOver {
        while aiStep() {}
        if state.isOver { break }

        if case .awaitingRebound(let shooter) = state.phase {
            guard let token = queue.first, token.hasPrefix("r") else {
                print(board(state))
                print("LOG:"); lines.suffix(logTail).forEach { print("  " + $0) }
                print("\n>> REBOUND. \(shooter.name) missed. Bid hidden — how many cards do you discard?")
                print("   options: " + Rules.legalReboundBid(state, for: human).map { "r\($0)" }.joined(separator: " ")
                      + "   or r:0,1,2 to pick exact cards")
                return
            }
            queue.removeFirst()
            // "r3" bids any three; "r:0,1,2" bids those exact cards.
            let mine: [Card.ID]
            if token.hasPrefix("r:") {
                let indices = token.dropFirst(2).split(separator: ",").compactMap { Int($0) }
                mine = indices.filter { $0 < state[human].bag.count }.map { state[human].bag[$0].id }
            } else {
                let count = min(Int(token.dropFirst()) ?? 0, state[human].bag.count)
                mine = state[human].bag.suffix(count).map(\.id)
            }
            var bids: [Seat: [Card.ID]] = [:]
            for s in Seat.allCases {
                bids[s] = s == human ? mine : ai.reboundBid(state, for: s)
            }
            lines += Rules.resolveRebound(bids: bids, state: &state).filter(\.isLoggable).map(\.logLine)
            continue
        }

        guard let seat = state.phase.actingSeat, seat == human else { break }
        let legal = Rules.legalMoves(state, for: human)

        guard let token = queue.first else {
            print(board(state))
            print("LOG:"); lines.suffix(logTail).forEach { print("  " + $0) }
            if case .inbound = state.phase {
                let targets = legal.compactMap { m -> Seat? in
                    if case .inbound(let t) = m { return t }; return nil }
                print("\n>> YOU INBOUND. Clock shows -- until the ball lands.")
                print("   options: " + targets.map { "in:\($0.abbreviation)  (\($0.name))" }.joined(separator: "   "))
            } else {
                print("\n>> YOUR POSSESSION at SHOT \(state.shot)%.")
                var opts = ["sh  (shoot at \(state.shot)%)"]
                for (i, c) in state[human].bag.enumerated() {
                    let d = c.descriptor
                    if let target = d.passTarget {
                        let seat = human.seat(inDirection: target) ?? state.lastPasser
                        let where_ = seat.map(\.name) ?? "NOBODY — TOV"
                        opts.append("p\(i)  (\(c.name) → \(where_), SHOT \(d.baseShotDelta >= 0 ? "+" : "")\(d.baseShotDelta)%)")
                    } else {
                        var bits = ["SHOT \(d.baseShotDelta >= 0 ? "+" : "")\(d.baseShotDelta)%"]
                        if d.drawCount > 0 { bits.append("draw \(d.drawCount)") }
                        if d.clockDelta != 0 { bits.append("clock \(d.clockDelta)") }
                        opts.append("p\(i)  (\(c.name) — " + bits.joined(separator: ", ") + ", keeps ball)")
                    }
                }
                print("   options: " + opts.joined(separator: "\n            "))
            }
            return
        }
        queue.removeFirst()

        if token == "sh" {
            lines += Rules.apply(.shoot, by: human, to: &state).filter(\.isLoggable).map(\.logLine)
        } else if token.hasPrefix("in:") {
            let abbr = String(token.dropFirst(3))
            guard let target = Seat.allCases.first(where: { $0.abbreviation == abbr }) else { return }
            lines += Rules.apply(.inbound(to: target), by: human, to: &state).filter(\.isLoggable).map(\.logLine)
        } else if token.hasPrefix("p") {
            guard let i = Int(token.dropFirst()), i < state[human].bag.count else { return }
            lines += Rules.apply(.play(state[human].bag[i].id), by: human, to: &state).filter(\.isLoggable).map(\.logLine)
        }
    }

    print(board(state))
    print("LOG:"); lines.suffix(logTail).forEach { print("  " + $0) }
    if state.isOver { print("\n>> GAME OVER.") }
}

let args = CommandLine.arguments
if args.contains("--text") {
    dumpText()
} else if args.contains("--turns") {
    measureTurns()
} else if args.contains("--sweep") {
    sweepThresholds()
} else if args.contains("--ft") {
    measureFreeThrows()
} else if args.contains("--test") {
    runTests()
} else if args.contains("--play") {
    let i = args.firstIndex(of: "--play")!
    let seed = UInt64(args[i + 1]) ?? 7
    let moves = args.dropFirst(i + 2).prefix { !$0.hasPrefix("--") }
    play(seed: seed, moves: Array(moves))
} else {
    var pts = 0, ast = 0, reb = 0, tov = 0, stuck = 0, shots = 0, makes = 0
    var moves: [String: Int] = [:]
    var combos = 0, failedReturns = 0, backPasses = 0, maxShot = 0
    var armed = 0, refocused = 0, clampsSet = 0, reinbounds = 0, shotPct = 0
    var forcedShots = 0, shootDecisions = 0, handSize = 0
    var ftTrips = 0, ftAttempts = 0, ftMade = 0
    var blew: [String: Int] = [:]
    let preset: MatchRules = args.contains("--standard") ? .standard : .classic
    print("pool: \(preset.name) — \(preset.cardPool.reduce(0) { $0 + $1.numberInDeck }) cards")
    for seed in UInt64(1)...500 {
        var (state, _) = Rules.newGame(seed: seed, rules: preset)
        var ai = AITable(seed: seed)
        var guardCounter = 0
        while !state.isOver && guardCounter < 5000 {
            guardCounter += 1
            if case .awaitingDiscard(let who, _, _) = state.phase {
                for e in Rules.resolveDiscardForShot(ai.discardForShot(state, for: who), state: &state) {
                    if case .shotAttempted = e { shots += 1 }
                    if case .shotMade = e { makes += 1 }
                }
                continue
            }
            if case .freeThrows = state.phase {
                for e in stepFreeThrows(&state) {
                    if case .freeThrowMade = e { ftMade += 1; ftAttempts += 1 }
                    if case .freeThrowMissed = e { ftAttempts += 1 }
                }
                continue
            }
            if case .awaitingRebound = state.phase {
                var bids: [Seat: [Card.ID]] = [:]
                for s in Seat.allCases { bids[s] = ai.reboundBid(state, for: s) }
                _ = Rules.resolveRebound(bids: bids, state: &state); continue
            }
            guard let seat = state.phase.actingSeat, let m = ai.move(state, for: seat) else { break }
            if case .shoot = m {
                handSize += state[seat].bag.count; shootDecisions += 1
                if !state[seat].bag.contains(where: { $0.isPass }) { forcedShots += 1 }
            }
            for e in Rules.apply(m, by: seat, to: &state) {
                if case .shotAttempted = e { shots += 1 }
                if case .shotMade = e { makes += 1 }
                if case .movePlayed(_, let c, _) = e { moves[c.name, default: 0] += 1 }
                if case .whistleArmed = e { armed += 1 }
                if case .whistleRefocused = e { refocused += 1 }
                if case .whistleBlew(_, let c, _, _) = e { blew[c.name, default: 0] += 1 }
                if case .clampSet = e { clampsSet += 1 }
                if case .reinbound = e { reinbounds += 1 }
                if case .shotAttempted(_, let pct, _) = e { shotPct += pct }
                if case .comboLanded = e { combos += 1 }
                if case .failedReturn = e { failedReturns += 1 }
                if case .freeThrowsAwarded = e { ftTrips += 1 }
                if case .passed(let c, _, _, _) = e, c.id == "behind-the-back" { backPasses += 1 }
                if case .shotClockTicked(let v) = e { maxShot = max(maxShot, state.shot); _ = v }
            }
        }
        if !state.isOver { stuck += 1 }
        for p in state.players { pts += p.points; ast += p.assists; reb += p.rebounds; tov += p.turnovers }
    }
    let n = 500.0
    print("500 games — unfinished: \(stuck)")
    print(String(format: "per game: PTS %.2f  AST %.2f  REB %.2f  TOV %.2f", Double(pts)/n, Double(ast)/n, Double(reb)/n, Double(tov)/n))
    print(String(format: "shots %.2f/game, made %.1f%%", Double(shots)/n, 100*Double(makes)/Double(max(shots,1))))
    print("move cards played/game: " + moves.sorted { $0.key < $1.key }
        .map { "\($0.key) \(String(format: "%.2f", Double($0.value)/n))" }.joined(separator: "  "))
    let shotsD = Double(max(shots, 1))
    print(String(format: "avg SHOT at attempt: %.1f%%", Double(shotPct)/shotsD))
    print(String(format: "free-action shots: %.1f/game, %.0f%% of them forced (no pass in hand), avg hand %.1f",
                 Double(shootDecisions)/n, 100*Double(forcedShots)/Double(max(shootDecisions,1)),
                 Double(handSize)/Double(max(shootDecisions,1))))
    print(String(format: "whistles: armed %.2f  refocused %.2f  blew %.2f  |  clamps set %.2f  re-inbounds %.2f",
                 Double(armed)/n, Double(refocused)/n,
                 Double(blew.values.reduce(0,+))/n, Double(clampsSet)/n, Double(reinbounds)/n))
    if !blew.isEmpty {
        print("  which blew: " + blew.sorted { $0.value > $1.value }
            .map { "\($0.key) \(String(format: "%.2f", Double($0.value)/n))" }.joined(separator: "  "))
    }
    print(String(format: "free throws: %.2f trips/game, %.2f attempts, %.0f%% made",
                 Double(ftTrips) / 500, Double(ftAttempts) / 500,
                 ftAttempts == 0 ? 0 : 100 * Double(ftMade) / Double(ftAttempts)))
    print(String(format: "Drive combos %.2f/game · Behind-the-Back passes %.2f · failed returns %.2f · peak SHOT seen %d",
                 Double(combos)/n, Double(backPasses)/n, Double(failedReturns)/n, maxShot))
}
