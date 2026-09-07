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
/// one goes, and whether it is drawn at all, is `MarkTuning`'s answer.
struct MarksOnSheet: View {
    let sheet: Sprite
    /// Which face off the strip.
    let face: Int
    let tone: Int
    var scale: CGFloat = Theme.Figure.playerScale
    /// The number on his back, when he is wearing one. Nil draws none — the court passes
    /// the man's own; the gallery passes whichever sample is being placed against.
    var number: String?
    /// What the number is set in, when nothing outside is dressing this. The trim, since
    /// that is the kit's second colour and a number in the shirt's own is a number nobody
    /// can read — see `ink`, which is where a dressed one gets its colour instead.
    var numberInk: Color = .white
    /// The cell to draw for, or nil to follow the sheet's own clock.
    var frame: Int?
    var fps: Double = Theme.Figure.playerFPS
    var playing = true
    /// Whether the caller has already put a skin swap round this. **A figure on the floor
    /// wears one bundle** — `PlayerLook.kit(for:)` carries the strip, the trim *and* the
    /// skin — so a second swap here would remap what the first one just wrote.
    var dressed = false
    /// Whether something outside has turned this figure around, so the number can be
    /// turned back. Where it *sits* still mirrors — it is printed on his back and goes
    /// where his back goes — but the digits themselves are read left to right.
    var mirrored = false

    @State private var eyes = MarkTuning.shared

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
            ForEach(Mark.eyes, id: \.self) { which in
                let spot = eyes.spot(sheet, frame: cell, eye: which)
                if spot.shown {
                    // The far eye is drawn flipped, so a nudge to the right has to be
                    // spelled backwards for it — the dial says screen, not sheet.
                    eye(at: CGPoint(x: which == .far ? -spot.x : spot.x, y: spot.y))
                        .scaleEffect(x: which == .far ? -1 : 1)
                }
            }
            if let number {
                let spot = eyes.spot(sheet, frame: cell, eye: .number)
                if spot.shown {
                    // **Clipped to the man wearing it.** A number is printed on a shirt,
                    // so the shirt is its shape — masking by the sheet's own cell cuts
                    // whatever would spill past an arm or off onto the floor, on every
                    // frame, without a rectangle having to be placed for each one.
                    digits(number, at: spot)
                        .mask {
                            SpriteAnimation(sprite: sheet, scale: scale,
                                            isPlaying: false, restFrame: cell)
                        }
                }
            }
        }
    }

    /// The number, centred on the cell and moved from there.
    ///
    /// **From the middle, not from a corner.** A number sits between his shoulders, and
    /// the middle of the cell is where that is on every sheet — so the dials are a nudge
    /// off centre rather than a measurement from an edge nobody can see.
    private func digits(_ number: String, at spot: Spot) -> some View {
        // **A single digit is not centred by being centred.** One glyph in a face built
        // for pairs sits half a pixel left of where the eye wants it, so it is nudged.
        let lone: CGFloat = number.count == 1 ? 0.5 : 0
        return Text(number)
            .font(.custom(eyes.numberFont, fixedSize: eyes.numberSize * scale))
            .foregroundStyle(ink)
            .fixedSize()
            // Turned back about its own middle, so it undoes the flip without moving.
            .scaleEffect(x: mirrored ? -1 : 1)
            .frame(width: sheet.frameSize * scale, height: sheet.frameSize * scale)
            .offset(x: (spot.x + lone) * scale, y: spot.y * scale)
    }

    /// What the number is actually printed in.
    ///
    /// **The belt's own light tone, and by construction rather than by agreement.** A
    /// dressed figure has `PixelPalette.trim` running over the whole of it, which turns
    /// `slate` into the belt's light colour — so a number drawn in `slate` comes out of
    /// that swap the same colour as the belt, whatever belt he picked. Handed the
    /// resolved colour instead, it went through the swap a second time and landed
    /// wherever *that* colour happened to map.
    ///
    /// Undressed — the gallery, My Hooper — no swap runs, so the caller's resolved
    /// colour is the right answer there.
    private var ink: Color { dressed ? PixelPalette.slate : numberInk }

    private func eye(at shift: CGPoint) -> some View {
        OnSheet(rect: CGRect(origin: sheet.headOrigin, size: CGSize(width: 8, height: 8)),
                shift: shift, scale: scale) {
            SpriteAnimation(sprite: .faces, scale: scale, isPlaying: false, restFrame: face)
                .paletteSwap(dressed ? [] : PixelPalette.skin(tone: tone))
        }
    }
}

