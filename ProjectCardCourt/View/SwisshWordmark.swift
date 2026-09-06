import SwiftUI

/// The game's name, drawn rather than typed.
///
/// The lettering is `ActionText`'s — the same ramp from loud to quiet every call on the
/// floor uses — and everything else here is the treatment over it:
///
/// * **A fill that is two colours, not a blend.** The stops sit on top of one another at
///   `split`, so the word is white down to four-fifths of its height and blue below it.
///   A real gradient would read as a lighting effect; this reads as a two-colour mark.
///   Applied by masking one gradient with the whole word rather than by colouring each
///   letter, or the split would land at a different height on every letter — the taper
///   makes them different sizes.
/// * **Two strokes.** Text has no stroke in SwiftUI, so each is a ring of copies drawn
///   behind the fill: a thin white one, and a thick navy one around that. Rasterised
///   once, because that is thirty-odd copies of the same word.
struct SwisshWordmark: View {
    var text = "Swissh"
    var size: CGFloat = Mark.size
    var taper: CGFloat = 0.55
    /// All three on the bench — see the preview at the foot of this file.
    var split: CGFloat = Mark.split
    var thin: CGFloat = Mark.thin
    var thick: CGFloat = Mark.thick
    /// The ball on the i: how big, and where against that letter's top-centre.
    var ballScale: CGFloat = Mark.ball
    var ballX: CGFloat = Mark.ballX
    var ballY: CGFloat = Mark.ballY
    /// Two Swing Right arrows over by the first S, in the same layer as the lettering.
    var arrows: [Arrow] = Mark.arrows
    /// The S is drawn by the two arrows rather than by the font, so the letter itself is
    /// left out — but its space is kept, or removing it would resize the word and slide
    /// everything after it along.
    var blanked: Set<Int> = Mark.blanked
    /// The arrows' own stroke shares.
    ///
    /// Separate from the letters', because the arrow has cuts in it and the letters do
    /// not. A ring closes any gap narrower than twice its radius, so the white pass —
    /// 1.2pt out in every direction at the word's own setting — fills the cuts in before
    /// the navy underneath can show through them. Take this to nothing and the cuts
    /// survive at whatever width the art already has.
    var arrowThin: CGFloat = Mark.arrowThin
    var arrowThick: CGFloat = Mark.arrowThick

    enum Mark {
        /// Where the fill stops being white, as a share of the word's height.
        static let split: CGFloat = 0.8
        /// Both as shares of the letter size, so the mark holds together at any scale.
        static let thin: CGFloat = 0.010
        static let thick: CGFloat = 0.100
        static let drop: CGFloat = 0.10
        /// How many copies make a ring.
        ///
        /// Twenty was more than the shape needs and more than the bench could carry: the
        /// mark is six letters and two arrows drawn once per point per pass, so every
        /// slider drag was re-rendering some three hundred views a frame. At these radii
        /// each copy overlaps its neighbours several times over, and twelve reads
        /// identically.
        static let points = 12

        /// The ball over the i, as a share of that letter's own width, and where it sits
        /// from the letter's top-centre in shares of its own size.
        static let ball: CGFloat = 1.000
        static let ballX: CGFloat = -0.033
        static let ballY: CGFloat = 0.900

        /// The word's own size, so the bench and the view start from one number.
        static let size: CGFloat = 100

        /// The arrows' strokes.
        ///
        /// Navy is **the letters' own number** — the mark has one navy edge and the
        /// arrows are part of it, not a thing beside it. It still tapers with the arrow's
        /// scale, exactly as the letters' does with theirs, so a smaller arrow gets a
        /// proportionally smaller edge the way a smaller letter does.
        ///
        /// White is its own, and much thinner: the arrow has cuts in it and the letters
        /// do not, and a ring closes any gap narrower than twice its radius.
        static let arrowThin: CGFloat = 0
        static let arrowThick: CGFloat = thick

        /// The first S, which the arrows are standing in for.
        static let blanked: Set<Int> = [0]

        /// Where the pair start out. On the bench, one knob each.
        static let arrows: [Arrow] = [
            Arrow(turn: 0, scale: 1.000, x: 0.075, y: -0.300),
            Arrow(turn: -180, scale: 0.667, x: -0.170, y: 0.150),
        ]
    }

    /// One of the two arrows, and everything about where it sits. Anchored to the first
    /// letter rather than to the view, so it follows the word when the size changes.
    struct Arrow: Equatable {
        var turn: Double = 0
        /// The arrow's width, as a share of the letter size.
        var scale: CGFloat = 0.5
        /// From the first letter's centre, in shares of the letter size.
        var x: CGFloat = 0
        var y: CGFloat = 0
        /// The second one is the first one turned around.
        var mirrored = false
    }

    @State private var letters: [Int: CGRect] = [:]

    /// Where the split actually falls in the *frame*, as against in the letters.
    ///
    /// A line of text is taller than its letters: above the caps there is nothing, and
    /// below the baseline there is a descender's worth of nothing, and "Swissh" has no
    /// descenders to put in it. Four-fifths of the frame lands under the ink, which is
    /// why the mark came out white — the blue half was painted on empty space.
    ///
    /// So `split` is read against the cap band, baseline to cap height, and mapped back
    /// onto the frame here. Measured off the face rather than guessed, because a
    /// different font moves it.
    private var fill: LinearGradient {
        .hardSplit(.white, CardPalette.lightBlue, at: split,
                   in: UIFont(name: Chrome.display, size: size))
    }

    var body: some View {
        // **One frame, one origin, one rule.**
        //
        // The word is the ground; the arrows stand outside it, so the frame is grown to
        // the left by exactly as far as they reach and *everything* positioned from here
        // adds `bleed` to its x. The letter passes hang off the trailing edge — the edge
        // that did not move — so they stay put.
        //
        // This was two bases before: the outline passes measured against one frame and
        // the fill against another, which put the arrows down twice, in two places.
        word(.clear)
            .coordinateSpace(name: ActionText.space)
            .onPreferenceChange(LetterFrames.self) { letters = $0 }
            .padding(.leading, bleed)
            // Navy outermost, white inside it, the fill on top. Each letter pass is the
            // word drawn again with an outline behind it and its own glyph left out —
            // `ActionText` handles the ring, so the radius tapers with the letters.
            .overlay(alignment: .trailing) { outlined(CardPalette.navy, share: thick) }
            .overlay { swings(outline: CardPalette.navy, share: arrowThick) }
            .overlay(alignment: .trailing) { outlined(.white, share: thin) }
            .overlay { swings(outline: .white, share: arrowThin) }
            .overlay { face }
            .overlay { ball }
            .fixedSize()
            // One shadow for the assembly rather than one per copy, which would be forty
            // of them stacked into a smear.
            .compositingGroup()
            .shadow(color: CardPalette.navy, radius: 0,
                    x: size * Mark.drop, y: size * Mark.drop)
    }

    /// The two-colour fill, over the word.
    ///
    /// **The word holds the size and the gradient is laid into it**, rather than the
    /// gradient being a sibling with a mask on it. A `LinearGradient` has no size of its
    /// own; asked for one — which `fixedSize` above does — it answers ten by ten, so as a
    /// sibling it collapsed to a dot behind the letters and the fill vanished. As an
    /// overlay it is handed the word's own frame and the split lands where it should.
    /// How far the arrows reach past the word's own left edge.
    ///
    /// The fill is laid into the word's frame, and the arrows stand outside it — so the
    /// gradient stopped at the `w` and everything left of it went unpainted. Worked out
    /// from where the arrows actually are rather than dialled: their centres come off the
    /// first letter's box and their widths off `scale`, so moving one moves this with it.
    private var bleed: CGFloat {
        guard let first = letters[0] else { return 0 }
        let left = arrows.map { first.midX + size * $0.x - size * $0.scale / 2 }.min() ?? 0
        return max(0, -left)
    }

    private var face: some View {
        // **Letters and arrows masked together, not filled separately.** One gradient over
        // the union of the two shapes means the split runs straight through an arrow the
        // way it runs through an S — fill them apart and an arrow crossing into the blue
        // half shows a seam, which is the one thing that gives away that it was laid on
        // rather than drawn in.
        //
        // Nothing special is done to reach the arrows: the frame already includes them.
        fill.mask {
            ZStack(alignment: .trailing) {
                word(.white)
                swings()
            }
        }
    }

    /// The word with no treatment on it at all — the shape everything else is built from.
    private func word(_ ink: Color) -> some View {
        ActionText(text, size: size, ink: ink, drop: .clear, taper: taper,
                   blanked: blanked)
    }

    /// One stroke. The glyph itself is drawn in nothing — only the ring behind it shows,
    /// so the layer is an outline and not a second copy of the word.
    private func outlined(_ ink: Color, share: CGFloat) -> some View {
        ActionText(text, size: size, ink: .clear, drop: .clear, taper: taper,
                   outline: (ink: ink, share: share),
                   blanked: blanked)
    }

    /// The pair of arrows.
    ///
    /// Called three times, once for each pass of the mark: given an ink and a share it
    /// draws their **outline** instead of them, using the same ring the letters wear at a
    /// radius of the arrow's own width. So the arrows take the strokes rather than
    /// sitting over them — they are part of the word, not a decal on it.
    @ViewBuilder private func swings(outline ink: Color? = nil,
                                     share: CGFloat = 0) -> some View {
        if let first = letters[0] {
            ForEach(arrows.indices, id: \.self) { index in
                let arrow = arrows[index]
                let side = size * arrow.scale
                let radius = side * share
                let points = Ring.points(radius: radius)
                ZStack {
                    if let ink {
                        ForEach(0..<points, id: \.self) { step in
                            let turn = Double(step) / Double(points) * 2 * .pi
                            swingArrow(side, ink: ink)
                                .offset(x: radius * cos(turn), y: radius * sin(turn))
                        }
                    } else {
                        swingArrow(side, ink: .white)
                    }
                }
                .fixedSize()
                // Flip first, then turn: the other order turns the arrow and then
                // mirrors the turn with it, so the pair never meet in the middle.
                .scaleEffect(x: arrow.mirrored ? -1 : 1)
                .rotationEffect(.degrees(arrow.turn))
                .position(x: bleed + first.midX + size * arrow.x,
                          y: first.midY + size * arrow.y)
            }
        }
    }

    private func swingArrow(_ side: CGFloat, ink: Color) -> some View {
        Image("WordmarkArrow")
            .resizable()
            .scaledToFit()
            .frame(width: side)
            .foregroundStyle(ink)
    }

    /// The ball on the dot of the i.
    ///
    /// Placed on the letter rather than at a measured offset: `ActionText` reports where
    /// each character landed, so the ball follows the i wherever the taper and the size
    /// put it. `ballX` and `ballY` are shares of the ball's own width, for the nudge that
    /// no amount of geometry settles.
    @ViewBuilder private var ball: some View {
        if let dot = text.firstIndex(of: "i").map({ text.distance(from: text.startIndex, to: $0) }),
           let box = letters[dot] {
            let side = box.width * ballScale
            BallView(diameter: side)
                .position(x: bleed + box.midX + side * ballX,
                          y: box.minY + side * ballY)
        }
    }
}

#if DEBUG
#Preview("Wordmark") {
    struct Bench: View {
        @State private var size = SwisshWordmark.Mark.size
        @State private var split = SwisshWordmark.Mark.split
        @State private var thin = SwisshWordmark.Mark.thin
        @State private var thick = SwisshWordmark.Mark.thick
        @State private var ballScale = SwisshWordmark.Mark.ball
        @State private var ballX = SwisshWordmark.Mark.ballX
        @State private var ballY = SwisshWordmark.Mark.ballY
        @State private var arrows = SwisshWordmark.Mark.arrows
        @State private var arrowThin = SwisshWordmark.Mark.arrowThin
        @State private var arrowThick = SwisshWordmark.Mark.arrowThick

        var body: some View {
            VStack(spacing: 30) {
                Spacer()
                SwisshWordmark(size: size, split: split, thin: thin, thick: thick,
                               ballScale: ballScale, ballX: ballX, ballY: ballY,
                               arrows: arrows,
                               arrowThin: arrowThin, arrowThick: arrowThick)
                Spacer()
                // Scrolled, because eighteen knobs do not fit under a wordmark.
                ScrollView {
                VStack(spacing: 10) {
                    dial("size", value: $size, range: 30...200)
                    dial("split", value: $split, range: 0...1)
                    dial("thin", value: $thin, range: 0...0.08)
                    dial("thick", value: $thick, range: 0...0.25)
                    dial("ball", value: $ballScale, range: 0.4...3)
                    dial("ball x", value: $ballX, range: -1.5...1.5)
                    dial("ball y", value: $ballY, range: -1.5...1.5)
                    dial("arrow thin", value: $arrowThin, range: 0...0.05)
                    dial("arrow thick", value: $arrowThick, range: 0...0.15)

                    ForEach(arrows.indices, id: \.self) { index in
                        Divider().overlay(CardPalette.navy)
                        dial("arrow \(index + 1) turn",
                             value: Binding(get: { CGFloat(arrows[index].turn) },
                                            set: { arrows[index].turn = Double($0) }),
                             range: -180...180)
                        dial("arrow \(index + 1) scale", value: $arrows[index].scale,
                             range: 0.05...1.5)
                        dial("arrow \(index + 1) x", value: $arrows[index].x,
                             range: -2...2)
                        dial("arrow \(index + 1) y", value: $arrows[index].y,
                             range: -2...2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
                }
                .frame(maxHeight: 300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CardPalette.blue)
        }

        private func dial(_ name: String, value: Binding<CGFloat>,
                          range: ClosedRange<CGFloat>) -> some View {
            HStack(spacing: 10) {
                Text(String(format: "%@ %.3f", name, value.wrappedValue))
                    .font(.custom(Chrome.display, size: 15))
                    .foregroundStyle(.white)
                    .frame(width: 130, alignment: .leading)
                Slider(value: value, in: range)
            }
        }
    }
    return Bench()
}
#endif
