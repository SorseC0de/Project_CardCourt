import SwiftUI

/// Stands on the sideline whenever a Whistle is armed. Deliberately says nothing about
/// whose it is or what it watches for — his presence is the whole tell.
struct RefereeFigure: View {
    var stripes = 3

    private var head: CGFloat { Theme.Figure.headDiameter }
    private var bodyWidth: CGFloat { Theme.Figure.bodyWidth }
    private var bodyHeight: CGFloat { Theme.Figure.bodyHeight }

    var body: some View {
        VStack(spacing: Theme.Figure.gap) {
            Circle()
                .fill(Color(white: 0.94))
                .frame(width: head, height: head)
                .shadow(color: .black.opacity(0.38), radius: 2.5, x: 0, y: 3)
                .zIndex(1)

            Capsule()
                .fill(Color(white: 0.94))
                .overlay {
                    HStack(spacing: bodyWidth / CGFloat(stripes * 2)) {
                        ForEach(0..<stripes, id: \.self) { _ in
                            Rectangle()
                                .fill(Color(white: 0.09))
                                .frame(width: bodyWidth / (CGFloat(stripes) * 2.6))
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(width: bodyWidth, height: bodyHeight)
        }
    }
}
