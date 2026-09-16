import SwiftUI

/// Where COMBO and BONUS sit on a card, and how big they are.
///
/// Held rather than passed, so a slider moves every card on screen at once — the row is one
/// button on some cards and two on others, and a spot that suits one has to be checked
/// against the other.
@Observable
@MainActor
final class ExtrasTuning {
    static let shared = ExtrasTuning()

    /// Against the lettering's own share of the card's width.
    var scale: CGFloat = ExtrasStyle.scale
    /// Off the spot above the text area, in shares of the card's width and height.
    var x: CGFloat = ExtrasStyle.x
    var y: CGFloat = ExtrasStyle.y

    func reset() {
        scale = ExtrasStyle.scale
        x = ExtrasStyle.x
        y = ExtrasStyle.y
    }
}

/// What the bench was left at.
enum ExtrasStyle {
    static let scale: CGFloat = 0.750
    static let x: CGFloat = -0.333
    /// The row's **highest** point: the buttons hang down from here, so this is where the
    /// first of them starts rather than where the pair is centred.
    static let y: CGFloat = -0.333
}

// MARK: - Bench

/// Three cards side by side: one with a combo alone, one with both buttons, and one with a
/// bonus alone — raised, so the words are on. The fourth is a hand-sized card, where only
/// the shapes show.
struct ExtrasBench: View {
    @State private var tuning = ExtrasTuning.shared
    @State private var width: CGFloat = 150

    private var cards: [CardDescriptor] {
        [CardLibrary.drive, CardLibrary.handOff, CardLibrary.lob]
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(cards, id: \.id) { card in
                    CardFrontView(descriptor: card, displayWidth: width, expanded: true,
                                  onCombo: {}, onBonus: { _ in })
                }
                CardFrontView(descriptor: CardLibrary.handOff, displayWidth: 76)
            }
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                dial("Scale", $tuning.scale, 0.3...2)
                dial("X", $tuning.x, -0.4...0.4)
                dial("Y", $tuning.y, -0.4...0.4)
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
        .padding(.vertical, 16)
        .background(Theme.panel)
    }

    /// The three numbers as they would be written into `ExtrasStyle`, ready to copy back.
    private var snapshot: String {
        String(format: "scale %.3f  x %.3f  y %.3f", tuning.scale, tuning.x, tuning.y)
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

#Preview("Extras bench") {
    ExtrasBench()
        .preferredColorScheme(.dark)
}
