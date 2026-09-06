import SwiftUI

/// The face, composed on a sheet.
///
/// **The only place eyes are drawn.** The portrait, the results card and the gallery all
/// come through here, so what is tuned in one is true in the others — and a sheet whose
/// eyes are wrong is wrong in exactly one place.
///
/// The sheet holds a single eye per cell. The far one is a flipped copy of it over the
/// same 8-wide box, mirrored about the box's own centre, which is where the head is
/// centred — so nothing here has to know where an eye sits inside its cell. Where each
/// one goes, and whether it is drawn at all, is `EyeTuning`'s answer.
struct FaceOnSheet: View {
    let sheet: Sprite
    /// Which face off the strip.
    let face: Int
    let tone: Int
    var scale: CGFloat = Theme.Figure.playerScale
    /// The cell to draw for, or nil to follow the sheet's own clock.
    var frame: Int?
    var fps: Double = Theme.Figure.playerFPS
    var playing = true

    @State private var eyes = EyeTuning.shared

    var body: some View {
        if let frame {
            composed(at: frame)
        } else {
            TimelineView(.animation(minimumInterval: 1 / fps, paused: !playing)) { tick in
                composed(at: playing
                         ? SpriteAnimation.cell(of: sheet, at: tick.date, fps: fps) : 0)
            }
        }
    }

    @ViewBuilder
    private func composed(at cell: Int) -> some View {
        ZStack {
            // **Nothing to paint out.** Every sheet is drawn faceless now, so a face is
            // only ever added — no skin-coloured rectangle over a printed one, no mask to
            // keep in step with a head that moves.
            ForEach(Eye.allCases, id: \.self) { which in
                let spot = eyes.spot(sheet, frame: cell, eye: which)
                if spot.shown {
                    // The far eye is drawn flipped, so a nudge to the right has to be
                    // spelled backwards for it — the dial says screen, not sheet.
                    eye(at: CGPoint(x: which == .far ? -spot.x : spot.x, y: spot.y))
                        .scaleEffect(x: which == .far ? -1 : 1)
                }
            }
        }
    }

    private func eye(at shift: CGPoint) -> some View {
        OnSheet(rect: CGRect(origin: sheet.headOrigin, size: CGSize(width: 8, height: 8)),
                shift: shift, scale: scale) {
            SpriteAnimation(sprite: .faces, scale: scale, isPlaying: false, restFrame: face)
                .paletteSwap(PixelPalette.skin(tone: tone))
        }
    }
}
