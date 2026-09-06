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

    /// Where the ball starts, in points off the rim it comes out of. **The rim does not
    /// move with it** — the hoop hangs where the court hangs it, and these two say where
    /// the board leaves it from.
    var spawnX: CGFloat = ReboundStyle.spawnX
    var spawnY: CGFloat = ReboundStyle.spawnY
    /// Where it meets his hands, in shares of his own drawn height from his feet.
    var handX: CGFloat = ReboundStyle.handX
    var handY: CGFloat = ReboundStyle.handY
    /// How big it is leaving the rim, against the size it arrives at.
    var fromHoop: CGFloat = ReboundStyle.fromHoop

    /// How long it takes to arrive.
    var flight: Double = ReboundStyle.flight
    /// How long after the catch the ball is taken off, in seconds. It is there and then
    /// it is not: the sprite draws one of its own once he is back on the floor, and this
    /// is the hand-over. Nothing fades — the old `fade` dial animated a view with
    /// `.transition(.identity)`, so it did nothing at all.
    var vanish: Double = ReboundStyle.vanish

    /// The leap. `rise` and `land` are the sheets' own rates and step through the ones
    /// that divide the refresh — see `Theme.Figure` — so the drawing cannot fall out of
    /// step with the timing. `hang`, `drop` and `lift` are free.
    var riseFPS: Double = ReboundStyle.riseFPS
    var landFPS: Double = ReboundStyle.landFPS
    var hang: Double = ReboundStyle.hang
    /// How long he takes to come down, **still holding the catch**. The landing sheet is
    /// what touching the floor looks like, so it plays after this rather than through it.
    var drop: Double = ReboundStyle.drop
    /// How much higher he goes than the sheet can draw, in art pixels.
    var lift: CGFloat = ReboundStyle.lift

    /// How long the rise takes, which is the sheet's, not a number of its own. The ball
    /// is thrown to arrive on the last cell of it.
    var rise: Double { Double(Sprite.rebound.frames - 1) / riseFPS }
    var landing: Double { Double(Sprite.land.frames) / landFPS }

    /// **When his hands close on it**, counted from the moment he leaves the floor.
    ///
    /// The top of the leap, and nothing else — `flight` says how long the ball's trip
    /// takes, not when it ends. Read the other way round, the ball began its descent at
    /// `flight + hang` while he began his at `rise + hang`, so with any flight shorter
    /// than the rise it left his hands early and reached the floor first. There is no
    /// pair of numbers that fixes that, which is why it could not be tuned out.
    ///
    /// A trip longer than the rise is the one case they cannot meet: the ball is still in
    /// the air when he starts down. The catch waits for it rather than the descent
    /// starting mid-flight.
    var catchAt: Double { max(rise, flight) }

    /// How long he actually holds it up there.
    ///
    /// The hang, plus however long the ball keeps him waiting when its trip is longer
    /// than his rise — he cannot start down before he has caught it. So whatever the
    /// dials are set to, his descent and the ball's begin on the same frame.
    var hold: Double { catchAt - rise + hang }

    /// The whole thing, which is what the game waits out — including a ball left on
    /// screen after he has landed.
    var whole: Double { catchAt + hang + max(drop + landing, vanish) }

    func reset() {
        spawnX = ReboundStyle.spawnX; spawnY = ReboundStyle.spawnY
        handX = ReboundStyle.handX;   handY = ReboundStyle.handY
        fromHoop = ReboundStyle.fromHoop
        flight = ReboundStyle.flight; vanish = ReboundStyle.vanish
        riseFPS = ReboundStyle.riseFPS; landFPS = ReboundStyle.landFPS
        hang = ReboundStyle.hang; drop = ReboundStyle.drop; lift = ReboundStyle.lift
    }
}

/// What the bench was left at.
enum ReboundStyle {
    /// Straight out of the rim.
    static let spawnX: CGFloat = 0
    static let spawnY: CGFloat = 0
    /// Both hands over his head. Under the old 28/32 the ball floated above them.
    static let handX: CGFloat = 0
    static let handY: CGFloat = 0.800
    /// Small leaving the rim, since it is coming from the horizon — but not nothing, or
    /// there is no ball to see for the first third of the trip.
    static let fromHoop: CGFloat = 0.300

    static let flight: Double = 0.25
    static let vanish: Double = 0.50

    static let riseFPS: Double = 12
    static let landFPS: Double = 15
    static let hang: Double = 0.35
    static let drop: Double = 0.25
    /// Art pixels. Two was the sheet's own head-room and no more, which is why he never
    /// looked like he left the floor.
    static let lift: CGFloat = 13
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
                Text(String(format: "%.2f + %.2f + %.2f + %.2f = %.2f",
                            tune.catchAt, tune.hang, tune.drop, tune.landing, tune.whole))
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
                        time("ball goes", $tune.vanish, 0...2)
                        heading("the leap")
                        rate("rise fps", $tune.riseFPS)
                        rate("land fps", $tune.landFPS)
                        time("hang", $tune.hang, 0...1.5)
                        time("drop", $tune.drop, 0.05...1.5)
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
