import Foundation

/// What a Whistle is waiting for. Transcribed from the Whistle rows of the card sheet.
enum WhistleTrigger: String, Hashable, Codable {
    case passPlayed
    case movePlayed
    case dribblePlayed
    case clampPlayed
    case whistlePlayed
    case intangiblePlayed
    case anyNonWhistlePlayed
    case shotAttempt
    case turnStart

    func matches(_ action: PendingAction) -> Bool {
        switch (self, action) {
        case (.shotAttempt, .shoot):
            return true
        case (.passPlayed, .playCard(_, let card)):
            return card.descriptor.isPass
        case (.movePlayed, .playCard(_, let card)):
            return card.descriptor.type == .move
        case (.dribblePlayed, .playCard(_, let card)):
            return card.descriptor.isDribble
        case (.clampPlayed, .playCard(_, let card)):
            return card.descriptor.type == .clamp
        case (.whistlePlayed, .playCard(_, let card)):
            return card.descriptor.type == .whistle
        case (.intangiblePlayed, .playCard(_, let card)):
            return card.descriptor.type == .intangible
        case (.anyNonWhistlePlayed, .playCard(_, let card)):
            return card.descriptor.type != .whistle
        default:
            return false
        }
    }
}

/// What a Whistle does when it blows. A nil `trigger` means the card resolves the moment
/// it is played instead of lying in wait — Timeout works that way.
struct WhistleEffect: Hashable, Codable {
    var trigger: WhistleTrigger?

    // On the player who tripped it.
    var turnoverOnOffender = false
    var offenderDiscards = 0
    var offenderDraws = 0
    /// Official Review. Dormant until Intangibles exist.
    var stripsIntangibles = false

    // Where the ball goes. A turnover re-inbounds by the offender unless one of these
    // says otherwise, and a re-inbound never advances the round.
    var setterChoosesInbound = false
    var endsRound = false
    var pointsToVictim = 0

    // Immediate whistles.
    var resetsShotClock = false
    var everyoneDraws = 0
    /// Coach's Challenge, which fishes a Timeout back out of the pile.
    var recoversTimeout = false
}

/// A move that has been declared but not yet resolved. This is the thing a Whistle
/// inspects, and the reason `Rules.apply` proposes before it commits.
enum PendingAction: Hashable {
    case inbound(from: Seat, to: Seat)
    case playCard(seat: Seat, card: Card)
    case shoot(seat: Seat)

    var actor: Seat {
        switch self {
        case .inbound(let from, _): return from
        case .playCard(let seat, _): return seat
        case .shoot(let seat): return seat
        }
    }
}

/// A Whistle set down and waiting on its condition. Hidden from other players in the
/// log — arming must emit nothing public.
struct ArmedWhistle: Hashable, Codable, Identifiable {
    let id: UUID
    let owner: Seat
    let card: Card

    init(owner: Seat, card: Card, id: UUID = UUID()) {
        self.id = id
        self.owner = owner
        self.card = card
    }

    var trigger: WhistleTrigger? { card.descriptor.whistle?.trigger }
}
