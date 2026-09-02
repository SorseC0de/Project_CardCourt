import SwiftUI

/// A player: capsule body under a circle head.
/// A squat downward wedge that sits over a marked player's head.
struct MarkerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A player: the pixel sheet, wearing that seat's colours.
///
/// One sheet serves all four. The uniform is a palette swap on the two jersey entries,
/// which the ball and the skin never use — so a recolour cannot touch anything but the
/// clothes, and there is no second sheet to keep in step.
struct PlayerFigure: View {
    let seat: Seat
    var isHolding = false
    var isActing = false
    var isDimmed = false
    var marker: Color?
    /// Cards in this player's bag, shown above their head.
    var handCount: Int?
    /// Overrides what they are doing. The cutscenes use it to make someone shoot.
    var sprite: Sprite?
    /// Who last passed, which is who the human turns to face as they catch.
    var facing: Seat?
    /// When this player took possession, which starts the catch.
    var caughtAt: Date?
    var scale: CGFloat = Theme.Figure.playerScale

    @State private var catching = false
    /// Two positions, held a beat each — a hop rather than a glide.
    @State private var hop: CGFloat = 0

    private var tint: Color { Theme.color(for: seat) }

    /// Catching for a beat as the ball arrives, then dribbling; jogging without it.
    private var action: Sprite {
        if let sprite { return sprite }
        guard isHolding else { return .run }
        return catching ? .catchBall : .dribble
    }

    /// Idle opponents jog and glance back every few seconds. The human never does —
    /// they are at the near edge facing upcourt, with nothing behind them to look at.
    private var glance: Sprite? {
        guard sprite == nil, !isHolding, !seat.isHuman else { return nil }
        return .runLook
    }

    /// Dribbling is never mirrored — everyone dribbles right-handed. Only the catch and
    /// the idle glance turn, and the human only turns to meet the pass.
    private var isMirrored: Bool {
        guard action != .dribble else { return false }
        switch seat {
        case .west:  return true
        // The two on the centre line turn to meet a pass from the left.
        case .south, .north: return action == .catchBall && facing == .west
        case .east:  return false
        }
    }

    var body: some View {
        SpriteAnimation(sprite: action, scale: scale,
                        fps: Theme.Figure.playerFPS,
                        alternate: glance,
                        phase: Double(seat.rawValue) * 1.3)
            .scaleEffect(x: isMirrored ? -1 : 1)
            .paletteSwap(PixelPalette.uniform(for: seat))
            .opacity(isDimmed ? 0.4 : 1)
            .overlay(alignment: .top) {
                if let handCount {
                    Text("\(handCount)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.65)))
                        .overlay(Capsule().stroke(tint.opacity(0.8), lineWidth: 1))
                        .offset(y: -5)
                        .contentTransition(.numericText())
                }
                if let marker {
                    MarkerTriangle()
                        .fill(marker)
                        .frame(width: 28, height: 14)
                        .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
                        .offset(y: -35 + hop)
                }
            }
            .onChange(of: marker == nil) { hop = 0 }
            .task(id: marker == nil) {
                guard marker != nil else { return }
                while !Task.isCancelled {
                    hop = hop == 0 ? -12 : 0
                    try? await Task.sleep(for: .milliseconds(340))
                }
            }
            .animation(.easeOut(duration: 0.22), value: marker)
            .animation(.easeOut(duration: 0.25), value: handCount)
            .animation(.easeOut(duration: 0.22), value: isDimmed)
            .task(id: caughtAt) {
                guard caughtAt != nil, isHolding, sprite == nil else { return }
                catching = true
                // One pass of the catch sheet at its own frame rate.
                try? await Task.sleep(for: .seconds(Double(Sprite.catchBall.frames)
                                                    / Theme.Figure.playerFPS))
                catching = false
            }
    }
}

/// The ball on the court: the 6px sprite, scaled with the players so it sits in their
/// hands at the right size.
struct PixelBallView: View {
    var scale: CGFloat = Theme.Figure.playerScale
    var shot: Int?

    private var side: CGFloat { 6 * scale }

    var body: some View {
        Image("Ball")
            .interpolation(.none)
            .resizable()
            .frame(width: side, height: side)
            .overlay(alignment: .bottom) {
                if let shot {
                    // Beside the ball rather than on it: at 18pt there is no room for a
                    // number, and scaling the ball up would break step with the sprites.
                    Text("\(shot)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                        .overlay(Capsule().stroke(PixelPalette.orange, lineWidth: 1))
                        .fixedSize()
                        .offset(y: 15)
                        .contentTransition(.numericText())
                }
            }
    }
}

/// The rebound cutscene's ball, drawn large enough to want the vector.
struct BallView: View {
    var diameter: CGFloat = 20

    var body: some View {
        Image("BallVector")
            .resizable()
            .scaledToFit()
            .frame(width: diameter, height: diameter)
    }
}
