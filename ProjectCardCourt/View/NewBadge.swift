import SwiftUI

/// Marks a card the player has never met before.
///
/// Pinned to a card's corner rather than floating, so it reads as belonging to that card
/// and not to the scene around it.
struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(CardPalette.navy)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(CardPalette.gold))
            .overlay(Capsule().stroke(CardPalette.blue, lineWidth: 2))
            // Flattened before the shadow. Without this SwiftUI casts one per piece, so
            // the lettering picks up its own hard drop — which reads as the text being
            // stroked — and the ring gets a second offset copy of itself.
            .compositingGroup()
            // Zero blur, offset south-east, like every other mark in the game.
            .shadow(color: CardPalette.blue, radius: 0, x: 3, y: 3)
            .rotationEffect(.degrees(-8))
    }
}

/// Told to a player who has to dismiss the card themselves.
struct TapToContinue: View {
    @State private var breathing = false

    var body: some View {
        Text("TAP TO CONTINUE")
            .font(.system(size: 10, weight: .heavy)).tracking(2)
            .foregroundStyle(Theme.inkDim)
            .opacity(breathing ? 1 : 0.35)
            .task {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
    }
}
