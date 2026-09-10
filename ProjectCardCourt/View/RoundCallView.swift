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
/// The *half* gets the **Z card**: the two black bars that cross the screen and meet in
/// the middle, which is how this game names a moment rather than a number. It is
/// `ModeCardView`, the same one the mode splash and the phase calls wear.
struct RoundCallView: View {
    let call: RoundCall
    var onFinished: () -> Void = {}
    /// The slab's width against the screen's, and its height against its own width.
    var acrossShare: CGFloat = 0.78
    var tallShare: CGFloat = 0.21

    /// **Raised so the Z card can leave.** `ModeCardView` fires `onFinished` at the end of
    /// its trip *out*, and it never starts that trip until it is told to — so a card
    /// handed a constant `false` arrives, holds, and holds, and the controller waiting on
    /// it waits forever. That is the hang: the same trap `ActionCallView` names in its
    /// own `task`, walked into a second time.
    @State private var leaving = false

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
        static let wordX: CGFloat = 0.10
        /// **The number, on its own and larger than the bar it is standing on.**
        /// Drawn before the word, so the word sits over it; drawn after the slab, so it
        /// spills off the top and bottom of it rather than being buried.
        ///
        /// **Kept under the icon's height on purpose.** A figure at the bar's old height
        /// carries a line box half as tall again, so the call came out taller than the
        /// one it replaced — the bar halved and the thing on screen grew. The icon is the
        /// tallest part of this now, which is what it was before.
        static let number: CGFloat = 0.30
        static let numberX: CGFloat = 0.36
        static let numberY: CGFloat = -0.02
    }

    var body: some View {
        Group {
            if call.isHalftime {
                ModeCardView(title: call.word, subtitle: "Shuffle up",
                             ink: .white, subtitleInk: CardPalette.gold,
                             isLeaving: leaving, onLanded: {}, onFinished: onFinished)
            } else {
                slab
            }
        }
        .task(id: call.id) {
            leaving = false
            try? await Task.sleep(for: .seconds(Pacing.actionCall))
            leaving = true
        }
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

                // The family the round is played with, standing on the slab. Both layers
                // of it — the plate and its subject — since the icon is drawn in two.
                ZStack {
                    Image("TypePass").resizable().scaledToFit()
                    Image("TypePassFront").resizable().scaledToFit()
                }
                .frame(width: across * Slab.icon, height: across * Slab.icon)
                .offset(x: across * Slab.iconX)

                // The number, then the word over it.
                ActionText("\(call.round)", size: across * Slab.number,
                           ink: CardPalette.gold, drop: CardPalette.navy)
                    .offset(x: across * Slab.numberX, y: across * Slab.numberY)

                ActionText(call.word, size: across * Slab.word,
                           ink: .white, drop: CardPalette.navy)
                    .offset(x: across * Slab.wordX)
            }
            .frame(width: across, height: tall)
            .position(x: screen.size.width / 2, y: screen.size.height / 2)
        }
        .allowsHitTesting(false)
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
    var word: String { isHalftime ? "Halftime" : "Round" }
}

#if DEBUG
#Preview("Round call") {
    ZStack {
        Theme.panel.ignoresSafeArea()
        RoundCallView(call: RoundCall(round: 3))
    }
}
#endif
