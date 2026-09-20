import SwiftUI

/// **The arrow that hangs over a man.**
///
/// One drawing, three tones and an outline, recoloured per meaning rather than redrawn:
/// the art is slate over stone over steel — light, mid, shadow — and each reading swaps
/// that ramp for one of Zughy32's own. The outline is left alone; black is black.
struct SelectionArrow: View {
    /// What the arrow is saying.
    enum Reading {
        /// A man you may pick. Zughy 7/8/9.
        case valid
        /// A man you may not. 27/28/29.
        case invalid
        /// Somewhere a pass in hand could go. 17/18/19.
        case pass
        /// Whoever has the ball — the drawing's own greys, which is no reading at all.
        case plain
        /// The deck, waiting to be taken from. 26/27 and the dark orange under them.
        case gold
    }

    let reading: Reading
    var width: CGFloat = Mark.width

    enum Mark {
        /// How wide it is drawn. The sheet is 144 across; this is the size it lands at
        /// over a player's head.
        static let width: CGFloat = 13
        /// The drawing's own proportions, so it is never squashed.
        static let aspect: CGFloat = 144.0 / 104.0
    }

    /// The art's own ramp, lightest first.
    private static let printed = [PixelPalette.slate, PixelPalette.stone, PixelPalette.steel]

    /// What each reading is wearing, lightest first.
    private var worn: [Color]? {
        switch reading {
        case .valid:   return [PixelPalette.lime, PixelPalette.green, PixelPalette.pine]
        case .invalid: return [PixelPalette.orange, PixelPalette.vermilion, PixelPalette.darkRed]
        case .pass:    return [PixelPalette.aqua, PixelPalette.azure, PixelPalette.blue]
        case .plain:   return nil
        case .gold:    return [PixelPalette.gold, PixelPalette.orange, PixelPalette.darkOrange]
        }
    }

    var body: some View {
        Image("Selection_Arrow")
            .interpolation(.none)
            .resizable()
            .frame(width: width, height: width / Mark.aspect)
            .paletteSwap(swaps)
    }

    private var swaps: [PaletteSwap] {
        guard let worn else { return [] }
        return zip(Self.printed, worn).map(PaletteSwap.init)
    }
}

#if DEBUG
#Preview("Selection arrow") {
    HStack(spacing: 24) {
        SelectionArrow(reading: .valid, width: 52)
        SelectionArrow(reading: .invalid, width: 52)
        SelectionArrow(reading: .pass, width: 52)
        SelectionArrow(reading: .plain, width: 52)
    }
    .padding(30)
    .background(Theme.sceneGround)
}
#endif
