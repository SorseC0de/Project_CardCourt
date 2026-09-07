import SwiftUI

/// A referee, on the floor for as long as the Whistle that called him is armed.
///
/// One per armed Whistle, and deliberately silent about whose it is or what it watches
/// for — that a referee is out there at all is the whole tell.
struct RefereeFigure: View {
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

    var body: some View {
        ZStack(alignment: .bottom) {
            SpriteShadow(scale: scale)
            SpriteAnimation(sprite: .refereeRunLook, scale: scale,
                            fps: Theme.Figure.playerFPS, isPlaying: !frozen, phase: phase)
                .scaleEffect(x: mirrored ? -1 : 1)
                .paletteSwap(PixelPalette.skin(tone: tone))
        }
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

    /// How much of it is left at the top of a jump. Applied as a scale about its own
    /// centre, so it stays where his feet were.
    private var gap: CGFloat { 1 - (1 - Theme.Figure.shadowInAir) * lift }

    var body: some View {
        Image("PlayerShadow")
            .interpolation(.none)
            .resizable()
            .frame(width: side, height: side)
            .scaleEffect(gap)
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
