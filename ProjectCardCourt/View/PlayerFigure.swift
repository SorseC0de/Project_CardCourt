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
    /// Stops on the last frame instead of looping. The shot does not repeat.
    var playsOnce = false
    /// Overrides the usual rate for a sprite that wants its own pace.
    var fps: Double?
    /// Plays up to this frame and holds there, counting from zero. The turnover runs the
    /// first of the catch and stops on the reach, so the ball is met but never gathered in.
    var stopAtFrame: Int?
    /// Who last passed, which is who the human turns to face as they catch.
    var facing: Seat?
    /// Overrides which way the sprite faces. A cutscene knows which side the ball is
    /// coming in from outright, where the court has to work it out from who threw it.
    var mirrored: Bool?
    /// When this player took possession, which starts the catch.
    var caughtAt: Date?
    /// The ball is still crossing to them. They have not got it yet, so they are not
    /// dribbling it — they are running to meet it.
    var awaitingBall = false
    var scale: CGFloat = Theme.Figure.playerScale

    @State private var look = PlayerLook.shared
    /// Observed, not just read — otherwise moving a slider changes nothing on screen.
    @State private var ballTuning = BallTuning.shared
    @State private var catching = false
    /// When this catch began. The sheet is counted from here, not from the wall clock.
    @State private var caughtFrom: Date?
    /// A one-shot sprite counts from here; without it the frame index never advances.
    @State private var startedAt: Date?
    /// Two positions, held a beat each — a hop rather than a glide.
    @State private var hop: CGFloat = 0

    private var tint: Color { Theme.color(for: seat) }

    /// The rate this sprite runs at. The catch has its own, and the hold that keeps
    /// `catching` true is measured from the same number — set them apart and the sprite
    /// finishes before the state does, or keeps playing after it.
    private var frameRate: Double {
        if let fps { return fps }
        return action == .catchBall ? ballTuning.catchFPS : Theme.Figure.playerFPS
    }

    /// Catching for a beat as the ball arrives, then dribbling; jogging without it.
    private var action: Sprite {
        if let sprite { return sprite }
        if catching { return .catchBall }
        guard isHolding, !awaitingBall else { return .run }
        return .dribble
    }

    /// Idle opponents jog and glance back every few seconds. The human never does —
    /// they are at the near edge facing upcourt, with nothing behind them to look at.
    private var glance: Sprite? {
        guard sprite == nil, !isHolding, !seat.isHuman else { return nil }
        return .runLook
    }

    /// Whether a seat catches flipped, given who threw it.
    ///
    /// Static and shared on purpose: the ball's hand offset is measured on the unflipped
    /// sprite, so anything putting something *in* those hands has to ask the same
    /// question the figure does — see `CourtView.ballPoint`. Two copies of this rule
    /// would drift and the ball would sit on the wrong hip for half the table.
    /// True when the ball is arriving from the player's **right**.
    ///
    /// Which is the same thing as asking which hand it lands in: the sheet holds the ball
    /// on its left, so a mirrored sprite holds it on its right. West is always turned that
    /// way and East never is; the two on the centre line turn to meet whichever side the
    /// pass came from. It read `facing == .west` before, which put the ball in the far
    /// hand — a pass from John arrived at the far side of the player receiving it.
    static func catchIsMirrored(seat: Seat, facing: Seat?) -> Bool {
        switch seat {
        case .west:  return true
        case .south, .north: return facing == .east
        case .east:  return false
        }
    }

    /// Dribbling is never mirrored — everyone dribbles right-handed. Only the catch and
    /// the idle glance turn, and the human only turns to meet the pass.
    private var isMirrored: Bool {
        if let mirrored { return mirrored }
        guard action != .dribble else { return false }
        // West faces the other way whatever they are doing; the centre line only turns
        // to meet a pass.
        if seat == .west { return true }
        guard action == .catchBall else { return false }
        return Self.catchIsMirrored(seat: seat, facing: facing)
    }

    var body: some View {
        SpriteAnimation(sprite: action, scale: scale,
                        fps: frameRate,
                        // A catch is a one-shot like the shot is. Looping it meant its
                        // frame came from `timeIntervalSinceReferenceDate % frames` — the
                        // wall clock — so every catch began on whatever frame the world
                        // happened to be on, and no two played the same.
                        playsOnce: playsOnce || action == .catchBall,
                        alternate: playsOnce ? nil : glance,
                        phase: Double(seat.rawValue) * 1.3,
                        // A catch on the court counts from when the ball landed; one a
                        // cutscene asks for directly counts from when it appeared.
                        startedAt: action == .catchBall ? (caughtFrom ?? startedAt) : startedAt,
                        stopAtFrame: stopAtFrame)
            .scaleEffect(x: isMirrored ? -1 : 1)
            // Never animated. Interpolating a flip runs the sprite through zero width,
            // which reads as a sheet of cardboard turning rather than a player facing
            // the other way.
            .animation(nil, value: isMirrored)
            .onAppear { if playsOnce { startedAt = Date() } }
            .paletteSwap(PixelPalette.uniform(for: seat)
                         + PixelPalette.skin(tone: look.tone(for: seat)))
            .opacity(isDimmed ? 0.4 : 1)
            .overlay(alignment: .top) {
                if let handCount {
                    // The number alone, at the size the badge around it used to be. Its
                    // own hard drop in the seat's colour is what ties it to its player now
                    // that there is no ring doing it.
                    Text("\(handCount)")
                        .font(.custom("AvenirNextCondensed-Heavy", size: 34))
                        .foregroundStyle(.white)
                        .shadow(color: tint, radius: 0, x: 4, y: 4)
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
                // Stamped before the sheet swaps in, or the first frame is drawn against
                // a start time that does not exist yet.
                caughtFrom = Date()
                catching = true
                // One pass of the catch sheet at its own frame rate.
                try? await Task.sleep(for: .seconds(Double(Sprite.catchBall.frames)
                                                    / ballTuning.catchFPS))
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
