import SwiftUI

/// Every colour on the printed cards. These are the game's palette, not just the cards'.
enum CardPalette {
    static let navy   = Color(red: 0x1F / 255, green: 0x36 / 255, blue: 0x65 / 255)
    static let blue   = Color(red: 0x14 / 255, green: 0x7C / 255, blue: 0xC1 / 255)
    static let gold   = Color(red: 0xF9 / 255, green: 0xA2 / 255, blue: 0x2F / 255)
    static let orange = Color(red: 0xEF / 255, green: 0x4E / 255, blue: 0x22 / 255)
    static let red    = Color(red: 0xE4 / 255, green: 0x19 / 255, blue: 0x5F / 255)
    static let gray   = Color(red: 0x91 / 255, green: 0x9C / 255, blue: 0xB8 / 255)
    /// Not on the printed cards, but the sheet assigns these two types their own.
    static let green  = Color(red: 0x1C / 255, green: 0xB0 / 255, blue: 0x00 / 255)
    /// The sheet's lavender sat far lighter than everything else. Same hue, dropped to
    /// the lightness the rest of the palette lives at.
    static let purple = Color(red: 0x8B / 255, green: 0x1F / 255, blue: 0xD6 / 255)

    /// The body colour a card type is printed in. Whistles have none — they are striped.
    ///
    /// Move and Special Move are orange and gold: neighbours on the same warm ramp,
    /// because a Special Move is still a Move card and the colours should say so. Green
    /// came free when Move gave it up, and Injuries took it.
    static func body(for type: CardType) -> Color {
        switch type {
        case .pass:        return blue
        case .move:        return orange
        case .specialMove: return gold
        case .clamp:       return red
        case .whistle:     return Color(white: 0.94)
        case .gameBreak:   return purple
        case .intangible:  return navy
        }
    }


    static func isStriped(_ type: CardType) -> Bool { type == .whistle }
}

/// A card body: a flat colour, plus a striped band across the top for Whistles.
struct CardBodyFill: View {
    let type: CardType
    /// Injuries are a family inside Game Break with their own colour, so the fill takes
    /// this rather than reading the type alone.
    var isInjury = false
    /// Playable but pointless. Only the body greys — draining the whole card made two
    /// Whistles indistinguishable, their stripes being white to begin with.
    var isDormant = false
    var stripes = 11
    /// How far down the card the stripes run.
    var bandFraction: CGFloat = 0.10
    var glossFraction: CGFloat = 0.35

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Rectangle().fill(isDormant ? CardPalette.gray
                                 : (isInjury ? CardPalette.green : CardPalette.body(for: type)))
                if CardPalette.isStriped(type), !isDormant {
                    HStack(spacing: 0) {
                        ForEach(0..<stripes, id: \.self) { index in
                            Rectangle()
                                .fill(index.isMultiple(of: 2) ? Color(white: 0.09) : Color(white: 0.94))
                                .frame(width: geo.size.width / CGFloat(stripes))
                        }
                    }
                    .frame(height: geo.size.height * bandFraction)
                    .overlay(alignment: .top) {
                        // A hard band, not a gradient — nothing else on the card is soft.
                        Rectangle()
                            .fill(Color(white: 0.94))
                            .frame(height: geo.size.height * bandFraction * glossFraction)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }
}

/// Geometry read straight out of CardCourt_CardBack.svg.
///
/// The artboard is 634x834, but the card shape inside it is 591.67x791.67 inset 20.83 all
/// round, with a corner radius of 47.333 — which is exactly 8% of the card's width, so
/// Affinity's "8%" is a fraction of the short side and translates directly.
enum CardMetrics {
    static let artboard = CGSize(width: 634, height: 834)
    static let shape = CGSize(width: 591.67, height: 791.67)
    /// The **back** is drawn to a second, larger shape around that one — 497 across plus
    /// two 68.167 corners — which all but fills the artboard. `shape` is the front's
    /// panel; anything lining something up with the printed back wants this instead.
    static let backShape = CGSize(width: 633.33, height: 833.33)

    static var aspect: CGFloat { shape.width / shape.height }
    /// Scale the back image by this to line its printed card up with a drawn rectangle.
    static var backImageScale: CGFloat { artboard.width / shape.width }
}

/// The card's layout, settled on the calibrator and frozen here.
///
/// Plain constants, deliberately: this used to be an `@Observable` the calibration screen
/// wrote to, which meant touching any one value invalidated every card on screen. Nothing
/// observes it now, so a card is only ever rebuilt when its own inputs change.
///
/// Values are written over the card's own dimensions, so `21 / across` is the 21 that was
/// dialled in rather than 0.0355. The calibrator is archived in Tools/calibration.
enum CardLayout {
    private static let across = CardMetrics.shape.width
    private static let down = CardMetrics.shape.height

    /// The card is drawn at this multiple of its display size and scaled back down, so
    /// every use is a scale *down* off the texture. Enlarging to 2x for a detail view is
    /// then still within what was rasterised, and stays crisp.
    static let rasterScale: CGFloat = 2

    static let cornerFraction: CGFloat = 0.08

    static let strokeFraction: CGFloat = 21 / across
    static let strokeInsetFraction: CGFloat = 15 / across
    static let strokeCornerFraction: CGFloat = 50 / across

    static let textOverlayWidthFraction: CGFloat = 0.75
    static let textOverlayBottomFraction: CGFloat = 51 / down

    static let nameOverlayYFraction: CGFloat = 11 / down
    static let nameOverlayWidthFraction: CGFloat = 1.0
    static let nameSizeFraction: CGFloat = 75 / across
    static let nameTracking: CGFloat = -0.04
    /// The name box's drop shadow, as a share of the plate's own width.
    ///
    /// Measured off the artwork that used to carry it baked in: two identical paths,
    /// the lower one offset 12.5 down in a 638-wide artboard and filled with the card
    /// blue. Written as the measurement so it reads back as what it came from.
    static let namePlateShadowFraction: CGFloat = 12.5 / 638
    /// Affinity counts negative as clockwise; SwiftUI counts positive that way.
    static let nameRotation: Double = 3
    static let nameCapHeight: CGFloat = 0.75
    static let nameTextYFraction: CGFloat = 7 / down

    static let ballSizeFraction: CGFloat = 111 / across
    static let ballCentreXFraction: CGFloat = 520 / across
    /// Dropped by its own height, so its top only just meets the name plate — which
    /// is what lets long names stay put instead of sliding out of the card.
    static let ballCentreYFraction: CGFloat = 182 / down
    static let ballShadowFraction: CGFloat = 7 / across
    static let badgeShadowFraction: CGFloat = 5 / across
    static let badgeSizeFraction: CGFloat = 75 / across
    static let badgeTracking: CGFloat = -0.05

    static let whistleBandFraction: CGFloat = 0.10
    static let whistleGlossFraction: CGFloat = 0.10

    static let arrowSizeFraction: CGFloat = 500 / across
    /// The chevrons read much heavier than the arrow at the same width.
    static let skipIconFraction: CGFloat = 300 / across
    /// Where a card's icon and effect text sit, for everything that is not a basic pass.
    static let iconYFraction: CGFloat = 0.40
    static let iconSizeFraction: CGFloat = 0.40
    /// A touch further than the card's other shadows; the icons need the separation.
    static let iconShadowFraction: CGFloat = 22 / across
    /// Whistles print their icon in Zuphy32 21 over blue; the white-on-navy every other
    /// type uses disappears against their stripes.
    static func iconTint(for type: CardType) -> Color {
        type == .whistle ? PixelPalette.midnight : .white
    }

    static func iconShadow(for type: CardType) -> Color {
        type == .whistle ? CardPalette.blue : CardPalette.navy
    }

    static let shootIconFraction: CGFloat = 0.30
    static let shootIconBottomFraction: CGFloat = 0.04
    /// How much the shoot mark shrinks so it reads as a footnote.
    static let shootIconCrowding: CGFloat = 0.75
    static let shootTextLift: CGFloat = 0.09
    static let effectYFraction: CGFloat = 0.75
    static let effectSizeFraction: CGFloat = 56 / across
    static let effectLineHeight: CGFloat = 0.75
    static let arrowCentreYFraction: CGFloat = 0.58
    static let arrowShadowOffsetFraction: CGFloat = 18 / across
    static let backPassArrowScale: CGFloat = 1.15

    // The overlay is solid black and templated, so tint decides its colour entirely.
    // Tinting with the body colour and multiplying gives a darker, more saturated
    // version of that colour.
    static func blend(for type: CardType) -> BlendMode { .multiply }
    static func tint(for type: CardType) -> OverlayTint { .body }

    static func opacity(for type: CardType) -> Double {
        switch type {
        case .gameBreak, .intangible: return 0.40
        case .move, .specialMove:     return 0.30
        case .pass:                   return 0.25
        case .clamp:                  return 0.60
        // Whistles keep theirs; the extra twenty was right on white.
        case .whistle:                return 0.90
        }
    }
}

/// The overlay art is solid black and templated, so its tint is the whole colour choice.
enum OverlayTint: String, CaseIterable, Hashable {
    case body, black, white

    func colour(on type: CardType) -> Color {
        switch self {
        case .body:  return CardPalette.body(for: type)
        case .black: return .black
        case .white: return .white
        }
    }
}
