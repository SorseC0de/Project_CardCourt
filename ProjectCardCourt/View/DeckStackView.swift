import SwiftUI

/// The draw pile, sitting in the middle of the diamond.
///
/// The pile itself is real geometry — see `DeckBody`. This wrapper is the court's view of
/// it: the body, sized. The count is not here — it lives under the SHOT badge now, where
/// it is not something the deck has to drag around while it flies.
struct DeckStackView: View {
    let remaining: Int
    var width: CGFloat = 44
    var routine: DeckStage.Routine = .rest
    /// False when a court-wide stage is drawing the pile instead.
    var showsPile = true

    private enum Pile {
        /// Raises the whole thing in its slot.
        static let lift: CGFloat = 0.12
        /// One layer per twenty cards, so a hundred is five slabs. Half what it was: the
        /// pile is a reading, not a stack you count, and at ten a full deck was a tower.
        static let cardsPerSlice = 20
    }

    /// The pile gets shorter as the deck empties.
    private var layers: Int {
        max(1, min(DeckBody.maxLayers, remaining / Pile.cardsPerSlice))
    }

    var body: some View {
        if showsPile {
            pile
                .offset(y: -width * Pile.lift)
                .animation(.easeOut(duration: 0.3), value: layers)
        }
    }

    /// Real geometry, so the pile keeps its body when the court turns. The flat
    /// rectangle version this replaced only held up from one angle.
    private var pile: some View {
        DeckBody(layers: layers, routine: routine)
            .frame(width: width, height: width * DeckBody.frameHeight)
            .allowsHitTesting(false)
    }

}

#if DEBUG
#Preview("Deck") {
    VStack(spacing: 40) {
        HStack(spacing: 40) {
            DeckStackView(remaining: 264, width: 138)
            DeckStackView(remaining: 96, width: 138)
            DeckStackView(remaining: 12, width: 138)
        }
        DeckStackView(remaining: 264)
    }
    .padding(60)
    .background(Theme.courtFloor)
}
#endif
