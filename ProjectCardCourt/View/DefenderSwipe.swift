import SwiftUI

/// A defender who arrives, takes something, and goes.
///
/// The one-off Clamps — the ones that empty a hand rather than sit on a SHOT — used to
/// leave a body standing on the floor for a possession as though they were still doing
/// something. They are not. He swipes, drifts off the way he came, and is gone.
struct DefenderSwipe: View {
    var seat: Seat
    /// Which way he leaves. Southwest normally, southeast when he is turned around, so he
    /// always drifts off behind his own swing.
    var mirrored = false
    var scale: CGFloat = Theme.Figure.playerScale

    private enum Drift {
        /// How far he travels on his way out, as a share of his own height.
        static let away: CGFloat = 0.34
        static let seconds: Double = 0.55
        /// How long the swipe reads before it starts to leave.
        static let hold: Double = 0.18
    }

    @State private var gone = false
    @State private var look = PlayerLook.shared

    private var side: CGFloat { Sprite.defenderSwipe.frameSize * scale }

    var body: some View {
        Image(Sprite.defenderSwipe.rawValue)
            .interpolation(.none)
            .resizable()
            .frame(width: side, height: side)
            // Red jersey, and skin of his own — a defender is a person, not a marker.
            .paletteSwap(PixelPalette.defenderUniform
                         + PixelPalette.skin(tone: look.defenderTone(for: seat)))
            .scaleEffect(x: mirrored ? -1 : 1)
            .offset(x: gone ? (mirrored ? side : -side) * Drift.away : 0,
                    y: gone ? side * Drift.away : 0)
            .opacity(gone ? 0 : 1)
            .task {
                try? await Task.sleep(for: .seconds(Drift.hold))
                withAnimation(.easeOut(duration: Drift.seconds)) { gone = true }
            }
            .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Swipe") {
    HStack(spacing: 40) {
        DefenderSwipe(seat: .east, scale: 5)
        DefenderSwipe(seat: .north, mirrored: true, scale: 5)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.courtFloor)
}
#endif
