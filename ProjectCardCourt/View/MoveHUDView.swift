import SwiftUI

/// **Which Move meter is drawn**, while both are kept.
///
/// The arcs on the ball have been the meter since there was one; these are the drawn
/// bars. Nothing is thrown away by preferring one — the arcs are the three shot buttons
/// as well, and they go back to being the meter the moment this is off.
@Observable
@MainActor
final class MoveHUDTuning {
    static let shared = MoveHUDTuning()

    var drawn = true
    /// How wide the drawing stands, against the ball it sits over. **The ball's own
    /// width**: the bars are drawn as an arc to wrap it, so anything narrower sat inside
    /// the ball instead of round it.
    var scale: CGFloat = 1.5
    var x: CGFloat = 15
    var y: CGFloat = -38
    /// **How far apart the pieces stand**, in points, each pushed outward from the arc's
    /// own centre along the line it already sits on — so the bars open out round the ball
    /// rather than sliding sideways past each other.
    var separation: CGFloat = 0

    /// **The shoe walking the bars.** Its three places — see `MoveHUDView.place` for which
    /// Moves put it where — as offsets in points from its place on the drawing, and a
    /// turn in degrees about its own middle. It springs from one to the next.
    var shoeBegin = ShoeStop(x: -237, y: -26, rotation: -90)
    /// **Centred on the drawing**, whatever the phone: its `x` is a nudge from the middle
    /// rather than from where the shoe is drawn — see `MoveHUDView.shoeOffset`.
    var shoeMiddle = ShoeStop(x: -17, y: -96, rotation: 4)
    var shoeEnd = ShoeStop(x: -20, y: -35, rotation: 45)
    /// **For tuning**: shows the meter at this many Moves whatever the game says, so each
    /// stop can be set without playing to it. Nil is the game's own count.
    var previewMoves: Int?
}

/// One place the shoe can stand — see `MoveHUDTuning.shoeBegin`.
struct ShoeStop: Equatable {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rotation: Double = 0
}

/// **The Moves left in a possession**, drawn rather than struck.
///
/// Three bars climbing away from a shoe, from your own drawing. Each bar is its own
/// piece and each is printed in the same three tones — a light, a mid and a shadow — so
/// a bar that has been spent is the same bar wearing a different three. The outline is
/// left alone; black is black.
///
/// The pieces keep their places on the drawing's own canvas, so they are stacked at one
/// size and assemble themselves.
struct MoveHUDView: View {
    /// How many are gone, and how many there are.
    var moves: Int = 0
    var limit: Int = 3
    var width: CGFloat = 120
    /// See `MoveHUDTuning.separation`.
    var separation: CGFloat = 0

    @State private var tuning = MoveHUDTuning.shared

    /// The Moves the drawing shows — the game's, unless the bench is previewing a count.
    private var shown: Int { tuning.previewMoves ?? moves }

    /// The drawing's own proportions.
    private enum Art {
        static let aspect: CGFloat = 1104.0 / 512.0
        static let bars = ["Move_Bar1", "Move_Bar2", "Move_Bar3"]
        /// **Which way each piece leaves the middle**, measured off the drawing: the three
        /// bars arc left, over the top and right round a centre near the bottom of the
        /// canvas, and the shoe sits out to the right. A unit direction apiece, from that
        /// centre to the piece's own.
        static let outward: [String: CGVector] = [
            "Move_Bar1": CGVector(dx: -0.863, dy: -0.505),
            "Move_Bar2": CGVector(dx: 0, dy: -1),
            "Move_Bar3": CGVector(dx: 0.863, dy: -0.505),
            "Move_Shoe": CGVector(dx: 0.984, dy: -0.177),
        ]
        /// The shoe turns about its own middle — here on the canvas, measured off the
        /// drawing — rather than about the middle of the whole picture.
        static let shoeCentre = UnitPoint(x: 0.872, y: 0.756)
        /// What every bar is printed in, lightest first. The drawing's fills are snapped
        /// to these exactly — Affinity rounds, and the swap matches on the value.
        static let printed = [CardPalette.lightBlue, CardPalette.teal, CardPalette.cobalt]
    }

    /// **What a bar wears.** Unspent it keeps its own colours; spent, it heats up — the
    /// same ramp the plate used to run, one step per bar, so a possession running out
    /// reads off the colour before the count.
    private func worn(_ index: Int) -> [Color]? {
        guard index < shown else { return nil }
        switch index {
        case 0:  return [CardPalette.gold, CardPalette.tangerine, CardPalette.brown]
        case 1:  return [CardPalette.orange, CardPalette.red, CardPalette.darkRed]
        default: return [CardPalette.red, CardPalette.darkRed, CardPalette.maroon]
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(Art.bars.enumerated()), id: \.offset) { index, name in
                piece(name)
                    .paletteSwap(swaps(for: index))
                    // A bar past the limit is not a bar you have — Torn Achilles takes
                    // one away, and the drawing should say so rather than sit there lit.
                    .opacity(index < limit ? 1 : Mark.beyond)
            }
            shoe
        }
        .frame(width: width, height: width / Art.aspect)
        .animation(.easeOut(duration: 0.25), value: shown)
    }

    /// **Three places, not a slide.** It stands at the first until the bar is nearly spent,
    /// moves to the middle on the second-to-last Move and to the end on the last — so with
    /// three to a possession, none made and one made look the same, and it only starts
    /// walking once a possession is getting somewhere.
    private enum Place { case begin, middle, end }

    private var place: Place {
        let made = min(shown, limit)
        if made >= limit { return .end }
        if made == limit - 1 { return .middle }
        return .begin
    }

    /// Where the shoe stands, and how it is turned, at this count.
    private var stop: ShoeStop {
        switch place {
        case .begin:  return tuning.shoeBegin
        case .middle: return tuning.shoeMiddle
        case .end:    return tuning.shoeEnd
        }
    }

    /// **The offset it is drawn at.** The middle stop is measured from the centre of the
    /// drawing — that is what "centred" means, and it moves with the ball's width — and
    /// the other two from where the shoe is drawn.
    private var shoeOffset: CGSize {
        let centring = place == .middle ? (0.5 - Art.shoeCentre.x) * width : 0
        return CGSize(width: centring + stop.x, height: stop.y)
    }

    private var shoe: some View {
        piece("Move_Shoe")
            .rotationEffect(.degrees(stop.rotation), anchor: Art.shoeCentre)
            .offset(shoeOffset)
            // **A step, not a jump**: it slides to the next stop as the Move lands.
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: shown)
    }

    private func piece(_ name: String) -> some View {
        let away = Art.outward[name] ?? CGVector(dx: 0, dy: 0)
        return Image(name)
            .resizable()
            .scaledToFit()
            .offset(x: away.dx * separation, y: away.dy * separation)
    }

    private func swaps(for index: Int) -> [PaletteSwap] {
        guard let worn = worn(index) else { return [] }
        return zip(Art.printed, worn).map(PaletteSwap.init)
    }

    private enum Mark {
        /// A bar the possession does not have.
        static let beyond: Double = 0.25
    }
}

#if DEBUG
#Preview("Move HUD") {
    VStack(spacing: 18) {
        ForEach(0...3, id: \.self) { spent in
            MoveHUDView(moves: spent, width: 200)
        }
    }
    .padding(24)
    .background(Theme.sceneGround)
}
#endif
