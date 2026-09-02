import SwiftUI

/// The three-point hand as a single mark.
///
/// Its own asset rather than the four celebration parts stacked: each part carries its own
/// viewBox, so `scaledToFit` sizes them independently and they never line back up.
struct ThreeHandMark: View {
    var width: CGFloat
    var tint: Color = CardPalette.gold
    var shadow: Color = CardPalette.navy
    var shadowOffset: CGFloat = 0

    var body: some View {
        Image("ThreeHandWhole")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .foregroundStyle(tint)
            .shadow(color: shadow, radius: 0, x: shadowOffset, y: shadowOffset)
    }
}
