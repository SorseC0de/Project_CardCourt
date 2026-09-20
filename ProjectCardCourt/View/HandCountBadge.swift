import SwiftUI

/// **How many cards a player is holding.**
///
/// It hung over his head on the floor, where it had four names, a Clamp count and the
/// player himself to stay clear of. It stands on his own block now, along the bottom edge
/// — the one place on the screen that is already only about him.
struct HandCountBadge: View {
    let count: Int
    var side: CGFloat = 17

    /// **It takes the card.** The bag swells for a beat as the count ticks over, so the
    /// arrival lands on something rather than a number quietly becoming a different one.
    @State private var took = false

    private enum Bag {
        static let gap: CGFloat = 2
        /// The art is trimmed to its own subject rather than squared off, so the number
        /// is set against what reads as the same size beside it.
        static let number: CGFloat = 1
        static let swell: CGFloat = 1.45
        /// The hold has to outlast the spring, or it is told to come back before it has
        /// finished going.
        static let holds: Double = 0.26
        static let spring: Double = 0.16
    }

    var body: some View {
        HStack(spacing: Bag.gap) {
            Image("BagIcon")
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
            Text("\(count)")
                .font(.custom("AvenirNextCondensed-Heavy", size: side * Bag.number))
                .contentTransition(.numericText())
        }
        .foregroundStyle(.white)
        .scaleEffect(took ? Bag.swell : 1)
        .animation(.spring(response: Bag.spring, dampingFraction: 0.5), value: took)
        // One drop for the pair. Without this SwiftUI casts one per child and the bag's
        // falls across the number.
        .compositingGroup()
        .shadow(color: CardPalette.black, radius: 0, x: 2, y: 2)
        .onChange(of: count) { was, now in
            guard now > was else { return }
            took = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Bag.holds))
                took = false
            }
        }
    }
}

#if DEBUG
#Preview("Hand count") {
    HStack(spacing: 20) {
        HandCountBadge(count: 4)
        HandCountBadge(count: 12, side: 26)
    }
    .padding(20)
    .background(Theme.color(for: .south))
}
#endif
