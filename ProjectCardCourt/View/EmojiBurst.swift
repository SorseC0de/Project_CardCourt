import SwiftUI

/// A one-shot spray of emoji out of a point. Every mark is driven by modifiers off a
/// single state flip, so the burst interpolates without rebuilding the view each frame.
struct EmojiBurst: View {
    /// What it throws. More than one and each piece picks its own, so a seasonal burst is
    /// a handful of different things rather than twenty of the same one.
    let emoji: [String]
    var count = 20
    var reach: CGFloat = 190
    var size: CGFloat = 30
    /// Lettering mixed in with the pieces, for a burst that is symbols as much as emoji.
    /// Emoji are colour glyphs and ignore a foreground colour, so this only shows on the
    /// pieces that are actually text — which is the point of mixing them.
    var ink: Color?
    var drop: Color?

    private enum Burst {
        /// The throw, and then the drift after it. Two flips rather than one curve: a
        /// single easeOut long enough to keep them up this long spends almost all of it
        /// stationary, which reads as the burst having frozen.
        ///
        /// **And the drift never stops.** It was an easeOut of its own, which only moves
        /// the freeze later — they still came to rest with seconds left on screen. It is
        /// linear now, at a share of the throw per second, running far longer than
        /// anything is ever up for: they are still going outward as they fade.
        static let creepRate: CGFloat = 0.15
        static let creepSeconds: Double = 12
        static let creep: CGFloat = 1 + creepRate * CGFloat(creepSeconds)
        /// How long they hold at full before any of them starts to go.
        static let solid: Double = 2.2
        static let fade: Double = 0.9
    }

    /// One mark, before it is thrown anywhere. Its own function because a ternary over a
    /// font plus two optional styles is more than the type checker will do inline.
    private func piece(_ text: String, side: CGFloat) -> some View {
        Text(text)
            .font(ink == nil ? .system(size: side)
                  : .system(size: side, weight: .black, design: .rounded))
            .foregroundStyle(ink ?? .primary)
            .shadow(color: drop ?? .clear, radius: 0, x: side * 0.09, y: side * 0.09)
    }

    @State private var fired = false
    @State private var drifted = false
    @State private var faded = false

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let angle = spread(index)
                let distance = reach * (0.45 + CGFloat(StreakStyle.scatter(index, 2)) * 0.75)
                let drop = reach * 0.55 * CGFloat(StreakStyle.scatter(index, 3))

                // Its own question of the same noise the rest of the piece is scattered
                // by, so the mix is spread rather than clumped at one side of the burst.
                let roll = StreakStyle.scatter(index, 8) * Double(emoji.count)
                let which = min(emoji.count - 1, Int(roll))

                let side = size * (0.7 + CGFloat(StreakStyle.scatter(index, 4)) * 0.6)
                piece(emoji[which], side: side)
                    .rotationEffect(.degrees(fired ? Double(StreakStyle.scatter(index, 5)) * 720 - 360 : 0))
                    .offset(x: fired ? cos(angle) * distance * carry : 0,
                            y: fired ? sin(angle) * distance * carry + drop : 0)
                    .opacity(faded ? 0 : 1)
                    .scaleEffect(fired ? 1 : 0.4)
                    .animation(.easeOut(duration: 0.85 + Double(StreakStyle.scatter(index, 6)) * 0.5)
                        .delay(Double(StreakStyle.scatter(index, 7)) * 0.12), value: fired)
                    // Its own curve, keyed to its own flip, so the drift does not retime
                    // the throw it follows.
                    .animation(.linear(duration: Burst.creepSeconds), value: drifted)
            }
        }
        .allowsHitTesting(false)
        .task {
            fired = true
            drifted = true
            // Solid for the whole of the drift; it only thins out at the very end.
            try? await Task.sleep(for: .seconds(Burst.solid))
            withAnimation(.easeIn(duration: Burst.fade)) { faded = true }
        }
    }

    /// How far out a piece has carried by now: all the way, and then some.
    private var carry: CGFloat { drifted ? Burst.creep : 1 }

    /// Fanned across the full circle, biased upward and outward from the rim.
    private func spread(_ index: Int) -> CGFloat {
        let base = Double(index) / Double(max(count, 1)) * 2 * .pi
        return CGFloat(base + StreakStyle.scatter(index, 1) * 0.5 - 0.25)
    }
}
