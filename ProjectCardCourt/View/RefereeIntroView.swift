import SwiftUI

/// **Where the officials' deck sits**, in the screen's own space: the corner an
/// official's card comes out of at the top of a game.
struct OfficialsPoint: PreferenceKey {
    static let defaultValue: CGPoint? = nil
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}

/// And the slot it comes to rest in, under the blocks.
struct CrewSlotPoint: PreferenceKey {
    static let defaultValue: CGPoint? = nil
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}

/// **The official coming out**, before a ball is thrown.
///
/// His card crosses from the officials' deck in the corner to the middle of the screen
/// and stands there to be read; he warps onto the floor with the ball while it waits;
/// then the card turns itself into its slot and the game starts. One view for the whole
/// trip, so the card is the same card the whole way rather than three that look alike.
struct RefereeIntroView: View {
    let card: CardDescriptor
    let phase: GameController.RefereeIntro
    /// Where it comes from, and where it ends up. Both in the screen's own space.
    var from: CGPoint?
    var slot: CGPoint?

    /// Flipped on the first frame, so the card starts in the corner and springs out of
    /// it rather than appearing already arrived.
    @State private var left = false

    private enum Trip {
        /// How wide the card is drawn at each end of the trip, and while it is read.
        static let atDeck: CGFloat = 26
        static let read: CGFloat = 150
        /// How far up the screen it stands while it is being read.
        static let readY: CGFloat = 0.42
        /// The turn it makes on its way into the slot, and the one it wears there —
        /// the row under the blocks stands its cards at an angle.
        static let spin: Double = -375
        static let resting: Double = -16
    }

    var body: some View {
        GeometryReader { screen in
            // **Both ends are measured on the screen**, and this view is not the screen:
            // its own origin is wherever the band it sits in begins. Brought into this
            // view's space, or the card flies from a corner nobody pressed.
            let mine = screen.frame(in: .named(Chrome.screen))
            let here = { (spot: CGPoint) in
                CGPoint(x: spot.x - mine.minX, y: spot.y - mine.minY)
            }
            let middle = CGPoint(x: screen.size.width / 2,
                                 y: screen.size.height * Trip.readY)
            let deck = from.map(here) ?? CGPoint(x: screen.size.width - 40, y: 60)
            let home = slot.map(here) ?? middle
            let travelling = phase == .toSlot
            CardFrontView(descriptor: card,
                          displayWidth: travelling ? SeatPanelsView.cardWidth
                                      : (left ? Trip.read : Trip.atDeck),
                          expanded: !travelling && left)
                .rotationEffect(.degrees(travelling ? Trip.resting : (left ? 0 : Trip.spin)))
                .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
                .position(travelling ? home : (left ? middle : deck))
                .onAppear {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { left = true }
                }
        }
        .allowsHitTesting(false)
        // The trip to the slot is the phase changing, so it is animated here rather than
        // by whoever set it — a controller has no springs.
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: phase)
    }
}

#if DEBUG
#Preview("Referee intro") {
    ZStack {
        Theme.sceneGround
        RefereeIntroView(card: CardLibrary.travel, phase: .read,
                         from: CGPoint(x: 340, y: 60),
                         slot: CGPoint(x: 300, y: 300))
    }
}
#endif
