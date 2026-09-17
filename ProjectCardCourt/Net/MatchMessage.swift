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
    /// Which answer is being spent, or nil for none. **Which and not whether** — a hand
    /// can hold more than one card that answers the same arrival.
    case counter(UUID?)
    case option(Bool)
    /// Which official is being sent off, or nil for none.
    case official(UUID?)
    case cardFrom(UUID)
    case mode(Int)
}

enum ClientMessage: Codable {
    /// Sent once the client is on screen and ready to be dealt to, carrying the man this
    /// player built. It is the one thing about a client the host takes at its word —
    /// nothing reads it but the sprites.
    case ready(Table.Look)
    case move(Move)
    /// The cards fed into a rebound bid.
    case reboundBid([UUID])
    /// Turnaround Three: the cards fed into the shot.
    case discardForShot([UUID])
    /// The toll, paid by hand — cards given up to an injury rather than to a shot.
    ///
    /// **Its own case, though the host drains both the same way.** It went as
    /// `.discardForShot`, whose handler guards on `.awaitingDiscard`; a give-up is only
    /// ever reachable from `.awaitingGiveUp`, so the host dropped it in silence while its
    /// own loop sat on the inbox waiting for it. With no action clock that wait never
    /// returns — a guest paying a Bone Bruise hung the whole table, for good.
    case giveUp([UUID])
    /// **A guest saying it has stopped agreeing.**
    ///
    /// Only a guest can notice: it is the one holding both fingerprints. But the host is
    /// the device somebody has attached to Xcode — it is the one running the game — so a
    /// report that only ever printed on the other phone was a report nobody read. Sent as
    /// formatted text rather than as fields: nothing acts on it, it is for a person.
    case parted(report: String)
    /// Everything else the game stops to ask for. See `Decision`.
    case decision(Decision)
    /// The free-throw mini-game's own result. The trip it belongs to is in the phase, so
    /// a stale result cannot be applied to a later one.
    case freeThrow(made: Bool)
}

/// What the host sends back to a player's device.
enum HostMessage: Codable {
    /// Where you are sitting, who else is at the table, and the roll that decides how
    /// everybody nobody is playing looks. Sent when the table is seated, and again
    /// whenever somebody's own look arrives.
    ///
    /// `crew` is the appearance seed, and it travels for the same reason the chairs do:
    /// the house seats, the men who come out to guard, and the referees were all rolled
    /// with `Int.random` on each device, so the same defender was two different people on
    /// the two screens. One number, and every device rolls the same crew.
    case seated(seat: Seat, chairs: [Seat: Table.Chair], crew: UInt64)
    /// The game as this player is allowed to see it, and what just happened to get there.
    ///
    /// State and events travel together on purpose: the state is what the court draws
    /// from and the events are the story of how it got there, and a client that had one
    /// without the other would either narrate a game it cannot see or show a board that
    /// changed for no stated reason.
    ///
    /// `digest` is the host's rolling fingerprint of every batch it has sent — see
    /// `Digest`. The guest folds the same events into its own and compares: the states
    /// cannot be diffed because they are redacted differently, but the events cannot.
    ///
    /// `shape` is the batch's event kinds in order, and it is what makes a desync
    /// *readable*. The digest says two devices stopped agreeing; without this, finding out
    /// about what meant playing the round again and watching harder.
    case turn(state: GameState, events: [GameEvent], digest: Digest, shape: [String])
    /// **The board as it stands, with no story attached.** Sent to a guest that arrived
    /// late or re-announced itself, to catch it up.
    ///
    /// A separate case from `.turn` because it is *not a batch*, and the difference is
    /// load-bearing. It used to be sent as `.turn` with no events — which the host never
    /// folded, since nothing had happened, while the guest folded it unconditionally.
    /// `Digest.fold` counts a batch and hashes the two bytes of an empty array, so the
    /// guest came out one batch ahead with a different value and reported a desync that
    /// had not happened — permanently, and on nearly every match, because a guest
    /// re-announces every 500ms until it is dealt. A snapshot carries the host's
    /// fingerprint to be **adopted**, not folded.
    case board(state: GameState, digest: Digest)
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
