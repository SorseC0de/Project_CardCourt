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
    /// Raised once the swipe has landed, so the court can bring him to the front. He
    /// arrives from *behind* the man he is reaching past — a defender who pops in front
    /// of him has already got there.
    var onFront: () -> Void = {}

    private enum Drift {
        /// Where he comes in from, as shares of his own height: up and to the right, so
        /// he arrives out of the court rather than out of the man he is guarding.
        static let inX: CGFloat = 0.55
        static let inY: CGFloat = -0.40
        static let arrive: Double = 0.28
        /// How far he travels on his way out, as a share of his own height.
        static let away: CGFloat = 0.34
        static let seconds: Double = 0.70
        /// How long the swipe reads before it starts to leave.
        static let hold: Double = 0.55
        /// The fade rides the tail of the drift rather than the whole of it. Fading from
        /// the first frame of the walk meant he was half gone before he had gone
        /// anywhere, which read as the sprite failing rather than as a man leaving.
        static let fade: Double = 0.30
        /// When he comes to the front, as a share of the way out. He arrives from behind
        /// the player — a defender who pops in front of the man he is reaching past has
        /// already got there — and steps in front once the swipe has landed.
        static let front: Double = 0.55
    }

    @State private var arrived = false
    @State private var gone = false
    @State private var faded = false
    @State private var look = PlayerLook.shared

    private var side: CGFloat { Sprite.defenderSwipe.frameSize * scale }

    var body: some View {
        ZStack(alignment: .bottom) {
            SpriteShadow(scale: scale)
            Image(Sprite.defenderSwipe.rawValue)
                .interpolation(.none)
                .resizable()
                .frame(width: side, height: side)
                // Red jersey, and skin of his own — a defender is a person, not a marker.
                .paletteSwap(PixelPalette.defenderUniform
                             + PixelPalette.skin(tone: look.defenderTone(for: seat)))
        }
            .scaleEffect(x: mirrored ? -1 : 1)
            .offset(x: entry.width + (gone ? (mirrored ? side : -side) * Drift.away : 0),
                    y: entry.height + (gone ? side * Drift.away : 0))
            .opacity(faded ? 0 : 1)
            .task {
                withAnimation(.easeOut(duration: Drift.arrive)) { arrived = true }
                try? await Task.sleep(for: .seconds(Drift.hold))
                withAnimation(.easeOut(duration: Drift.seconds)) { gone = true }
                // Told rather than drawn: which layer he is on belongs to the court, not
                // to him — see `CourtView`, where the swipe is a layer of its own.
                onFront()
                withAnimation(.easeIn(duration: Drift.fade)
                    .delay(Drift.seconds - Drift.fade)) { faded = true }
            }
            .allowsHitTesting(false)
    }

    /// How far off his mark he still is. Zero once he has arrived.
    private var entry: CGSize {
        guard !arrived else { return .zero }
        // Mirrored, he came from the other side, so he comes *in* from the other side too.
        return CGSize(width: side * Drift.inX * (mirrored ? -1 : 1),
                      height: side * Drift.inY)
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
