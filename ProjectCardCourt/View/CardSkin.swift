import SwiftUI

/// **How a card is printed**, resolved from its face and the theme in force.
///
/// Two things decide every colour on a card. **What it is** — its type, which is the one
/// colour it carries. And **what it does**: a card you play and discard is printed on
/// white, a card that goes down and stays there is printed on black. Cloud and black are
/// not a light mode and a dark mode; they are the two halves of the deck saying which
/// half they are in.
///
/// The themes are three ways of spending that. A prints the white or black as the body
/// and the type on the badge; B is the same in tan and brown; C turns it inside out and
/// makes the type the body, with the white or black as the frame, the badge and the ring.
enum CardTheme: String, CaseIterable, Identifiable, Codable {
    /// Cloud and black bodies, type colour on the badge and the ring.
    case a
    /// The same, in tan and brown.
    case b
    /// Reversed: the type is the body, and the white or black is the frame.
    case c

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }

    /// **The theme in force.** A debug switch until it is a setting — see `CardTextBench`,
    /// which is where it is set and why it lives on the tuning rather than here.
    @MainActor static var current: CardTheme { CardTextTuning.shared.theme }
}

extension CardFace {
    /// **Whether this card goes down and stays there.**
    ///
    /// A Pass or a Move is spent the moment it is played; an Intangible, a Ball or a
    /// Clamp is put on the table and stands until something takes it off. That difference
    /// is worth a colour of its own, because it is the difference between a card you are
    /// holding and a card you are living under.
    var isStanding: Bool {
        switch self {
        case .intangible, .variaball, .clamp, .varena: return true
        case .pass, .move, .specialMove, .whistle, .gameBreak,
             .injury, .devastatingInjury:              return false
        }
    }
}

/// Every colour a card is drawn in, for one face under one theme.
struct CardSkin {
    /// The paper the whole card sits on.
    var body: Color
    /// Theme C only: the panel of type colour inside the frame. Nil means the body is
    /// the whole of it.
    var panel: Color?
    /// The name badge, and the shade under it.
    var plate: Color
    var plateShade: Color
    /// The line round the card.
    var ring: Color
    /// **The plate the subject stands in**, by role. The circle it sits on, the court
    /// lines printed across it, and the shadow those lines throw. Nil leaves that role
    /// exactly as it was drawn.
    var iconPlate: Color?
    var iconLine: Color?
    var iconLineShade: Color?
    /// **The drop under the whole icon.** Nil keeps the one the face was tuned to — only
    /// a theme that says otherwise moves it, and only the tan bodies do.
    var iconShade: Color?
    /// The card's own words.
    var text: Color
    /// The name on the badge, top and bottom.
    var nameTop: Color
    var nameBottom: Color
    /// What the words are laid on, and how much of it.
    var overlay: Color

    /// **What each type's plate is actually drawn in**, by role.
    ///
    /// Three types share the court-line plate — a circle, the lines across it and the
    /// shadow those lines throw — and each was drawn in its own colours. Everything else
    /// is its own thing and is left alone: a Clamp keeps its purple plate and azure drop,
    /// and the two-colour plates have no lines to recolour.
    struct PlateInks {
        var circle: Color?
        var line: Color?
        var lineShade: Color?
    }

    static func printed(_ face: CardFace) -> PlateInks {
        switch face {
        case .pass:    return PlateInks(circle: CardPalette.tan, line: CardPalette.cloud,
                                        lineShade: CardPalette.lightBlue)
        // Its line shadow was drawn gray where every other court-line plate throws
        // light blue; the swap is what puts it back in step.
        case .move:    return PlateInks(circle: CardPalette.tan, line: CardPalette.cloud,
                                        lineShade: CardPalette.gray)
        case .whistle: return PlateInks(circle: CardPalette.plum, line: CardPalette.cloud,
                                        lineShade: CardPalette.lightBlue)
        default:       return PlateInks()
        }
    }

    /// The swaps that take this face's plate from how it was drawn to how the theme wants
    /// it. Empty when nothing about it moves.
    @MainActor
    static func plateSwaps(for face: CardFace) -> [PaletteSwap] {
        let drawn = printed(face)
        let skin = of(face)
        return zip([drawn.circle, drawn.line, drawn.lineShade],
                   [skin.iconPlate, skin.iconLine, skin.iconLineShade])
            .compactMap { from, to in
                guard let from, let to, from != to else { return nil }
                return PaletteSwap(from, to)
            }
    }

    @MainActor
    static func of(_ face: CardFace) -> CardSkin { of(face, theme: CardTheme.current) }

    static func of(_ face: CardFace, theme: CardTheme) -> CardSkin {
        let standing = face.isStanding
        let type = face.colour.colour
        let shade = face.shade.colour
        // The half of the deck this card is in, said in one colour.
        let intent: Color = standing ? CardPalette.black : CardPalette.cloud

        // **The circle a court-line plate stands on**, per theme. A Whistle's is gray
        // rather than the tan the other two wear.
        let plainCircle: Color = face == .whistle ? CardPalette.gray : CardPalette.tan

        switch theme {
        case .a:
            return CardSkin(
                body: intent, panel: nil,
                plate: type, plateShade: shade, ring: type,
                iconPlate: plainCircle,
                iconLine: CardPalette.cloud,
                iconLineShade: CardPalette.lightBlue,
                iconShade: nil,
                text: standing ? CardPalette.cloud : CardPalette.navy,
                nameTop: face.lettersDark ? CardPalette.navy : CardPalette.cloud,
                nameBottom: face.lettersDark ? CardPalette.darkBlue : .white,
                overlay: type)
        case .b:
            // Cloud for tan, and tan for steel on the icon plates. A standing card takes
            // brown for the black, and its plate takes the tan back.
            return CardSkin(
                body: standing ? CardPalette.brown : CardPalette.tan, panel: nil,
                plate: type, plateShade: shade, ring: type,
                // A standing card takes the tan plate back, and everything that comes
                // with it.
                iconPlate: standing ? plainCircle : CardPalette.steel,
                iconLine: CardPalette.cloud,
                iconLineShade: CardPalette.lightBlue,
                // Gray under a tan body; a standing card takes back what accompanies
                // the tan plate, which is the drop the face was tuned to.
                iconShade: standing ? nil : CardPalette.gray,
                text: standing ? CardPalette.cloud : CardPalette.navy,
                nameTop: face.lettersDark ? CardPalette.navy : CardPalette.cloud,
                nameBottom: face.lettersDark ? CardPalette.darkBlue : .white,
                overlay: type)
        case .c:
            // Turned inside out: the type is the paper, and the white or black is the
            // frame it sits in, the badge it is named on and the ring round it.
            return CardSkin(
                body: intent, panel: type,
                // **The banner's drop follows the banner**: dark blue under a black one,
                // light blue under a cloud one.
                plate: intent,
                plateShade: standing ? CardPalette.darkBlue : CardPalette.lightBlue,
                ring: intent,
                // Measured off card_colors.png: a standing card's circle is gray there,
                // not steel — steel is what theme B's play cards use.
                iconPlate: standing ? CardPalette.gray : CardPalette.cloud,
                iconLine: CardPalette.cloud,
                iconLineShade: CardPalette.lightBlue,
                iconShade: nil,
                text: .white,
                nameTop: standing ? CardPalette.cloud : CardPalette.navy,
                nameBottom: standing ? .white : CardPalette.darkBlue,
                overlay: intent)
        }
    }
}
