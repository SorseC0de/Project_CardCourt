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
                        ZStack {
                            Rectangle()
                                .fill(AngularGradient(colors: Spectrum.ring, center: .center))
                                .frame(width: side, height: side)
                                .rotationEffect(.degrees(turned ? 360 : 0))
                                .blur(radius: Spectrum.softness)
                                .opacity(Spectrum.strength)
                                .animation(.linear(duration: Spectrum.period)
                                    .repeatForever(autoreverses: false), value: turned)
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        }
                        .frame(width: box.size.width, height: box.size.height)
                    }
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
    /// reading as a pie chart.
    static let strength: Double = 0.85
    static let softness: CGFloat = 33
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
