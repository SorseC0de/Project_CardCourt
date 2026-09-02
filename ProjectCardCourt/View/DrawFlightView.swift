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

    var body: some View {
        Image("CardBack")
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 26)
        .scaleEffect(arrived ? endScale : startScale)
        .rotationEffect(.degrees(arrived ? 0 : -12))
        .position(arrived ? to : from)
        .opacity(arrived ? 0 : 1)
        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
        .onAppear {
            withAnimation(.easeInOut(duration: duration)) { arrived = true }
        }
    }
}
