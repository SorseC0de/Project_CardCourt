import SwiftUI

/// **A figure set in the game's pixel face, cut out with a black stroke.**
///
/// The same idea as `TwoXMark` — letters, an outline walked round a ring, a hard drop to
/// the south-east — with the pixel face instead of the condensed one, for numbers that
/// are called out rather than read: what a bucket was worth, and the like.
struct StrokedPixelText: View {
    let text: String
    let size: CGFloat
    var ink: Color = .white
    /// What the outline and the drop are drawn in.
    var edge: Color = CardPalette.black

    private enum Layout {
        /// The outline and the drop, as shares of the text's size.
        static let stroke: CGFloat = 0.1
        static let drop: CGFloat = 0.14
        /// Steps round the ring the outline is drawn on. A pixel face has square
        /// corners, so it needs fewer than a curved one to close.
        static let steps = 12
    }

    private var face: Font {
        PixelFont.register()
        return .custom(NumberStyle.a.font, size: size)
    }

    var body: some View {
        let stroke = size * Layout.stroke
        let drop = size * Layout.drop
        ZStack {
            outline(width: stroke).offset(x: drop, y: drop)
            outline(width: stroke)
            Text(text).font(face).foregroundStyle(ink)
        }
        .padding(stroke + drop)
    }

    /// A thick outline: the letters in the edge colour, nudged round a ring.
    private func outline(width: CGFloat) -> some View {
        ZStack {
            ForEach(0..<Layout.steps, id: \.self) { step in
                let angle = Double(step) * 2 * .pi / Double(Layout.steps)
                Text(text)
                    .font(face)
                    .foregroundStyle(edge)
                    .offset(x: cos(angle) * width, y: sin(angle) * width)
            }
        }
    }
}

#if DEBUG
#Preview("Stroked pixel") {
    VStack(spacing: 16) {
        StrokedPixelText(text: "+2", size: 40)
        StrokedPixelText(text: "3", size: 64, ink: CardPalette.gold)
    }
    .padding(24)
    .background(Theme.sceneGround)
}
#endif
