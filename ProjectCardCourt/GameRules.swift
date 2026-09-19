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

    /// **Who the ball goes to first.** In a debug build, always the local seat, so the
    /// player being tested has it; in a release build, nobody — the rules roll for it.
    /// Either way the rotation runs clockwise from there, round by round.
    #if DEBUG || HARNESS
    static let debugFirstInbounder: Seat? = .south
    #else
    static let debugFirstInbounder: Seat? = nil
    #endif
}
