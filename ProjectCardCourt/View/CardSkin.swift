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
    /// The circle the subject stands in, which the artwork carries as tan.
    var iconPlate: Color
    /// The card's own words.
    var text: Color
    /// The name on the badge, top and bottom.
    var nameTop: Color
    var nameBottom: Color
    /// What the words are laid on, and how much of it.
    var overlay: Color

    /// **The plate colour the artwork is drawn with**, which every type icon shares. The
    /// circle is recoloured by swapping this one entry rather than by keeping a set of
    /// recoloured drawings — see `View.paletteSwap`.
    static let printedIconPlate = CardPalette.tan

    @MainActor
    static func of(_ face: CardFace) -> CardSkin { of(face, theme: CardTheme.current) }

    static func of(_ face: CardFace, theme: CardTheme) -> CardSkin {
        let standing = face.isStanding
        let type = face.colour.colour
        let shade = face.shade.colour
        // The half of the deck this card is in, said in one colour.
        let intent: Color = standing ? CardPalette.black : CardPalette.cloud

        switch theme {
        case .a:
            return CardSkin(
                body: intent, panel: nil,
                plate: type, plateShade: shade, ring: type,
                iconPlate: CardPalette.tan,
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
                iconPlate: standing ? CardPalette.tan : CardPalette.steel,
                text: standing ? CardPalette.cloud : CardPalette.navy,
                nameTop: face.lettersDark ? CardPalette.navy : CardPalette.cloud,
                nameBottom: face.lettersDark ? CardPalette.darkBlue : .white,
                overlay: type)
        case .c:
            // Turned inside out: the type is the paper, and the white or black is the
            // frame it sits in, the badge it is named on and the ring round it.
            return CardSkin(
                body: intent, panel: type,
                plate: intent, plateShade: standing ? CardPalette.navy : CardPalette.steel,
                ring: intent,
                // Measured off card_colors.png: a standing card's circle is gray there,
                // not steel — steel is what theme B's play cards use.
                iconPlate: standing ? CardPalette.gray : CardPalette.cloud,
                text: .white,
                nameTop: standing ? CardPalette.cloud : CardPalette.navy,
                nameBottom: standing ? .white : CardPalette.darkBlue,
                overlay: intent)
        }
    }
}
