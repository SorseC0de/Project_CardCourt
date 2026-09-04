import SwiftUI

/// Where this player's passes go, drawn rather than written.
///
/// A Swing Left and a Swing Right mean different people depending on which chair you are
/// sitting in, and that is exactly the thing a sentence is bad at saying. Four nodes in
/// the seating order with the player at the bottom: left is left, right is right, and the
/// long arrow up the middle is across. Nobody is named — the colours and the initials are
/// who they are, the same way they are on the floor.
struct PassCompass: View {
    let seat: Seat
    var side: CGFloat = 132

    private enum Dial {
        /// A node, as a share of the whole.
        static let node: CGFloat = 0.26
        static let arrow: CGFloat = 0.055
        /// How far the flanks sit from the middle, as a share of the half-width.
        static let spread: CGFloat = 0.82
    }

    private var node: CGFloat { side * Dial.node }

    var body: some View {
        ZStack {
            arrow(to: CGPoint(x: 0.5 - Dial.spread / 2, y: 0.42))
            arrow(to: CGPoint(x: 0.5 + Dial.spread / 2, y: 0.42))
            arrow(to: CGPoint(x: 0.5, y: 0.12))

            chip(seat.left,   at: CGPoint(x: 0.5 - Dial.spread / 2, y: 0.42))
            chip(seat.right,  at: CGPoint(x: 0.5 + Dial.spread / 2, y: 0.42))
            chip(seat.across, at: CGPoint(x: 0.5, y: 0.12))
            chip(seat, at: CGPoint(x: 0.5, y: 0.86), isSelf: true)
        }
        .frame(width: side, height: side)
    }

    /// One tapered line from the player to a neighbour, stopping short of both discs.
    private func arrow(to target: CGPoint) -> some View {
        let from = CGPoint(x: side * 0.5, y: side * 0.86)
        let to = CGPoint(x: side * target.x, y: side * target.y)
        let run = CGPoint(x: to.x - from.x, y: to.y - from.y)
        let length = max(sqrt(run.x * run.x + run.y * run.y), 1)
        let clear = node / 2 + side * 0.03

        return Path { path in
            path.move(to: CGPoint(x: from.x + run.x / length * clear,
                                  y: from.y + run.y / length * clear))
            path.addLine(to: CGPoint(x: to.x - run.x / length * clear,
                                     y: to.y - run.y / length * clear))
        }
        .stroke(CardPalette.gray, style: StrokeStyle(lineWidth: side * Dial.arrow,
                                                     lineCap: .round))
    }

    /// A neighbour: their colour, their initial, and the same hard rim everything wears.
    private func chip(_ target: Seat, at point: CGPoint, isSelf: Bool = false) -> some View {
        Text(target.playerName.prefix(1).uppercased())
            .font(.custom(Chrome.display, size: node * 0.62))
            .foregroundStyle(.white)
            .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
            .frame(width: node, height: node)
            .background(Circle().fill(Theme.color(for: target)))
            .overlay(Circle().strokeBorder(isSelf ? .white : CardPalette.navy,
                                           lineWidth: node * 0.09))
            .position(x: side * point.x, y: side * point.y)
    }
}

#if DEBUG
#Preview("Pass compass") {
    HStack(spacing: 24) {
        PassCompass(seat: .south)
        PassCompass(seat: .east)
    }
    .padding(30)
    .background(CardPalette.navy)
}
#endif
