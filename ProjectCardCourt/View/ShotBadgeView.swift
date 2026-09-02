import SwiftUI

/// The live SHOT reading, drawn the way the cards draw theirs — ball behind, number over
/// it, hard zero-blur shadows — just larger, and without a sign, since this is a total
/// rather than a change.
struct ShotBadgeView: View {
    let shot: Int
    var ballSize: CGFloat = 58

    private var numberSize: CGFloat { ballSize * 0.68 }
    private var drop: CGFloat { ballSize * 0.06 }

    var body: some View {
        ZStack {
            Image("BallVector")
                .resizable()
                .scaledToFit()
                .frame(width: ballSize, height: ballSize)
                .shadow(color: CardPalette.blue, radius: 0, x: drop, y: drop)

            HStack(alignment: .center, spacing: 0) {
                Text("\(shot)")
                    .font(.custom("AvenirNextCondensed-Heavy", size: numberSize))
                    .tracking(numberSize * CardLayout.badgeTracking)
                    .contentTransition(.numericText())
                Text("%")
                    .font(.custom("AvenirNextCondensed-Heavy", size: numberSize * 0.5))
            }
            .foregroundStyle(.white)
            .shadow(color: .black, radius: 0, x: drop * 0.7, y: drop * 0.7)
        }
        .animation(.easeOut(duration: 0.25), value: shot)
    }
}
