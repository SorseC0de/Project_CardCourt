import Observation

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

    func tone(for seat: Seat) -> Int {
        tones[seat] ?? PixelPalette.drawnSkinTone
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
