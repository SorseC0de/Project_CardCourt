import Foundation

enum GameEvent: Hashable {
    case gameBegan(firstInbounder: Seat)
    case roundBegan(round: Int, inbounder: Seat)
    case inbounded(from: Seat, to: Seat)
    case drew(seat: Seat, card: CardDescriptor)
    case shotClockSet(Int)
    case shotClockTicked(Int)
    case passed(card: CardDescriptor, from: Seat, to: Seat, shot: Int)
    case movePlayed(seat: Seat, card: CardDescriptor, shot: Int)
    case comboLanded(seat: Seat, card: CardDescriptor, bonus: Int)
    case coinRun(seat: Seat, card: CardDescriptor, heads: Int)
    case discardedForShot(seat: Seat, card: CardDescriptor, count: Int)
    case failedReturn(seat: Seat)
    case whistleBlew(owner: Seat, card: CardDescriptor, cancelled: String)
    case whistleArmed(seat: Seat)
    case whistleRefocused
    case whistlesDismissed
    case intangiblesStripped(seat: Seat)
    case gameBreakRevealed(seat: Seat, card: CardDescriptor)
    case intangibleRevealed(seat: Seat, card: CardDescriptor)
    case intangibleDisplaced(seat: Seat, card: CardDescriptor)
    case reinbound(seat: Seat)
    case clampSet(seat: Seat, card: CardDescriptor)
    case clampBit(seat: Seat, card: CardDescriptor, discarded: Int)
    case shotAttempted(seat: Seat, chance: Int, breakdown: ShotResolution)
    case shotMade(seat: Seat, points: Int, roll: Int)
    case shotMissed(seat: Seat, roll: Int)
    case assisted(Seat)
    case reboundBids(bids: [Seat: Int], order: [Seat])
    case rebounded(Seat)
    case turnover(Seat)
    case roundEnded(Int)
    case deckReshuffled
    case halftime
    case gameEnded(winners: [Seat])

    /// True for events the player should see spelled out; draws and clock sets are noise.
    var isLoggable: Bool {
        switch self {
        case .drew, .shotClockSet: return false
        default: return true
        }
    }

    var logLine: String {
        switch self {
        case .gameBegan(let seat):
            return "Tip-off. \(seat.playerName) \(seat.verb("inbounds", "inbound")) first."
        case .roundBegan(let round, let inbounder):
            return "— Round \(round) — \(inbounder.playerName) to inbound."
        case .inbounded(let from, let to):
            return "\(from.playerName) \(from.verb("inbounds", "inbound")) to \(to.playerName)."
        case .drew(let seat, let card):
            return "\(seat.playerName) drew \(card.name)."
        case .shotClockSet(let value):
            return "Shot clock set to \(value)."
        case .shotClockTicked(let value):
            return "Shot clock \(value)."
        case .passed(let card, let from, let to, let shot):
            return "\(from.playerName) \(from.verb("plays", "play")) \(card.name) → \(to.playerName). SHOT \(shot)%."
        case .movePlayed(let seat, let card, let shot):
            return "\(seat.playerName) \(seat.verb("plays", "play")) \(card.name). SHOT \(shot)%."
        case .discardedForShot(let seat, let card, let count):
            return "\(seat.playerName) \(seat.verb("feeds", "feed")) \(count) card\(count == 1 ? "" : "s") into \(card.name)."
        case .coinRun(let seat, let card, let heads):
            return "\(seat.playerName): \(card.name) — \(heads) head\(heads == 1 ? "" : "s") before tails."
        case .comboLanded(let seat, let card, let bonus):
            return "\(seat.playerName) \(seat.verb("strings", "string")) it together — \(card.name) +\(bonus)% bonus."
        case .gameBreakRevealed(let seat, let card):
            return "\(seat.playerName) \(seat.verb("draws", "draw")) \(card.name)!"
        case .intangibleRevealed(let seat, let card):
            return "\(seat.playerName) \(seat.verb("reveals", "reveal")) \(card.name)."
        case .intangibleDisplaced(let seat, let card):
            return "\(card.name) drops off \(seat.playerName)'s slots."
        case .intangiblesStripped(let seat):
            return "\(seat.playerName) \(seat.verb("loses", "lose")) every Intangible."
        case .whistleArmed:
            // Deliberately says nothing about who or what — the trap is the point.
            return "The Referees are watching intently…"
        case .whistlesDismissed:
            return "The referees leave the floor."
        case .whistleRefocused:
            return "The referees seem to have shifted their focus…"
        case .reinbound(let seat):
            return "\(seat.playerName) \(seat.verb("takes", "take")) it back in. The round carries on."
        case .clampSet(let seat, let card):
            return "\(seat.playerName) \(seat.verb("clamps", "clamp")) down — \(card.name)."
        case .clampBit(let seat, let card, let discarded):
            return "\(card.name) on \(seat.playerName): \(discarded) card\(discarded == 1 ? "" : "s") gone."
        case .whistleBlew(let owner, let card, let cancelled):
            return "WHISTLE! \(owner.playerName)'s \(card.name) cancels \(cancelled)."
        case .failedReturn(let seat):
            return "\(seat.playerName) \(seat.verb("has", "have")) nobody to give it back to!"
        case .shotAttempted(let seat, let chance, _):
            return "\(seat.playerName) \(seat.verb("pulls", "pull")) up at \(chance)%…"
        case .shotMade(let seat, let points, _):
            return "GOOD! \(seat.playerName) +\(points) PTS."
        case .shotMissed(let seat, _):
            return "No good. \(seat.playerName) \(seat.verb("misses", "miss"))."
        case .assisted(let seat):
            return "\(seat.playerName) +1 AST."
        case .reboundBids(let bids, let order):
            let parts = order.map { "\($0.playerName) \(bids[$0] ?? 0)" }
            return "Crash the glass: " + parts.joined(separator: " · ")
        case .rebounded(let seat):
            return "\(seat.playerName) \(seat.verb("grabs", "grab")) the board. +1 REB."
        case .turnover(let seat):
            return "Shot clock violation! \(seat.playerName) +1 TOV."
        case .roundEnded(let round):
            return "End of round \(round)."
        case .deckReshuffled:
            return "Deck reshuffled."
        case .halftime:
            return "— HALFTIME — bags and discards reshuffled, fresh 5 each."
        case .gameEnded(let winners):
            return winners.count == 1
                ? "FINAL. \(winners[0].playerName) \(winners[0].verb("wins", "win"))."
                : "FINAL. Tie: " + winners.map(\.playerName).joined(separator: ", ") + "."
        }
    }
}
