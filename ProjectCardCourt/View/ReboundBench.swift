import SwiftUI

/// Every number in a rebound, on a dial.
///
/// The leap is six things happening against each other — a ball leaving the rim, a man
/// leaving the floor, the two meeting, and the pair of them coming down — and none of
/// them reads right on its own. They are all here so one can be moved against the others
/// and watched, rather than guessed at a build at a time.
@Observable
@MainActor
final class ReboundTuning {
    static let shared = ReboundTuning()

    /// Where the ball comes from, in points off the rim on the horizon.
    var spawnX: CGFloat = ReboundStyle.spawnX
    var spawnY: CGFloat = ReboundStyle.spawnY
    /// Where it meets his hands, in shares of his own drawn height from his feet.
    var handX: CGFloat = ReboundStyle.handX
    var handY: CGFloat = ReboundStyle.handY
    /// How big it is leaving the rim, against the size it arrives at.
    var fromHoop: CGFloat = ReboundStyle.fromHoop

    /// How long it takes to arrive, and how long it takes to go once he has it.
    var flight: Double = ReboundStyle.flight
    var fade: Double = ReboundStyle.fade

    /// The leap. `rise` and `land` are the sheets' own rates and step through the ones
    /// that divide the refresh — see `Theme.Figure` — so the drawing cannot fall out of
    /// step with the timing. `hang` and `lift` are free.
    var riseFPS: Double = ReboundStyle.riseFPS
    var landFPS: Double = ReboundStyle.landFPS
    var hang: Double = ReboundStyle.hang
    /// How much higher he goes than the sheet can draw, in art pixels.
    var lift: CGFloat = ReboundStyle.lift

    /// How long the rise takes, which is the sheet's, not a number of its own. The ball
    /// is thrown to arrive on the last cell of it.
    var rise: Double { Double(Sprite.rebound.frames - 1) / riseFPS }
    var landing: Double { Double(Sprite.land.frames) / landFPS }
    /// The whole thing, which is what the game waits out.
    var whole: Double { rise + hang + landing }

    func reset() {
        spawnX = ReboundStyle.spawnX; spawnY = ReboundStyle.spawnY
        handX = ReboundStyle.handX;   handY = ReboundStyle.handY
        fromHoop = ReboundStyle.fromHoop
        flight = ReboundStyle.flight; fade = ReboundStyle.fade
        riseFPS = ReboundStyle.riseFPS; landFPS = ReboundStyle.landFPS
        hang = ReboundStyle.hang; lift = ReboundStyle.lift
    }
}

/// What the bench was left at.
enum ReboundStyle {
    /// Off the rim: right of centre and a little below it, so the ball is not born
    /// inside the ring.
    static let spawnX: CGFloat = 0
    static let spawnY: CGFloat = 0
    /// Both hands over his head. Under the old 28/32 the ball floated above them.
    static let handX: CGFloat = 0
    static let handY: CGFloat = 0.780
    /// It leaves at nothing, coming from the horizon.
    static let fromHoop: CGFloat = 0.010

    static let flight: Double = 0.60
    static let fade: Double = 0.25

    /// Slower than it was: at twelve the whole leap was over before it read as one.
    static let riseFPS: Double = 10
    static let landFPS: Double = 10
    static let hang: Double = 0.30
    /// Art pixels. Two was the sheet's own head-room and no more, which is why he never
    /// looked like he left the floor.
    static let lift: CGFloat = 9
}

// MARK: - Bench

#if DEBUG
/// The leap, on a court that is the real one.
///
/// **`GameView` at full height, not a court in a box.** The floor's geometry is worked
/// out from the space it is given — the horizon, the rows, how big a man at the far end
/// is — so a court sharing the screen with a stack of sliders is a different court, and
/// numbers found against it are numbers for a court nobody plays on. The dials sit over
/// the top instead, and fold away.
///
/// Nothing is dealt: `begin` is never called, so there is no opening deal to sit through
/// and no deck working away behind the thing being looked at.
struct ReboundBench: View {
    @State private var tune = ReboundTuning.shared
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
                    Text("GO UP FOR IT")
                        .font(.system(size: 11, weight: .black)).tracking(0.8)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(CardPalette.gold))
                }
                Button("reset") { tune.reset() }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(CardPalette.red)
                Spacer()
                Text(String(format: "%.2f + %.2f + %.2f", tune.rise, tune.hang, tune.landing))
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
                        heading("the ball")
                        dial("spawn x", $tune.spawnX, -160...160)
                        dial("spawn y", $tune.spawnY, -160...160)
                        dial("hand x", $tune.handX, -1...1)
                        dial("hand y", $tune.handY, 0...1.6)
                        dial("leaves at", $tune.fromHoop, 0.01...1)
                        time("flight", $tune.flight, 0.1...2)
                        time("fade", $tune.fade, 0.05...1.5)
                        heading("the leap")
                        rate("rise fps", $tune.riseFPS)
                        rate("land fps", $tune.landFPS)
                        time("hang", $tune.hang, 0...1.5)
                        dial("lift (px)", $tune.lift, 0...40)
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
        row(name, String(format: "%.3f", value.wrappedValue)) {
            Slider(value: value, in: range)
        }
    }

    private func time(_ name: String, _ value: Binding<Double>,
                      _ range: ClosedRange<Double>) -> some View {
        row(name, String(format: "%.2fs", value.wrappedValue)) {
            Slider(value: value, in: range)
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

#Preview("Rebound bench") { ReboundBench() }
#endif
