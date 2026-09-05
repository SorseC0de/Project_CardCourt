import SwiftUI

/// The mark of a defender standing on you.
///
/// Zigzags either side of the figure, red and lit — the Pokémon bind. It replaced a pair
/// of little red bodies on the floor, which read as two more players rather than as
/// something being done *to* one.
///
/// Only standing Clamps show it. A Clamp that takes cards and leaves has nothing to
/// signal, and the swipe says that instead — see `DefenderSwipe`.
struct BindLines: View {
    /// The figure's own height, which everything here is a share of.
    var height: CGFloat

    private enum Coil {
        /// How far out from the figure's middle each side sits. Clear of the sprite —
        /// drawn over him they read as markings on the shirt.
        static let spread: CGFloat = 0.34
        /// How tall the zigzag is against the figure, and how wide one zag runs.
        static let length: CGFloat = 0.30
        static let zag: CGFloat = 0.038
        static let steps = 6
        static let line: CGFloat = 0.018
        static let glow: CGFloat = 0.04
        /// How long the wave takes to travel one zag. It is a live coil, not a stamp.
        static let seconds: Double = 0.5
    }

    var body: some View {
        // **Two, whatever is on him.** The count used to be the defender count, so a Trap
        // wore three coils a side and a Contest one — which read as a drawing bug rather
        // than as a number. How many are on him is the cutscene's job to say; this only
        // says that somebody is.
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate / Coil.seconds
            ZStack {
                ForEach([-1, 1], id: \.self) { side in
                    zigzag(side: CGFloat(side), phase: phase)
                }
            }
        }
        .frame(width: height, height: height)
        .allowsHitTesting(false)
    }

    /// One coil, with the wave running down it.
    private func zigzag(side: CGFloat, phase: Double) -> some View {
        let out = height * Coil.spread
        let run = height * Coil.length
        let zag = height * Coil.zag
        let travel = phase.truncatingRemainder(dividingBy: 2)
        return Path { path in
            let x = height / 2 + side * out
            let top = height / 2 - run / 2
            path.move(to: CGPoint(x: x, y: top))
            for step in 1...Coil.steps {
                let y = top + run * CGFloat(step) / CGFloat(Coil.steps)
                // The sine is what animates it: the same zigzag, walked along. Alternating
                // by index alone gave a static mark that only its glow moved.
                let swing = sin((Double(step) + travel) * .pi) * Double(zag)
                path.addLine(to: CGPoint(x: x + CGFloat(swing) * side, y: y))
            }
        }
        .stroke(CardPalette.red, style: StrokeStyle(lineWidth: height * Coil.line,
                                                   lineCap: .round, lineJoin: .round))
        .shadow(color: CardPalette.red.opacity(0.85), radius: height * Coil.glow)
        .shadow(color: CardPalette.red.opacity(0.5), radius: height * Coil.glow * 2)
    }
}

#if DEBUG
#Preview("Bind") {
    HStack(spacing: 40) {
        ForEach(0..<2, id: \.self) { _ in
            ZStack {
                PlayerFigure(seat: .east)
                BindLines(height: Theme.Figure.height)
            }
        }
    }
    .padding(40)
    .background(Theme.courtFloor)
}
#endif
