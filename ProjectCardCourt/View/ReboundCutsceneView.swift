import SwiftUI

/// The rebound phase, played as a cutscene: the ball loose and spinning, streaks
/// tearing past behind it, while everyone commits a hidden bid.
struct ReboundCutsceneView: View {
    let shooter: Seat
    let revealedBids: [Seat: Int]?

    @State private var spin = false
    @State private var lift = false

    private var order: [Seat] { shooter.clockwiseOrderFromHere }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.55))

            SideStreaks()

            VStack(spacing: 10) {
                Text(revealedBids == nil ? "LOOSE BALL" : "CRASHING THE GLASS")
                    .font(.system(size: 13, weight: .black))
                    .tracking(2.2)
                    .foregroundStyle(Theme.ball)

                BallView(diameter: 260)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .offset(y: lift ? -7 : 7)
                    .shadow(color: Theme.ball.opacity(0.55), radius: 14)

                if let revealedBids {
                    // Revealed shooter-first then clockwise, the order the rule names.
                    HStack(spacing: 10) {
                        ForEach(order, id: \.self) { seat in
                            VStack(spacing: 2) {
                                Text(seat.playerName.uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Theme.inkDim)
                                Text("\(revealedBids[seat] ?? 0)")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                                    .frame(width: 26, height: 24)
                                    .background(RoundedRectangle(cornerRadius: 6)
                                        .fill(Theme.color(for: seat).opacity(0.85)))
                            }
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(shooter.isHuman ? "your" : shooter.playerName + "'s") miss · SHOT stays live")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.inkDim)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: revealedBids)
        .onAppear {
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { lift = true }
        }
    }
}
