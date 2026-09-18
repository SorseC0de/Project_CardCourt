import Foundation

/// Client-side facts that are not part of a match's rules and never travel with it.
/// Everything that governs play lives in `MatchRules`, frozen into the state.
enum GameRules {
    /// Which seat this device is playing. A constant in a solo game and set from the
    /// match once there are other people at the table — every device believes a different
    /// answer, which is what lets each of them draw themselves at the near edge.
    static var localSeat: Seat = .south

    /// Whether a phase or event announces itself across the screen before it happens.
    /// One switch, because four cards a possession is a lot of card.
    static let announcesPhases = true

    /// How long a played card is held in the middle of the screen.
    static let playedCardSeconds = 2.5

    /// Forces the opening inbound to a seat instead of rolling for it. nil plays normally.
    /// Point it at whoever is being tested.
    static let debugFirstInbounder: Seat? = .south

    /// **Who a referee throws it in to at the top of a round.** The rule is a random
    /// player; while the game is being developed it is always the local seat, so the
    /// player being tested gets the ball. nil plays the rule.
    static let debugRefereeInboundsTo: Seat? = .south
}
