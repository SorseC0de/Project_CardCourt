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

    @State private var turned = false

    var body: some View {
        content
            .foregroundStyle(resting)
            .overlay {
                if isLive {
                    GeometryReader { box in
                        let side = hypot(box.size.width, box.size.height)
                        Rectangle()
                            .fill(AngularGradient(colors: Spectrum.ring, center: .center))
                            .frame(width: side, height: side)
                            .rotationEffect(.degrees(turned ? 360 : 0))
                            // **Softened against its own size, not a fixed radius.**
                            // Stars blurs by 33 points across a button the width of a
                            // panel. The same 33 across a letter is wider than the letter
                            // — every hue averages into the same mud, which is why the
                            // number came out grey.
                            .blur(radius: side * Spectrum.softness)
                            .opacity(Spectrum.strength)
                            .animation(.linear(duration: Spectrum.period)
                                .repeatForever(autoreverses: false), value: turned)
                            .frame(width: box.size.width, height: box.size.height)
                    }
                    // **No glass.** Stars puts `.ultraThinMaterial` over the sweep, and a
                    // material samples what is *behind* it — inside an overlay that is
                    // then masked there is nothing behind it to sample, so it renders as
                    // flat grey and covers the spectrum entirely. On a button it is glass;
                    // here it was a lid.
                    .mask { content }
                    .allowsHitTesting(false)
                }
            }
            .onAppear { turned = true }
    }
}

/// The wheel the spectrum turns, and how it turns.
///
/// **Twice round, not once** — Stars' own note, and it holds here for the same reason: the
/// same run laid twice halves how much of the circle any one hue owns, so no band is wide
/// enough to read as a side of something.
enum Spectrum {
    static let ring: [Color] = hues + hues + [hues[0]]

    /// Ours rather than Stars', so a thing lit by this still belongs to this game. The
    /// palette's whole loud half, in wheel order.
    private static let hues: [Color] = [
        CardPalette.magenta, CardPalette.red, CardPalette.orange, CardPalette.tangerine,
        CardPalette.gold, CardPalette.green, CardPalette.teal, CardPalette.lightBlue,
        CardPalette.blue, CardPalette.azure, CardPalette.purple,
    ]

    /// One turn of the sweep.
    static let period: Double = 4.5
    /// How hard the light is, and how soft its bands are. The blur is what stops the ring
    /// reading as a pie chart — **as a share of what it is being drawn across**, so a
    /// figure and a whole button are softened by the same amount of themselves.
    static let strength: Double = 1
    static let softness: CGFloat = 0.09
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
