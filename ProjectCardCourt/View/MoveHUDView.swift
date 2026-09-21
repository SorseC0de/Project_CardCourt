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
    /// How wide the drawing stands, against the ball it sits over.
    var scale: CGFloat = 0.62
    var x: CGFloat = 0
    var y: CGFloat = -6
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

    /// The drawing's own proportions.
    private enum Art {
        static let aspect: CGFloat = 1104.0 / 512.0
        static let bars = ["Move_Bar1", "Move_Bar2", "Move_Bar3"]
        /// What every bar is printed in, lightest first. The drawing's fills are snapped
        /// to these exactly — Affinity rounds, and the swap matches on the value.
        static let printed = [CardPalette.lightBlue, CardPalette.teal, CardPalette.cobalt]
    }

    /// **What a bar wears.** Unspent it keeps its own colours; spent, it heats up — the
    /// same ramp the plate used to run, one step per bar, so a possession running out
    /// reads off the colour before the count.
    private func worn(_ index: Int) -> [Color]? {
        guard index < moves else { return nil }
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
            piece("Move_Shoe")
        }
        .frame(width: width, height: width / Art.aspect)
        .animation(.easeOut(duration: 0.25), value: moves)
    }

    private func piece(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
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
