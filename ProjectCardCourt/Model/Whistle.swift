import Foundation

/// What a Whistle is waiting for. Transcribed from the Whistle rows of the card sheet.
///
/// Every trigger watches a card the player *activated*. A Game Break is a game event —
/// it fires off the top of the deck and nobody chose to play it — so no Whistle can ever
/// be called on one. That falls out of `PendingAction.playCard` never carrying a Break,
/// and it is intended rather than incidental.
enum WhistleTrigger: String, Hashable, Codable {
    case passPlayed
    case movePlayed
    case dribblePlayed
    case clampPlayed
    case whistlePlayed
    case intangiblePlayed
    case anyNonWhistlePlayed
    case shotAttempt
    /// Any card that spends Shot Clock — Rhythm Dribble, Hesi.
    case shotClockLowered

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
        case (.shotClockLowered, .playCard(_, let card)):
            return card.descriptor.clockDelta < 0
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
    /// Flagrant Foul II. Everything they are holding.
    var offenderDiscardsBag = false
    /// Official Review. Dormant until Intangibles exist.
    var stripsIntangibles = false

    // Where the ball goes. A turnover re-inbounds by the offender unless one of these
    // says otherwise, and a re-inbound never advances the round.
    /// Negates the effect rather than the activation.
    ///
    /// The Clamp card is played, resolves, and takes its place in the pending pile as
    /// normal. This fires later, when a possession opening would hand those defenders
    /// out — which is the first moment anyone knows who the clamped player is, and so
    /// the first moment a card can say "the clamped player" and mean something.
    var voidsClampOnLanding = false
    /// For the player those defenders were about to land on.
    var freeThrowsToClampVictim = 0
    /// They keep what they were about to lose instead of the offender handing it back in.
    var victimKeepsBall = false
    /// Charge: the ball goes back in by the player who was called, with no turnover.
    var offenderInbounds = false
    var setterChoosesInbound = false
    var endsRound = false
    var pointsToVictim = 0
    /// Trips to the line for the Whistle's owner.
    var freeThrowsToVictim = 0
    /// Delay-of-Game: the first call is a warning, the second is a foul.
    var freeThrowsOnRepeatCall = 0
    /// The cancelled card still spends the Shot Clock it was going to spend. Delay-of-Game
    /// stops the card doing anything; it does not give the time back.
    var keepsClockCost = false
    /// Stays on the floor after it fires instead of being spent. Only for Whistles that
    /// are meant to be called more than once.
    var staysArmed = false

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
