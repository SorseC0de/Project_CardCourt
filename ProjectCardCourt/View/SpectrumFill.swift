import SwiftUI

/// **The Start button's face from Project Stars, as a fill.**
///
/// An angular spectrum turning for ever behind thin dark glass — the same two rectangles
/// `SpectrumPane` stacks over there, lifted whole. What is different here is what it is
/// *for*: over there it is a button's face, and here it is the ink inside a shape. So the
/// pane is drawn at the mask's size and the mask is whatever it is handed — lettering, a
/// hand, anything with an alpha channel.
///
/// **The square is drawn on the diagonal.** A rotating rectangle only the size of its box
/// swings its own corners into view; at the diagonal there is no corner near an edge, so
/// the sweep reads as light turning rather than as a card spinning.
struct SpectrumFill<Content: View>: View {
    /// Off, the spectrum is not drawn at all and the mask keeps `resting`. A thing that
    /// glows all the time is a thing nobody looks at.
    var isLive = true
    /// What it looks like when the light is off.
    var resting: Color = .white
    @ViewBuilder var content: Content

    @State private var drifted = false

    var body: some View {
        content
            .foregroundStyle(resting)
            .overlay {
                if isLive {
                    GeometryReader { box in
                        drift(in: box.size)
                    }
                    .mask { content }
                    .allowsHitTesting(false)
                }
            }
            .onAppear { drifted = true }
    }

    /// **Blobs of colour drifting across each other**, which is the trick itself rather
    /// than an impression of it.
    ///
    /// A blurred angular sweep was the shortcut, and it does not work small: one gradient
    /// between two points is a straight line of colour however it is turned, and blurring
    /// it far enough to hide the bands averages every hue into the same mud. What this
    /// wants is colour that *moves through* other colour, and a handful of overlapping
    /// circles do that on their own — where two meet the blur has already mixed them, and
    /// the mixture moves when they do.
    ///
    /// **Each is a gradient out to nothing rather than a disc with a blur over it.** Same
    /// look, and it costs a fill instead of an offscreen pass per frame — which matters
    /// here, where this is masked into lettering that is already being redrawn.
    private func drift(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<Spectrum.blobs, id: \.self) { index in
                // Scattered rather than stepped, so size does not march along the row in
                // order with position.
                let seed = wobble(index, 1)
                let lane = wobble(index, 2)
                let colour = Spectrum.ring[index % Spectrum.ring.count]
                let reach = size.width * Spectrum.drift
                let across = size.height
                    * (Spectrum.smallest + seed * (Spectrum.largest - Spectrum.smallest))

                Circle()
                    .fill(RadialGradient(colors: [colour, colour.opacity(0)],
                                         center: .center,
                                         startRadius: 0, endRadius: across / 2))
                    .frame(width: across, height: across)
                    // **All of them the same way.** Alternating the direction made two
                    // pass each other, which reads as things crossing rather than as one
                    // field moving. A conveyor only looks like one if nothing on it is
                    // going the other way.
                    .position(x: size.width / 2
                              + (drifted ? reach * (0.5 + lane) : -reach * (0.5 + seed)),
                              y: size.height * (0.15 + 0.7 * lane))
                    .scaleEffect(drifted ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: Spectrum.period + seed * Spectrum.spread)
                        .repeatForever(autoreverses: true), value: drifted)
            }
        }
        .frame(width: size.width, height: size.height)
        .opacity(Spectrum.strength)
    }

    /// A fixed number in `0..<1` for this blob and this question. The same every launch,
    /// so the field is a thing that can be looked at twice.
    private func wobble(_ index: Int, _ question: Int) -> CGFloat {
        let n = sin(Double(index) * 12.9898 + Double(question) * 78.233) * 43758.5453
        return CGFloat(n - n.rounded(.down))
    }
}

/// The wheel the spectrum turns, and how it turns.
///
/// **Twice round, not once** — Stars' own note, and it holds here for the same reason: the
/// same run laid twice halves how much of the circle any one hue owns, so no band is wide
/// enough to read as a side of something.
enum Spectrum {
    /// The wheel the blobs are coloured from. Ours rather than Stars', so a thing lit by
    /// this still belongs to this game — the palette's whole loud half, in wheel order.
    static let ring: [Color] = [
        CardPalette.magenta, CardPalette.red, CardPalette.orange, CardPalette.tangerine,
        CardPalette.gold, CardPalette.green, CardPalette.teal, CardPalette.lightBlue,
        CardPalette.blue, CardPalette.azure, CardPalette.purple,
    ]

    /// How many are drifting, and how far across they go.
    static let blobs = 9
    static let drift: CGFloat = 0.85
    /// Their size, against the height of what they are filling. Bigger than the box on
    /// purpose — a blob smaller than its field reads as a dot, not as weather.
    static let smallest: CGFloat = 0.9
    static let largest: CGFloat = 3.4
    /// One drift, and how much the slowest differs from the fastest. Different periods or
    /// they travel as one row however their timings differ.
    static let period: Double = 5.2
    static let spread: Double = 3.4
    /// How hard the light is.
    static let strength: Double = 0.75
}

#if DEBUG
#Preview("Spectrum fill") {
    ZStack {
        CardPalette.navy.ignoresSafeArea()
        VStack(spacing: 30) {
            SpectrumFill {
                Text("4").font(.custom("AvenirNextCondensed-Heavy", size: 160))
            }
            SpectrumFill {
                ThreeHandMark(width: 150, tint: .white, shadow: .clear)
            }
        }
    }
}
#endif
