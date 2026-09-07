import Observation
import SwiftUI

/// How each seat looks beyond their uniform.
///
/// **Everything here is either built or rolled, and both travel.** A person wears what
/// they made on the My Hooper screen, which reaches the other devices on the table — see
/// `Table.Look`. Everybody else on the court is rolled: the seats nobody is sitting in,
/// the man who comes out to guard, the referee a Whistle called. Those are rolled from
/// `crew`, one number the host hands round, so two people in the same match are watching
/// the same men rather than each device inventing its own.
///
/// Nothing in here is read by the rules. It is drawn and nothing else.
@Observable
final class PlayerLook {
    static let shared = PlayerLook()

    /// The roll every device at this table shares.
    ///
    /// Set from the host's `seated`; rolled here for a solo game, where there is nobody
    /// to agree with. Everything below is derived from it rather than stored, so two
    /// devices holding the same number draw the same court without exchanging another
    /// word about it.
    /// **Held by `Table`**, which is where everything else that travels in `.seated`
    /// already lives — and which the engine can name without importing SwiftUI.
    var crew: UInt64 { Table.shared.crew }

    /// A number both devices reach for the same thing.
    ///
    /// **Not `hashValue`.** Swift seeds its hasher per process, so two phones hashing the
    /// same seat get two different answers — which is most of how the two screens ended
    /// up with different men on them.
    private func roll(_ key: UInt64, upTo count: Int) -> Int {
        guard count > 0 else { return 0 }
        var rng = SeededRNG(seed: crew &* 0x9E37_79B9 &+ key)
        return Int(rng.next() % UInt64(count))
    }

    /// What a seat built for itself, when somebody built it. Nil is the house.
    private func look(_ seat: Seat) -> Table.Look? { Table.shared.chairs[seat]?.look }

    func tone(for seat: Seat) -> Int {
        if seat.isLocal { return HooperKit.shared.tone }
        if let look = look(seat) { return look.tone }
        return roll(0x70_4E &+ UInt64(seat.rawValue), upTo: PixelPalette.skinTones.count)
    }

    /// What a seat wears, skin and all.
    ///
    /// Your own chair is whatever you built on the My Hooper screen, and so is anybody
    /// else's who built one — their strip crosses with the table. A chair the house is
    /// playing wears the seat's colours, which is what tells the four of them apart when
    /// they are not people. One question, asked in one place, so a figure cannot come out
    /// in the kit and the wrong skin.
    func kit(for seat: Seat) -> [PaletteSwap] {
        if seat.isLocal, !Table.shared.isBot(seat) { return HooperKit.shared.swaps }
        if let look = look(seat) {
            // His strip and his trim as he left them; the skin is what changes.
            return PixelPalette.kit(Kit.colours[safe: look.jersey] ?? Kit.colours[0])
                + PixelPalette.trim(Kit.colours[safe: look.belt] ?? Kit.colours[0])
                + skin(for: seat)
        }
        return PixelPalette.uniform(for: seat) + skin(for: seat)
    }

    /// What a seat's skin is drawn with.
    ///
    /// **A man the house took over goes grey.** Everything else about him is where he left
    /// it — his strip, his number, his face — and the metal is the one thing that says
    /// nobody is home. Asked in one place so a head drawn on its own and a body on the
    /// floor cannot disagree about it.
    func skin(for seat: Seat) -> [PaletteSwap] {
        Table.shared.isBot(seat) ? PixelPalette.metalSkin
                                 : PixelPalette.skin(tone: tone(for: seat))
    }

    /// A built man, dressed. The one place a `Look` turns into pixels — `HooperKit` goes
    /// through here for its own, so the man you are building and the man they see are
    /// assembled by the same line.
    static func swaps(of look: Table.Look) -> [PaletteSwap] {
        PixelPalette.kit(Kit.colours[safe: look.jersey] ?? Kit.colours[0])
            + PixelPalette.trim(Kit.colours[safe: look.belt] ?? Kit.colours[0])
            + PixelPalette.skin(tone: look.tone)
    }

    /// How this seat stands while waiting for a throw-in: one of the sheet's poses, with
    /// the last also offered mirrored.
    ///
    /// **Cell nought is not among them.** It is the deprecated pose the sheet keeps for
    /// the sake of its own numbering, and a player standing in it looks like a player the
    /// artist has moved on from.
    ///
    /// Fixed per seat, so nobody changes stance while the thrower is deciding.
    func waiting(for seat: Seat) -> (cell: Int, mirrored: Bool) {
        let rolled = roll(0x57_41 &+ UInt64(seat.rawValue), upTo: 3)
        return (cell: rolled == 0 ? 1 : 2, mirrored: rolled == 2)
    }

    /// The skin of whoever is guarding this seat.
    ///
    /// Fixed per seat, so a defender who arrives twice in a possession is the same man
    /// twice rather than two strangers. Deliberately not the clamped player's own tone —
    /// he is somebody else.
    func defenderTone(for seat: Seat) -> Int {
        roll(0x44_45 &+ UInt64(seat.rawValue), upTo: PixelPalette.skinTones.count)
    }

    /// The skin of the referee a Whistle called out.
    ///
    /// Keyed on the Whistle rather than on where he is standing: the crew shuffles as
    /// Whistles come and go, and a referee who changes colour because somebody else's
    /// call ended is two men rather than one. The id is the same one on every device, so
    /// so is the man.
    func refereeTone(for whistle: UUID) -> Int {
        roll(0x52_45 &+ PlayerLook.fold(whistle), upTo: PixelPalette.skinTones.count)
    }

    /// Which head this seat wears. Yours is the one you built, and so is theirs; the
    /// house is rolled off the crew.
    func face(for seat: Seat) -> Int {
        if seat.isLocal { return HooperKit.shared.face }
        if let look = look(seat) { return look.face }
        return roll(0x46_41 &+ UInt64(seat.rawValue), upTo: Sprite.heads.frames)
    }

    /// The number on this man's back. Yours is the one you chose, theirs comes with the
    /// table, and the house is rolled off the crew like everything else about it.
    func number(for seat: Seat) -> Int {
        if seat.isLocal { return HooperKit.shared.number }
        if let look = look(seat) { return look.number }
        return roll(0x4E_4F &+ UInt64(seat.rawValue), upTo: Kit.numbers.count)
    }

    /// What this seat's number reads as, on his back and anywhere else.
    func numberText(for seat: Seat) -> String {
        Kit.numbers[safe: number(for: seat)] ?? "0"
    }

    /// The kit's second colour, which is what a number is set in — one in the shirt's own
    /// colour is one nobody can read.
    func trim(for seat: Seat) -> Color {
        if seat.isLocal, !Table.shared.isBot(seat) {
            return (Kit.colours[safe: HooperKit.shared.belt] ?? Kit.colours[0]).main
        }
        if let look = look(seat) {
            return (Kit.colours[safe: look.belt] ?? Kit.colours[0]).main
        }
        return .white
    }

    /// Everything a sheet needs to wear this seat's face — see `SpriteAnimation.face`.
    func faceOn(_ seat: Seat) -> SpriteFace {
        SpriteFace(index: face(for: seat), tone: tone(for: seat),
                   number: numberText(for: seat), numberInk: trim(for: seat))
    }

    /// **How a name is written wherever there is room for the whole of it**: the number,
    /// then the man. A squad list reads this way and so does the back of a shirt.
    func billing(for seat: Seat) -> String {
        "#\(Kit.numbers[safe: number(for: seat)] ?? "0") \(seat.playerName)"
    }

    /// The main colour of a seat's kit, for anything that wants the table's own palette
    /// rather than the UI's — see `SideStreaks`.
    func jersey(for seat: Seat) -> Color {
        if seat.isLocal {
            return (Kit.colours[safe: HooperKit.shared.jersey] ?? Kit.colours[0]).main
        }
        if let look = look(seat) {
            return (Kit.colours[safe: look.jersey] ?? Kit.colours[0]).main
        }
        switch seat {
        case .north: return PixelPalette.gold
        case .east:  return PixelPalette.green
        case .west:  return PixelPalette.rose
        case .south: return PixelPalette.blue
        }
    }

    /// A UUID as one number, the same one everywhere. `hashValue` is no use for this —
    /// see `roll`.
    private static func fold(_ id: UUID) -> UInt64 {
        withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1) }
        }
    }
}
