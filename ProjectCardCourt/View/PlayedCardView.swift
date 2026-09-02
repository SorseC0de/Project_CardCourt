import SwiftUI

/// A card someone just played, sprung from their seat to the middle of the screen.
///
/// Whistles arrive face down. Arming one is deliberately secret — the log only says the
/// referees are watching — so showing the front here would give the trap away.
struct PlayedCardView: View {
    let played: PlayedCard
    let width: CGFloat

    @State private var arrived = false

    private var origin: UnitPoint {
        switch played.seat.slot(viewedFrom: GameRules.humanSeat) {
        case .north: return .top
        case .east:  return .trailing
        case .west:  return .leading
        case .south: return .bottom
        }
    }

    var body: some View {
        GeometryReader { geo in
            let start = CGPoint(x: geo.size.width * origin.x, y: geo.size.height * origin.y)
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            Group {
                if played.faceDown {
                    Image("CardBackFull")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width)
                } else {
                    CardFrontView(descriptor: played.descriptor, displayWidth: width)
                }
            }
            .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
            .scaleEffect(arrived ? 1 : 0.25)
            .rotationEffect(.degrees(arrived ? 0 : -14))
            .position(arrived ? centre : start)
            .opacity(arrived ? 1 : 0)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { arrived = true }
        }
    }
}
