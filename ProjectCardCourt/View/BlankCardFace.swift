import SwiftUI

/// The face a card wears while it is in the air.
///
/// A card in flight is not a particular card yet — the printed one only appears once it
/// has landed and `CardFlip` takes over — so it wears the card's own furniture with
/// nothing filled in: the black body, the gold inner stroke, and an empty name plate.
/// Drawn rather than exported so it tracks `CardPalette` and `CardLayout` by itself.
struct BlankCardFace: View {
    /// Raster width in pixels. Everything else is a share of it, as on a real card.
    let width: CGFloat

    private var height: CGFloat { width / CardMetrics.aspect }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * CardLayout.cornerFraction,
                             style: .continuous)
                .fill(CardPalette.black)
            RoundedRectangle(cornerRadius: width * CardLayout.strokeCornerFraction,
                             style: .continuous)
                .strokeBorder(CardPalette.gold,
                              lineWidth: width * CardLayout.strokeFraction)
                .padding(width * CardLayout.strokeInsetFraction)
            VStack(spacing: 0) {
                let plate = width * CardLayout.nameOverlayWidthFraction
                Image("NamePlaceholder")
                    .resizable()
                    .scaledToFit()
                    .frame(width: plate)
                    .shadow(color: CardPalette.gold, radius: 0, x: 0,
                            y: plate * CardLayout.namePlateShadowFraction)
                Spacer()
            }
            .padding(.top, height * CardLayout.nameOverlayYFraction)
        }
        .frame(width: width, height: height)
    }
}

extension BlankCardFace {
    /// Rasterised once, at the size the texture wants rather than whatever bitmap the
    /// catalog would hand over for the name plate.
    @MainActor static func printed() -> CGImage? {
        let renderer = ImageRenderer(content: BlankCardFace(width: 512))
        renderer.scale = 1
        return renderer.cgImage
    }
}

#Preview("Blank card face") {
    BlankCardFace(width: 300)
        .padding(40)
        .background(Theme.panel)
}
