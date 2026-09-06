import Observation
import SwiftUI

/// Everything the player has chosen about the man they play as.
///
/// Nothing about the rules reads any of it, and it is kept in `UserDefaults` because it
/// is the one thing on this device that should outlive a game. What it is **not** is
/// private to this device: `look` crosses with the table so the other players see the man
/// you built rather than a stranger in the seat's colours — see `Table.Look`.
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
    /// The stances they are willing to be caught in when they win, by raw value.
    ///
    /// **Empty is not "none".** Nobody wants to win and be drawn as nothing, so an empty
    /// set means the whole list — which is also what it means before anybody has been to
    /// this screen. Ticking one is how you say "always this"; ticking three is how you
    /// say "any of these".
    var winPoses: Set<String> { didSet { save() } }

    /// What the results card may actually catch this player in.
    var chosenWinPoses: [Kit.Pose] {
        let picked = Kit.Pose.winnable.filter { winPoses.contains($0.rawValue) }
        return picked.isEmpty ? Kit.Pose.winnable : picked
    }

    func toggleWinPose(_ pose: Kit.Pose) {
        guard pose.canWin else { return }
        if winPoses.contains(pose.rawValue) {
            winPoses.remove(pose.rawValue)
        } else {
            winPoses.insert(pose.rawValue)
        }
    }

    /// The four things about him that anybody else can see, ready to travel.
    var look: Table.Look {
        Table.Look(tone: tone, face: face, jersey: jersey, belt: belt)
    }

    /// What the sprite wears, ready to hand to `paletteSwap`. Dressed by the same line
    /// that dresses everybody else's man — see `PlayerLook.swaps(of:)`.
    var swaps: [PaletteSwap] { PlayerLook.swaps(of: look) }

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
        winPoses = Set(store.stringArray(forKey: Key.winPoses) ?? [])
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
        static let winPoses = "hooper.winPoses"
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
        store.set(Array(winPoses), forKey: Key.winPoses)
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
        // Shaded with the palette's 19 rather than its 10: deep teal is two rows away
        // from azure and read as a different colour under it rather than as its shadow.
        Pair(name: "Teal",   main: PixelPalette.azure,     shade: PixelPalette.blue),
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
    ///
    /// - TODO: Re-import every sheet faceless and make the eyes programmatic. Painting a
    ///   skin-coloured rectangle over a printed face is a patch, and it costs: the mask
    ///   has to be tracked per sheet and per frame (see `Pose.headShift`), it only works
    ///   where the head is drawn at a known offset, and a blink or a look is impossible
    ///   because the eyes are baked into the art. Faceless sheets plus eyes drawn at
    ///   runtime would drop the mask, the offsets and the `hasBakedFace` flag together,
    ///   and give expressions for nothing.
    static let faceMask = CGRect(x: 13, y: 6, width: 6, height: 5)

    /// How a view wears the face sheet.
    ///
    /// **The sheet holds one eye.** A face is symmetric, so a view drawn looking at you is
    /// that eye and a flipped copy of it over the same 8-wide cell — one drawing doing
    /// both sides. A view in profile is the eye on its own; the far one is behind the
    /// nose. Nothing here has to know where an eye sits: the mirror is about the cell's
    /// own centre, and the head is centred on that cell.
    ///
    /// The sheets where he glances over a shoulder are the exception symmetry does not
    /// cover. His head is turned, so the eye nearer the edge of it rides a pixel higher
    /// than the one facing you.
    enum FaceBuild: Equatable {
        /// The eye and its mirror, level.
        case whole
        /// The eye alone.
        case profile
        /// Both, with the mirrored one moved — in art pixels, negative being up.
        case glancing(lift: CGFloat)

        /// Where the flipped copy goes, or nil when there is not one.
        var mirror: CGPoint? {
            switch self {
            case .whole:            return .zero
            case .profile:          return nil
            case .glancing(let up): return CGPoint(x: 0, y: up)
            }
        }
    }

    /// The poses the sprite can be turned to, in the order they are offered.
    enum Pose: String, CaseIterable, Identifiable {
        /// The three idle ones lead, because they are the ones worth watching — a kit is
        /// judged on a player standing there with the ball, not mid-stride.
        case stand, spinning, bouncing, holding, gooseneck, praised, fierce, defending,
             running, dribbling, receiving, shooting
        /// The three views `stand` turns through. Not stances anybody picks — they are
        /// frames of one that is — so they are never offered on their own.
        case front, back, right

        /// The ones My Hooper offers, which is not all of them.
        static let offered: [Pose] = allCases.filter { !turnOnly.contains($0) }
        private static let turnOnly: Set<Pose> = [.front, .back, .right]

        /// The views the turn walks, and which of them is mirrored: front, his right, his
        /// back, then that same side sheet flipped. One sheet does the work of two, a man
        /// being the same shape from either side.
        static let turn: [(view: Pose, mirrored: Bool)] = [
            (.front, false), (.right, false), (.back, false), (.right, true),
        ]

        /// Whether this is the turn rather than a single sheet.
        var turns: Bool { self == .stand }

        /// Whether this is a stance somebody can be caught standing in when they win.
        ///
        /// **Not everything is.** A shot, a catch and a run are things happening to a
        /// player mid-play, and the turn is how he stands when nothing is happening at
        /// all — none of them is a way of being looked at after the final whistle.
        var canWin: Bool {
            ![.stand, .shooting, .receiving, .running].contains(self)
        }

        /// Every pose the results card may catch somebody in.
        static let winnable: [Pose] = offered.filter(\.canWin)

        var id: String { rawValue }

        var title: String {
            switch self {
            case .stand:     return "Stand"
            case .spinning:  return "Spin"
            case .bouncing:  return "Bounce"
            case .holding:   return "Hold"
            case .front:     return "Front"
            case .right:     return "Side"
            case .gooseneck: return "Gooseneck"
            case .fierce:    return "Fierce"
            case .back:      return "Back"
            case .praised:   return "Praised"
            case .defending: return "D-Up"
            case .running:   return "Run"
            case .dribbling: return "Dribble"
            case .receiving: return "Catch"
            case .shooting:  return "Shoot"
            }
        }

        var sprite: Sprite {
            switch self {
            // The view the turn opens on. Anything drawing a `stand` walks `Pose.turn`
            // rather than asking for one sheet — see `HooperPortrait`.
            case .stand:     return .front
            case .spinning:  return .spinBall
            case .bouncing:  return .bounceBall
            // The throw-in wind-up, held on its first cell: hands up, facing the room.
            case .holding:   return .inbounder
            case .front:     return .front
            case .gooseneck: return .gooseneck
            case .back:      return .back
            case .right:     return .right
            // Squared up with his back to the room, arms out.
            case .fierce:    return .akuma
            case .praised:   return .praised
            case .defending: return .defender
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
            case .front, .back, .right, .fierce,
                 .receiving, .holding, .gooseneck, .praised: return false
            default: return true
            }
        }

        /// How fast it runs. The two ball idles are deliberately unhurried.
        var fps: Double {
            switch self {
            // Half a second a view, so a full turn takes two.
            case .stand:               return Theme.Figure.turnFPS
            case .spinning, .bouncing: return Theme.Figure.idleBallFPS
            case .shooting:            return Theme.Figure.shootFPS
            // Two poses, braced. Four a second, like everything off the run of play.
            case .defending:           return Theme.Figure.sidelineFPS
            default:                   return Theme.Figure.playerFPS
            }
        }

        /// Whether the sheet is drawn face-on, and so wears the chosen face. The two ball
        /// idles are front views like `front` itself; the sideline figure is one too, but
        /// it puts its own face on.
        ///
        /// `stand` answers for the view it is showing rather than for itself, so the face
        /// comes and goes as he turns — see `HooperPortrait`.
        var facesYou: Bool {
            switch self {
            case .spinning, .bouncing, .front, .gooseneck, .praised: return true
            // In profile, and wearing one eye of it — see `FaceBuild`.
            case .right: return true
            default: return false
            }
        }

        /// How this view wears the face sheet — the sheet's own answer, since the court
        /// draws sheets no pose has a name for. See `FaceBuild`.
        var face: FaceBuild { sprite.face ?? .whole }

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
            case .front, .spinning, .bouncing, .gooseneck, .praised: return true
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
            // Head thrown back a pixel with the arms out.
            case .praised:  return CGPoint(x: 0, y: -1)
            default:        return .zero
            }
        }
    }
}
