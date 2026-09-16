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
    /// **A passive landing on somebody's board.** Named for what happens rather than for
    /// a play, because an Intangible is never played: it is turned over in a draw and it
    /// activates itself. Raised where it lands, like `injuryDrawn`.
    case intangibleRevealed
    case anyNonWhistlePlayed
    /// Tile Tampering and Over-Varing Evidence: a floor or a ball being played.
    case varenaPlayed
    case variaballPlayed
    /// Extravagant Mechanics: the showy plays — a passive onto a board, a floor, a ball,
    /// or a Special Move.
    case slotOrSpecialPlayed
    case shotAttempt
    /// Any card that spends Shot Clock — Rhythm Dribble, Hesi.
    case shotClockLowered
    case whistleFired
    /// An Injury turning up in somebody's draw. Like a Game Break it is an event rather than
    /// a play — Cleared to Play is the sheet's own answer to one — so it is raised where the
    /// Injury lands, not by matching an action.
    case injuryDrawn
    /// A Game Break turning up in somebody's draw. The **second** exception to Breaks
    /// being events rather than plays, and for the same reason as `injuryDrawn`: Play-On
    /// is the sheet's own answer to one, and a Break is not something anybody activated,
    /// so it is raised where the card lands rather than matched against an action.
    /// Any *other* Whistle actually firing — not one being set down. Inadvertent Whistle
    /// is the referee blowing over the top of another call, so it cannot be matched
    /// against a `PendingAction` the way the rest are; see `Rules.blow`.
    case gameBreakDrawn
    /// **A card reaching a hand.** The third exception to Breaks and draws being events
    /// rather than plays, and the loudest: Discontinued Dribble is called on the draw
    /// itself, so it is raised where the card lands rather than matched against an
    /// action — and it is the one thing that cuts a draw chain short. See `Rules.draw`.
    case cardDrawn

    func matches(_ action: PendingAction) -> Bool {
        // Never intercepts a play. It waits for another Whistle instead.
        if self == .whistleFired || self == .injuryDrawn
            || self == .gameBreakDrawn || self == .cardDrawn { return false }
        switch (self, action) {
        case (.shotAttempt, .shoot):
            return true
        case (.passPlayed, .playCard(_, let card)):
            return card.descriptor.isPass
        case (.movePlayed, .playCard(_, let card)):
            return card.descriptor.isMove
        case (.dribblePlayed, .playCard(_, let card)):
            return card.descriptor.isDribble
        case (.clampPlayed, .playCard(_, let card)):
            return card.descriptor.type == .clamp
        case (.whistlePlayed, .playCard(_, let card)):
            return card.descriptor.type == .whistle
        case (.anyNonWhistlePlayed, .playCard(_, let card)):
            return card.descriptor.type != .whistle
        case (.varenaPlayed, .playCard(_, let card)):
            return card.descriptor.varena != nil
        case (.variaballPlayed, .playCard(_, let card)):
            return card.descriptor.variaball != nil
        case (.slotOrSpecialPlayed, .playCard(_, let card)):
            let type = card.descriptor.type
            return type == .intangible || type == .specialMove
                || card.descriptor.varena != nil || card.descriptor.variaball != nil
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
    /// Crew Chief Review: the pass is waved off and the ball is handed to whoever called
    /// it. Not a steal and not an inbound — the review simply gives them the ball.
    var takesBall = false

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
    /// Whether the card that tripped it is cancelled.
    ///
    /// Nearly always. Shot Clock Violation is the exception: lowering the clock past the
    /// buzzer is not a card being disallowed, it is a violation — the card does what it
    /// said and the ball goes out.
    var cancelsCard = true
    /// Charge: the ball goes back in by the player who was called, with no turnover.
    var offenderInbounds = false
    /// **Ends the possession where it stands.** Discontinued Dribble: the dribble is
    /// over, whatever was still owed. Everything the draw had queued is thrown away —
    /// those cards were being drawn for a possession that no longer exists.
    var endsPossession = false
    /// Timeout: the Whistle's owner takes the ball and puts it back in play.
    var ownerInbounds = false
    var setterChoosesInbound = false
    var endsRound = false
    var pointsToVictim = 0
    /// Trips to the line for the Whistle's owner.
    var freeThrowsToVictim = 0
    /// And for the player who tripped it. **A Clear Path Foul is called *for* the man who
    /// was fouled**, and he is the one shooting — so unlike every other Whistle here, the
    /// offender is the beneficiary.
    var freeThrowsToOffender = 0
    /// Cancels the Clamps that were reducing the shooter's SHOT, and pays them what the
    /// shot they were taking was worth.
    var clearsShotDebuffClamps = false
    var awardsShotValueToOffender = false
    /// Only fires when the man shooting is actually being held down. A Whistle with a
    /// condition rather than only a trigger — see `Rules.interceptor`.
    var requiresShotDebuffClamp = false
    /// **Tighter officiating.** The speed limit is a core rule now — see
    /// `MatchRules.movesPerPossession` — and a referee watching for Traveling does not
    /// bring it, he lowers it: one fewer Move a possession for as long as he is working.
    var lowersMoveLimit = 0
    /// **Which finish the crew is watching.** A call on dunks says nothing about a layup.
    /// This is the half of the matrix a Clamp forces a player into.
    var requiresShotType: ShotType?
    /// The shot still counts, for one point fewer. Foot On The Line does not wave a three
    /// off; it says it was never a three.
    var downgradesThree = false
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
    /// **Nil for a member of the crew**, which is every official on the floor now that
    /// Whistles are dealt face-up from their own deck rather than set down by a player.
    /// Anything a Whistle pays *its owner* is simply not paid when nobody set it.
    let owner: Seat?
    let card: Card
    /// Policeum: called, and still standing on the floor.
    var stayed = false

    init(owner: Seat?, card: Card, id: UUID = UUID()) {
        self.id = id
        self.owner = owner
        self.card = card
    }

    var trigger: WhistleTrigger? { card.descriptor.whistle?.trigger }
}
