import Foundation

/// Client-side facts that are not part of a match's rules and never travel with it.
/// Everything that governs play lives in `MatchRules`, frozen into the state.
enum GameRules {
    static let humanSeat: Seat = .south

    /// How long a played card is held in the middle of the screen.
    static let playedCardSeconds = 3.0

    /// Forces the opening inbound to a seat instead of rolling for it. nil plays normally.
    /// Point it at whoever is being tested.
    static let debugFirstInbounder: Seat? = .south
}
