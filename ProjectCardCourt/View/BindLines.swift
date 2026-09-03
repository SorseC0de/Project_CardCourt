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
    /// How many are on them. More coils for more defenders.
    var defenders: Int = 1
    /// The figure's own height, which everything here is a share of.
    var height: CGFloat

    private enum Coil {
        /// How far out from the figure's middle each side sits.
        static let spread: CGFloat = 0.20
        /// How tall the zigzag is against the figure, and how wide one zag runs.
        static let length: CGFloat = 0.42
        static let zag: CGFloat = 0.055
        /// Points per side, per defender.
        static let steps = 5
        static let line: CGFloat = 0.022
        static let glow: CGFloat = 0.05
    }

    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<max(1, defenders), id: \.self) { rank in
                ForEach([-1, 1], id: \.self) { side in
                    zigzag(side: CGFloat(side), rank: CGFloat(rank))
                }
            }
        }
        .frame(width: height, height: height)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func zigzag(side: CGFloat, rank: CGFloat) -> some View {
        let out = height * Coil.spread * (1 + rank * 0.45)
        let run = height * Coil.length
        let zag = height * Coil.zag
        return Path { path in
            let x = height / 2 + side * out
            let top = height / 2 - run / 2
            path.move(to: CGPoint(x: x, y: top))
            for step in 1...Coil.steps {
                let y = top + run * CGFloat(step) / CGFloat(Coil.steps)
                // Alternating, and mirrored on the far side so the two read as a pair
                // squeezing rather than two identical marks.
                path.addLine(to: CGPoint(x: x + (step.isMultiple(of: 2) ? zag : -zag) * side,
                                         y: y))
            }
        }
        .stroke(CardPalette.red, style: StrokeStyle(lineWidth: height * Coil.line,
                                                   lineCap: .round, lineJoin: .round))
        .shadow(color: CardPalette.red.opacity(pulse ? 0.9 : 0.45),
                radius: height * Coil.glow)
        .shadow(color: CardPalette.red.opacity(pulse ? 0.6 : 0.25),
                radius: height * Coil.glow * 2)
    }
}

#if DEBUG
#Preview("Bind") {
    HStack(spacing: 40) {
        ForEach(1..<4, id: \.self) { n in
            ZStack {
                PlayerFigure(seat: .east)
                BindLines(defenders: n, height: Theme.Figure.height)
            }
        }
    }
    .padding(40)
    .background(Theme.courtFloor)
}
#endif
