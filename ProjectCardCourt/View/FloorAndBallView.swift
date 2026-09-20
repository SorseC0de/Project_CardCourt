import SwiftUI

/// **The ball in play**, when there is one. Tapping it raises it to be read, the way a
/// slotted card is.
///
/// **No floor.** Varenas are benched, so every game is played on plain Cardwood and a slot
/// showing the same card in every match of every game is a slot saying nothing. The floor
/// half is still here, unused, for when the venue comes back.
struct FloorAndBallView: View {
    let state: GameState
    /// **Says what is in play even when that is nothing special.** A Regulation ball is
    /// still the ball everybody is playing with, and a slot that empties says the game
    /// has stopped having one.
    var alwaysShowsBall = false
    var onSelect: (CardDescriptor, CGPoint) -> Void = { _, _ in }

    private enum Layout {
        /// **The size of one of the crew's cards** in the HUD, so the ball reads as one
        /// more card in the same set.
        static var card: CGFloat { StatusHUDView.crewCardWidth() }
        static let gap: CGFloat = 6
        static let note: CGFloat = 10
    }

    var body: some View {
        VStack(spacing: 2) {
            if state.courtCard != nil { slot(state.currentCourt, note: floorNote) }
            if let ball = state.currentBall {
                slot(ball, note: ballNote)
                    .transition(.scale.combined(with: .opacity))
            } else if alwaysShowsBall {
                // Nothing played over it: the ball everybody starts with.
                BallView(diameter: Layout.card * 0.8)
                    .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
            }
            FloorName(text: "Ball")
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
