import Foundation

/// The console channel for on-device testing, read in Xcode while attached.
///
/// The in-game log is written for a player: short, in prose, and deliberately vague where
/// the game wants to be — an armed Whistle says only that the referees are watching. This
/// says what actually happened, in the terms the code thinks in, so a thing seen once on a
/// phone can be answered afterwards instead of re-guessed.
///
/// Every line is tagged, so Xcode's console filter is the whole interface: type `[shot]`
/// to watch nothing but shots resolving.
///
/// DEBUG only, and the message is an autoclosure — nothing is built, formatted or
/// concatenated in a release build, or when a channel is switched off.
enum DevLog {

    enum Tag: String {
        /// What the player actually did — the tap, not its consequences.
        case input
        case shot
        case card
        case phase
        case whistle
        case freeThrow = "ft"
        case deck
        /// The wire: signing in, matchmaking, and what crosses between devices.
        case net
    }

    /// Switch a channel off when it drowns out what is being chased.
    static var channels: Set<Tag> = Set(
        [.input, .shot, .card, .phase, .whistle, .freeThrow, .deck, .net])

    /// Wall clock to the millisecond, and how long since the line before it.
    ///
    /// The gap is the useful half. Most of what goes wrong here is ordering — a scene
    /// starting before the thing it is meant to follow, a stamp landing on the wrong beat
    /// — and a list of times you have to subtract in your head hides exactly that.
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    private static var last: Date?

    private static func stamp() -> String {
        let now = Date()
        let gap = last.map { now.timeIntervalSince($0) } ?? 0
        last = now
        return String(format: "%@ %+6.0fms", clock.string(from: now), gap * 1000)
    }

    static func say(_ tag: Tag, _ message: @autoclosure () -> String) {
#if DEBUG
        guard channels.contains(tag) else { return }
        print("\(stamp())  [\(tag.rawValue)] \(message())")
#endif
    }

    /// A rule across the console, for finding the start of a round by eye.
    static func mark(_ title: String) {
#if DEBUG
        print("\(stamp())  ── \(title) "
              + String(repeating: "─", count: max(0, 40 - title.count)))
#endif
    }

    /// Everything one move produced, in the order it happened.
    static func record(_ events: [GameEvent]) {
#if DEBUG
        for event in events {
            switch event {
            case .roundBegan(let round, let inbounder):
                mark("round \(round) · \(inbounder.dev) inbounds")

            case .shotAttempted(let seat, let chance, let breakdown):
                // The whole stack, every time. A shot arriving at a number nobody expects
                // is otherwise unanswerable after the fact, and the question is always
                // *which* step did or did not happen.
                let stack = breakdown.steps
                    .map { "\($0.label)→\($0.total)" }
                    .joined(separator: " ")
                say(.shot, "\(seat.dev) at \(chance)%  base \(breakdown.base)"
                    + (stack.isEmpty ? "  (no modifiers)" : "  | \(stack)"))
            case .shotMade(let seat, let points, let roll, _):
                say(.shot, "\(seat.dev) MADE  +\(points)  roll \(roll)")
            case .shotMissed(let seat, let roll, _):
                say(.shot, "\(seat.dev) missed  roll \(roll)")

            case .passed(let card, let from, let to, let shot):
                say(.card, "\(from.dev) → \(to.dev)  \(card.name)  SHOT \(shot)%")
            case .movePlayed(let seat, let card, let shot):
                say(.card, "\(seat.dev) plays \(card.name)  SHOT \(shot)%")
            case .clampSet(let seat, let card):
                say(.card, "\(seat.dev) sets \(card.name)")
            case .drew(let seat, let card):
                say(.card, "\(seat.dev) drew \(card.name)")
            case .gameBreakRevealed(let seat, let card):
                say(.card, "\(seat.dev) turns up \(card.name)")
            case .intangibleRevealed(let seat, let card):
                say(.card, "\(seat.dev) reveals \(card.name)")

            case .whistleUsed(let seat, let card):
                say(.whistle, "\(seat.dev) calls \(card.name)")
            case .whistleArmed(let seat):
                say(.whistle, "\(seat.dev) arms one")
            case .whistleBlew(let owner, let card, let cancelled, let victim):
                say(.whistle, "\(owner.dev)'s \(card.name) cancels \(cancelled)"
                    + (victim.map { " (\($0.name))" } ?? ""))
            case .whistlesDismissed:
                say(.whistle, "silenced for the round")

            case .freeThrowsAwarded(let seat, let count, let source):
                say(.freeThrow, "\(seat.dev) awarded \(count) by \(source)")
            case .freeThrowMade(let seat, _, let index, let total):
                say(.freeThrow, "\(seat.dev) \(index)/\(total) good")
            case .freeThrowMissed(let seat, let index, let total):
                say(.freeThrow, "\(seat.dev) \(index)/\(total) missed")

            case .turnover(let seat, _):
                say(.phase, "turnover on \(seat.dev)")
            case .reinbound(let seat):
                say(.phase, "\(seat.dev) re-inbounds, round holds")
            case .rebounded(let seat):
                say(.phase, "\(seat.dev) rebounds")
            case .shotClockTicked(let value):
                say(.phase, "clock \(value)")
            case .halftime:
                mark("halftime")
            case .gameEnded(let winners):
                mark("final · " + winners.map(\.dev).joined(separator: ", "))

            default:
                break
            }
        }
#endif
    }
}

private extension Seat {
    /// How the console names a seat: their place in turn order counting from the player,
    /// and who is sitting there — "Player 2 (John)".
    ///
    /// Numbered from the human rather than by the enum's own order, because that is the
    /// order play actually goes round in, and the one a screen recording can be followed
    /// against.
    var dev: String {
        let order = GameRules.localSeat.clockwiseOrderFromHere
        let place = (order.firstIndex(of: self) ?? rawValue) + 1
        return "Player \(place) (\(playerName))"
    }
}
