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

    /// The face already printed on the front sheets: (13,6) through (18,10) inclusive,
    /// in art pixels. Painted over in skin before the chosen face goes on, which is
    /// cheaper than re-exporting four sheets without one.
    static let faceMask = CGRect(x: 13, y: 6, width: 6, height: 5)

    /// The poses the sprite can be turned to, in the order they are offered.
    enum Pose: String, CaseIterable, Identifiable {
        /// The three idle ones lead, because they are the ones worth watching — a kit is
        /// judged on a player standing there with the ball, not mid-stride.
        case spinning, bouncing, holding, front, running, dribbling, receiving, shooting

        var id: String { rawValue }

        var title: String {
            switch self {
            case .spinning:  return "Spin"
            case .bouncing:  return "Bounce"
            case .holding:   return "Hold"
            case .front:     return "Front"
            case .running:   return "Run"
            case .dribbling: return "Dribble"
            case .receiving: return "Catch"
            case .shooting:  return "Shoot"
            }
        }

        var sprite: Sprite {
            switch self {
            case .spinning:  return .spinBall
            case .bouncing:  return .bounceBall
            // The throw-in wind-up, held on its first cell: hands up, facing the room.
            case .holding:   return .inbounder
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
        var plays: Bool {
            switch self {
            case .front, .receiving, .holding: return false
            default: return true
            }
        }

        /// How fast it runs. The two ball idles are deliberately unhurried.
        var fps: Double {
            switch self {
            case .spinning, .bouncing: return Theme.Figure.idleBallFPS
            case .shooting:            return Theme.Figure.shootFPS
            default:                   return Theme.Figure.playerFPS
            }
        }

        /// Whether the sheet is drawn face-on, and so wears the chosen head. The two ball
        /// idles are front views like `front` itself; the sideline figure is one too, but
        /// it puts its own face on.
        var facesYou: Bool {
            switch self {
            case .spinning, .bouncing, .front: return true
            default: return false
            }
        }

        /// Whether this is the sideline figure rather than a plain sheet.
        ///
        /// The throw-in stance is drawn empty-handed and faceless, and `InbounderFigure`
        /// already knows where the ball and the face go on it — tuned once, when he was
        /// put on the sideline. Drawing him here a second way would be two answers to a
        /// question that has one.
        var isSideline: Bool { self == .holding }

        /// Whether the sheet has a face printed on it that the chosen one has to cover.
        /// The three front views do; nothing else is drawn looking at you.
        var hasBakedFace: Bool {
            switch self {
            case .front, .spinning, .bouncing: return true
            default: return false
            }
        }

        /// Where this sheet's head sits, in art pixels against the one on `Player_front`.
        ///
        /// The two ball sheets are drawn a pixel to the right of it, and the bounce lifts
        /// him a pixel for the second half of the toss — so whatever is laid on his face
        /// has to move with him rather than sitting where the still pose left it.
        func headShift(atFrame frame: Int) -> CGPoint {
            switch self {
            case .spinning: return CGPoint(x: 1, y: 0)
            case .bouncing: return CGPoint(x: 1, y: frame >= 3 ? -1 : 0)
            default:        return .zero
            }
        }
    }
}
