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

    var body: some View {
        ZStack(alignment: .bottom) {
            SpriteShadow(scale: scale)
            SpriteAnimation(sprite: .refereeRunLook, scale: scale,
                            fps: Theme.Figure.playerFPS, phase: phase)
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

    private var side: CGFloat {
        Sprite.run.frameSize * scale * Self.shrink
            * (1 - (1 - Theme.Figure.shadowInAir) * lift)
    }

    var body: some View {
        Image("PlayerShadow")
            .interpolation(.none)
            .resizable()
            .frame(width: side, height: side)
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
