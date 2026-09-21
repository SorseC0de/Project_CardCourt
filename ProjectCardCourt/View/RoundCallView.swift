import SwiftUI

/// What the game says between rounds, and at the half.
///
/// **Two shapes, because they are two different sizes of moment.**
///
/// A *round* gets a slab of the game's own furniture: one parallelogram in the card blue,
/// the Pass icon standing on it, and the round said over the top in the lettering every
/// other call uses. The drop is two colours rather than one — gold first and orange beyond
/// it, the pair the cards' own gold wears everywhere else — so it reads as printed rather
/// than as a rectangle with a shadow.
///
/// The *half* wears the same slab with neither the icon nor the number on it — there is no
/// family being played and no figure to say — and its word takes the light instead. Same
/// furniture, stripped to the one thing it is announcing.
struct RoundCallView: View {
    let call: RoundCall
    var onFinished: () -> Void = {}
    /// **The half waits to be dismissed.** A round is a marker and goes on its own; the
    /// half is the game stopping, which is the one moment worth being allowed to sit in.
    /// Nothing is dealt behind it — see `GameController.callTheHalf`.
    /// The slab's width against the screen's, and its height against its own width.
    var acrossShare: CGFloat = 0.78
    var tallShare: CGFloat = 0.21


    /// **Everything is a share of the slab's width, not its height.**
    ///
    /// The slab is half as tall as it was and the icon and the lettering did not change
    /// with it — they are the same size on a thinner bar, standing proud of it top and
    /// bottom. Measured against the height, halving the bar would have halved them too.
    private enum Slab {
        /// The rake, as a share of the slab's height. Positive leans the top to the east.
        static let lean: CGFloat = 0.52
        /// The two drops, as shares of the slab's width. The second is beyond the first
        /// rather than instead of it — see the note above.
        static let nearDrop: CGFloat = 0.023
        static let farDrop: CGFloat = 0.046
        /// The icon standing on the slab, against the slab's width.
        static let icon: CGFloat = 0.36
        /// And how far the icon sits off the middle, so the lettering has the other half.
        static let iconX: CGFloat = -0.26
        /// The word, against the slab's width.
        static let word: CGFloat = 0.126
        /// The half says one word and nothing else, so it takes the room the number leaves.
        static let halftimeWord: CGFloat = 0.20
        /// **"1st Quarter", read left to right**: the icon, then the figure, then the word.
        /// With the figure out past the word it read "Quarter 1st".
        static let wordX: CGFloat = 0.20
        /// **The number, on its own and larger than the bar it is standing on.**
        /// Drawn before the word, so the word sits over it; drawn after the slab, so it
        /// spills off the top and bottom of it rather than being buried.
        ///
        /// **Kept under the icon's height on purpose.** A figure at the bar's old height
        /// carries a line box half as tall again, so the call came out taller than the
        /// one it replaced — the bar halved and the thing on screen grew. The icon is the
        /// tallest part of this now, which is what it was before.
        static let number: CGFloat = 0.30
        /// The ordinal's letters against the figure, and how far below its top they
        /// start — high and small, as print sets them.
        static let ordinal: CGFloat = 0.36
        static let ordinalLift: CGFloat = 0.12
        static let numberX: CGFloat = -0.04
        static let numberY: CGFloat = -0.02
        /// Its hard drop, drawn as a second copy behind it.
        static let numberDrop: CGFloat = 0.012
    }

    var body: some View {
        slab
            .contentShape(Rectangle())
            .allowsHitTesting(call.isHalftime)
            .onTapGesture { if call.isHalftime { onFinished() } }
    }

    private var slab: some View {
        GeometryReader { screen in
            let across = screen.size.width * acrossShare
            let tall = across * tallShare
            ZStack {
                // Far drop first, then the near one over it, then the slab itself.
                shape(tall).fill(CardPalette.orange)
                    .offset(x: across * Slab.farDrop, y: across * Slab.farDrop)
                shape(tall).fill(CardPalette.gold)
                    .offset(x: across * Slab.nearDrop, y: across * Slab.nearDrop)
                shape(tall).fill(CardPalette.blue)

                // **A round wears its family and its figure; the half wears neither.**
                // Nothing is being played and there is no number to say, so the word is
                // the whole announcement — it takes the middle, and it takes the light.
                if !call.isHalftime {
                    ZStack {
                        Image("TypePass").resizable().scaledToFit()
                        Image("TypePassFront").resizable().scaledToFit()
                    }
                    .frame(width: across * Slab.icon, height: across * Slab.icon)
                    .offset(x: across * Slab.iconX)
                }

                // The number, then the word over it. **The number is lit** — Project
                // Stars' Start button, turned into a fill: the spectrum turns inside the
                // figure rather than behind a pane. Its drop is drawn as a second copy,
                // because a `shadow` under a masked view shadows the mask.
                if !call.isHalftime {
                    // **"1st", as one word.** The figure large and lit, its letters raised
                    // and small against it the way print sets them — see `Ordinal`.
                    HStack(alignment: .top, spacing: 0) {
                        ZStack {
                            ActionText("\(call.round)", size: across * Slab.number,
                                       ink: CardPalette.navy, drop: .clear)
                                .offset(x: across * Slab.numberDrop,
                                        y: across * Slab.numberDrop)
                            SpectrumFill(resting: CardPalette.gold) {
                                ActionText("\(call.round)", size: across * Slab.number,
                                           ink: .white, drop: .clear)
                            }
                        }
                        ActionText(Ordinal.suffix(call.round),
                                   size: across * Slab.number * Slab.ordinal,
                                   ink: .white, drop: CardPalette.navy)
                            .offset(y: across * Slab.number * Slab.ordinalLift)
                    }
                    .offset(x: across * Slab.numberX, y: across * Slab.numberY)

                    ActionText(call.word, size: across * Slab.word,
                               ink: .white, drop: CardPalette.navy)
                        .offset(x: across * Slab.wordX)
                } else {
                    // The half's own word, lit and centred, with its drop drawn as a
                    // second copy — a `shadow` under a masked view shadows the mask.
                    ZStack {
                        ActionText(call.word, size: across * Slab.halftimeWord,
                                   ink: CardPalette.navy, drop: .clear)
                            .offset(x: across * Slab.numberDrop,
                                    y: across * Slab.numberDrop)
                        SpectrumFill(resting: .white) {
                            ActionText(call.word, size: across * Slab.halftimeWord,
                                       ink: .white, drop: .clear)
                        }
                    }
                }
            }
            .frame(width: across, height: tall)
            .position(x: screen.size.width / 2, y: screen.size.height / 2)
        }
    }

    /// A parallelogram raked to the east. `Parallelogram` is the mode cards' own shape —
    /// the game has one slanted slab and this is it.
    private func shape(_ tall: CGFloat) -> some Shape {
        Parallelogram(lean: Slab.lean)
    }
}

/// What a round call says.
struct RoundCall: Equatable, Identifiable {
    let round: Int
    /// The half is its own announcement rather than a round with a different word.
    var isHalftime = false

    var id: String { isHalftime ? "half" : "round-\(round)" }
    /// **The word only.** The number is its own lettering on the slab, drawn large and
    /// behind it — see `RoundCallView.Slab.number`.
    var word: String { isHalftime ? "Halftime" : "Quarter" }
}

#if DEBUG
#Preview("Round call") {
    ZStack {
        Theme.panel.ignoresSafeArea()
        RoundCallView(call: RoundCall(round: 3))
    }
}
#endif
