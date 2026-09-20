import SwiftUI

/// **The game waiting on you to take your own cards off the deck.**
///
/// It bobs and glows rather than standing still: while the game is waiting nothing else
/// on the screen is moving, and an arrow that does not move either reads as a label
/// printed over the pile instead of an instruction.
struct DrawArrow: View {
    var width: CGFloat = 34
    var ink: Color = CardPalette.gold

    @State private var bob = false

    private enum Mark {
        /// How far it travels, and the length of one trip down and back.
        static let travel: CGFloat = 8
        static let beat: Double = 0.55
        /// The bloom, in two passes — one copy of a glow this size comes out flat.
        static let glow: CGFloat = 9
    }

    var body: some View {
        SelectionArrow(reading: .gold, width: width)
            .shadow(color: ink.opacity(0.7), radius: Mark.glow)
            .shadow(color: ink.opacity(0.45), radius: Mark.glow * 2)
            .offset(y: bob ? Mark.travel : -Mark.travel)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: Mark.beat).repeatForever(autoreverses: true)) {
                    bob = true
                }
            }
    }
}

#if DEBUG
#Preview("Draw arrow") {
    DrawArrow()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.sceneGround)
}
#endif
