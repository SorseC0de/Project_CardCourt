import Foundation

/// A rolling fingerprint of everything a device has been told, in the order it was told.
///
/// **What two devices can compare, when their states are not comparable.** The host holds
/// the only complete game and sends each seat a redacted view of it, so the boards cannot
/// be diffed — one of them has a hand the other is only allowed to count. The *events*
/// cross whole, and the order they arrive in is the game itself, so a hash folded over
/// them says whether two devices are playing the same match however differently they are
/// allowed to see it.
///
/// A match says nothing. A mismatch names the batch where they parted, which is the one
/// thing a week of two-phones-side-by-side could never establish.
struct Digest: Codable, Hashable, CustomStringConvertible {
    /// FNV-1a over the encoded events, folded batch by batch.
    private(set) var value: UInt64 = 0xCBF2_9CE4_8422_2325
    /// How many batches have gone into it, so a divergence can be counted as well as seen.
    private(set) var batches = 0

    /// Short enough to read off a screen beside another phone.
    var description: String { String(format: "%04X/%d", UInt16(value & 0xFFFF), batches) }

    /// Folds one batch in. **Order matters and repetition matters**: the same events
    /// applied twice is a different game from applying them once, which is exactly the
    /// class of fault this is meant to catch.
    mutating func fold(_ events: [GameEvent]) {
        batches += 1
        guard let data = try? Digest.coder.encode(events) else { return }
        for byte in data {
            value = (value ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
    }

    /// **Sorted keys, or the hash is a coin toss.** Two devices encoding the same event
    /// must produce the same bytes, and dictionary order is not otherwise guaranteed.
    private static let coder: JSONEncoder = {
        let coder = JSONEncoder()
        coder.outputFormatting = [.sortedKeys]
        return coder
    }()
}
