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

    /// The roll that decides how everybody nobody is playing looks.
    ///
    /// Set from the host's `.seated`; rolled here for a solo game, where there is nobody
    /// to agree with. Everything about the house seats, the defenders and the referees is
    /// derived from it rather than stored, so two devices holding the same number draw
    /// the same court without exchanging another word about it — see `PlayerLook`.
    ///
    /// **Here rather than on `PlayerLook`**, which is a view-layer object full of colours
    /// and palette swaps. This is one integer that crosses the wire, and the engine has
    /// to be able to set it without reaching into the art.
    private(set) var crew: UInt64 = UInt64.random(in: 1...9_999_999)

    /// The host has said what the crew is. Whatever was rolled before this arrived was
    /// this device's own guess.
    func setCrew(_ seed: UInt64) {
        guard seed != crew else { return }
        crew = seed
    }

    /// Fresh opponents for a fresh game. The human keeps whatever they have chosen.
    ///
    /// **A solo game only.** In a match the roll comes off the wire, and rolling again
    /// here would be this device deciding for itself what the table looks like.
    func randomiseTheCrew() {
        guard remotes.isEmpty else { return }
        crew = UInt64.random(in: 1...9_999_999)
    }

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
        /// What he called himself. **Not the Game Center name**: the account is who you
        /// are to Apple, and this is who you are on the court — and it is the one a player
        /// spent time choosing, so it is the one everybody should see.
        var name: String = ""
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

    /// Somebody dropped, and the house plays out their seat.
    ///
    /// **The man stays.** His hand, his turn, his strip and his face are all where he left
    /// them — what changes is that nobody is choosing for him any more. So the look is
    /// kept and his name is marked, and `PlayerLook` draws a kept look on a computer chair
    /// in metal. A seat that emptied and came back as a stranger would read as a different
    /// game rather than as the same one carrying on.
    func replaceWithComputer(at seat: Seat) {
        let was = chairs[seat]
        let name = was?.name ?? seat.houseName
        chairs[seat] = Chair(occupant: .computer,
                             name: name.hasSuffix(Table.botSuffix) ? name
                                 : name + Table.botSuffix,
                             look: was?.look)
    }

    /// What is put on the end of a name the house has taken over.
    static let botSuffix = "_bot"

    /// True when this chair is a player the house is finishing for — a look nobody is
    /// choosing with any more.
    func isBot(_ seat: Seat) -> Bool {
        occupant(at: seat) == .computer && chairs[seat]?.look != nil
    }

    /// What somebody at the table built. Arrives after the seating, since a device has to
    /// be asked before it can say.
    func setLook(_ look: Look, at seat: Seat) {
        chairs[seat]?.look = look
        // The name he chose beats the name Apple has for him — see `Look.name`. Blank
        // means he never set one, and then the account's name is the best there is.
        if !look.name.isEmpty { chairs[seat]?.name = look.name }
    }

    /// What this device's own player looks like.
    ///
    /// **Recorded on the table like everybody else's.** It was read straight off
    /// `HooperKit` at the moment of sending, which is a view-layer singleton the engine
    /// had to import the art to reach — and it meant the local look was only ever written
    /// to the table by `GameCenterMatch.readAsGuest`, so on a loopback this device was the
    /// one player at the table nobody had a look for. `RootView` sets it once at join.
    var myLook: Look {
        chairs[GameRules.localSeat]?.look ?? mine ?? Look(tone: 0, face: 0, jersey: 0, belt: 0)
    }

    /// What this device said about itself, kept even before it has a chair.
    private(set) var mine: Look?

    /// This device's own player, as built on the My Hooper screen.
    func setMyLook(_ look: Look) {
        mine = look
        setLook(look, at: GameRules.localSeat)
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
