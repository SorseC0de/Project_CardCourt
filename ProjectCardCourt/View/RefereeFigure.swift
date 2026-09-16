import SwiftUI

/// A referee, on the floor for as long as the Whistle that called him is armed.
///
/// One per armed Whistle, and deliberately silent about whose it is or what it watches
/// for — that a referee is out there at all is the whole tell.
struct RefereeFigure: View {
    /// What he is doing, which is one loop and three held poses.
    enum Duty: Equatable {
        /// Jogging and looking about, which is the only one that moves on its own.
        case working
        /// Stood still, because the game is. Anything that holds the players in a pose
        /// holds him in this one — see `CourtView.courtIsRunning`.
        case waiting
        /// Blowing it. The pose does the shouting; the shake is this view's.
        case calling
        /// **Turned to the play.** Nought is looking straight out, one is looking left and
        /// two is looking right — which is how the rest of the crew turn toward whichever
        /// of them is making a call.
        case turned(Int)
        /// Following a free throw up, from the moment it is launched.
        case watching

        var sheet: Sprite {
            switch self {
            case .working:  return .refereeRunLook
            case .waiting:  return .refereeRight
            case .calling:  return .refereeCall
            case .turned:   return .refereeFront
            case .watching: return .refereeShotFront
            }
        }

        /// Which cell he is held on. Only the turned poses pick one.
        var frame: Int {
            if case .turned(let at) = self { return at }
            return 0
        }
    }

    var duty: Duty = .working
    /// The sheet faces the right-hand touchline. The left-hand posts turn him around.
    var mirrored = false
    /// His own offset into the sprite clock, so two referees do not jog in step.
    var phase: TimeInterval = 0
    var scale: CGFloat = Theme.Figure.playerScale
    /// Which of the ramp's skins he wears — see `PlayerLook.refereeTone(for:)`. A crew of
    /// four identical men is one man printed four times.
    var tone: Int = PixelPalette.drawnSkinTone
    /// Held with everything else on the floor. A referee jogging on the spot behind a
    /// dimmed court is the one man who did not notice the game had stopped.
    var frozen = false

    /// The rattle on a call.
    ///
    /// **Whole pixels, and more of them than a vibration.** The pose is already doing
    /// something ridiculous, so a polite one-pixel tremble undersells it — this is a man
    /// blowing a whistle hard enough to move himself. The two axes run at different rates
    /// so it never settles into a clean back-and-forth.
    private enum Rattle {
        static let side: CGFloat = 2
        static let hop: CGFloat = 1
        /// Both divide the refresh, and neither divides the other.
        static let sideFPS: Double = 20
        static let hopFPS: Double = 15
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SpriteShadow(scale: scale)
            TimelineView(.animation(minimumInterval: 1 / Rattle.sideFPS,
                                    paused: duty != .calling)) { tick in
                let shake = rattle(at: tick.date)
                SpriteAnimation(sprite: duty.sheet, scale: scale,
                                fps: Theme.Figure.playerFPS,
                                isPlaying: duty == .working && !frozen,
                                restFrame: duty.frame, phase: phase)
                    .scaleEffect(x: mirrored ? -1 : 1)
                    .offset(x: shake.x * scale, y: shake.y * scale)
            }
            .paletteSwap(PixelPalette.skin(tone: tone))
        }
    }

    /// Where the shake has him this instant, in art pixels. Zero unless he is calling.
    private func rattle(at date: Date) -> CGPoint {
        guard duty == .calling else { return .zero }
        let now = date.timeIntervalSinceReferenceDate
        let side = Int(now * Rattle.sideFPS) % 2 == 0 ? Rattle.side : -Rattle.side
        // Off the floor on one beat in three, which is the bit that reads as comic.
        let hop = Int(now * Rattle.hopFPS) % 3 == 0 ? -Rattle.hop : 0
        return CGPoint(x: side, y: hop)
    }
}

/// What a sprite puts on the floor.
///
/// Drawn at the sheet's own frame size, because the art is already placed inside a 32×32
/// frame to sit under a character in one — so there is nothing to position here.
struct SpriteShadow: View {
    var scale: CGFloat = Theme.Figure.playerScale

    /// The art fills its frame, which turned out to be a good deal bigger than a figure
    /// standing in the middle of one.
    private static let shrink: CGFloat = 0.75

    /// How far off the floor whoever is casting it has got, 0 to 1. A shadow does not
    /// go up with a jump — the gap opening under him is what it says, by shrinking and
    /// thinning as he rises.
    var lift: CGFloat = 0

    private static let rest: Double = 0.66

    /// What it measures on the floor, which does not change. **The gap is drawn, not
    /// laid out**: shrinking the frame itself made a bottom-aligned shadow shrink toward
    /// its own bottom edge, so it slid down the floor as he went up and back as he came
    /// down — a shadow walking away from the man casting it.
    private var side: CGFloat { Sprite.run.frameSize * scale * Self.shrink }

    /// How much of it is left at the top of a jump.
    private var gap: CGFloat { 1 - (1 - Theme.Figure.shadowInAir) * lift }

    /// Where the blob actually is in its cell. **Measured, not assumed**: the drawing
    /// occupies rows 25 to 29 of 32 — it is at the bottom of the frame, not the middle of
    /// it — so scaling about the frame's centre walked the ink up toward the middle as it
    /// shrank, which is a shadow climbing with the man casting it. Scaled about itself, it
    /// stays where his feet were.
    private static let blob = UnitPoint(x: 0.5, y: 27.5 / 32)

    var body: some View {
        Image("PlayerShadow")
            .interpolation(.none)
            .resizable()
            .frame(width: side, height: side)
            .scaleEffect(gap, anchor: Self.blob)
            .opacity(Self.rest * (1 - Theme.Figure.shadowFadeInAir * lift))
    }
}

#if DEBUG
#Preview("Referee") {
    HStack(spacing: 0) {
        RefereeFigure(scale: 4, tone: 0)
        RefereeFigure(mirrored: true, scale: 4, tone: 3)
    }
    .background(Theme.courtFloor)
}
#endif
