import SwiftUI

/// A card front, drawn rather than exported — so the body recolours per type and the
/// name and percentage are live text.
///
/// Layered back to front exactly as specified: body, text overlay, border stroke, name
/// plate, name, then the SHOT badge.
struct CardFrontView: View {
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
            }
            if let shot = descriptor.shotEffect { shotBadge(shot) }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        // Flattened to one texture. Without it the overlay's blend mode costs an
        // offscreen pass per card, which a fanned hand pays for every frame.
        .grayscale(isDormant ? 1 : 0)
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
        let side = width * CardLayout.iconSizeFraction
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
            } else if let art = descriptor.artwork {
                Image(art.name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * art.scale, height: side * art.scale)
                    .scaleEffect(x: art.mirrored ? -1 : 1)
            } else if let accent = descriptor.accentSymbol {
                ZStack {
                    Image(systemName: descriptor.symbol)
                        .font(.system(size: side, weight: .semibold))
                        .rotationEffect(.degrees(descriptor.symbolRotation))
                    Image(systemName: accent.name)
                        .font(.system(size: side * accent.scale, weight: .semibold))
                        .rotationEffect(.degrees(accent.turn))
                        .offset(x: side * accent.x, y: side * accent.y)
                }
            } else {
                Image(systemName: descriptor.symbol)
                    .font(.system(size: side, weight: .semibold))
            }
        }
        .foregroundStyle(CardLayout.iconTint(for: descriptor.type))
        .modifier(SlashIfNeeded(on: descriptor.isSlashed, side: side,
                                slash: CardLayout.iconShadow(for: descriptor.type)))
        .rotationEffect(.degrees(descriptor.iconRotation))
        .shadow(color: descriptor.id == "behind-the-back"
                    ? .clear : CardLayout.iconShadow(for: descriptor.type),
                radius: 0, x: drop, y: drop)
        .position(x: width / 2,
                  y: height * (CardLayout.iconYFraction + descriptor.iconYAdjust))
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
                    // On the image, not the stack — the hand carries its own.
                    .shadow(color: CardLayout.iconShadow(for: descriptor.type),
                            radius: 0, x: drop, y: drop)
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
        return TightText(text: expanded ? descriptor.detailedEffect : descriptor.printedEffect,
                         font: "AvenirNextCondensed-Bold",
                         size: size,
                         width: width - inset * 2,
                         lineHeight: CardLayout.effectLineHeight,
                         tracking: size * CardLayout.badgeTracking,
                         highlight: "(?i)SHOT\\s*=",
                         highlightColour: CardPalette.gold,
                         highlightShadow: CardPalette.navy,
                         highlightShadowOffset: width * 0.014,
                         namedCards: CardLibrary.namesReferencedInText,
                         nameColour: CardPalette.gold,
                         nameShadow: CardPalette.red)
            .foregroundStyle(effectColour)
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
                .renderingMode(.template)
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
    /// The inner ring, and the name over it.
    ///
    /// Navy on everything but an Intangible, which is navy-bodied — the ring would
    /// disappear into it and the name would be unreadable, so both go the other way.
    private var isNavyBodied: Bool { descriptor.type == .intangible }
    private var ringColour: Color { isNavyBodied ? CardPalette.gold : CardPalette.navy }
    /// The name sits on the gold plate, so it stays navy whatever the body is. The effect
    /// text sits on the body itself, which is why that one turns white on a navy card.
    private var effectColour: Color { isNavyBodied ? .white : CardPalette.navy }
    /// Blue is what the artwork used to carry baked in; only the navy-bodied cards
    /// change it, because blue on navy would not read at all.
    private var namePlateShadow: Color { isNavyBodied ? CardPalette.gold : CardPalette.blue }

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

    private func arrowImage(_ side: CGFloat) -> some View {
        Image("SwingArrowRight")
            .renderingMode(.template)
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
