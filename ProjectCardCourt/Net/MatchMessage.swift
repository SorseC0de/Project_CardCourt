import Foundation

/// What a player's device sends to the host.
///
/// Only ever a decision. A client never asserts state, never says what a move did, and is
/// never believed about anything but what its own player chose — the host owns the game
/// and re-derives every consequence itself. That is what makes a modified client a player
/// who can make illegal choices and have them refused, rather than one who can rewrite
/// the score.
/// An answer to whatever the game stopped to ask.
///
/// **One case rather than eight.** The host already knows what the question was — the
/// phase says so — so a client that answers a question nobody asked is refused on that
/// rather than on which message it reached for. It also means a new prompt needs a case
/// here and nothing else: the alternative was eight more `ClientMessage`s, and the eight
/// that were missing are exactly why a guest answering a prompt went off on its own.
enum Decision: Codable {
    case target(Seat)
    case naming(Seat?)
    case toll(CardPick?)
    case dropping(String)
    case injury(String)
    case counter(Bool)
    case cardFrom(UUID)
    case mode(Int)
}

enum ClientMessage: Codable {
    /// Sent once the client is on screen and ready to be dealt to.
    case ready
    case move(Move)
    /// The cards fed into a rebound bid.
    case reboundBid([UUID])
    /// Turnaround Three: the cards fed into the shot.
    case discardForShot([UUID])
    /// Everything else the game stops to ask for. See `Decision`.
    case decision(Decision)
    /// The free-throw mini-game's own result. The trip it belongs to is in the phase, so
    /// a stale result cannot be applied to a later one.
    case freeThrow(made: Bool)
}

/// What the host sends back to a player's device.
enum HostMessage: Codable {
    /// Where you are sitting, and who else is at the table. Sent once, before play.
    case seated(seat: Seat, chairs: [Seat: Table.Chair])
    /// The game as this player is allowed to see it, and what just happened to get there.
    ///
    /// State and events travel together on purpose: the state is what the court draws
    /// from and the events are the story of how it got there, and a client that had one
    /// without the other would either narrate a game it cannot see or show a board that
    /// changed for no stated reason.
    case turn(state: GameState, events: [GameEvent])
    /// The host has started the game. Until this arrives a guest sits in the lobby
    /// watching the chairs fill.
    case start
}

/// The only place the wire format is decided.
///
/// JSON rather than a property list: it is the format the model already round-trips
/// through in the tests, and a match is a handful of messages a second — nowhere near
/// enough for the size difference to matter.
enum MatchCoder {
    static func encode(_ message: some Encodable) throws -> Data {
        try JSONEncoder().encode(message)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
