import SwiftUI

/// What the game says between rounds, and at the half.
///
/// A slab of the game's own furniture rather than a line of text: a parallelogram in the
/// card blue, the type icon of the family the round is about to be played with standing on
/// it, and the round said over the top in the lettering every other call uses.
///
/// **The drop is two colours, not one.** Gold first and orange beyond it — the pair the
/// cards' own gold wears everywhere else — so the slab reads as printed rather than as a
/// rectangle with a shadow.
struct RoundCallView: View {
    let call: RoundCall
    /// The slab's width against the screen's, and its height against its own width.
    var acrossShare: CGFloat = 0.78
    var tallShare: CGFloat = 0.42

    private enum Slab {
        /// The rake, as a share of the slab's height. Positive leans the top to the east.
        static let lean: CGFloat = 0.26
        /// The two drops, as shares of the slab's height. The second is beyond the first
        /// rather than instead of it — see the note above.
        static let nearDrop: CGFloat = 0.055
        static let farDrop: CGFloat = 0.11
        /// The icon standing on the slab, against the slab's height.
        static let icon: CGFloat = 0.86
        /// And how far the icon sits off the middle, so the lettering has the other half.
        static let iconX: CGFloat = -0.26
        /// The word, against the slab's height.
        static let word: CGFloat = 0.30
        static let wordX: CGFloat = 0.16
    }

    var body: some View {
        GeometryReader { screen in
            let across = screen.size.width * acrossShare
            let tall = across * tallShare
            ZStack {
                // Far drop first, then the near one over it, then the slab itself.
                shape(tall).fill(CardPalette.orange)
                    .offset(x: tall * Slab.farDrop, y: tall * Slab.farDrop)
                shape(tall).fill(CardPalette.gold)
                    .offset(x: tall * Slab.nearDrop, y: tall * Slab.nearDrop)
                shape(tall).fill(CardPalette.blue)

                // The family the round is played with, standing on the slab. Both layers
                // of it — the plate and its subject — since the icon is drawn in two.
                ZStack {
                    Image("TypePass").resizable().scaledToFit()
                    Image("TypePassFront").resizable().scaledToFit()
                }
                .frame(width: tall * Slab.icon, height: tall * Slab.icon)
                .offset(x: tall * Slab.iconX)

                ActionText(call.word, size: tall * Slab.word,
                           ink: .white, drop: CardPalette.navy)
                    .offset(x: tall * Slab.wordX)
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
    var word: String { isHalftime ? "Halftime" : "Round \(round)" }
}

#if DEBUG
#Preview("Round call") {
    ZStack {
        Theme.panel.ignoresSafeArea()
        RoundCallView(call: RoundCall(round: 3))
    }
}
#endif
