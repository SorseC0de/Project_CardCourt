import SwiftUI

/// The draw pile, sitting in the middle of the diamond.
///
/// The pile itself is real geometry — see `DeckBody`. This wrapper is the court's view of
/// it: the body, sized, with the count underneath.
struct DeckStackView: View {
    let remaining: Int
    var width: CGFloat = 44
    var routine: DeckStage.Routine = .rest
    /// False when a court-wide stage is drawing the pile instead, leaving only the count.
    var showsPile = true

    @State private var render = RenderDebug.shared

    private enum Pile {
        /// Raises the whole thing in its slot.
        static let lift: CGFloat = 0.12
        /// Five layers per fifty cards — one for every ten.
        static let cardsPerSlice = 10
    }

    /// The pile gets shorter as the deck empties.
    private var layers: Int {
        max(1, min(DeckBody.maxLayers, remaining / Pile.cardsPerSlice))
    }

    var body: some View {
        // Negative, to close the empty part of the renderer's frame. Shrinking the frame
        // instead would shrink the deck, since the camera's field of view is what sets
        // the rendered size.
        VStack(spacing: showsPile ? -width * DeckBody.labelGap : 4) {
            if showsPile { pile }
            Text("\(remaining)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.inkDim)
                .contentTransition(.numericText())
        }
        .offset(y: -width * Pile.lift)
        .animation(.easeOut(duration: 0.3), value: layers)
    }

    /// Real geometry, so the pile keeps its body when the court turns. The flat
    /// rectangle version this replaced only held up from one angle.
    @ViewBuilder
    private var pile: some View {
        if render.flatPiles {
            FlatPile(width: width, tall: true)
                .frame(width: width, height: width * DeckBody.frameHeight)
        } else {
            DeckBody(layers: layers, routine: routine)
                .frame(width: width, height: width * DeckBody.frameHeight)
                .allowsHitTesting(false)
        }
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

/// A pile with no renderer behind it, for measuring what the renderer costs.
struct FlatPile: View {
    let width: CGFloat
    let tall: Bool

    var body: some View {
        Image("CardBackFull")
            .resizable()
            .scaledToFit()
            .frame(width: width * 0.8)
            .drawingGroup()
            .rotation3DEffect(.degrees(56), axis: (x: 1, y: 0, z: 0),
                              anchor: .bottom, perspective: 0.4)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(CardPalette.gold)
                    .frame(width: width * 0.7, height: tall ? 14 : 8)
                    .offset(y: 8)
            }
    }
}
