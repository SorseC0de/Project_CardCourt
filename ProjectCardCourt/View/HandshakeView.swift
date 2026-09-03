import SwiftUI

/// The connection, drawn as what it is.
///
/// Two slots, both there from the start: your half and theirs. An empty slot is flat
/// grey; a filled one is white with the blue drop everything else in the game wears. Yours
/// fills the moment you start looking, theirs when they arrive.
///
/// Nothing moves. The whole point is to read the state at a glance — one filled and one
/// empty means it is still waiting, and two filled means it is done. Motion would only
/// say "busy", which is the thing a spinner already says badly.
///
/// **The art.** `HandshakeL` and `HandshakeR` on one viewBox, laid over each other at the
/// same size, so the drawing decides where the hands meet rather than this file.
struct HandshakeView: View {
    /// False while waiting, true once the other half has arrived.
    var clasped: Bool
    var side: CGFloat = 220

    private enum Art {
        static let empty = CardPalette.gray
        static let filled = Color.white
        static let drop = CardPalette.blue
        /// A share of the whole, so the drop keeps its weight at any size.
        static let dropShare: CGFloat = 0.022
    }

    var body: some View {
        ZStack {
            half(mine: true)
            half(mine: false)
        }
        .frame(width: side, height: side)
    }

    private func half(mine: Bool) -> some View {
        let filled = mine || clasped
        return Image(mine ? "HandshakeL" : "HandshakeR")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .foregroundStyle(filled ? Art.filled : Art.empty)
            // Flattened before the shadow, or SwiftUI casts one per path in the drawing.
            .drawingGroup()
            .shadow(color: filled ? Art.drop : .clear, radius: 0,
                    x: side * Art.dropShare, y: side * Art.dropShare)
    }
}

#if DEBUG
#Preview("Handshake") {
    struct Bench: View {
        @State private var clasped = false
        var body: some View {
            VStack(spacing: 40) {
                HandshakeView(clasped: clasped)
                ChunkyButton(title: clasped ? "Reset" : "Match found") { clasped.toggle() }
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Chrome.ground)
        }
    }
    return Bench()
}
#endif
