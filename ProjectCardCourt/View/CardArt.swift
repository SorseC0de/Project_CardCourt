import SwiftUI

/// Every colour on the printed cards. These are the game's palette, not just the cards'.
enum CardPalette {
    static var navy   : Color { Palette.pick("1C3261", "21315E") }
    static var blue   : Color { Palette.pick("147CC1", "397ABC") }
    static var gold   : Color { Palette.pick("F9A22F", "EDA64A") }
    /// **The art's own orange**, which the code had never carried. Every SVG in the
    /// project that oranges anything uses this; nothing anywhere used the old value but
    /// this line. A sixteenth lighter, at the same chroma and half a degree of hue —
    /// which is what lets it sit beside gold instead of arguing with it.
    static var orange : Color { Palette.pick("F55426", "E36038") }
    static var red    : Color { Palette.pick("E4195F", "D13560") }
    static var gray   : Color { Palette.pick("919CB8", "9AA2B8") }
    /// Not on the printed cards. Placed by measuring the six above rather than picked:
    /// every one of those sits in a chroma band of 0.137 to 0.228 in OKLCH, so these were
    /// built at a chosen hue and dropped into the same band. Anything outside it reads as
    /// borrowed from another palette, which is what the old lavender did.
    /// The not-black black: the *lightest* black that still reads as one, which is the
    /// rule rather than the result. Three things mark where it stops, and every neighbour
    /// fails one:
    /// **not desaturated enough to be greyscale, not blue enough to compete with navy,
    /// and not too dark.**
    ///
    /// Navy's hue turned toward red to 279 at a sixth of the chroma the gamut allows, at
    /// L 0.32. Drop the chroma further and it goes grey; raise it and navy has a rival;
    /// darken it and it stops being a surface. Not a ground — navy keeps that.
    static var black   : Color { Palette.pick("2F3143", "363845") }
    /// A tint of the blue rather than a rival to it: the wordmark's lower half, where a
    /// second saturated colour would have read as a different mark stuck to the first.
    static var lightBlue : Color { Palette.pick("89D7ED", "9BD5EA") }
    /// **Between the blue and the navy, two thirds of the way toward the blue.**
    ///
    /// Mixed in OKLab rather than in sRGB — a straight channel average of these two comes
    /// out muddy, because the blue carries far more chroma than the navy and averaging
    /// the numbers throws most of it away. L 0.48, against the blue's 0.57 and the navy's
    /// 0.33: dark enough to sit under the blue without becoming the ground navy is.
    static var darkBlue : Color { Palette.pick("1D619E", "326099") }
    /// Barely a colour at all: white with the blue's own hue left in it, for a ground
    /// that has to read as paper rather than as a light being shone on one.
    static var cloud   : Color { Palette.pick("E3F0F8", "E6F0F7") }
    /// The warm pair. Light enough to be printed on and to be printed with, which the
    /// saturated half of the palette is not.
    static var sand    : Color { Palette.pick("F8D3A0", "F2D4A6") }
    static var tan     : Color { Palette.pick("E6B792", "DFB997") }
    /// The dark end of the warm run — where sand and tan go when they have to hold type.
    static var brown   : Color { Palette.pick("BC8051", "B38359") }
    /// **The cool one that lives with orange.** Hue 188 — green sits at 145 and blue at
    /// 250, so this is the band that is genuinely neither.
    ///
    /// Chosen at the top of the quiet half rather than the bottom of the loud one, which
    /// is the palette's own character: **it is two groups with a gap between them.**
    /// Seven colours carry a chroma of 0.14 to 0.23 and nine carry 0.02 to 0.10, and
    /// almost nothing sits in the middle. Punchy where it speaks, muted where it holds
    /// something — a teal picked for saturation would have joined the wrong group and
    /// read as a third thing.
    static var teal    : Color { Palette.pick("1B8C85", "438A85") }
    static var green   : Color { Palette.pick("2EA93E", "56A74C") }
    static var magenta : Color { Palette.pick("D34BD2", "C354CC") }
    static var purple  : Color { Palette.pick("A45FFF", "9B62F6") }

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
        // The not-black black rather than navy. Navy is what the ring is drawn in, so an
        // Intangible was a navy card with a navy border around it.
        case .intangible:  return black
        }
    }


    static func isStriped(_ type: CardType) -> Bool { type == .whistle }
}

/// **Every colour the printing of a card turns on, per type, in one place.**
///
/// The rules have to be per type because the bodies are: what reads on orange does not
/// read on navy, and a keyword inked orange on a blue card disappears on an orange one.
/// They were spread across five different views and two enums, each answering for the
/// case in front of it, which is how a card ended up with a keyword the same colour as
/// the card.
///
/// Everything here is a printing decision and nothing reads it but the drawing.
struct CardInk {
    /// The card's own words, and the picture that leads them.
    var text: Color
    /// The hard drop under the big icon.
    var iconShade: Color
    /// A card named inside the effect — `@[Rhythm Dribble]` — and its drop.
    var name: Color
    var nameShade: Color
    /// A mechanic the rules name — `#[Draw]` — its drop, and the small picture that goes
    /// in front of it. The picture takes the word's colour: they are one thing said twice.
    var keyword: Color
    var keywordShade: Color
    /// The inner ring, and the drop under the name plate.
    var ring: Color
    var plate: Color

    /// **The printing, as it is being tuned.** The two colours a card is read by — its
    /// own words and the mechanics inside them — come off the dials so the bench can move
    /// them; everything else here is settled. See `CardTextStyle`.
    @MainActor
    static func of(_ type: CardType) -> CardInk {
        var ink = frozen(type)
        let tuned = CardTextTuning.shared
        ink.text = tuned.ink(for: type)
        ink.keyword = tuned.keywordInk(for: type)
        ink.ring = tuned.ringInk(for: type)
        ink.plate = tuned.plateInk(for: type)
        return ink
    }

    private static func frozen(_ type: CardType) -> CardInk {
        // The two dark bodies. Navy lettering on either is lettering nobody can find, and
        // navy is also what the ring is drawn in — so both turn over together.
        let dark = type == .intangible || type == .gameBreak
        return CardInk(
            // A Whistle's stripes are black and white and its body is nearly white, so
            // navy sits between the two rather than on either side of them.
            text: type == .whistle ? .black : (dark ? .white : CardPalette.navy),
            iconShade: type == .whistle ? CardPalette.blue : CardPalette.navy,
            name: CardPalette.gold,
            nameShade: CardPalette.orange,
            // **Blue on a Move card.** Orange keywords on an orange body were the card
            // saying its own mechanic in its own colour, which is the same as not saying
            // it. Everywhere else orange is the accent that is not the body.
            keyword: type == .move ? CardPalette.blue : CardPalette.orange,
            keywordShade: CardPalette.navy,
            ring: type == .intangible ? CardPalette.gold : CardPalette.navy,
            // Blue is what the artwork used to carry baked in; only the dark bodies
            // change it, because blue on either would not read at all.
            plate: dark ? CardPalette.gold : CardPalette.blue)
    }
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
    /// The keywords the card draws a mark for, and what it draws. **Beside the word, not
    /// instead of it** — a card that says its mechanic only in pictures is a card you have
    /// to have been told about, which is what the experiment turned out to mean.
    static let badgeFraction: CGFloat = 0.26
    /// What `CardText` falls back to when nobody says. The card itself always says —
    /// see `CardTextStyle.glyphShare`.
    static let keywordGlyphShare: CGFloat = 0.85
    /// And the whole middle of the card, when the badge is all the card says.
    /// The badge's own letter spacing. **Not the card text's** — that is a dial now, and
    /// the two were one number by accident rather than by intent. See `CardTextStyle`.
    static let badgeTracking: CGFloat = -0.05
    static let badgeAloneFraction: CGFloat = 0.42
    /// How big the value on its face is, against the badge itself.
    static let badgeValueShare: CGFloat = 0.42

    static let keywordGlyphs: [String: String] = [
        "Draw": "DrawIcon", "Draws": "DrawIcon",
        "Discard": "DiscardIcon", "Discards": "DiscardIcon",
        "Lock": "LockIcon", "Locks": "LockIcon",
    ]

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

    @MainActor
    static func iconShadow(for type: CardType) -> Color { CardInk.of(type).iconShade }

    /// The mark a Dribble card wears at its foot, and the one that goes before the word
    /// wherever another card names it.
    static let dribbleSymbol = "figure.basketball"
    /// How much of the shoot mark's size the dribble symbol takes. Smaller, because a
    /// symbol is measured by its height and an image by the box it fits inside.
    static let dribbleSymbolShare: CGFloat = 0.62

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
