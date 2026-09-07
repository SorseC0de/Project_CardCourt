import SwiftUI

/// A many-pointed star, drawn rather than typed.
///
/// The assist badge sits on one. `points` is how many spikes; `waist` is how far the
/// valleys come in, as a share of the radius — a low waist is a sharp burst, a high one
/// is a rounded seal.
struct RadialStar: Shape {
    var points = 12
    var waist: CGFloat = 0.82

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * waist
        var path = Path()
        for step in 0..<(points * 2) {
            let radius = step.isMultiple(of: 2) ? outer : inner
            let turn = Double(step) / Double(points * 2) * 2 * .pi - .pi / 2
            let point = CGPoint(x: centre.x + radius * cos(turn),
                                y: centre.y + radius * sin(turn))
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// The board after a basket: what it was worth, and who is owed for it.
///
/// On the scorer's own card, because the points are his. The assists are stars laid over
/// it, one per man credited — and with Wide-Open Three that can be three at once, which
/// is the whole reason they are badges rather than a line of text.
struct ScoreCallView: View {
    let call: ScoreCall

    private enum Board {
        /// The score is a number and every other call is a phrase. A number wants to be
        /// bigger than a phrase.
        static let titleScale: CGFloat = 1.35
        static let star: CGFloat = 92
        static let head: CGFloat = 3
        static let drop: CGFloat = 4
        /// How far off the card's own corner the badge hangs, as shares of its own size.
        /// Off the edge on purpose — a badge tucked inside reads as part of the message
        /// rather than as something stuck on top of it.
        static let overhangX: CGFloat = 0.30
        static let overhangY: CGFloat = 0.45
        static let inset: CGFloat = 18
    }

    var body: some View {
        GeometryReader { geo in
            // The same bar the card is built from, so the badge finds the card's own
            // corner rather than the screen's.
            let bar = ModeCardStyle.bar(across: geo.size.width)
            ZStack {
                ModeCardView(title: "+\(call.points)pts",
                             subtitle: "",
                             ink: .white,
                             subtitleInk: .white,
                             seat: call.seat,
                             titleScale: Board.titleScale,
                             isLeaving: false,
                             onLanded: {},
                             onFinished: {})

                if !call.assists.isEmpty {
                    stars
                        .position(x: geo.size.width - Board.inset
                                     - Board.star * (0.5 - Board.overhangX),
                                  y: geo.size.height / 2 + bar.height
                                     + Board.star * (Board.overhangY - 0.5))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// South-east of the card, hanging off its corner.
    private var stars: some View {
        HStack(spacing: 8) {
            ForEach(call.assists, id: \.self) { seat in
                star(seat)
            }
        }
        .fixedSize()
    }

    /// One man's credit. His colour, his face, his name.
    private func star(_ seat: Seat) -> some View {
        VStack(spacing: 2) {
            SmallCapsText(text: "+1 AST", font: Chrome.display, size: 18, tracking: 0.8)
                .foregroundStyle(.white)
                .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
            HStack(spacing: 3) {
                SpriteAnimation(sprite: .heads, scale: Board.head, isPlaying: false,
                                restFrame: PlayerLook.shared.face(for: seat))
                    .paletteSwap(PlayerLook.shared.skin(for: seat))
                SmallCapsText(text: PlayerLook.shared.billing(for: seat), font: Chrome.display, size: 12,
                              tracking: 0.6)
                    .foregroundStyle(.white)
                    .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, 8)
        .frame(width: Board.star, height: Board.star)
        .background {
            RadialStar()
                .fill(Theme.color(for: seat))
                //.overlay { RadialStar().stroke(CardPalette.navy, lineWidth: 2) }
                // Hard and south-east, like every other mark in the game.
                .shadow(color: CardPalette.navy, radius: 0, x: Board.drop, y: Board.drop)
        }
    }
}

#if DEBUG
#Preview("Score call") {
    ZStack {
        Theme.courtFloor.ignoresSafeArea()
        ScoreCallView(call: ScoreCall(seat: .south, points: 3, assists: [.west, .north]))
    }
}
#endif
