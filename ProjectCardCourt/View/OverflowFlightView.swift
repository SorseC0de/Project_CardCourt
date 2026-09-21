import SwiftUI

/// **A card there was no room for, going into the SHOT instead.**
///
/// Off the deck, across to the plate, and smaller as it goes, so it reads as being taken
/// in rather than put down. The plate swells as it lands — see `ShootDomeView` — which is
/// what makes the raise something seen rather than a number that has changed.
struct OverflowFlightView: View {
    let card: CardDescriptor
    /// Both ends, on the screen.
    let from: CGPoint
    let to: CGPoint

    @State private var gone = false

    private enum Trip {
        /// How wide it leaves the deck, and how small it is by the time it is in.
        static let width: CGFloat = 46
        static let absorbed: CGFloat = 0.2
    }

    var body: some View {
        GeometryReader { screen in
            let mine = screen.frame(in: .named(Chrome.screen))
            let start = CGPoint(x: from.x - mine.minX, y: from.y - mine.minY)
            let end = CGPoint(x: to.x - mine.minX, y: to.y - mine.minY)
            CardFrontView(descriptor: card, displayWidth: Trip.width)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
                .scaleEffect(gone ? Trip.absorbed : 1)
                .opacity(gone ? 0.35 : 1)
                .position(gone ? end : start)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeIn(duration: Pacing.overflowFlight)) { gone = true }
        }
    }
}
