import SwiftUI

/// **The floor and the ball in play**: the Varena that is out — the table's own Cardwood
/// until somebody plays over it — and the Variaball, when there is one. Tapping either
/// raises it to be read, the way a slotted card is.
struct FloorAndBallView: View {
    let state: GameState
    var onSelect: (CardDescriptor, CGPoint) -> Void = { _, _ in }

    private enum Layout {
        static let card: CGFloat = 40
        static let gap: CGFloat = 6
        static let note: CGFloat = 10
    }

    var body: some View {
        HStack(alignment: .top, spacing: Layout.gap) {
            slot(state.currentCourt, note: floorNote)
            if let ball = state.currentBall {
                slot(ball, note: ballNote)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: state.currentCourt.id)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: state.currentBall?.id)
    }

    private func slot(_ card: CardDescriptor, note: String?) -> some View {
        VStack(spacing: 2) {
            CardFrontView(descriptor: card, displayWidth: Layout.card)
                .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
                .overlay {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(card, CGPoint(x: geo.frame(in: .global).midX,
                                                       y: geo.frame(in: .global).midY))
                            }
                    }
                }
            if let note {
                Text(note)
                    .font(.system(size: Layout.note, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: CardPalette.navy, radius: 0, x: 1, y: 1)
            }
        }
    }

    /// What a floor that changes from possession to possession is doing right now.
    private var floorNote: String? {
        let floor = state.floorEffect
        if floor.turnstileSwing != 0 {
            return state.turnstileUp ? "+\(floor.turnstileSwing)%" : "−\(floor.turnstileSwing)%"
        }
        if floor.rotatesHands, let clockwise = state.carouselClockwise {
            return clockwise ? "LEFT" : "RIGHT"
        }
        return nil
    }

    /// Monster Ball: how many Intangibles are inside it.
    private var ballNote: String? {
        let held = state.monsterBallIntangibles.count
        return held > 0 ? "×\(held)" : nil
    }
}
