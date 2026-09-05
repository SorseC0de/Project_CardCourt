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

    enum Pile {
        /// Raises the whole thing in its slot.
        static let lift: CGFloat = 0.12
        /// How much of the deck one slab stands for.
        static let cardsPerSlab = 30
    }

    /// The pile gets shorter as the deck empties.
    ///
    /// A reading, not a stack you count — see `DeckTuning.slabs`, which is the ceiling and
    /// is on the bench because how tall a deck *looks* right is an eye question.
    ///
    /// **Static, because two renderers draw this pile.** `CourtStage` draws the one you
    /// actually see and this view draws the flat fallback; with the arithmetic written out
    /// in each, the slider moved one of them and the game showed the other.
    static func layers(for remaining: Int) -> Int {
        let most = min(DeckBody.maxLayers, max(1, Int(DeckTuning.shared.slabs)))
        let asked = (remaining + Pile.cardsPerSlab - 1) / Pile.cardsPerSlab
        return max(1, min(most, asked))
    }

    private var layers: Int { Self.layers(for: remaining) }

    var body: some View {
        if showsPile {
            pile
                .offset(y: -width * Pile.lift)
                .animation(.easeOut(duration: 0.3), value: layers)
        }
    }

    /// Flat, and owing RealityKit nothing.
    ///
    /// This view only draws at all when the court's 3D stage is off — and the whole point
    /// of turning that off is to be rid of the renderer, which swapping it for two of
    /// `DeckBody`'s did not do.
    private var pile: some View {
        FlatPile(layers: layers)
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
