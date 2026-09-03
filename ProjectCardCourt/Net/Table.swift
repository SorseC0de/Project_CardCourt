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

    struct Chair: Hashable, Codable {
        var occupant: Occupant
        var name: String
    }

    private(set) var chairs: [Seat: Chair] = Table.solo()

    /// Back to one person against three opponents.
    func seatSolo() {
        GameRules.localSeat = .south
        chairs = Table.solo()
    }

    /// Seats a match. The local player is told which chair is theirs, and everything else
    /// follows from that — the court draws itself from `GameRules.localSeat`.
    func seat(_ chairs: [Seat: Chair], asLocal seat: Seat) {
        GameRules.localSeat = seat
        self.chairs = chairs
    }

    /// Somebody dropped. The house plays out their seat.
    func replaceWithComputer(at seat: Seat) {
        chairs[seat] = Chair(occupant: .computer, name: chairs[seat]?.name ?? seat.houseName)
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
