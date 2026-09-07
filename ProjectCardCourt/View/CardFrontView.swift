import SwiftUI

/// A card front, drawn rather than exported — so the body recolours per type and the
/// name and percentage are live text.
///
/// Layered back to front exactly as specified: body, text overlay, border stroke, name
/// plate, name, then the SHOT badge.
struct CardFrontView: View {
    /// Observed, not just read — otherwise the bench's weight button changes nothing.
    @State private var cardFont = CardFont.shared
    /// The icon and badge dials — see `IconBench`. Frozen numbers live in `IconTuning`
    /// itself, so nothing here changes until the bench is used.
    @State private var icons = IconTuning.shared

    let descriptor: CardDescriptor
    /// Width in points. Everything else is a fraction of it, so the card holds together
    /// at any size — a 76pt hand card and a 600pt calibration card are the same drawing.
    let displayWidth: CGFloat
    /// Raised for reading, which is where the longer wording goes.
    var expanded = false
    /// In play but unable to act — drained of colour rather than dimmed, so it still
    /// reads at a glance without looking merely faded.
    var isDormant = false


    /// Everything inside is drawn at raster size; the whole thing is scaled back down
    /// at the end, so `width` still means the size it occupies.
    private var width: CGFloat { displayWidth * CardLayout.rasterScale }
    private var height: CGFloat { width / CardMetrics.aspect }
    private var corner: CGFloat { width * CardLayout.cornerFraction }


    var body: some View {
        ZStack {
            CardBodyFill(type: descriptor.type,
                         isInjury: descriptor.gameBreak?.isInjury == true,
                         isDormant: isDormant,
                         bandFraction: CardLayout.whistleBandFraction,
                         glossFraction: CardLayout.whistleGlossFraction)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

            textOverlay
            border
            // Every card carries its name. The three basic passes say the rest with an
            // icon alone; everything else gets its symbol and effect text.
            namePlate
            if let art = passArt {
                passMark(art)
            } else {
                icon
                effectText
                if descriptor.takesShot { shootMark }
                if descriptor.isDribble { dribbleMark }
            }
            if let shot = descriptor.shotEffect { shotBadge(shot) }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        // Flattened to one texture. Without it the overlay's blend mode costs an
        // offscreen pass per card, which a fanned hand pays for every frame.
        .drawingGroup()
        .scaleEffect(1 / CardLayout.rasterScale)
        .frame(width: displayWidth, height: displayWidth / CardMetrics.aspect)
    }

    private enum PassArt { case swingRight, swingLeft, skip, backPass }

    /// Only the three basic passes replace their text with a mark. Behind-the-Back has a
    /// condition worth reading, so it keeps its words.
    private var passArt: PassArt? {
        switch descriptor.id {
        case "swing-right": return .swingRight
        case "swing-left":  return .swingLeft
        case "skip-pass":   return .skip
        default:            return nil
        }
    }

    @ViewBuilder private var icon: some View {
        let side = width * CardLayout.iconSizeFraction * icons.iconScale
        let drop = width * CardLayout.iconShadowFraction
        Group {
            if descriptor.id == "behind-the-back" {
                // The swing arrow turned upright and shrunk, shadowed twice — navy then
                // red over it. Both east, applied after the flip so they stay east. Red
                // rather than blue, since the card body is already CardBlue.
                arrowImage(side * CardLayout.backPassArrowScale)
                    // Both flips before the shadows, so the shadows stay east.
                    .scaleEffect(x: -1, y: -1)
                    .shadow(color: CardPalette.navy, radius: 0, x: drop, y: 0)
                    .shadow(color: CardPalette.red, radius: 0, x: drop, y: 0)
            } else if let copies = descriptor.iconRepeat, let art = descriptor.artwork {
                // Two defenders, or three. Touching rather than spaced: it is one mark
                // saying how many are on you, not a row of separate icons.
                HStack(spacing: 0) {
                    ForEach(Array(copies.enumerated()), id: \.offset) { _, share in
                        Image(art.name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: side * art.scale * share,
                                   height: side * art.scale * share)
                    }
                }
            } else if let art = descriptor.artwork {
                ZStack {
                    Image(art.name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: side * art.scale, height: side * art.scale)
                        .scaleEffect(x: art.mirrored ? -1 : 1)
                    // The same accent the symbol icons wear, so a drawn icon and a drawn
                    // symbol put the same ball in the same place.
                    if let accent = descriptor.accentSymbol {
                        accentImage(accent, side: side)
                    }
                }
            } else if let accent = descriptor.accentSymbol {
                ZStack {
                    Image(systemName: descriptor.symbol)
                        .font(.system(size: side, weight: .semibold))
                        .rotationEffect(.degrees(descriptor.symbolRotation))
                    accentImage(accent, side: side)
                }
            } else {
                Image(systemName: descriptor.symbol)
                    .font(.system(size: side, weight: .semibold))
            }
        }
        .foregroundStyle(CardLayout.iconTint(for: descriptor.type))
        // The *drawn* side, not the nominal one. `SlashedMark` frames its content and
        // masks against that frame, so a drawing bigger than the icon slot — every piece
        // of artwork carries its own multiplier — was being cut off at the slot's edge.
        .modifier(SlashIfNeeded(on: descriptor.isSlashed,
                                side: side * (descriptor.artwork?.scale ?? 1),
                                slash: CardLayout.iconShadow(for: descriptor.type)))
        .rotationEffect(.degrees(descriptor.iconRotation))
        .shadow(color: descriptor.id == "behind-the-back"
                    ? .clear : CardLayout.iconShadow(for: descriptor.type),
                radius: 0, x: drop, y: drop)
        .position(x: width / 2,
                  y: height * (CardLayout.iconYFraction + descriptor.iconYAdjust))
    }

    /// Bottom-centre, the way the shoot mark is: some dribbles no longer have the word in
    /// their name, so the family needs a face rather than a spelling.
    private var dribbleMark: some View {
        // A symbol's font size is its whole height, where the shoot icon's frame is a box
        // the drawing fits inside — so the same number came out a good deal bigger here.
        let side = width * CardLayout.shootIconFraction
            * CardLayout.shootIconCrowding * CardLayout.dribbleSymbolShare
        let drop = width * CardLayout.iconShadowFraction
        return VStack {
            Spacer()
            Image(systemName: CardLayout.dribbleSymbol)
                .font(.system(size: side, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: CardLayout.iconShadow(for: descriptor.type),
                        radius: 0, x: drop, y: drop)
                .padding(.bottom, height * CardLayout.shootIconBottomFraction)
        }
    }

    /// Bottom-centre, in place of the words it replaces.
    private var shootMark: some View {
        // Small: it is a footnote under the effect, not the card's icon.
        let side = width * CardLayout.shootIconFraction * CardLayout.shootIconCrowding
        let drop = width * CardLayout.iconShadowFraction
        return VStack {
            Spacer()
            HStack(spacing: side * 0.18) {
                Image("ShootIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)
                    // On the image, not the stack — the hand carries its own. The drop is
                    // blue to match the three beside it; the drawing keeps its own colours.
                    .shadow(color: CardPalette.blue, radius: 0, x: drop, y: drop)
                if descriptor.isThree {
                    ThreeHandMark(width: side, shadowOffset: drop)
                }
            }
            .padding(.bottom, height * CardLayout.shootIconBottomFraction)
        }
    }

    /// Applied only where a card asks for it, so no other icon pays for the masking.
    private struct SlashIfNeeded: ViewModifier {
        let on: Bool
        let side: CGFloat
        let slash: Color

        @ViewBuilder func body(content: Content) -> some View {
            if on {
                SlashedMark(side: side, slash: slash) { content }
            } else {
                content
            }
        }
    }

    private var effectText: some View {
        let size = width * CardLayout.effectSizeFraction
        let inset = width * 0.05
        return TightText(text: expanded ? descriptor.detailedEffect
                                       : descriptor.printedEffect,
                         font: cardFont.name,
                         size: size,
                         width: width - inset * 2,
                         lineHeight: CardLayout.effectLineHeight,
                         tracking: size * CardLayout.badgeTracking,
                         markShadowOffset: width * 0.014,
                         glyphs: CardLayout.keywordGlyphs,
                         glyphShare: CardLayout.keywordGlyphShare * icons.badgeScale,
                         type: descriptor.type,
                         ink: effectColour)
            .frame(width: width - inset * 2)
            .position(x: width / 2,
                      y: height * (CardLayout.effectYFraction
                                   - (descriptor.takesShot ? CardLayout.shootTextLift : 0)))
    }

    // MARK: - Layers

    /// Bottom-centre, blended into the body. SwiftUI has no vivid light, so hard light —
    /// the nearest of the two the spec allows.
    private var textOverlay: some View {
        VStack {
            Spacer()
            Image("CardTextOverlay")
                .resizable()
                .scaledToFit()
                .frame(width: width * CardLayout.textOverlayWidthFraction)
                .foregroundStyle(CardLayout.tint(for: descriptor.type).colour(on: descriptor.type))
                .blendMode(CardLayout.blend(for: descriptor.type))
                .opacity(CardLayout.opacity(for: descriptor.type))
                .padding(.bottom, height * CardLayout.textOverlayBottomFraction)
        }
    }

    /// Carries its own radius, so tuning it cannot disturb the card's.
    /// The inner ring, and the text over the body.
    ///
    /// Two different questions. The ring only changes on a card whose body is the same
    /// navy the ring is drawn in, which is Intangibles alone. The text changes on any card
    /// dark enough to swallow navy lettering, which is Intangibles and Game Breaks both.
    /// What this card is printed in. One table, asked once — see `CardInk`.
    private var ink: CardInk { CardInk.of(descriptor.type) }
    private var ringColour: Color { ink.ring }
    /// The name sits on the gold plate, so it stays navy whatever the body is. This is the
    /// effect text, which sits on the body itself.
    private var effectColour: Color { ink.text }
    private var namePlateShadow: Color { ink.plate }

    private var border: some View {
        RoundedRectangle(cornerRadius: width * CardLayout.strokeCornerFraction, style: .continuous)
            .strokeBorder(ringColour, lineWidth: width * CardLayout.strokeFraction)
            .padding(width * CardLayout.strokeInsetFraction)
    }

    /// The plate carries its own curve on the left, so it only sits right at one Y.
    private var namePlate: some View {
        VStack(spacing: 0) {
            ZStack {
                // The shadow is drawn here rather than baked into the SVG, so a card can
                // choose its colour. Zero blur, straight down — the offset is the one the
                // baked artwork used, scaled to however wide the plate is drawn.
                let plateWidth = width * CardLayout.nameOverlayWidthFraction
                Image("NamePlaceholder")
                    .resizable()
                    .scaledToFit()
                    .frame(width: plateWidth)
                    .shadow(color: namePlateShadow, radius: 0, x: 0,
                            y: plateWidth * CardLayout.namePlateShadowFraction)
                let nameSize = width * CardLayout.nameSizeFraction
                SmallCapsText(text: descriptor.name,
                              font: "AvenirNextCondensed-Heavy",
                              size: nameSize,
                              capHeight: CardLayout.nameCapHeight,
                              tracking: nameSize * CardLayout.nameTracking)
                    .foregroundStyle(CardPalette.navy)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .padding(.horizontal, width * 0.10)
                    .rotationEffect(.degrees(CardLayout.nameRotation))
                    .offset(y: height * CardLayout.nameTextYFraction)
            }
            Spacer()
        }
        .padding(.top, height * CardLayout.nameOverlayYFraction)
    }

    /// One arrow asset does three of the four; Skip Pass borrows a symbol.
    ///
    /// Shadows are applied *after* the flips and rotations, so they stay put in the card's
    /// own space rather than turning with the art.
    @ViewBuilder
    private func passMark(_ art: PassArt) -> some View {
        let side = width * CardLayout.arrowSizeFraction
        let drop = width * CardLayout.arrowShadowOffsetFraction

        Group {
            switch art {
            case .swingRight:
                arrowImage(side)
                    .shadow(color: CardPalette.navy, radius: 0, x: 0, y: drop)
            case .swingLeft:
                arrowImage(side)
                    .scaleEffect(x: -1)
                    .shadow(color: CardPalette.red, radius: 0, x: 0, y: drop)
            case .skip:
                Image(systemName: "chevron.right.dotted.chevron.right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * CardLayout.skipIconFraction)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: CardPalette.purple, radius: 0, x: 0, y: drop)
            case .backPass:
                // Flipped upright, smaller, and shadowed twice — navy first, then blue
                // over it. Both east, so they read as a doubled edge rather than a drop.
                arrowImage(side * CardLayout.backPassArrowScale)
                    // Both flips before the shadows, so the shadows stay east.
                    .scaleEffect(x: -1, y: -1)
                    .shadow(color: CardPalette.navy, radius: 0, x: drop, y: 0)
                    .shadow(color: CardPalette.blue, radius: 0, x: drop, y: 0)
            }
        }
        .position(x: width / 2, y: height * CardLayout.arrowCentreYFraction)
    }

    /// The second symbol on an icon, wherever it is worn.
    private func accentImage(_ accent: (name: String, scale: CGFloat, x: CGFloat,
                                        y: CGFloat, turn: Double),
                             side: CGFloat) -> some View {
        Image(systemName: accent.name)
            .font(.system(size: side * accent.scale, weight: .semibold))
            .rotationEffect(.degrees(accent.turn))
            .offset(x: side * accent.x, y: side * accent.y)
    }

    private func arrowImage(_ side: CGFloat) -> some View {
        Image("SwingArrowRight")
            .resizable()
            .scaledToFit()
            .frame(width: side)
            .foregroundStyle(.white)
    }

    /// Only on cards that touch SHOT. Hard shadows — zero blur, offset south-east.
    private func shotBadge(_ shot: Int) -> some View {
        let side = width * CardLayout.ballSizeFraction
        return ZStack {
            Image("BallVector")
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
                .shadow(color: CardPalette.blue, radius: 0,
                        x: width * CardLayout.ballShadowFraction,
                        y: width * CardLayout.ballShadowFraction)

            percentage(shot)
                .shadow(color: .black, radius: 0,
                        x: width * CardLayout.badgeShadowFraction,
                        y: width * CardLayout.badgeShadowFraction)
        }
        .position(x: width * CardLayout.ballCentreXFraction,
                  y: height * CardLayout.ballCentreYFraction)
    }

    /// The number carries the weight; the sign and the percent sit small beside it.
    private func percentage(_ shot: Int) -> some View {
        let big = width * CardLayout.badgeSizeFraction
        let small = big * 0.5
        // Centred rather than baselined, and only the number is tightened — tracking on
        // the symbols just pushed them off centre.
        return HStack(alignment: .center, spacing: 0) {
            Text(descriptor.setsShot ? "=" : (shot < 0 ? "−" : "+"))
                .font(.custom("AvenirNextCondensed-Heavy", size: small))
            Text("\(abs(shot))")
                .font(.custom("AvenirNextCondensed-Heavy", size: big))
                .tracking(big * CardLayout.badgeTracking)
            Text("%")
                .font(.custom("AvenirNextCondensed-Heavy", size: small))
        }
        .foregroundStyle(.white)
    }
}
