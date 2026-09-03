import SwiftUI

/// A card turning face up, without ever drawing a card that is face down.
///
/// The trick: while the card is turned away it is nothing but a solid rectangle in its
/// type's colour, and the real `CardFrontView` only appears **just past edge-on** — on a
/// frame where the card is a sliver and neither version is legible. The printed card
/// picks up at exactly the angle the slab left off and finishes the turn, so the swap
/// happens inside a moment nobody can see.
///
/// Driven by `KeyframeAnimator` rather than `withAnimation`, because the swap is a *gate*
/// on the angle: a gate that reads an animated value is handed the end of the animation on
/// the first frame, and the card would be printed for the whole turn.
struct CardFlip: View {
    let descriptor: CardDescriptor
    var width: CGFloat = 96
    /// Where it starts. 180 is face down; 0 is face up and square to the viewer.
    var from: Double = 180
    /// Where the solid slab hands over. Just past 90 — one step after the edge is flush
    /// with the camera, which is the frame the handoff hides in.
    var handoff: Double = 84
    var seconds: Double = 0.6
    /// Flat to the viewer, or laid back onto the floor the way the deck sits.
    var settleTo: Double = 0
    var onFinished: () -> Void = {}

    @State private var turning = false

    private var corner: CGFloat { width * 0.08 }

    var body: some View {
        KeyframeAnimator(initialValue: from, trigger: turning) { angle in
            Group {
                if angle > handoff {
                    // Nothing but its colour: there is no back to draw, and at this angle
                    // there is nothing to read anyway.
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(CardPalette.body(for: descriptor.type))
                        .overlay(
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .stroke(CardPalette.navy, lineWidth: width * 0.03))
                        .frame(width: width, height: width / CardMetrics.aspect)
                } else {
                    CardFrontView(descriptor: descriptor, displayWidth: width)
                }
            }
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                // Eased at the end alone: a card turns over fast and then presents itself.
                CubicKeyframe(settleTo, duration: seconds)
            }
        }
        .task {
            turning = true
            try? await Task.sleep(for: .seconds(seconds))
            onFinished()
        }
    }
}

#if DEBUG
#Preview("Card flip") {
    FlipPreview()
}

private struct FlipPreview: View {
    @State private var round = 0
    private let cards: [CardDescriptor] = [
        CardLibrary.drive, CardLibrary.swingLeft, CardLibrary.travel, CardLibrary.foul,
    ]

    var body: some View {
        VStack(spacing: 24) {
            CardFlip(descriptor: cards[round % cards.count], width: 150)
                .id(round)
            Button("Flip again") { round += 1 }
        }
        .padding(40)
        .background(Color.black)
    }
}
#endif
