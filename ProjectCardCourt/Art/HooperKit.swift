import Observation
import SwiftUI

/// Everything the player has chosen about the man they play as.
///
/// Client-side only, like `PlayerLook`: an appearance never travels with a match, and
/// nothing about the rules reads any of it. Kept in `UserDefaults` because it is the one
/// thing on this device that should outlive a game.
@Observable
final class HooperKit {
    static let shared = HooperKit()

    var name: String { didSet { save() } }
    /// Index into `Kit.numbers` — 0 is "00" and the rest are 0 through 99.
    var number: Int { didSet { save() } }
    /// Which head off `Player_heads`.
    var face: Int { didSet { save() } }
    /// Index into `PixelPalette.skinTones`.
    var tone: Int { didSet { save() } }
    /// Indices into `Kit.colours`.
    var jersey: Int { didSet { save() } }
    var belt: Int { didSet { save() } }
    var position: Kit.Position { didSet { save() } }
    /// A card off the pool they have actually met. Nil until they pick one.
    var favourite: String? { didSet { save() } }

    /// What the sprite wears, ready to hand to `paletteSwap`.
    var swaps: [PaletteSwap] {
        PixelPalette.kit(Kit.colours[safe: jersey] ?? Kit.colours[0])
            + PixelPalette.trim(Kit.colours[safe: belt] ?? Kit.colours[0])
            + PixelPalette.skin(tone: tone)
    }

    /// How the name reads wherever it is shown whole.
    var billing: String { "#\(Kit.numbers[safe: number] ?? "0") \(name)" }

    private init() {
        let store = UserDefaults.standard
        name = store.string(forKey: Key.name) ?? "You"
        number = store.object(forKey: Key.number) as? Int ?? 1
        face = store.object(forKey: Key.face) as? Int ?? 0
        tone = store.object(forKey: Key.tone) as? Int ?? PixelPalette.drawnSkinTone
        jersey = store.object(forKey: Key.jersey) as? Int ?? 0
        belt = store.object(forKey: Key.belt) as? Int ?? Kit.drawnTrim
        position = Kit.Position(rawValue: store.string(forKey: Key.position) ?? "")
            ?? .pointGuard
        favourite = store.string(forKey: Key.favourite)
    }

    private enum Key {
        static let name = "hooper.name"
        static let number = "hooper.number"
        static let face = "hooper.face"
        static let tone = "hooper.tone"
        static let jersey = "hooper.jersey"
        static let belt = "hooper.belt"
        static let position = "hooper.position"
        static let favourite = "hooper.favourite"
    }

    private func save() {
        let store = UserDefaults.standard
        store.set(name, forKey: Key.name)
        store.set(number, forKey: Key.number)
        store.set(face, forKey: Key.face)
        store.set(tone, forKey: Key.tone)
        store.set(jersey, forKey: Key.jersey)
        store.set(belt, forKey: Key.belt)
        store.set(position.rawValue, forKey: Key.position)
        store.set(favourite, forKey: Key.favourite)
    }
}

/// What there is to choose from.
enum Kit {
    /// A colour and the colour it is shaded with. Both come off the sprite palette rather
    /// than the card one — these are pixels in a 32-colour sheet, and a colour from
    /// outside it would be the one thing on the man that was not drawn.
    struct Pair: Hashable {
        let name: String
        let main: Color
        let shade: Color
    }

    /// Main tones only, each with the neighbour it is shaded by. Grey, black and white
    /// are in here as kit colours in their own right — a plain strip is a real strip.
    static let colours: [Pair] = [
        Pair(name: "Blue",   main: PixelPalette.blue,      shade: PixelPalette.indigo),
        Pair(name: "Gold",   main: PixelPalette.gold,      shade: PixelPalette.orange),
        Pair(name: "Orange", main: PixelPalette.orange,    shade: PixelPalette.darkOrange),
        Pair(name: "Red",    main: PixelPalette.vermilion, shade: PixelPalette.darkRed),
        Pair(name: "Green",  main: PixelPalette.green,     shade: PixelPalette.pine),
        Pair(name: "Lime",   main: PixelPalette.lime,      shade: PixelPalette.green),
        Pair(name: "Teal",   main: PixelPalette.azure,     shade: PixelPalette.deepTeal),
        Pair(name: "Rose",   main: PixelPalette.rose,      shade: PixelPalette.darkMagenta),
        Pair(name: "Violet", main: PixelPalette.lavender,  shade: PixelPalette.dusk),
        Pair(name: "White",  main: PixelPalette.ice,       shade: PixelPalette.slate),
        Pair(name: "Grey",   main: PixelPalette.stone,     shade: PixelPalette.steel),
        Pair(name: "Black",  main: PixelPalette.iron,      shade: PixelPalette.warmBlack),
    ]

    /// The pair the sheets are already drawn in, so the default belt swaps nothing.
    static let drawnTrim = 9

    /// "00" first, the way a squad list has it, then 0 through 99.
    static let numbers: [String] = ["00"] + (0...99).map(String.init)

    enum Position: String, CaseIterable, Identifiable {
        case pointGuard = "PG"
        case shootingGuard = "SG"
        case smallForward = "SF"
        case powerForward = "PF"
        case centre = "C"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pointGuard:     return "Point Guard"
            case .shootingGuard:  return "Shooting Guard"
            case .smallForward:   return "Small Forward"
            case .powerForward:   return "Power Forward"
            case .centre:         return "Centre"
            }
        }
    }

    /// The poses the sprite can be turned to, in the order they are offered.
    enum Pose: String, CaseIterable, Identifiable {
        case front, running, dribbling, receiving, shooting

        var id: String { rawValue }

        var title: String {
            switch self {
            case .front:     return "Front"
            case .running:   return "Run"
            case .dribbling: return "Dribble"
            case .receiving: return "Catch"
            case .shooting:  return "Shoot"
            }
        }

        var sprite: Sprite {
            switch self {
            case .front:     return .front
            case .running:   return .run
            case .dribbling: return .dribble
            // The receiver sheet the court actually uses. `inboundReceiver` is the old
            // single-cell one, kept only so the numbering behind it still lines up.
            case .receiving: return .inboundReceiverBack
            case .shooting:  return .shoot
            }
        }

        /// Which cell a still pose holds on. Cell nought of the receiver sheet is the
        /// deprecated stance — see `PlayerLook.waiting(for:)`, which passes over it too.
        var frame: Int { self == .receiving ? 1 : 0 }

        /// The still poses hold on a frame; the rest run — the shot included. It is a
        /// one-shot on the court because a shot happens once; here it is a thing being
        /// looked at, and a pose that plays through and stops is a pose you miss.
        var plays: Bool { self != .front && self != .receiving }
    }
}
