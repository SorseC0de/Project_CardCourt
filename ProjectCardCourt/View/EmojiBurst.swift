import SwiftUI

/// A one-shot spray of emoji out of a point. Every mark is driven by modifiers off a
/// single state flip, so the burst interpolates without rebuilding the view each frame.
struct EmojiBurst: View {
    let emoji: String
    var count = 20
    var reach: CGFloat = 190
    var size: CGFloat = 30

    @State private var fired = false
    @State private var faded = false

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let angle = spread(index)
                let distance = reach * (0.45 + CGFloat(StreakStyle.scatter(index, 2)) * 0.75)
                let drop = reach * 0.55 * CGFloat(StreakStyle.scatter(index, 3))

                Text(emoji)
                    .font(.system(size: size * (0.7 + CGFloat(StreakStyle.scatter(index, 4)) * 0.6)))
                    .rotationEffect(.degrees(fired ? Double(StreakStyle.scatter(index, 5)) * 720 - 360 : 0))
                    .offset(x: fired ? cos(angle) * distance : 0,
                            y: fired ? sin(angle) * distance + drop : 0)
                    .opacity(faded ? 0 : 1)
                    .scaleEffect(fired ? 1 : 0.4)
                    .animation(.easeOut(duration: 0.85 + Double(StreakStyle.scatter(index, 6)) * 0.5)
                        .delay(Double(StreakStyle.scatter(index, 7)) * 0.12), value: fired)
            }
        }
        .allowsHitTesting(false)
        .task {
            fired = true
            // Solid for most of the flight; it only thins out on the way off screen.
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.easeIn(duration: 0.45)) { faded = true }
        }
    }

    /// Fanned across the full circle, biased upward and outward from the rim.
    private func spread(_ index: Int) -> CGFloat {
        let base = Double(index) / Double(max(count, 1)) * 2 * .pi
        return CGFloat(base + StreakStyle.scatter(index, 1) * 0.5 - 0.25)
    }
}
