import SwiftUI

/// Every colour on the printed cards. These are the game's palette, not just the cards'.
enum CardPalette {
    static let navy   = Color(red: 0x1C / 255, green: 0x32 / 255, blue: 0x61 / 255)
    static let blue   = Color(red: 0x14 / 255, green: 0x7C / 255, blue: 0xC1 / 255)
    static let gold   = Color(red: 0xF9 / 255, green: 0xA2 / 255, blue: 0x2F / 255)
    /// **The art's own orange**, which the code had never carried. Every SVG in the
    /// project that oranges anything uses this; nothing anywhere used the old value but
    /// this line. A sixteenth lighter, at the same chroma and half a degree of hue —
    /// which is what lets it sit beside gold instead of arguing with it.
    static let orange = Color(red: 0xF5 / 255, green: 0x54 / 255, blue: 0x26 / 255)
    static let red    = Color(red: 0xE4 / 255, green: 0x19 / 255, blue: 0x5F / 255)
    /// **What a devastating injury is printed on**, and the drop under it.
    ///
    /// Hue 5 at L 0.44 — the red end of the arc between red and purple, made distinct by
    /// being dark rather than by being a different hue. Magenta already sits dead centre
    /// of that arc at 328, so a colour that is only "between" them is a dark magenta,
    /// which this is not.
    ///
    /// **The pair is nine points of lightness apart**, hue and chroma held, so the drop
    /// is the same colour going down rather than a second one. Deliberately shallower
    /// than the drops elsewhere — gold falls 45 points onto navy — because a card about
    /// a season-ending injury should read heavier and flatter than the rest of the deck.
    static let darkRed  = Color(red: 0x94 / 255, green: 0x18 / 255, blue: 0x47 / 255)
    static let maroon  = Color(red: 0x69 / 255, green: 0x0E / 255, blue: 0x3E / 255)
    static let gray   = Color(red: 0x91 / 255, green: 0x9C / 255, blue: 0xB8 / 255)
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
    static let black   = Color(red: 0x2F / 255, green: 0x31 / 255, blue: 0x43 / 255)
    /// A tint of the blue rather than a rival to it: the wordmark's lower half, where a
    /// second saturated colour would have read as a different mark stuck to the first.
    static let lightBlue = Color(red: 0x89 / 255, green: 0xD7 / 255, blue: 0xED / 255)
    /// **Between the blue and the navy, two thirds of the way toward the blue.**
    ///
    /// Mixed in OKLab rather than in sRGB — a straight channel average of these two comes
    /// out muddy, because the blue carries far more chroma than the navy and averaging
    /// the numbers throws most of it away. L 0.48, against the blue's 0.57 and the navy's
    /// 0.33: dark enough to sit under the blue without becoming the ground navy is.
    static let darkBlue = Color(red: 0x1D / 255, green: 0x61 / 255, blue: 0x9E / 255)
    /// Barely a colour at all: white with the blue's own hue left in it, for a ground
    /// that has to read as paper rather than as a light being shone on one.
    static let cloud   = Color(red: 0xE3 / 255, green: 0xF0 / 255, blue: 0xF8 / 255)
    /// **The midpoint of cloud and gray**, mixed in OKLab and then turned to hue 294 —
    /// far enough off both neighbours' 235 and 268 to read as its own neutral rather than
    /// a dimmer cloud, and the only tone in the palette that is neither warm nor cool.
    /// Sits 12.9 from each of them, which is what makes it usable as either one's drop.
    static let steel   = Color(red: 0xC4 / 255, green: 0xC2 / 255, blue: 0xD1 / 255)
    /// **Between orange and gold**, which was the last loud stretch of the warm run:
    /// brown, tan and the rest of that arc are all quiet. Nearer gold than the wheel's
    /// middle at ΔE 5.2 — the closest pair in the palette, and chosen that way.
    static let tangerine = Color(red: 0xFA / 255, green: 0x8A / 255, blue: 0x0B / 255)
    /// Light enough to be printed on and to be printed with, which the saturated half of
    /// the palette is not.
    static let tan     = Color(red: 0xE6 / 255, green: 0xB7 / 255, blue: 0x92 / 255)
    /// The dark end of the warm run — where sand and tan go when they have to hold type.
    static let brown   = Color(red: 0xBC / 255, green: 0x80 / 255, blue: 0x51 / 255)
    /// **The cool one that lives with orange.** Hue 188 — green sits at 145 and blue at
    /// 250, so this is the band that is genuinely neither.
    ///
    /// Chosen at the top of the quiet half rather than the bottom of the loud one, which
    /// is the palette's own character: **it is two groups with a gap between them.**
    /// Seven colours carry a chroma of 0.14 to 0.23 and nine carry 0.02 to 0.10, and
    /// almost nothing sits in the middle. Punchy where it speaks, muted where it holds
    /// something — a teal picked for saturation would have joined the wrong group and
    /// read as a third thing.
    static let teal    = Color(red: 0x1B / 255, green: 0x8C / 255, blue: 0x85 / 255)
    /// **The shadow that works under seven of them** — green, teal, blue, azure,
    /// darkBlue, gray and purple.
    ///
    /// A drop does not have to be its base's own colour darkened; it has to be dark and
    /// related. At L 0.42 and a chroma of 0.048 this is dark enough to sit under almost
    /// anything cool and quiet enough not to argue with it, and hue 232 puts it between
    /// teal and blue where it can lean either way.
    ///
    /// Arrived at by being wrong twice: called too near black at L 0.30, then too flat
    /// once lightened. Neither held — a shadow is read against the thing it sits under,
    /// not as a swatch beside black, and the numbers that judge swatches judge this
    /// badly.
    static let cobalt  = Color(red: 0x31 / 255, green: 0x52 / 255, blue: 0x63 / 255)
    /// **Moved off the yellow-green it was**, without leaving the loud group. At H 145
    /// it pulled toward gold and read crude beside teal. Four degrees round and four
    /// points darker, chroma held at 0.162 — the correction is the pull, not the volume.
    /// Dropping chroma instead put green in with the quiet colours, which left the whole
    /// cool half of the palette muted.
    static let green   = Color(red: 0x1E / 255, green: 0x9E / 255, blue: 0x4A / 255)
    static let magenta = Color(red: 0xD3 / 255, green: 0x4B / 255, blue: 0xD2 / 255)
    /// **The twentieth, and the one bare stretch of the wheel.** Nothing loud or quiet
    /// sat between blue at 245 and purple at 300; this is at 274.
    ///
    /// **Chroma is what separates it from blue, not hue.** At 0.18 it fell inside blue's
    /// reach — ΔE 8.5, the same distance blue and darkBlue get away with only by being a
    /// fill and its shade. At 0.22 it clears everything by at least twelve. The optimum
    /// for "furthest from all four blues" is out at hue 288, but that is a violet: it
    /// wins the arithmetic and stops being the colour.
    ///
    /// Four blues is not an accident of the palette. The game's colour is blue, so having
    /// several is the point rather than a redundancy.
    static let azure   = Color(red: 0x4C / 255, green: 0x53 / 255, blue: 0xE7 / 255)
    static let purple  = Color(red: 0xA4 / 255, green: 0x5F / 255, blue: 0xFF / 255)
    /// **The shadow that becomes whatever it is under.**
    ///
    /// L 0.44 at a chroma of 0.055, hue 322. Quiet enough that the base above it decides
    /// what it reads as: depth under the warms, a cool cast under gray, a relative under
    /// purple and magenta. Cobalt does the same job for the cool half of the palette;
    /// this is its counterpart.
    ///
    /// **Its chroma is the whole of it.** The same hue and lightness at 0.160 stops
    /// receding and starts announcing itself — that is a contrast drop, a different
    /// thing, and it is `orchid`.
    static let plum   = Color(red: 0x61 / 255, green: 0x48 / 255, blue: 0x65 / 255)
    /// **The warm half of the same idea.** Plum bridges red to blue through purple;
    /// this bridges red to brown through purple, and the two reach opposite ways.
    ///
    /// Measured: after the reds, plum's nearest neighbour is azure at 20.7 and this
    /// one's is brown at 16.5. Same corner of the wheel, 28 degrees and eight points of
    /// lightness apart, pointing away from each other.
    ///
    /// It began as a reddish brown and rotated here. At hue 50 it was brown getting
    /// darker; by 350 it had become its own thing — which is why it earns a slot rather
    /// than filling the warm-mid gap it was drawn for. That gap is still open.
    static let blood = Color(red: 0x8A / 255, green: 0x56 / 255, blue: 0x6F / 255)

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
        case .gameBreak:   return magenta
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
    /// **Injuries are a family inside Game Break, and not one colour.** The sheet already
    /// tells them apart — one is off at the end of the round, the other is on for the
    /// rest of the game — so the card says which it is rather than saying only that it is
    /// an injury. Nil is not an injury at all.
    var injury: Injury?
    /// Playable but pointless. Only the body greys — draining the whole card made two
    /// Whistles indistinguishable, their stripes being white to begin with.
    var isDormant = false
    var stripes = 11
    /// How far down the card the stripes run.
    var bandFraction: CGFloat = 0.10
    var glossFraction: CGFloat = 0.35

    /// What this card is printed on. A knock that clears at the end of the round is the
    /// medical green; one that is on you for the rest of the game is its own dark red.
    private var ground: Color {
        switch injury {
        case .game:  return CardPalette.darkRed
        case .round: return CardPalette.green
        case nil:    return CardPalette.body(for: type)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Rectangle().fill(isDormant ? CardPalette.gray : ground)
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
    /// How big a card's icon is drawn, for everything that is not a basic pass.
    /// Where it sits is `CardTextStyle.iconTop`, on the bench with the rest of the dials.
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
