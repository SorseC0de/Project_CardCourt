import SwiftUI

/// **"2X"**, the picture that stands in for "Double" in card text: white over light blue,
/// a thick black outline and a black drop to the south-east.
///
/// Set in the line as an image, because a `Text` run cannot carry an outline — see
/// `CardText`, which asks for it wherever a card writes `$[2X]`.
struct TwoXMark: View {
    let size: CGFloat
    /// **What is lettered in it.** "2X" on a card; the deck in the bar wears the number
    /// of cards it still owes you in the same hand, since it is the same kind of fact —
    /// a small figure that has to read over whatever it is standing on.
    var text: String = "2X"

    /// How far under the baseline the picture sits, as a share of the text size, so it
    /// centres on the letters beside it rather than standing on their feet.
    @MainActor static var baselineDrop: CGFloat { CardTextTuning.shared.markDrop }

    private enum Layout {
        static let face = "AvenirNextCondensed-Heavy"
        /// The outline and the drop, as shares of the text size.
        static let stroke: CGFloat = 0.09
        static let drop: CGFloat = 0.12
        /// Steps round the ring the outline is drawn on.
        static let steps = 16
    }

    var body: some View {
        let stroke = size * Layout.stroke
        let drop = size * Layout.drop
        ZStack {
            outline(width: stroke)
                .offset(x: drop, y: drop)
            outline(width: stroke)
            letters
                .foregroundStyle(LinearGradient(
                    stops: [.init(color: .white, location: 0.5),
                            .init(color: CardPalette.lightBlue, location: 0.5)],
                    startPoint: .top, endPoint: .bottom))
        }
        .padding(stroke + drop)
    }

    private var letters: Text {
        Text(text).font(.custom(Layout.face, size: size))
    }

    /// A thick outline: the letters in black, nudged round a ring.
    private func outline(width: CGFloat) -> some View {
        ZStack {
            ForEach(0..<Layout.steps, id: \.self) { step in
                let angle = Double(step) * 2 * .pi / Double(Layout.steps)
                letters
                    .foregroundStyle(.black)
                    .offset(x: cos(angle) * width, y: sin(angle) * width)
            }
        }
    }

    @MainActor private static var rendered: [CGFloat: UIImage] = [:]

    /// The mark as an image at this text size, drawn once per size.
    @MainActor static func image(size: CGFloat) -> UIImage {
        if let cached = rendered[size] { return cached }
        let renderer = ImageRenderer(content: TwoXMark(size: size))
        renderer.scale = 3
        let image = renderer.uiImage ?? UIImage()
        rendered[size] = image
        return image
    }
}
