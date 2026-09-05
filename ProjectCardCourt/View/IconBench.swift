import SwiftUI

/// The dials behind a card's icon and its numbered badge.
///
/// Held rather than passed so a slider in `IconBench` moves every card on screen at once
/// — the three sample cards are three different badge layouts, and a number that suits
/// one has to be checked against the other two.
@Observable
@MainActor
final class IconTuning {
    static let shared = IconTuning()

    /// The card's main icon, against `CardLayout.iconSizeFraction`.
    var iconScale: CGFloat = IconStyle.iconScale
    /// The keyword badge, against whichever of `badgeFraction` / `badgeAloneFraction`
    /// its layout calls for.
    var badgeScale: CGFloat = IconStyle.badgeScale
    /// The figure printed on the badge, against `CardLayout.badgeValueShare`.
    var valueScale: CGFloat = IconStyle.valueScale
    /// Where that figure sits on the badge's face, in shares of the badge's own side.
    var valueX: CGFloat = IconStyle.valueX
    var valueY: CGFloat = IconStyle.valueY

    func reset() {
        iconScale = IconStyle.iconScale
        badgeScale = IconStyle.badgeScale
        valueScale = IconStyle.valueScale
        valueX = IconStyle.valueX
        valueY = IconStyle.valueY
    }
}

/// What the bench was left at. Everything starts neutral: the sizes already in
/// `CardLayout` are the drawing, and these multiply them.
enum IconStyle {
    static let iconScale: CGFloat = 1.000
    static let badgeScale: CGFloat = 1.000
    static let valueScale: CGFloat = 1.000
    static let valueX: CGFloat = 0.000
    static let valueY: CGFloat = 0.000
}

// MARK: - Bench

/// Three cards side by side, one per badge layout: a badge standing alone in the middle
/// of the card, a badge at the foot with words above it, and a badge whose figure is a
/// question mark. Whatever a slider does has to read on all three.
struct IconBench: View {
    @State private var tuning = IconTuning.shared
    @State private var width: CGFloat = 150

    private var cards: [CardDescriptor] {
        [CardLibrary.allStarSelection, CardLibrary.doubleTeam, CardLibrary.designedPlay]
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(cards, id: \.id) { card in
                    CardFrontView(descriptor: card, displayWidth: width)
                }
            }
            .frame(maxHeight: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    dial("Icon scale", $tuning.iconScale, 0.2...2.5)
                    dial("Badge scale", $tuning.badgeScale, 0.2...2.5)
                    dial("Number scale", $tuning.valueScale, 0.2...2.5)
                    dial("Number x", $tuning.valueX, -0.5...0.5)
                    dial("Number y", $tuning.valueY, -0.5...0.5)
                    dial("Card width", $width, 80...240)

                    HStack {
                        Button("Reset") { tuning.reset() }
                        Spacer()
                        Text(snapshot)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 240)
        }
        .padding(.vertical, 16)
        .background(Theme.panel)
    }

    /// The five numbers as they would be written into `IconStyle`, ready to copy back.
    private var snapshot: String {
        String(format: "icon %.3f  badge %.3f  num %.3f  x %.3f  y %.3f",
               tuning.iconScale, tuning.badgeScale, tuning.valueScale,
               tuning.valueX, tuning.valueY)
    }

    private func dial(_ name: String, _ value: Binding<CGFloat>,
                      _ range: ClosedRange<CGFloat>) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 92, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.3f", value.wrappedValue))
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 52, alignment: .trailing)
        }
        .foregroundStyle(.white)
    }
}

#Preview("Icon bench") {
    IconBench()
        .preferredColorScheme(.dark)
}
