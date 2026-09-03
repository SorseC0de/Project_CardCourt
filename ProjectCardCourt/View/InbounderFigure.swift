import SwiftUI

/// The player throwing it back in, stood on the sideline.
///
/// Three sheets laid over one another: a body, a head, and a face. They are separate so a
/// face can be chosen later without redrawing a body, and so the face can move a pixel on
/// its own — which is the whole animation.
///
/// **The loop is four frames and deliberately slow.** Neutral, face a pixel right,
/// neutral, face a pixel left. Game & Watch rather than animation: two poses and a hold,
/// so the eye reads a *state* rather than a motion. Anything faster looks like a fidget.
struct InbounderFigure: View {
    var seat: Seat
    /// Which body. The thrower's four frames, or the receiver's one.
    var sprite: Sprite = .inbounder
    /// Which face he wears. Nine to choose from; customisation later.
    var face: Int = 0
    var scale: CGFloat = Theme.Figure.playerScale
    var mirrored = false
    /// Frames a second. The slowest thing in the game on purpose.
    var fps: Double = Theme.Figure.sidelineFPS

    private var side: CGFloat { sprite.frameSize * scale }
    /// The face's shift per frame, in art pixels — the loop, written out.
    private static let sway: [CGFloat] = [0, 1, 0, -1]

    @State private var look = PlayerLook.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / fps)) { timeline in
            // A one-frame body has nothing to step through, and a face that swayed on
            // its own would be a head shaking on a statue.
            let step = sprite.frames > 1
                ? Int(timeline.date.timeIntervalSinceReferenceDate * fps) % sprite.frames : 0
            ZStack(alignment: .topLeading) {
                cell(sprite, index: step, size: sprite.frameSize)
                head(.heads, index: look.tone(for: seat) == nil ? 0 : 0, shift: 0)
                head(.faces, index: face, shift: Self.sway[step % Self.sway.count])
            }
            .frame(width: side, height: side)
        }
        .paletteSwap(PixelPalette.uniform(for: seat)
                     + PixelPalette.skin(tone: look.tone(for: seat)))
        .scaleEffect(x: mirrored ? -1 : 1)
    }

    /// One cell of a sheet, drawn at the body's size.
    private func cell(_ sprite: Sprite, index: Int, size: CGFloat) -> some View {
        Image(sprite.rawValue)
            .interpolation(.none)
            .resizable()
            .frame(width: size * scale, height: size * scale * CGFloat(sprite.frames))
            .offset(y: -CGFloat(index) * size * scale)
            .frame(width: size * scale, height: size * scale, alignment: .top)
            .clipped()
    }

    /// A head or a face, placed on the body's shoulders and nudged by the loop.
    private func head(_ sprite: Sprite, index: Int, shift: CGFloat) -> some View {
        cell(sprite, index: index, size: sprite.frameSize)
            .offset(x: (SpriteMetrics.headOrigin.x + shift) * scale,
                    y: SpriteMetrics.headOrigin.y * scale)
    }
}

#if DEBUG
#Preview("Inbounder") {
    HStack(spacing: 30) {
        InbounderFigure(seat: .south, scale: 5)
        InbounderFigure(seat: .east, sprite: .inboundReceiver, scale: 5, mirrored: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.courtFloor)
}
#endif
