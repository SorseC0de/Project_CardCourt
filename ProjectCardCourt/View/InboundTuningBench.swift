#if DEBUG
import SwiftUI

/// A bench for the inbound, with the scene above the dials rather than on top of them.
///
/// These lived on the in-game bench, which sits over the court and ran off the bottom of
/// the screen once there were a dozen of them. A tuning surface that covers the thing
/// being tuned is not one.
struct InboundTuningBench: View {
    @State private var tune = InboundTextTuning.shared
    @State private var state: GameState = {
        var (state, _) = Rules.newGame(seed: 7)
        state.phase = .inbound(inbounder: .south)
        state.ball = nil
        return state
    }()

    /// Wide enough for Tanaka, who wanted more than the bench's range allowed.
    private let reach: ClosedRange<Double> = -400...400

    var body: some View {
        VStack(spacing: 0) {
            CourtView(state: state,
                      gate: .awaitingInbound(.south),
                      revealedBids: nil,
                      onSelect: { _ in })
                .frame(maxHeight: .infinity)

            dials
                .padding(10)
                .background(Theme.panel)
        }
        .background(Theme.panel)
    }

    /// Three columns, so a dozen dials fit on one screen under the court.
    private var dials: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Button("reset") { reset() }
                    .font(.system(size: 11, weight: .heavy))
                    .buttonStyle(.borderedProminent)
                    .tint(PixelPalette.gold)
                Text("inbound tuning")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkDim)
                Spacer()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                     count: 3), spacing: 2) {
                slider("line 1 x", text(\.topX), reach)
                slider("line 1 y", text(\.topY), reach)
                slider("ball x", text(\.ballX), 0...32)
                slider("line 2 x", text(\.bottomX), reach)
                slider("line 2 y", text(\.bottomY), reach)
                slider("ball y", text(\.ballY), 0...32)
                slider("thrower x", text(\.throwerX), reach)
            }
        }
    }

    private func reset() {
        tune.topX = 0; tune.topY = 270
        tune.bottomX = 0; tune.bottomY = 320
        tune.ballX = 14; tune.ballY = 14
        tune.throwerX = -120
    }

    private func text(_ path: ReferenceWritableKeyPath<InboundTextTuning, CGFloat>) -> Binding<Double> {
        Binding(get: { Double(tune[keyPath: path]) },
                set: { tune[keyPath: path] = CGFloat($0) })
    }

    private func slider(_ label: String, _ value: Binding<Double>,
                        _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: -2) {
            Text("\(label)  \(Int(value.wrappedValue.rounded()))")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
            Slider(value: value, in: range).tint(PixelPalette.gold)
        }
    }
}

#Preview("Inbound tuning") {
    InboundTuningBench()
}
#endif
