import SwiftUI

/// A body a Clamp puts on its victim. Always red, whoever played the card.
struct DefenderFigure: View {
    var body: some View {
        VStack(spacing: Theme.Figure.gap) {
            Circle()
                .fill(Theme.defender)
                .frame(width: Theme.Figure.headDiameter * 0.9,
                       height: Theme.Figure.headDiameter * 0.9)
                .shadow(color: .black.opacity(0.38), radius: 2.5, x: 0, y: 3)
                .zIndex(1)
            Capsule()
                .fill(Theme.defender)
                .frame(width: Theme.Figure.bodyWidth * 0.9, height: Theme.Figure.bodyHeight * 0.9)
        }
        .shadow(color: Theme.defender.opacity(0.5), radius: 7)
    }
}
