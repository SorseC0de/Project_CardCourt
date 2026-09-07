import SwiftUI

/// What the dust is drawn with when nobody is tuning it.
///
/// **The only copy.** These lived in `Theme.Figure` while the dials lived here, which is
/// two files each thinking it held the number.
enum SmokeStyle {
    /// The landing puff: where it sits in art pixels from the middle of the foot line —
    /// right and up positive — how big it is against the man, its own rate, and how faint
    /// it has gone by its last cell.
    static let landX: CGFloat = 0
    static let landY: CGFloat = 0
    static let landScale: CGFloat = 0.75
    static let landFPS: Double = 12
    static let landFade: Double = 0.10

    /// The bounce puff. Out where the ball comes down rather than under him, and smaller:
    /// a ball is not a body.
    static let ballX: CGFloat = 16
    static let ballY: CGFloat = 6
    static let ballScale: CGFloat = 0.5
    static let ballFPS: Double = 12
    static let ballFade: Double = 0.10

    /// **Which cells of the dribble the ball is on the floor for.** Read off the sheet
    /// rather than picked: its lowest row is 27 on these two and higher on every other,
    /// and both are drawn wider than the ball is, which is the squash.
    static let firstStrike = 2
    static let secondStrike = 10
}

/// Every number in a puff, on a dial.
///
/// Two puffs that were one: a landing and a bounce shared a rate and a fade because they
/// share a sheet, which is not a reason — one is a body arriving and the other is a ball
/// glancing off. They are separate here so they can disagree.
@Observable
@MainActor
final class SmokeTuning {
    static let shared = SmokeTuning()

    var landX: CGFloat = SmokeStyle.landX
    var landY: CGFloat = SmokeStyle.landY
    var landScale: CGFloat = SmokeStyle.landScale
    var landFPS: Double = SmokeStyle.landFPS
    var landFade: Double = SmokeStyle.landFade

    var ballX: CGFloat = SmokeStyle.ballX
    var ballY: CGFloat = SmokeStyle.ballY
    var ballScale: CGFloat = SmokeStyle.ballScale
    var ballFPS: Double = SmokeStyle.ballFPS
    var ballFade: Double = SmokeStyle.ballFade

    /// Held as doubles so a slider can carry them; read back as cells.
    var firstStrike: Double = Double(SmokeStyle.firstStrike)
    var secondStrike: Double = Double(SmokeStyle.secondStrike)

    var strikes: [Int] { [Int(firstStrike), Int(secondStrike)].sorted() }

    /// How long a puff is on screen, which is the sheet's length at whatever rate it is
    /// being played — not a number of its own.
    var landRun: Double { Double(Sprite.smoke.frames) / landFPS }
    var ballRun: Double { Double(Sprite.smoke.frames) / ballFPS }

    func reset() {
        landX = SmokeStyle.landX; landY = SmokeStyle.landY
        landScale = SmokeStyle.landScale
        landFPS = SmokeStyle.landFPS; landFade = SmokeStyle.landFade
        ballX = SmokeStyle.ballX; ballY = SmokeStyle.ballY
        ballScale = SmokeStyle.ballScale
        ballFPS = SmokeStyle.ballFPS; ballFade = SmokeStyle.ballFade
        firstStrike = Double(SmokeStyle.firstStrike)
        secondStrike = Double(SmokeStyle.secondStrike)
    }

    /// The dials as `SmokeStyle`, ready to paste over it.
    var source: String {
        func n(_ value: CGFloat) -> String { String(format: "%g", value) }
        func t(_ value: Double) -> String { String(format: "%g", value) }
        return """
        static let landX: CGFloat = \(n(landX))
        static let landY: CGFloat = \(n(landY))
        static let landScale: CGFloat = \(n(landScale))
        static let landFPS: Double = \(t(landFPS))
        static let landFade: Double = \(t(landFade))

        static let ballX: CGFloat = \(n(ballX))
        static let ballY: CGFloat = \(n(ballY))
        static let ballScale: CGFloat = \(n(ballScale))
        static let ballFPS: Double = \(t(ballFPS))
        static let ballFade: Double = \(t(ballFade))

        static let firstStrike = \(Int(firstStrike))
        static let secondStrike = \(Int(secondStrike))
        """
    }
}

#if DEBUG
/// The dust, on the floor, with the dials under it.
///
/// The bounce is drawn the whole time a man is dribbling, so it needs nothing to set it
/// off; the landing needs a landing, which is what the button is for.
struct SmokeBench: View {
    @State private var tune = SmokeTuning.shared
    @State private var controller = GameController()
    @State private var open = true

    /// The rates a sheet may play at — see `Theme.Figure`. Stepped rather than dragged,
    /// because everything between them judders.
    private let rates: [Double] = [4, 7.5, 10, 12, 15, 20, 30]

    var body: some View {
        GameView(controller: controller)
            .overlay(alignment: .bottom) { panel }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    controller.debugRebound()
                } label: {
                    Text("LAND HIM")
                        .font(.system(size: 11, weight: .black)).tracking(0.8)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(CardPalette.gold))
                }
                Button("print") {
                    UIPasteboard.general.string = tune.source
                    print(tune.source)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CardPalette.gold)
                Button("reset") { tune.reset() }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(CardPalette.red)
                Spacer()
                Text(String(format: "%.2fs / %.2fs", tune.landRun, tune.ballRun))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Button { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
                    Image(systemName: open ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)

            if open {
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        heading("landing")
                        dial("x (px)", $tune.landX, -16...16)
                        dial("y (px)", $tune.landY, -16...16)
                        dial("size", $tune.landScale, 0.1...2.5)
                        rate("fps", $tune.landFPS)
                        level("last cell", $tune.landFade)
                        heading("bounce")
                        dial("x (px)", $tune.ballX, -24...24)
                        dial("y (px)", $tune.ballY, -24...24)
                        dial("size", $tune.ballScale, 0.1...2.5)
                        rate("fps", $tune.ballFPS)
                        level("last cell", $tune.ballFade)
                        // Which cells the ball is actually on the floor for. Wrong and
                        // the puff fires in mid-air, which no other dial can fix.
                        cell("strike 1", $tune.firstStrike)
                        cell("strike 2", $tune.secondStrike)
                    }
                    .padding(.horizontal, 10).padding(.bottom, 8)
                }
                .frame(height: 210)
            }
        }
        .background(.black.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private func heading(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .black)).tracking(1)
            .foregroundStyle(CardPalette.gold)
            .padding(.top, 4)
    }

    private func dial(_ name: String, _ value: Binding<CGFloat>,
                      _ range: ClosedRange<CGFloat>) -> some View {
        row(name, String(format: "%.2f", value.wrappedValue)) {
            Slider(value: value, in: range)
        }
    }

    /// A share of one, for the fade — held as a `Double` because opacity is.
    private func level(_ name: String, _ value: Binding<Double>) -> some View {
        row(name, String(format: "%.2f", value.wrappedValue)) {
            Slider(value: value, in: 0...1)
        }
    }

    /// A whole cell of the dribble sheet, never a fraction of one.
    private func cell(_ name: String, _ value: Binding<Double>) -> some View {
        row(name, String(Int(value.wrappedValue))) {
            Slider(value: value, in: 0...Double(Sprite.dribble.frames - 1), step: 1)
        }
    }

    /// Stepped through the legal rates rather than dragged across them.
    private func rate(_ name: String, _ value: Binding<Double>) -> some View {
        row(name, "") {
            HStack(spacing: 3) {
                ForEach(rates, id: \.self) { fps in
                    Button(fps == 7.5 ? "7.5" : String(Int(fps))) { value.wrappedValue = fps }
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3)
                            .fill(value.wrappedValue == fps
                                  ? CardPalette.blue : .white.opacity(0.12)))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func row(_ name: String, _ reading: String,
                     @ViewBuilder _ control: () -> some View) -> some View {
        HStack(spacing: 6) {
            Text(name).font(.system(size: 10, weight: .semibold))
                .frame(width: 62, alignment: .leading)
            control()
            Text(reading).font(.system(size: 9, design: .monospaced))
                .frame(width: 44, alignment: .trailing)
        }
        .foregroundStyle(.white)
    }
}

#Preview("Smoke bench") { SmokeBench() }
#endif
