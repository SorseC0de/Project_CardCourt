import Observation

/// Who is in each seat, and what to call them.
///
/// A solo game seats the local player and three house names with an AI behind each. A
/// match seats whoever Game Center found, and fills any empty chair with an AI so a
/// three-handed game is still a game.
///
/// Nothing in `Rules` knows this exists. The rules deal with seats; this is only ever
/// asked *who* is in one, never what they should do — which is what keeps a match and a
/// solo game the same game.
@Observable
final class Table {
    static let shared = Table()

    enum Occupant: Hashable, Codable {
        /// The person holding this device.
        case local
        /// Somebody else's device. Their moves arrive over the wire.
        case remote(playerID: String)
        case computer
    }

    /// What a person built for themselves on the My Hooper screen, small enough to
    /// travel with the table.
    ///
    /// **The one thing about a player that is not in the rules and still has to cross.**
    /// It was client-side on the grounds that nothing about the game reads it — true, and
    /// beside the point: two people in the same match were looking at two different sets
    /// of men, each device rolling its own opponents and drawing the other player in the
    /// seat's colours rather than the strip they chose.
    struct Look: Hashable, Codable {
        /// Index into `PixelPalette.skinTones`.
        var tone: Int
        /// Which head off `Player_heads`.
        var face: Int
        /// Indices into `Kit.colours`.
        var jersey: Int
        var belt: Int
        /// Index into `Kit.numbers` — 0 is "00" and the rest are 0 through 99. It is on
        /// his back and in front of his name, so it travels with the rest of him.
        var number: Int = 1
    }

    struct Chair: Hashable, Codable {
        var occupant: Occupant
        var name: String
        /// How they look. **Nil is the house** — a chair nobody built wears the seat's
        /// own colours, which is what tells the four apart when they are not people.
        var look: Look?
    }

    private(set) var chairs: [Seat: Chair] = Table.solo()

    /// Back to one person against three opponents.
    func seatSolo() {
        GameRules.localSeat = .south
        chairs = Table.solo()
    }

    /// Seats a match. The local player is told which chair is theirs, and everything else
    /// follows from that — the court draws itself from `GameRules.localSeat`.
    ///
    /// **Whose chair is whose depends on who is reading.** One record of the table travels
    /// to everybody, so on the wire every person is a `remote` named by id and each device
    /// promotes its own chair on arrival. Sent as it stands, the host's chair reached the
    /// guest still marked `local`: the guest's own seat came out remote, so it counted
    /// itself among the other devices and the lobby put "You" on the host's chair.
    func seat(_ chairs: [Seat: Chair], asLocal seat: Seat) {
        GameRules.localSeat = seat
        var mine = chairs
        mine[seat]?.occupant = .local
        self.chairs = mine
    }

    /// Somebody dropped. The house plays out their seat, in the house's colours — the
    /// man who built that strip has gone.
    func replaceWithComputer(at seat: Seat) {
        chairs[seat] = Chair(occupant: .computer, name: chairs[seat]?.name ?? seat.houseName)
    }

    /// What somebody at the table built. Arrives after the seating, since a device has to
    /// be asked before it can say.
    func setLook(_ look: Look, at seat: Seat) {
        chairs[seat]?.look = look
    }

    func name(at seat: Seat) -> String {
        chairs[seat]?.name ?? seat.houseName
    }

    func occupant(at seat: Seat) -> Occupant {
        chairs[seat]?.occupant ?? .computer
    }

    /// True when this seat's decisions arrive over the wire rather than being made here.
    func isRemote(_ seat: Seat) -> Bool {
        if case .remote = occupant(at: seat) { return true }
        return false
    }

    /// Every seat somebody else is sitting in.
    var remotes: [Seat] { Seat.allCases.filter { isRemote($0) } }

    private static func solo() -> [Seat: Chair] {
        Dictionary(uniqueKeysWithValues: Seat.allCases.map { seat in
            (seat, Chair(occupant: seat == .south ? .local : .computer,
                         name: seat.houseName))
        })
    }
}
