import SwiftUI

/// **The officials deck's own back.**
///
/// The crew is a separate pile now — shuffled once at the start of the game and dealt
/// from at the top of every round — so it wants a back nobody could mistake for the main
/// deck. The stripes that run across the top of a Whistle's face carry straight on down
/// the length of it, and the whistle itself sits in the middle in gold.
struct RefereeCardBack: View {
    var width: CGFloat
    /// How many stripes across. The same count the face's band uses, so the two line up
    /// when a card is turned over.
    var stripes = 11

    private var height: CGFloat { width / CardMetrics.aspect }
    private var corner: CGFloat { width * CardLayout.cornerFraction }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(0..<stripes, id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? CardPalette.black : CardPalette.cloud)
                        .frame(width: width / CGFloat(stripes))
                }
            }
            Image("GoldWhistle")
                .resizable()
                .scaledToFit()
                .frame(width: width * Back.whistle)
                .shadow(color: CardPalette.navy, radius: 0,
                        x: width * Back.drop, y: width * Back.drop)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        // The same inset line every card front wears, so a pile of these reads as cards
        // rather than as a striped block.
        .overlay {
            RoundedRectangle(cornerRadius: width * CardLayout.strokeCornerFraction,
                             style: .continuous)
                .strokeBorder(CardPalette.cloud,
                              lineWidth: width * CardLayout.strokeFraction)
                .padding(width * CardLayout.strokeInsetFraction)
        }
    }

    private enum Back {
        /// The whistle's share of the card's width.
        static let whistle: CGFloat = 0.52
        /// Its drop, as a share of the same.
        static let drop: CGFloat = 0.012
    }
}
