import SwiftUI

/// A thick arrow, pointing down at whatever it is hung over.
struct DownArrow: Shape {
    /// The shaft's width, as a share of the whole arrow's.
    var shaft: CGFloat = 0.44
    /// The head's height, as a share of the whole arrow's.
    var head: CGFloat = 0.52

    func path(in rect: CGRect) -> Path {
        let headHeight = rect.height * head
        let shoulder = rect.maxY - headHeight
        let left = rect.midX - rect.width * shaft / 2
        let right = rect.midX + rect.width * shaft / 2
        return Path { path in
            path.move(to: CGPoint(x: left, y: rect.minY))
            path.addLine(to: CGPoint(x: right, y: rect.minY))
            path.addLine(to: CGPoint(x: right, y: shoulder))
            path.addLine(to: CGPoint(x: rect.maxX, y: shoulder))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: shoulder))
            path.addLine(to: CGPoint(x: left, y: shoulder))
            path.closeSubpath()
        }
    }
}

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
        /// How tall it is against its own width, how far it travels, and the length of
        /// one trip down and back.
        static let tall: CGFloat = 1.15
        static let travel: CGFloat = 8
        static let beat: Double = 0.55
        /// The bloom, in two passes — one copy of a glow this size comes out flat.
        static let glow: CGFloat = 9
    }

    var body: some View {
        DownArrow()
            .fill(ink)
            .overlay {
                DownArrow().stroke(CardPalette.navy, lineWidth: 2)
            }
            .frame(width: width, height: width * Mark.tall)
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
