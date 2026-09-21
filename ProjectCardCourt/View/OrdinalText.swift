import SwiftUI

/// **A number with its ordinal raised.** The letters sit high and small against the
/// figure, the way they are set in print — "1st" as one word rather than a number and a
/// suffix side by side.
struct OrdinalText: View {
    let number: Int
    let size: CGFloat
    var font: String = Chrome.display

    private enum Mark {
        /// The letters against the figure, and how far up they ride.
        static let scale: CGFloat = 0.5
        static let lift: CGFloat = 0.36
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(number)")
                .font(.custom(font, size: size))
            Text(Ordinal.suffix(number))
                .font(.custom(font, size: size * Mark.scale))
                .baselineOffset(size * Mark.lift)
        }
    }
}

#if DEBUG
#Preview("Ordinals") {
    VStack(spacing: 10) {
        ForEach([1, 2, 3, 4, 11, 12, 13, 21], id: \.self) { n in
            HStack {
                OrdinalText(number: n, size: 34)
                Text(Ordinal.plain(n)).font(.system(size: 16, design: .monospaced))
            }
        }
    }
    .foregroundStyle(.white)
    .padding(24)
    .background(Theme.sceneGround)
}
#endif
