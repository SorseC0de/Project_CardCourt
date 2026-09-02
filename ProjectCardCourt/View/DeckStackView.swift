import SwiftUI

/// The draw pile, sitting in the middle of the diamond.
struct DeckStackView: View {
    let remaining: Int
    var width: CGFloat = 44

    var body: some View {
        VStack(spacing: 4) {
            Image("Deck")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: width)
            Text("\(remaining)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.inkDim)
                .contentTransition(.numericText())
        }
    }
}
