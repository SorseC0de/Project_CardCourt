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

    /// **The shoe walking the bars: one place for each Move made.** At the start with none,
    /// then at the end of each bar in turn — four places for four counts, so no two share
    /// one. Offsets in points and a turn in degrees about the shoe's own middle; it springs
    /// from one to the next. Tuned in `MoveHUDBench`, which draws nothing else.
    var shoeStops: [ShoeStop] = [
        ShoeStop(x: -237, y: -26, rotation: -90),
        ShoeStop(x: -237, y: -26, rotation: -90),
        ShoeStop(x: -17, y: -96, rotation: 4, fromCentre: true),
        ShoeStop(x: -20, y: -35, rotation: 45),
    ]
}

/// One place the shoe can stand — see `MoveHUDTuning.shoeBegin`.
struct ShoeStop: Equatable {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rotation: Double = 0
    /// **Measured from the centre of the drawing** rather than from where the shoe is
    /// drawn. The centre moves with the ball's width, so a stop set this way stays centred
    /// on every phone.
    var fromCentre = false
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

    /// The Moves the drawing shows. The shoe's bench sets this directly — see
    /// `MoveHUDBench` — so there is no override to leave switched on in a real game.
    private var shown: Int { moves }

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

    /// **Where the shoe stands at this count.** One stop per Move made; a full bar is
    /// always the last stop, so a shorter bar — Torn Achilles — still finishes at the end
    /// rather than stopping partway along it.
    private var stop: ShoeStop {
        let stops = tuning.shoeStops
        guard !stops.isEmpty else { return ShoeStop() }
        let made = min(shown, limit)
        if made >= limit { return stops[stops.count - 1] }
        return stops[min(made, stops.count - 1)]
    }

    /// **The offset it is drawn at**, from where the shoe is drawn — or from the centre of
    /// the drawing, for a stop set that way.
    private var shoeOffset: CGSize {
        let centring = stop.fromCentre ? (0.5 - Art.shoeCentre.x) * width : 0
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
