import SwiftUI

/// **The shine off a challenge**: a four-point star opening out of the man who made it.
///
/// Four points rather than a burst, because a burst is what a basket does — this is one
/// hard flash off a single player, and the shape says it is his rather than the table's.
struct ChallengeStar: View {
    /// How wide the arms reach at full stretch, in points.
    var reach: CGFloat = 220

    @State private var out = false

    var body: some View {
        ZStack {
            arm.frame(width: reach, height: reach * Star.thin)
            arm.frame(width: reach * Star.thin, height: reach)
                .rotationEffect(.degrees(90))
            core
        }
        .scaleEffect(out ? 1 : Star.from)
        .opacity(out ? 0 : 1)
        .blendMode(.screen)
        .allowsHitTesting(false)
        .task {
            withAnimation(.easeOut(duration: Star.seconds)) { out = true }
        }
    }

    /// One arm, brightest in the middle and gone at the tips.
    private var arm: some View {
        Capsule()
            .fill(LinearGradient(colors: [.clear, ChallengeView.Green.bright, .white,
                                          ChallengeView.Green.bright, .clear],
                                 startPoint: .leading, endPoint: .trailing))
    }

    private var core: some View {
        Circle()
            .fill(RadialGradient(colors: [.white, ChallengeView.Green.bright, .clear],
                                 center: .center, startRadius: 0,
                                 endRadius: reach * Star.core))
            .frame(width: reach * Star.core * 2, height: reach * Star.core * 2)
    }

    private enum Star {
        /// How thin an arm is against its length.
        static let thin: CGFloat = 0.055
        static let core: CGFloat = 0.11
        /// It starts small and opens; it does not appear at full size.
        static let from: CGFloat = 0.2
        static let seconds: Double = 0.55
    }
}
