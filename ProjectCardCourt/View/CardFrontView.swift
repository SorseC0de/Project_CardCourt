import SwiftUI

/// A card front, drawn rather than exported — so the body recolours per type and the
/// name and percentage are live text.
///
/// Layered back to front exactly as specified: body, text overlay, border stroke, name
/// plate, name, then the SHOT badge.
struct CardFrontView: View {
    /// Observed, not just read — otherwise the bench's weight button changes nothing.
    /// Everything about how the words are set — see `CardTextBench`. **One set for all
    /// seven types**; only the two colours in it are asked per card.
    @State private var set = CardTextTuning.shared
    /// Where COMBO and BONUS sit, and how big — see `ExtrasBench`.
    @State private var extras = ExtrasTuning.shared

    let descriptor: CardDescriptor
    /// Width in points. Everything else is a fraction of it, so the card holds together
    /// at any size — a 76pt hand card and a 600pt calibration card are the same drawing.
    let displayWidth: CGFloat
    /// Raised for reading, which is where the longer wording goes.
    var expanded = false
    /// In play but unable to act — drained of colour rather than dimmed, so it still
    /// reads at a glance without looking merely faded.
    var isDormant = false
    /// The locked card behind a combo not done yet: grey, blanked, a question mark on the
    /// plate. See `ComboView`.
    var isBlank = false
    /// Handed the mechanic a reader pressed, when this card is raised to be read. Nil
    /// leaves the words inert — see `CardText`.
    var onKeyword: ((String) -> Void)?
    /// Handed on a raised card: opens its combo scene, and puts the COMBO and BONUS buttons
    /// under its words. Nil leaves them off.
    var onCombo: (() -> Void)?
    /// Handed on a raised card: the BONUS button, and where it is on screen, so the screen
    /// can hang the bonus off it. See `BonusBubble`.
    var onBonus: ((CGPoint) -> Void)?


    /// Everything inside is drawn at raster size; the whole thing is scaled back down
    /// at the end, so `width` still means the size it occupies.
    private var width: CGFloat { displayWidth * CardLayout.rasterScale }
    private var height: CGFloat { width / CardMetrics.aspect }
    private var corner: CGFloat { width * CardLayout.cornerFraction }
    /// **What this card is printed as** — its type, except that the two Injuries are their
    /// own faces. Everything about the printing is asked of this rather than of the type.
    private var face: CardFace { CardFace(of: descriptor) }


    var body: some View {
        ZStack {
            if isBlank {
                Rectangle().fill(CardPalette.gray)
            } else {
                CardBodyFill(face: face,
                             isDormant: isDormant,
                             bandFraction: CardLayout.whistleBandFraction,
                             glossFraction: CardLayout.whistleGlossFraction)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            }

            // **The icon's plate, at the bottom of the drawing.** Everything else on the
            // card prints on top of it — the court, the wash the words are read on, the
            // name banner — so the circle can be made as big as it likes without
            // swallowing anything. Only its subject comes back over the top, below.
            if face.type == .varena {
                // **A Varena's court is its art**: over the inner ring and the name banner,
                // under the wash the words are read on, the words, and the name.
                border
                namePlate(letters: false)
                varenaArt
                textOverlay
                effectText
                footMarks
                namePlate(banner: false)
            } else {
                if passArt == nil { icon }
                if !isBlank { textOverlay }
                border
                // Every card carries its name. Which side of the icon's plate the banner is
                // drawn on is the question — `plateOverIcon` on the bench.
                if !set.plateOverIcon { namePlate(letters: !artOverName) }
                // The three basic passes say the rest with an icon alone; everything else
                // gets its words.
                if let art = passArt {
                    passMark(art)
                } else if !isBlank {
                    effectText
                    footMarks
                }
                if set.plateOverIcon { namePlate(letters: !artOverName) }
                // **What the icon puts in front of the plate.** The circle belongs behind the
                // banner and the thing standing in it belongs over it — the ball on a Pass,
                // the ankle on a Move — so the drawing is in two layers and the plate is
                // printed between them. Nothing is drawn until that second layer exists; see
                // `Card.typeIconFront`.
                if passArt == nil, hasIconFront, !isBlank { iconFront }
                // A ball spills out of its plate and over the banner, but never over the name.
                if artOverName { namePlate(banner: false) }
            }
            // **A three says so on the icon.** Bottom-right of the big drawing, over
            // everything it stands on, so a card worth an extra point is one glance rather
            // than a line of text.
            if descriptor.isThree { threeMark }
            // **A card that shoots says so on the icon too**, in place of the words.
            if descriptor.takesShot, !isBlank { shootMark }
            // The corner badge is for a card whose number is not already at its foot.
            // Nothing wears one today; it is kept because a type may yet want the number
            // up top rather than down there.
            if let shot = descriptor.shotEffect, footBallShot == nil {
                shotBadge(shot)
            }
            if isBlank { lockedMarks }
            if hasExtras { extrasButtons }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        // Flattened to one texture. Without it the overlay's blend mode costs an
        // offscreen pass per card, which a fanned hand pays for every frame.
        //
        // **Except while it is raised.** A `drawingGroup` renders its subtree into an
        // image, and an image takes no taps — so a keyword inside one cannot be pressed.
        // A raised card is one card rather than a fan of them, so the pass it costs is
        // affordable and the words become live.
        .modifier(FlattenUnlessRead(live: expanded && (onKeyword != nil || showsExtras)))
        .scaleEffect(1 / CardLayout.rasterScale)
        .frame(width: displayWidth, height: displayWidth / CardMetrics.aspect)
    }

    // MARK: - Combo and bonus

    private enum Extras {
        /// The buttons' lettering, as a share of the card's width.
        static let size: CGFloat = 0.06
        /// Between the row and the top of the text area, as a share of the card's width.
        static let gap: CGFloat = 0.02
        /// Each button's drop, as a share of its lettering.
        static let drop: CGFloat = 0.2
        /// **What the words need to be readable.** A card drawn at least this wide says
        /// COMBO and BONUS whether or not it has been raised; the fan shows the shapes
        /// alone, so nothing pops in when one is lifted out of it.
        static let wordsFrom: CGFloat = 110
    }

    /// Whether the buttons say what they are, rather than standing as shapes.
    private var showsExtraWords: Bool { expanded || displayWidth >= Extras.wordsFrom }

    private var combos: [Combo] { Combo.involving(descriptor) }

    /// Whether the card has a combo or a bonus at all. The buttons' shapes are printed on
    /// every size of it, so raising one does not make them pop in.
    private var hasExtras: Bool {
        guard !isBlank else { return false }
        return !combos.isEmpty || !descriptor.bonusLines.isEmpty
    }

    /// Raised, with somewhere for a press to go.
    private var showsExtras: Bool {
        guard expanded, !isBlank else { return false }
        return (onCombo != nil && !combos.isEmpty)
            || (onBonus != nil && !descriptor.bonusLines.isEmpty)
    }

    /// **COMBO and BONUS, over the words.** Centred alone, side by side together. Words
    /// only on a raised card; a card in the hand shows the shapes.
    private var extrasButtons: AnyView {
        AnyView(Group {
            let size = width * Extras.size * extras.scale
            let across = width * set.overlayWidth
            let textTop = height * (1 - CardLayout.textOverlayBottomFraction)
                - across * CardLayout.textOverlayAspect
            // **Printed as the card is.** COMBO wears the body with the inner ring under it;
            // BONUS wears the name plate, its drop and its lettering — so both read as parts
            // of this card rather than as two buttons the app put on top of it.
            return VStack(spacing: size * 0.4) {
                if !combos.isEmpty {
                    extrasCapsule("COMBO", size: size, fill: skin.plate,
                                  drop: namePlateShadow, ink: skin.nameBottom) { onCombo?() }
                }
                if !descriptor.bonusLines.isEmpty {
                    extrasCapsule("BONUS", size: size, fill: skin.plate,
                                  drop: namePlateShadow,
                                  ink: skin.nameBottom) {}
                        // Where it is on screen, so the bubble hangs off the button itself.
                        .overlay {
                            if let onBonus {
                                GeometryReader { button in
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            let frame = button.frame(in: .global)
                                            onBonus(CGPoint(x: frame.midX, y: frame.minY))
                                        }
                                }
                            }
                        }
                }
            }
            .allowsHitTesting(showsExtras)
            // **Hung from the top.** The tuned spot is the row's highest point, so a second
            // button hangs under the first rather than shifting the pair off it.
            .frame(width: width, height: height, alignment: .top)
            .offset(x: width * extras.x,
                    y: textTop - size * 0.9 - width * Extras.gap + height * extras.y)
        })
    }

    private func extrasCapsule(_ word: String, size: CGFloat, fill: Color, drop: Color,
                               ink: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(word)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .tracking(size * 0.08)
                .foregroundStyle(ink)
                .opacity(showsExtraWords ? 1 : 0)
                .padding(.horizontal, size * 0.8)
                .padding(.vertical, size * 0.3)
                .background(Capsule().fill(fill)
                    .shadow(color: drop, radius: 0,
                            x: size * Extras.drop, y: size * Extras.drop))
        }
        .buttonStyle(.plain)
    }

    /// A combo not done yet: everything under a black wash, and a white question mark
    /// where the plate's shadow falls, printed over the wash.
    private var lockedMarks: AnyView {
        AnyView(Group {
            let side = width * CardLayout.iconSizeFraction * set.iconScale
            let drop = side * 0.04
            return ZStack {
                Color.black.opacity(0.66)
                Text("?")
                    .font(.system(size: side * 0.5, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 0, x: drop, y: drop)
                    .position(x: width / 2,
                              y: height * (set.iconTop + descriptor.iconYAdjust)
                                  + side * (0.5 - CardLayout.iconRingInset))
            }
            .frame(width: width, height: height)
        })
    }

    /// Flattens the card to one texture, unless its words are meant to be pressed.
    ///
    /// A `drawingGroup` draws its subtree into an image, and an image takes no taps. A
    /// fan of cards needs the flattening — the body's blend mode costs an offscreen pass
    /// each, every frame — and a single raised card does not.
    private struct FlattenUnlessRead: ViewModifier {
        let live: Bool

        @ViewBuilder func body(content: Content) -> some View {
            if live { content } else { content.drawingGroup() }
        }
    }

    private enum PassArt { case swingRight, swingLeft, skip, backPass }

    /// Only the three basic passes replace their text with a mark. Behind-the-Back has a
    /// condition worth reading, so it keeps its words.
    private var passArt: PassArt? {
        switch descriptor.id {
        case "swing-right": return .swingRight
        case "swing-left":  return .swingLeft
        case "skip-pass":   return .skip
        // **Its own arrow, like the other three.** Left out of this list, it fell through
        // to the type icon — and then took the Pass subject over the top of its arrow.
        case "behind-the-back": return .backPass
        default:            return nil
        }
    }

    private var icon: AnyView {
        AnyView(Group {
            let side = width * CardLayout.iconSizeFraction * set.iconScale
            let drop = width * set.iconDrop
            Group {
                if let copies = descriptor.iconRepeat, let art = descriptor.artwork {
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
            .foregroundStyle(CardLayout.iconTint(for: face))
            // The *drawn* side, not the nominal one. `SlashedMark` frames its content and
            // masks against that frame, so a drawing bigger than the icon slot — every piece
            // of artwork carries its own multiplier — was being cut off at the slot's edge.
            .modifier(SlashIfNeeded(on: descriptor.isSlashed,
                                    side: side * (descriptor.artwork?.scale ?? 1),
                                    slash: set.iconShadeInk(for: face)))
            .rotationEffect(.degrees(descriptor.iconRotation))
            // **The plate the subject stands in, recoloured by role** — the circle, the court
            // lines across it and the shadow those lines throw. Swapped on the GPU rather than
            // kept as a set of recoloured drawings, so no art is re-cut for a theme. A plate
            // that is nobody else's shape — a Clamp's purple and azure — is left alone.
            // See `CardSkin.plateSwaps(for:)`.
            .paletteSwap(CardSkin.plateSwaps(for: face))
            .shadow(color: skin.iconShade ?? set.iconShadeInk(for: face),
                    radius: 0, x: drop, y: drop)
            // **Placed by the top of its circle, not by its centre or its frame**, because
            // what the number has to hold is how far the icon disappears behind the name
            // plate. Anchored at the centre, every change of `iconScale` moved the top and
            // changed the cut; anchored at the frame, the clear band every type icon carries
            // around its circle counted as part of the drawing.
            .position(x: width / 2,
                      y: height * (set.iconTop + descriptor.iconYAdjust)
                          + side * (0.5 - CardLayout.iconRingInset))
        })
    }

    /// The icon's front layer, drawn over the name plate and lined up with the icon
    /// underneath it exactly — same size, same anchor, same nudges.
    /// Whether this type's front layer has been drawn yet. The model only names it — an
    /// asset catalog is the view's business — so a type without one keeps its whole icon
    /// behind the banner and nothing has to be switched on.
    private var hasIconFront: Bool { UIImage(named: frontArt) != nil }

    /// **A Variaball's ball goes over the name banner and under the name.** Every ball is
    /// drawn to spill out of its plate that way.
    private var artOverName: Bool { face.type == .variaball && !isBlank }

    /// **What stands in the plate.** A Variaball with a drawing of its own wears it — drawn
    /// on the Variaball plate's own artboard, so every ball is the same size — and every
    /// other card wears its type's.
    private var frontArt: String {
        let ball = "Ball-\(descriptor.id)"
        return face.type == .variaball && UIImage(named: ball) != nil ? ball : descriptor.artworkFront
    }

    private var iconFront: AnyView {
        AnyView(Group {
            let side = width * CardLayout.iconSizeFraction * set.iconScale
            let drop = width * set.iconDrop
            return Image(frontArt)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
                // The same drop the plate behind it takes — a ball spilling out of its circle
                // with a different shadow under it reads as two drawings.
                .shadow(color: skin.iconShade ?? set.iconShadeInk(for: face),
                        radius: 0, x: drop, y: drop)
                .position(x: width / 2,
                          y: height * (set.iconTop + descriptor.iconYAdjust)
                              + side * (0.5 - CardLayout.iconRingInset))
        })
    }

    /// **A Varena's own art**: the court, drawn whole where the icon would be, with no plate
    /// behind it.
    private var varenaArt: AnyView {
        AnyView(Group {
            let side = width * CardLayout.iconSizeFraction * set.iconScale
            return Image(descriptor.artwork?.name ?? "ISO_Court")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: width * VarenaArt.width)
                .position(x: width / 2,
                          y: height * (set.iconTop + descriptor.iconYAdjust - VarenaArt.lift)
                              + side * (0.5 - CardLayout.iconRingInset))
        })
    }

    private enum VarenaArt {
        /// How wide the court is drawn, as a share of the card's width.
        static let width: CGFloat = 0.9
        /// How far above the icon's place it sits, as a share of the card's height.
        static let lift: CGFloat = 0.06
    }

    /// Where a mark sits on the plate's rim, from the icon's middle. `side` is the icon's.
    private func rimOffset(_ side: CGFloat) -> CGSize {
        let angle = CardLayout.markRimAngle * .pi / 180
        return CGSize(width: side * CardLayout.markRimRadius * CGFloat(cos(angle)),
                      height: side * CardLayout.markRimRadius * CGFloat(sin(angle)))
    }

    /// The three's hand, bottom-left on the plate's rim. Bottom-right is the shoot mark's,
    /// which every shooting card wears, so it never moves.
    private var threeMark: AnyView {
        AnyView(Group {
            let side = width * CardLayout.iconSizeFraction * set.iconScale
            return ThreeHandMark(width: side * CardLayout.threeMarkShare,
                                 tint: CardPalette.lightBlue,
                                 shadow: CardPalette.blue,
                                 shadowOffset: width * CardLayout.threeMarkDrop)
                .position(x: width / 2 - rimOffset(side).width,
                          y: height * (set.iconTop + descriptor.iconYAdjust)
                              + side * (0.5 - CardLayout.iconRingInset)
                              + rimOffset(side).height)
        })
    }

    /// **The ball at the foot of the card, and nothing else.**
    ///
    /// It used to be a row: what the card is worth, what it makes you do, whether it
    /// shoots. The rest have gone — a card that says Draw in words does not also need a
    /// picture of it, and a row of small drawings under a full-colour icon was two
    /// pictures arguing. What is left is the one thing the words cannot say as quickly:
    /// **the number**.
    private var footMarks: AnyView {
        AnyView(Group {
            let side = width * set.footSize
            if let ball = footBallShot {
                VStack {
                    Spacer()
                    footBall(ball, side: side * set.scale(of: .ball))
                        .tutorialTarget(reportsBadge ? .cardBadge(descriptor.id) : nil)
                        .shadow(color: set.footShadeInk(for: face), radius: 0,
                                x: width * set.footDrop, y: width * set.footDrop)
                        .padding(.bottom, height * set.footBottom)
                }
            }
        })
    }

    /// What a pass is worth, when it is a pass. Everything else keeps its ball in the
    /// corner, where there is room for it above the words.
    /// **Every type whose number lands somewhere.** Passes and Special Moves put it on
    /// the man, Game Breaks on the possession, Clamps on whoever gets the ball next —
    /// see `Card.shotEffect`, which is the one place that is decided.
    private var footBallShot: Int? { descriptor.shotEffect }
    @Environment(\.tutorialReportsBadge) private var reportsBadge

    /// Whether there is a mark at the foot — which is what the words lift for.
    private var hasFootMarks: Bool { footBallShot != nil }

    /// The pictures this card's words call for, in the order it says them and without
    /// repeats — a card that says Draw twice is still one Draw to look at.
    private var footGlyphs: [String] {
        var found: [String] = []
        for run in Marked.runs(of: descriptor.printedEffect) where run.ink == .keyword {
            let word = String(run.text.prefix(while: { $0 != " " }))
            guard let art = CardLayout.keywordGlyphs[word], !found.contains(art) else {
                continue
            }
            found.append(art)
        }
        return found
    }

    /// What a pass is worth. The same ball the corner badge draws, sized to the row it is
    /// standing in.
    ///
    /// **The number is laid over the ball and is meant to run past it.** That is the mark:
    /// a ball with a figure across it, not a figure fitted inside a ball. The ball alone
    /// sets the size of the slot — `frame` below — so a long number never moves anything
    /// else on the card.
    private func footBall(_ shot: Int, side: CGFloat) -> AnyView {
        AnyView(Group {
            ZStack {
                Image("BallVector")
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)
                // **Its own size, never the ball's.** Offered the ball's width it truncates,
                // which is what was eating the sign off a Clamp's −25%. Nothing here should
                // ever be made to fit: see above.
                percentage(shot, across: side)
                    .fixedSize()
                    .shadow(color: descriptor.type == .clamp ? CardPalette.orange : .black,
                            radius: 0,
                            x: width * CardLayout.badgeShadowFraction,
                            y: width * CardLayout.badgeShadowFraction)
            }
            .frame(width: side, height: side)
        })
    }

    /// Some dribbles no longer have the word in their name, so the family needs a face
    /// rather than a spelling.
    private func dribbleMark(_ row: CGFloat) -> AnyView {
        AnyView(Group {
            // A symbol's font size is its whole height, where the drawn marks beside it are a
            // box the drawing fits inside — so the same number comes out a good deal bigger.
            let side = row * CardLayout.dribbleSymbolShare
            return Image(systemName: CardLayout.dribbleSymbol)
                .font(.system(size: side, weight: .heavy))
                .foregroundStyle(effectColour)
                .frame(width: row, height: row)
        })
    }

    /// **It shoots** — or it dunks — bottom-right on the plate's rim, on every card that
    /// shoots, so it is always in the same place. Printed the way the three's hand is, a size
    /// down from it.
    private var shootMark: AnyView {
        AnyView(Group {
            let side = width * CardLayout.iconSizeFraction * set.iconScale
            let mark = side * CardLayout.shootMarkShare
            let drop = width * CardLayout.threeMarkDrop
            return Image(descriptor.special?.dunks == true ? "DunkIcon" : "ShootIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: mark, height: mark)
                .foregroundStyle(CardPalette.lightBlue)
                .shadow(color: CardPalette.blue, radius: 0, x: drop, y: drop)
                .position(x: width / 2 + rimOffset(side).width,
                          y: height * (set.iconTop + descriptor.iconYAdjust)
                              + side * (0.5 - CardLayout.iconRingInset)
                              + rimOffset(side).height)
        })
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

    private var effectText: AnyView {
        AnyView(Group {
            let size = width * set.size
            let inset = width * set.inset
            return CardText(text: expanded ? descriptor.detailedEffect
                                          : descriptor.printedEffect,
                            font: CardFont.name(set.weight),
                            size: size,
                            lineHeight: set.lineHeight,
                            tracking: size * set.tracking,
                            maxLines: set.maxLines,
                            minScale: set.minScale,
                            ink: effectColour,
                            highlight: set.highlight,
                            face: face,
                            // **Only where a finger can reach it.** A card in the hand is
                            // flattened to a texture and takes no taps at all; one raised to
                            // be read is not, which is the only size the words can be
                            // pressed at anyway.
                            onKeyword: expanded ? onKeyword : nil)
                .frame(width: width - inset * 2, alignment: .leading)
                .position(x: width / 2,
                          y: height * (set.y - (hasFootMarks ? set.footLift : 0)))
        })
    }

    // MARK: - Layers

    /// Bottom-centre, blended into the body. SwiftUI has no vivid light, so hard light —
    /// the nearest of the two the spec allows.
    /// The court printed on the body, and the wash over it that the words are read on.
    ///
    /// **One box, laid out once.** The wash is the overlay's own area and nothing else —
    /// giving it a frame of its own is how the two end up a few points apart on a card
    /// nobody thinks to check.
    private var textOverlay: AnyView {
        AnyView(Group {
            let across = width * set.overlayWidth
            let down = across * CardLayout.textOverlayAspect
            return VStack {
                Spacer()
                ZStack {
                    Image("CardTextOverlay")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(skin.overlay)
                        .blendMode(CardLayout.blend(for: face))
                        .opacity(Double(set.overlayWash))
                    // Over the court rather than under it: the lines are as much of what the
                    // words have to be read against as the body colour is.
                    if set.panel {
                        RoundedRectangle(cornerRadius: width * set.panelCorner,
                                         style: .continuous)
                            .fill(.black)
                            .opacity(Double(set.panelDark))
                    }
                }
                .frame(width: across, height: down)
                .padding(.bottom, height * CardLayout.textOverlayBottomFraction)
            }
        })
    }

    /// Carries its own radius, so tuning it cannot disturb the card's.
    /// The inner ring, and the text over the body.
    ///
    /// Two different questions. The ring only changes on a card whose body is the same
    /// navy the ring is drawn in, which is Intangibles alone. The text changes on any card
    /// dark enough to swallow navy lettering, which is Intangibles and Game Breaks both.
    /// What this card is printed in. One table, asked once — see `CardInk`.
    private var ink: CardInk { CardInk.of(face) }
    private var skin: CardSkin { CardSkin.of(face) }
    private var ringColour: Color { skin.ring }
    /// The name sits on the gold plate, so it stays navy whatever the body is. This is the
    /// effect text, which sits on the body itself.
    private var effectColour: Color { skin.text }
    private var namePlateShadow: Color { skin.plateShade }

    /// **The one line round the card.** Its weight is per type — see
    /// `CardTextStyle.ringWidth`, which says why the same number does not look the same
    /// on a dark body as on a light one.
    private var border: AnyView {
        AnyView(Group {
            RoundedRectangle(cornerRadius: width * CardLayout.strokeCornerFraction,
                             style: .continuous)
                .strokeBorder(ringColour,
                              lineWidth: width * CardLayout.strokeFraction
                                  * set.ringWeight(for: face))
                .padding(width * CardLayout.strokeInsetFraction)
                .overlay(alignment: .bottomTrailing) { patch }
        })
    }

    /// **The patch**, over the inner ring and pinned to its bottom-trailing corner. Every
    /// corner is its own radius — see `CardTextStyle.patch`, which is where all of it is
    /// dialled. Off until something is put in it.
    private var patch: AnyView {
        AnyView(Group {
            if set.patch {
                UnevenRoundedRectangle(
                    topLeadingRadius: width * set.patchTopLeading,
                    bottomLeadingRadius: width * set.patchBottomLeading,
                    bottomTrailingRadius: width * set.patchBottomTrailing,
                    topTrailingRadius: width * set.patchTopTrailing,
                    style: .continuous)
                    .fill(ringColour)
                    .frame(width: width * (set.patchNamed ? set.patchNamedWidth : set.patchWidth),
                           height: width * set.patchHeight)
                    // **B says what the card is.** The type's own name, set in the game's
                    // lettering and inked to read on the patch — which is the ring's colour,
                    // so the name is the same colour as the badge up top said it was.
                    .overlay {
                        if set.patchNamed {
                            ActionText(runs: [.init(face.type.rawValue.uppercased(),
                                                    ink: CardSkin.ink(on: ringColour),
                                                    drop: namePlateShadow)],
                                       size: width * set.patchNamedSize)
                        }
                    }
                    .offset(x: width * set.patchX, y: width * set.patchY)
            }
        })
    }

    /// **Two inks, per face.** A name in one colour is that colour top and bottom, which
    /// is a gradient of a colour against itself — so there is no separate single-ink case
    /// to keep in step with this one.
    private func nameFill(size: CGFloat) -> LinearGradient {
        .hardSplit(skin.nameTop, skin.nameBottom,
                   in: UIFont(name: "AvenirNextCondensed-Heavy", size: size))
    }

    /// The plate carries its own curve on the left, so it only sits right at one Y.
    /// **The name banner, and the name on it.** Either can be left out, so art can be drawn
    /// between the two — see `body`. A banner left out still holds its place, so the name
    /// sits exactly where it does with the banner under it.
    private func namePlate(banner: Bool = true, letters: Bool = true) -> AnyView {
        AnyView(Group {
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
                        // The drawing is one flat shape, so its colour is a tint rather than
                        // anything baked in — see `CardTextStyle.plateFill`.
                        .foregroundStyle(skin.plate)
                        .shadow(color: namePlateShadow, radius: 0, x: 0,
                                y: plateWidth * CardLayout.namePlateShadowFraction)
                        .opacity(banner ? 1 : 0)
                    let nameSize = width * CardLayout.nameSizeFraction
                    SmallCapsText(text: descriptor.name,
                                  font: "AvenirNextCondensed-Heavy",
                                  size: nameSize,
                                  capHeight: CardLayout.nameCapHeight,
                                  tracking: nameSize * CardLayout.nameTracking)
                        // **One ink or two.** Two is the wordmark's own trick: the fill
                        // changes colour at a line drawn across the capitals rather than
                        // walking between them, so it reads as lettering in two inks and not
                        // as type with a gradient on it. See `LinearGradient.hardSplit`,
                        // which wants the face itself — the split is measured against the cap
                        // band and lands under the letters entirely without it.
                        .foregroundStyle(nameFill(size: nameSize))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .padding(.horizontal, width * 0.10)
                        .rotationEffect(.degrees(CardLayout.nameRotation))
                        .offset(y: height * CardLayout.nameTextYFraction)
                        .opacity(letters ? 1 : 0)
                }
                Spacer()
            }
            .padding(.top, height * CardLayout.nameOverlayYFraction)
        })
    }

    /// One arrow asset does three of the four; Skip Pass borrows a symbol.
    ///
    /// Shadows are applied *after* the flips and rotations, so they stay put in the card's
    /// own space rather than turning with the art.
    @ViewBuilder
    private func passMark(_ art: PassArt) -> AnyView {
        AnyView(Group {
            let side = width * CardLayout.arrowSizeFraction
            let drop = width * CardLayout.arrowShadowOffsetFraction

            // **A colour each, and one drop under all four.** White arrows were drawn for
            // bodies that were the type's colour; on paper they need the colour themselves,
            // and telling them apart at a glance is what these cards do instead of using
            // words.
            //
            // **Blue right, red left, and purple for both the others** — which is not a clash.
            // The swings are the two basic passes; across and behind-the-back are the
            // alternatives to them, and purple is those two colours mixed. Two marks sharing
            // it says they are the same kind of thing.
            //
            // Theme A only. B and C still carry the white they were drawn with, until there is
            // a reading of what they should be on tan and on the type's own colour.
            let plain = CardTheme.current != .a
            let lift = width * (art == .skip ? set.skipLift : set.backPassLift)

            return Group {
                switch art {
                case .swingRight:
                    arrowImage(side, ink: plain ? .white : CardPalette.blue)
                        .shadow(color: CardPalette.darkBlue, radius: 0, x: 0, y: drop)
                case .swingLeft:
                    arrowImage(side, ink: plain ? .white : CardPalette.red)
                        .scaleEffect(x: -1)
                        .shadow(color: CardPalette.darkBlue, radius: 0, x: 0, y: drop)
                case .skip:
                    Image(systemName: "chevron.right.dotted.chevron.right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width * CardLayout.skipIconFraction)
                        .foregroundStyle(plain ? .white : CardPalette.purple)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: CardPalette.darkBlue, radius: 0, x: 0, y: drop)
                case .backPass:
                    // Flipped upright and smaller. The doubled edge it used to wear was two
                    // shadows standing in for a colour it did not have; it has one now.
                    arrowImage(side * CardLayout.backPassArrowScale,
                               ink: plain ? .white : CardPalette.purple)
                        // Both flips before the shadow, so the shadow stays east.
                        .scaleEffect(x: -1, y: -1)
                        .shadow(color: CardPalette.darkBlue, radius: 0, x: drop, y: 0)
                }
            }
            .position(x: width / 2,
                      y: height * CardLayout.arrowCentreYFraction
                          - (art == .skip || art == .backPass ? lift : 0))
        })
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

    private func arrowImage(_ side: CGFloat, ink: Color = .white) -> AnyView {
        AnyView(Group {
            Image("SwingArrowRight")
                .resizable()
                .scaledToFit()
                .frame(width: side)
                .foregroundStyle(ink)
        })
    }

    /// Only on cards that touch SHOT. Hard shadows — zero blur, offset south-east.
    private func shotBadge(_ shot: Int) -> AnyView {
        AnyView(Group {
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
        })
    }

    /// The number carries the weight; the sign and the percent sit small beside it.
    /// **Sized to the ball it is printed on**, not to the card — the corner badge and the
    /// one down in the row of marks are two different sizes of the same ball.
    private func percentage(_ shot: Int,
                            across ball: CGFloat = 0) -> some View {
        let side = ball == 0 ? width * CardLayout.ballSizeFraction : ball
        let big = side * (CardLayout.badgeSizeFraction / CardLayout.ballSizeFraction)
        let small = big * 0.5
        // Centred rather than baselined, and only the number is tightened — tracking on
        // the symbols just pushed them off centre.
        return HStack(alignment: .center, spacing: 0) {
            // **An equals is set at the number's size.** At a sign's, its two bars close up
            // under the drop into one, and a SHOT = read as a minus.
            Text(descriptor.setsShot ? "=" : (shot < 0 ? "−" : "+"))
                .font(.custom("AvenirNextCondensed-Heavy",
                              size: descriptor.setsShot ? big : small))
            Text("\(abs(shot))")
                .font(.custom("AvenirNextCondensed-Heavy", size: big))
                .tracking(big * CardLayout.badgeTracking)
            Text("%")
                .font(.custom("AvenirNextCondensed-Heavy", size: small))
        }
        // **A Clamp's number is gold, not white.** It is the one percentage on a card
        // that does not land on the man holding it — it lands on whoever gets the ball
        // next — and a second colour is what says so without a sentence.
        .foregroundStyle(descriptor.type == .clamp ? CardPalette.gold : .white)
    }
}
