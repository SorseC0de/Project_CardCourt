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
    /// How wide the card is drawn. It stands opposite the official's card under the
    /// blocks, at that card's own size.
    var width: CGFloat = Layout.card
    /// What an empty slot is called. The same shape stands in for the official.
    var word: String = "Ball"
    var onSelect: (CardDescriptor, CGPoint) -> Void = { _, _ in }

    enum Layout {
        /// **Its own size, and a small one.** It stands in the quarter beside the ball you
        /// shoot with, and anything taller than that band pushes the ball off the floor.
        static let card: CGFloat = 54
        static let gap: CGFloat = 6
        static let note: CGFloat = 10
        /// The dashes round an empty slot. Thick, so it reads as a slot rather than a rule.
        static let dash: CGFloat = 3
    }

    var body: some View {
        VStack(spacing: 2) {
            if state.courtCard != nil { slot(state.currentCourt, note: floorNote) }
            // **The card, not the ball.** What the ball is doing is drawn on the one you
            // shoot with; this is the card that put it in play, to be read — and the slot
            // it would stand in when nothing has.
            if let ball = state.currentBall {
                slot(ball, note: ballNote)
                    .transition(.scale.combined(with: .opacity))
            } else if alwaysShowsBall {
                empty
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: state.currentCourt.id)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: state.currentBall?.id)
    }

    /// **The slot with nothing in it.** A Regulation ball is no card at all, so what
    /// stands here is the shape of the one that would: a Variaball with nothing printed
    /// on it, cut out of the screen and dashed round.
    /// **The shape of a card that is not there**, dashed round and named. Shared, so the
    /// ball's empty slot and the official's are the same object rather than two drawings
    /// that happen to look alike.
    static func emptySlot(width: CGFloat, word: String) -> some View {
        let corner = width * CardLayout.cornerFraction
        return RoundedRectangle(cornerRadius: corner, style: .continuous)
            .strokeBorder(CardPalette.cloud.opacity(0.7),
                          style: StrokeStyle(lineWidth: Layout.dash,
                                             dash: [Layout.dash * 2, Layout.dash * 1.4]))
            .frame(width: width, height: width / CardMetrics.aspect)
            .overlay {
                SmallCapsText(text: word, font: Chrome.display,
                              size: width * 0.15, tracking: 0.4)
                    .foregroundStyle(CardPalette.cloud.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 4)
            }
    }

    private var empty: some View { Self.emptySlot(width: width, word: word) }

    private func slot(_ card: CardDescriptor, note: String?) -> some View {
        VStack(spacing: 2) {
            CardFrontView(descriptor: card, displayWidth: width)
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
