import SwiftUI

/// **Where the deck's middle is**, in the screen's own space. The court flies a drawn
/// card from here, since the pile is no longer standing on the floor.
struct DeckPoint: PreferenceKey {
    static let defaultValue: CGPoint? = nil
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}

/// **The deck, in reach.**
///
/// It stood out on the floor with the discard, which is where a deck sits on a table and
/// nowhere you can reach on a phone — and your own cards come off it by hand: the card
/// your possession opens with, and the four you start the game with. So it lives down
/// here beside the ball you shoot with, and it is tapped rather than watched.
///
/// The arrow is up only while the game is actually waiting on you — see
/// `GameController.deckWaiting`.
struct DeckSlotView: View {
    let remaining: Int
    /// The game is holding a card at the top of the pile until you take it.
    var waiting: Bool
    /// The card on its way to somebody, so the pile can turn and nod toward them.
    var dealing: (seat: Seat, id: UUID)?
    var width: CGFloat = 54
    var onTake: () -> Void

    @State private var render = RenderDebug.shared

    private enum Slot {
        /// How far above the pile the arrow's point sits.
        static let arrow: CGFloat = 38
        static let arrowWidth: CGFloat = 30
        /// How far out the man it is dealing to stands, in the deck's own metres. Only
        /// the direction is read, so this is any distance that is not nothing.
        static let reach: Float = 0.2
    }

    /// **Where a seat stands, from the deck's point of view.** The camera looks down the
    /// z axis from in front, so your own seat is toward it and North is away — see
    /// `CourtStage.cameraTransform`.
    private func toward(_ seat: Seat) -> SIMD3<Float> {
        let places: [Seat: SIMD3<Float>] = [
            .south: [0, 0, 1], .north: [0, 0, -1], .east: [1, 0, 0], .west: [-1, 0, 0],
        ]
        return (places[seat] ?? [0, 0, 1]) * Slot.reach
    }

    var body: some View {
        pile
            .frame(width: width, height: width * DeckBody.frameHeight)
            // The footprint answers the press, not the slabs drawn inside it.
            .contentShape(Rectangle())
            .onTapGesture(perform: onTake)
            .overlay(alignment: .top) {
                if waiting {
                    DrawArrow(width: Slot.arrowWidth)
                        .offset(y: -Slot.arrow)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .background {
                GeometryReader { box in
                    let screen = box.frame(in: .named(Chrome.screen))
                    Color.clear.preference(key: DeckPoint.self,
                                           value: CGPoint(x: screen.midX, y: screen.midY))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: waiting)
    }

    /// **The pile itself.** The deck a player watches is the drawn one; the flat stack is
    /// the same escape hatch the court's piles have — see `DeckStackView`.
    @ViewBuilder private var pile: some View {
        if render.courtStage {
            DeckBody(layers: DeckStackView.layers(for: remaining),
                     dealingTo: dealing.map { .init(id: $0.id, toward: toward($0.seat)) })
        } else {
            FlatPile(layers: DeckStackView.layers(for: remaining))
        }
    }
}

#if DEBUG
#Preview("Deck slot") {
    VStack(spacing: 40) {
        DeckSlotView(remaining: 120, waiting: true, onTake: {})
        DeckSlotView(remaining: 12, waiting: false, onTake: {})
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.sceneGround)
}
#endif
