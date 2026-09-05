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
        /// How much of the deck one slab stands for. Read off the ceiling rather than
        /// fixed: a full Standard deck fills the pile, and it shortens as that empties.
        static let full = 400
    }

    /// The pile gets shorter as the deck empties.
    ///
    /// A reading, not a stack you count — see `DeckTuning.slabs`, which is the ceiling and
    /// is on the bench because how tall a deck *looks* right is an eye question.
    private var layers: Int {
        let most = min(DeckBody.maxLayers, max(1, Int(DeckTuning.shared.slabs)))
        return max(1, min(most, Int((Double(remaining) / Double(Pile.full)
                                     * Double(most)).rounded(.up))))
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
