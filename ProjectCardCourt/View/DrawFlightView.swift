import SwiftUI

/// A card crossing from the deck to a player. Face down — what was drawn is the
/// drawer's business, and it lands in their hand a moment later anyway.
struct DrawFlightView: View {
    let from: CGPoint
    let to: CGPoint
    let startScale: CGFloat
    let endScale: CGFloat
    var duration: Double

    @State private var arrived = false
    /// Kept off `arrived`, so the card is at full strength the whole way over.
    @State private var gone = false

    var body: some View {
        Image("CardBack")
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 26)
        .scaleEffect(arrived ? endScale : startScale)
        .rotationEffect(.degrees(arrived ? 0 : -12))
        .position(arrived ? to : from)
        .opacity(gone ? 0 : 1)
        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
        .task {
            // Committed unanimated first. Without a frame at the start state SwiftUI
            // goes straight to the end, and a card that also faded across the flight was
            // half transparent for all of it — at a 0.14s deal, invisible.
            var appear = Transaction(); appear.disablesAnimations = true
            withTransaction(appear) { arrived = false; gone = false }

            withAnimation(.easeInOut(duration: duration)) { arrived = true }
            try? await Task.sleep(for: .seconds(duration * 0.8))
            withAnimation(.easeOut(duration: duration * 0.2)) { gone = true }
        }
    }
}
