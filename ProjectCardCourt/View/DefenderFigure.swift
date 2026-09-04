import SwiftUI

/// The body a standing Clamp puts in front of its victim, drawn when it matters — which
/// is the shot, not the whole possession. On the court the Clamp shows as coils on the
/// player; see `BindLines`.
///
/// Two poses at four frames a second, like everything else off the run of play. He is
/// braced, not scrambling.
struct DefenderFigure: View {
    /// Whoever he is guarding. His own skin is rolled from it and kept, so the same
    /// defender comes back rather than a new man each time.
    var seat: Seat
    var scale: CGFloat = Theme.Figure.playerScale
    var mirrored = false
    var fps: Double = Theme.Figure.sidelineFPS

    @State private var look = PlayerLook.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            SpriteShadow(scale: scale)
            SpriteAnimation(sprite: .defender, scale: scale, fps: fps)
        }
            // Red whoever played the card — a Clamp is the defence arriving, not a
            // teammate.
            .paletteSwap(PixelPalette.defenderUniform
                         + PixelPalette.skin(tone: look.defenderTone(for: seat)))
            .scaleEffect(x: mirrored ? -1 : 1)
    }
}

#if DEBUG
#Preview("Defender") {
    HStack(spacing: 20) {
        DefenderFigure(seat: .south, scale: 5)
        DefenderFigure(seat: .east, scale: 5, mirrored: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.courtFloor)
}
#endif
