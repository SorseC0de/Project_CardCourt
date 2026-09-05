import SwiftUI

/// A pile of cards drawn flat, with no renderer behind it.
///
/// **The escape hatch.** `DeckBody` is a RealityKit scene, and so is `CourtStage` — which
/// meant turning the stage off swapped one renderer for two and changed nothing about the
/// cost of bringing RealityKit up at all. This is the drawing that owes the frameworks
/// nothing: rounded rectangles stacked up the screen with the printed back over the top.
///
/// It only holds up from one angle, which is why the 3D pile exists. From the one angle
/// the court actually looks at it, it is a deck.
struct FlatPile: View {
    /// How many slabs. Each stands for several cards — see `DeckStackView.layers(for:)`.
    var layers: Int
    /// Thinner ones for the discard, the way the real pile does it.
    var slab: CGFloat = 0.055
    /// The stack's edge, alternating the way the slabs' materials do.
    var light: Color = CardPalette.gold
    var dark: Color = CardPalette.navy

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let card = width / CardMetrics.aspect
            let lift = width * slab
            let shown = max(1, layers)
            ZStack(alignment: .bottom) {
                ForEach(0..<shown, id: \.self) { index in
                    RoundedRectangle(cornerRadius: width * CardLayout.cornerFraction,
                                     style: .continuous)
                        .fill(index.isMultiple(of: 2) ? light : dark)
                        .frame(width: width, height: card)
                        .offset(y: -CGFloat(index) * lift)
                }
                Image("CardBackFull")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width)
                    .offset(y: -CGFloat(shown - 1) * lift)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
        }
    }
}
