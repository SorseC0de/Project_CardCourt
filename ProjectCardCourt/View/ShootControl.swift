import SwiftUI

/// **The ball you shoot with, and the SHOT it is worth.**
///
/// The board's number used to sit in the HUD at the top and the three finishes in a
/// capsule at the bottom, so the reading and the decision were at opposite ends of the
/// screen. They are one object now: the ball says what the shot is worth, and pressing it
/// throws the three finishes out as rays.
///
/// **The word over the number, overlapping it** — the title's own arrangement, small over
/// large. See `TitleWordmark`.
struct ShootControl: View {
    let shot: Int
    /// Dim Dome: the number is not this player's to read.
    var hidden = false
    /// Which finishes are on offer. The rest are thrown out greyed, so the shape of the
    /// choice never changes and you can see what you are working toward.
    var offered: Set<ShotType> = []
    /// Whether the rays are out. Owned by the screen, because a press anywhere else puts
    /// them away — see `GameView`.
    @Binding var open: Bool
    /// What the pad's cursor is on, so a ring can sit on a ray — and so the rays are out
    /// whenever the pad is pointing at one.
    var ringed: PadSpot?
    var onShoot: (ShotType) -> Void = { _ in }

    /// Out because they were asked for, or because the pad is on one of them.
    private var showing: Bool {
        if case .finish = ringed { return true }
        return open
    }

    private enum Ray {
        /// How big the ball is drawn, and how far a ray's own centre sits from its own.
        static let ball: CGFloat = 76
        static let reach: CGFloat = 96
        /// Where the three of them sit, in degrees from straight up.
        static let angles: [Double] = [-52, 0, 52]
        static let word: CGFloat = 13
        static let pill = CGSize(width: 74, height: 30)
        static let drop: CGFloat = 3
        /// How far the small word laps over the number, as a share of its own size.
        static let overlap: CGFloat = 0.34
        static let greyed: Double = 0.45
    }

    /// The three, in the order they are thrown out: left, up, right.
    private static let finishes: [ShotType] = [.layup, .dunk, .three]

    /// **The colour each finish wears.** Orange is the shot that is always there; the two
    /// that have to be earned say so by not being it.
    private static func ink(for finish: ShotType) -> Color {
        switch finish {
        case .layup: return CardPalette.orange
        case .dunk:  return CardPalette.red
        case .three: return CardPalette.gold
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(Self.finishes.enumerated()), id: \.offset) { index, finish in
                ray(finish, at: Ray.angles[index])
            }
            ball
        }
        .frame(width: Ray.ball, height: Ray.ball)
        .animation(.spring(response: 0.34, dampingFraction: 0.72), value: showing)
    }

    /// The ball itself: the board's number on it, and the word over that.
    private var ball: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) { open.toggle() }
        } label: {
            ZStack(alignment: .top) {
                ShotBadgeView(shot: shot, ballSize: Ray.ball, hidden: hidden)
                ActionText("Shoot", size: Ray.word, ink: .white, drop: CardPalette.blue,
                           taper: 0, tracking: 0.08)
                    .offset(y: -Ray.word * Ray.overlap)
            }
        }
        .buttonStyle(.plain)
        .tutorialTarget(.shotHUD)
    }

    /// One finish, thrown out from the ball on its own line.
    private func ray(_ finish: ShotType, at angle: Double) -> some View {
        let live = offered.contains(finish)
        let radians = (angle - 90) * .pi / 180
        let out = showing ? Ray.reach : 0
        return Button { onShoot(finish) } label: {
            Text(finish.name.uppercased())
                .font(.system(size: Ray.word, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(live ? .white : Color.white.opacity(Ray.greyed))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: Ray.pill.width, height: Ray.pill.height)
                .background {
                    if live {
                        // Lit the way every ready thing in this game is — see `SpectrumFill`.
                        SpectrumFill(resting: Self.ink(for: finish)) { Capsule() }
                    } else {
                        Capsule().fill(CardPalette.gray)
                    }
                }
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                .background(Capsule().fill(CardPalette.blue)
                    .offset(x: Ray.drop, y: Ray.drop))
        }
        .buttonStyle(.plain)
        .disabled(!live || !showing)
        .padRing(ringed == .finish(finish), corner: Ray.pill.height / 2)
        .opacity(showing ? 1 : 0)
        .scaleEffect(showing ? 1 : 0.4)
        .offset(x: CGFloat(cos(radians)) * out, y: CGFloat(sin(radians)) * out)
    }
}

#if DEBUG
#Preview("Shoot") {
    struct Bench: View {
        @State private var open = true
        var body: some View {
            ShootControl(shot: 65, offered: [.layup, .three], open: $open)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.sceneGround)
        }
    }
    return Bench()
}
#endif
