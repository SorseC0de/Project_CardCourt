import Observation
import SwiftUI

/// How each seat looks beyond their uniform.
///
/// Client-side only: appearance never travels with a match, so two people watching the
/// same multiplayer game may see different opponents and nothing about the rules cares.
///
/// Opponents are rolled at the start of a match. It is written as a per-seat setter
/// rather than a shuffle because the intent is a picker — the player choosing their own
/// tone, and eventually an archetype bringing its own — so the roll is just the default
/// nobody has overridden yet.
@Observable
final class PlayerLook {
    static let shared = PlayerLook()

    private var tones: [Seat: Int] = [:]

    private var defenderTones: [Seat: Int] = [:]
    private var faces: [Seat: Int] = [:]
    private var waits: [Seat: (cell: Int, mirrored: Bool)] = [:]

    func tone(for seat: Seat) -> Int {
        if seat.isLocal { return HooperKit.shared.tone }
        return tones[seat] ?? PixelPalette.drawnSkinTone
    }

    /// What a seat wears, skin and all.
    ///
    /// Your own chair is whatever you built on the My Hooper screen; everybody else wears
    /// the seat's colours and a rolled tone. One question, asked in one place, so a
    /// figure cannot come out in the kit and the wrong skin.
    func kit(for seat: Seat) -> [PaletteSwap] {
        guard seat.isLocal else {
            return PixelPalette.uniform(for: seat) + PixelPalette.skin(tone: tone(for: seat))
        }
        return HooperKit.shared.swaps
    }

    /// How this seat stands while waiting for a throw-in: one of the sheet's poses, with
    /// the last also offered mirrored.
    ///
    /// **Cell nought is not among them.** It is the deprecated pose the sheet keeps for
    /// the sake of its own numbering, and a player standing in it looks like a player the
    /// artist has moved on from.
    ///
    /// Rolled once per seat and kept, so nobody changes stance while the thrower is
    /// deciding.
    func waiting(for seat: Seat) -> (cell: Int, mirrored: Bool) {
        if let known = waits[seat] { return known }
        let rolled = Int.random(in: 0..<3)
        let look = (cell: rolled == 0 ? 1 : 2, mirrored: rolled == 2)
        waits[seat] = look
        return look
    }

    /// The skin of whoever is guarding this seat.
    ///
    /// Rolled once per seat and kept, so a defender who arrives twice in a possession is
    /// the same man twice rather than two strangers. Deliberately not the clamped
    /// player's own tone — he is somebody else.
    func defenderTone(for seat: Seat) -> Int {
        if let known = defenderTones[seat] { return known }
        let rolled = Int.random(in: 0..<PixelPalette.skinTones.count)
        defenderTones[seat] = rolled
        return rolled
    }

    /// Which head this seat wears. Yours is the one you built; everybody else is rolled
    /// once and kept, so a man does not change face between one basket and the next.
    func face(for seat: Seat) -> Int {
        if seat.isLocal { return HooperKit.shared.face }
        if let known = faces[seat] { return known }
        let rolled = Int.random(in: 0..<Sprite.heads.frames)
        faces[seat] = rolled
        return rolled
    }

    /// The main colour of a seat's kit, for anything that wants the table's own palette
    /// rather than the UI's — see `SideStreaks`.
    func jersey(for seat: Seat) -> Color {
        guard !seat.isLocal else {
            return (Kit.colours[safe: HooperKit.shared.jersey] ?? Kit.colours[0]).main
        }
        switch seat {
        case .north: return PixelPalette.gold
        case .east:  return PixelPalette.green
        case .west:  return PixelPalette.rose
        case .south: return PixelPalette.blue
        }
    }

    /// Set by the picker, once there is one.
    func setTone(_ tone: Int, for seat: Seat) {
        tones[seat] = tone
    }

    /// Fresh opponents for a fresh match. The human keeps whatever they have chosen.
    func randomiseOpponents(except seat: Seat) {
        for other in Seat.allCases where other != seat {
            tones[other] = Int.random(in: 0..<PixelPalette.skinTones.count)
        }
    }
}
