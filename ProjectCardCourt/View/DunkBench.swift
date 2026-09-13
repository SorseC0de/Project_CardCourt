import SwiftUI

/// What a finish at the rim is drawn with when nobody is tuning it.
///
/// The shape of each dunk — which cells climb, how often, and which one he has to arrive
/// on — is `Dunk`'s, because that is a fact about the drawings. These are the trip: how
/// far he goes, how small he gets, and how long he takes over it.
enum DunkStyle {
    /// One finish's trip: how far he goes, how small he gets, and how long he takes.
    ///
    /// **Per dunk, not shared.** They climb differently — a one-hand holds a cell, a
    /// reverse cycles three, a whirlwind is already spinning — so a rise tuned on one
    /// arrives wrong on the others.
    struct Trip: Hashable {
        /// How far he travels toward the rim, in points, at the **top** of the climb. The
        /// rim is upcourt and upcourt is away, so he shrinks to `arrivesAt` as he goes.
        var rise: CGFloat
        var arrivesAt: CGFloat
        /// How long the climb takes. The drawing fills it rather than deciding it.
        var climb: Double
        /// The wind-up's rate, and the finish's once he is up there.
        var gatherFPS: Double
        var finishFPS: Double
        /// **He peaks above where he lands.** How many art pixels he comes back down at
        /// the end, one per frame — hanging on the rim and dropping off it, rather than
        /// stopping dead at the top of the jump.
        ///
        /// Counted in pixels rather than in cells, and **not clamped to the sheet**: a
        /// reverse spends only two cells at the rim, so a cell-per-pixel sink could never
        /// go past two on it. Past the last cell he keeps descending on the held frame.
        var sink: Int
        /// **The climb does not have to be one rate.** How many of its opening cells
        /// play at `leadFPS`, with the rest of them dividing whatever is left of `climb`.
        /// A whirlwind's spin is unreadable spread evenly over a short climb; held at a
        /// legal rate at the start it reads, and the cells after it can hurry.
        var leadCells: Int = 0
        var leadFPS: Double = 10
        /// Which burst comes off the rim, and how fast it plays. **One each**: three
        /// finishes that land the same way read as one animation with three wind-ups —
        /// and the sheets are not the same length, so one rate does not suit all three.
        var burst: Sprite = .sparkleBurst
        var burstFPS: Double = Theme.Figure.playerFPS
        /// **How many of the burst's opening cells to cut.** A wind-up is time the rim
        /// does not have: the bang has to land on the slam, so the cells before it are
        /// dropped rather than led up to. Measured off the sheets — `SparkleBurst3` sits
        /// under 220 lit pixels for eight frames and then jumps to 1124 on the ninth —
        /// it opens on the last of those, so the bang has a frame to arrive on. The
        /// other two are already at full on their first and cut nothing.
        var burstSkip: Int = 0
    }

    static func trip(for dunk: Dunk) -> Trip {
        switch dunk {
        case .oneHand:
            return Trip(rise: 34, arrivesAt: 0.5, climb: 0.40,
                        gatherFPS: 10, finishFPS: 10, sink: 4,
                        burst: .sparkleBurst2, burstFPS: 20)
        case .reverse:
            return Trip(rise: 34, arrivesAt: 0.5, climb: 0.50,
                        gatherFPS: 10, finishFPS: 10, sink: 4)
        case .whirlwind:
            // Three of its five climb cells held at ten, which leaves the last two to
            // share a tenth of a second. **Which cells are the spin is a guess** — set
            // `lead cells` on the bench once it is on screen.
            return Trip(rise: 34, arrivesAt: 0.5, climb: 0.40,
                        gatherFPS: 10, finishFPS: 10, sink: 4,
                        leadCells: 3, leadFPS: 10,
                        burst: .sparkleBurst3, burstFPS: 10, burstSkip: 8)
        }
    }

    /// How far over the iron a finish was arriving, counted by eye. See
    /// `DunkTuning.overTheRim`, which is the dial, and the court tuner. The scene is laid out
    /// in `HoopStage`, so the canvas and a phone agree and it can be turned on either.
    static let overTheRim: CGFloat = 0

    /// **The rim takes his weight.** He goes this many art pixels *past* the tuned
    /// finish as he catches hold of it, and the ring goes down with him — then a spring
    /// puts both of them back where they belong. Snapped on the way down, because that is
    /// an impact; sprung on the way up, because that is iron.
    static let grab: CGFloat = 2
    /// How long he hangs at the bottom before it lets go.
    static let grabHold: Double = 0.06
    static let grabSpring = Animation.spring(response: 0.26, dampingFraction: 0.45)
    /// **What the rim gives back.** The spring alone was the ring moving; this is the
    /// energy coming off it — a burst out of the net on the way up.
    static let burstScale: CGFloat = 3

    /// **A swing is not the impact.** Two pixels is what arriving on the rim costs; a
    /// man already hanging on it moves less than that, and the ring moves less again —
    /// at two he was travelling 27 points against the ring's 11, which is him bouncing
    /// on a rim that is barely giving. One art pixel is 14 points, which is as near the
    /// ring's own travel as a whole pixel gets.
    static let bounce: CGFloat = 1

    /// A reverse hangs on and keeps swinging until the scene is done with him. **Slow
    /// and heavy**: a loaded rim is a long piece of sprung steel, not a diving board.
    ///
    /// **The gap is twice the spring.** Each swing gets exactly its own response to come
    /// back and exactly that again at rest, so every one starts from a settled rim and no
    /// two can differ — which is why it locks at a half and a whole and reads as ringing
    /// at anything else. Keep the pair in that ratio.
    static let bounceResponse: Double = 0.50
    static let bounceDamping: Double = 0.30
    static let bounceEvery: Double = bounceResponse * 2

    /// The whirlwind keeps turning on the rim, slowly, either side of upright — pivoted
    /// on the hand holding it. **Measured off the sheet**: the topmost ink on its last
    /// cell is two pixels wide at column 18–19, row 4, which is his hand on the iron.
    static let spinTo: Double = 10
    static let spinSeconds: Double = 1.6
    /// **Straight off the last cell.** A beat here stopped him dead between the whirl and
    /// the swing, which is what made the whirl itself hard to read — the motion has to
    /// carry through rather than land and restart.
    static let spinAfter: Double = 0
    static let hand = UnitPoint(x: 19.0 / 32, y: 4.5 / 32)

    // ── When it does not go in ──────────────────────────────────────────

    /// How far past the rim he carries when he sails over it, as a share of the climb —
    /// and how long that takes. The scale falls out of the same number: he is already
    /// shrinking toward `arrivesAt` on the way up, so carrying on past one shrinks him
    /// past it too, which is what going away looks like.
    static let pastReach: CGFloat = 1.9
    static let pastSeconds: Double = 0.55
    /// The smallest he is allowed to get. Past two the scale would cross zero and turn
    /// him inside out.
    static let pastFloor: CGFloat = 0.06
    /// **Up and to the left, not straight up.** Going over the rim means going clear of
    /// the board behind it; straight up is going through it. Art pixels, at full carry.
    ///
    static let pastDrift: CGFloat = -20

    /// **How high he gets when he does not get up to it, in art pixels.** Not a share of
    /// the climb: the shrink has to reach the *same* size it would at the rim — he is as
    /// far upcourt as anybody else, just lower — so the height and the size come apart
    /// here and are two values rather than one.
    static let shortPeak: CGFloat = 28
    /// Where the fall leaves him, as a share of that peak, and how long it takes.
    static let shortLands: CGFloat = 0.42
    static let shortFall: Double = 0.45
    /// A beat at the top before he drops.
    ///
    /// **Without it the apex is not a moment, it is a corner.** The climb and the fall
    /// used to meet on the same frame, so however high he actually got, the eye only ever
    /// saw him rising and then falling — and read the height off where he ended rather
    /// than where he turned. He has to hang for the peak to be seen at all.
    static let shortHang: Double = 0.12
    /// The landing sheet's rate, and how long the turn-around holds its one profile cell.
    static let landFPS: Double = 7.5
    static let turnHold: Double = 0.16

    /// A tumble: how far round he goes and over how long, repeating. **Clockwise, and it
    /// starts with the leap** — the ball is gone the moment he leaves the floor, not once
    /// he is level with the rim.
    static let tumbleTurns: Double = 1
    static let tumbleSeconds: Double = 1.2
    /// How long he is held coiled on the last cell of the wind-up before a tumble leaves
    /// the floor. **The gather has to read first**: a man who comes apart needs to be
    /// seen gathering himself, or the tumble is the whole of what happened rather than
    /// the thing that went wrong with it.
    static let tumbleGather: Double = 0.30

    /// How far the ring is pulled down, against its own width, and how far the net
    /// stretches doing it. **One pull for both halves**, or the ring comes apart.
    static let rimDrop: CGFloat = 0.08
    static let netStretch: CGFloat = 0.35

    /// How many cells play at the rim, which is what `sink` is counted against.
    static func finishCells(of dunk: Dunk) -> Int {
        let from = dunk.climb?.upperBound ?? dunk.arrivesBy ?? 0
        return max(0, dunk.sheet.frames - from)
    }
}

/// Every number in a dunk, on a dial. The dials edit whichever finish is `showing`.
@Observable
@MainActor
final class DunkTuning {
    static let shared = DunkTuning()

    /// **How far over the iron a finish arrives, in art pixels.** Dropped by this, so a
    /// positive number brings him down onto the ring.
    ///
    /// In art pixels because that is the unit the drawing is in and the unit the error
    /// gets counted in — one of them at the top of the climb is a little under seven
    /// points, so a step of one is a pixel on the screen. See
    /// `ShotCutsceneView.stageY(in:)`.
    var overTheRim: CGFloat = DunkStyle.overTheRim

    /// Which one the bench — and the in-game `dunk` button — throws down.
    var showing: Dunk = .oneHand
    /// How it fails when it does. Nil throws it down.
    var missing: DunkMiss?

    private var trips: [Dunk: DunkStyle.Trip] = Dictionary(
        uniqueKeysWithValues: Dunk.allCases.map { ($0, DunkStyle.trip(for: $0)) })

    /// The numbers for one finish. The view asks for the dunk it is drawing; the dials
    /// ask for whichever is on screen.
    func trip(for dunk: Dunk) -> DunkStyle.Trip {
        trips[dunk] ?? DunkStyle.trip(for: dunk)
    }

    private var here: DunkStyle.Trip {
        get { trip(for: showing) }
        set { trips[showing] = newValue }
    }

    var rise: CGFloat { get { here.rise } set { here.rise = newValue } }
    var arrivesAt: CGFloat { get { here.arrivesAt } set { here.arrivesAt = newValue } }
    var climb: Double { get { here.climb } set { here.climb = newValue } }
    var gatherFPS: Double { get { here.gatherFPS } set { here.gatherFPS = newValue } }
    var finishFPS: Double { get { here.finishFPS } set { here.finishFPS = newValue } }
    /// Held as a double so a slider can carry it; read back as a count of cells.
    var sink: Double {
        get { Double(here.sink) }
        set { here.sink = Int(newValue) }
    }

    /// The whole trip, so the timing can be read against the scene it plays inside.
    var whole: Double {
        Double(Sprite.dunkPrepare.frames) / gatherFPS + climbRun + finishRun
    }

    /// How long the climb actually takes. **The lead can outlast the budget**: hold four
    /// cells at ten and the climb is four tenths whatever the dial says, so this reports
    /// the longer of the two rather than the number that was asked for.
    var climbRun: Double { max(climb, Double(here.leadCells) / here.leadFPS) }

    var leadCells: Double {
        get { Double(here.leadCells) }
        set { here.leadCells = Int(newValue) }
    }
    var leadFPS: Double { get { here.leadFPS } set { here.leadFPS = newValue } }
    var burstFPS: Double { get { here.burstFPS } set { here.burstFPS = newValue } }
    var burstSkip: Double {
        get { Double(here.burstSkip) }
        set { here.burstSkip = Int(newValue) }
    }

    /// The swing, shared by all three — only a reverse uses it, and it is the rim's
    /// behaviour rather than a finish's.
    var bounceResponse: Double = DunkStyle.bounceResponse
    var bounceEvery: Double = DunkStyle.bounceEvery
    var bounceSpring: Animation {
        .spring(response: bounceResponse, dampingFraction: DunkStyle.bounceDamping)
    }

    /// How long he spends at the rim.
    ///
    /// **The sink can outlast the sheet.** A reverse has three cells there and sinks four
    /// pixels, so it holds its last cell for a fourth frame — which this used to leave
    /// out, reporting a tenth of a second less than the finish actually runs.
    var finishRun: Double {
        Double(max(DunkStyle.finishCells(of: showing), Int(sink))) / finishFPS
    }

    func reset() {
        overTheRim = DunkStyle.overTheRim
        trips[showing] = DunkStyle.trip(for: showing)
        bounceResponse = DunkStyle.bounceResponse
        bounceEvery = DunkStyle.bounceEvery
    }

    /// The dials as `DunkStyle`, ready to paste over its `trip(for:)`.
    var source: String {
        func g(_ value: some BinaryFloatingPoint) -> String {
            String(format: "%g", Double(value))
        }
        return Dunk.allCases.map { dunk in
            let trip = self.trip(for: dunk)
            return """
            case .\(dunk.rawValue):
                return Trip(rise: \(g(trip.rise)), arrivesAt: \(g(trip.arrivesAt)), \
            climb: \(g(trip.climb)),
                            gatherFPS: \(g(trip.gatherFPS)), \
            finishFPS: \(g(trip.finishFPS)), sink: \(trip.sink),
                            leadCells: \(trip.leadCells), leadFPS: \(g(trip.leadFPS)),
                            burst: .\(trip.burst), burstFPS: \(g(trip.burstFPS)), \
            burstSkip: \(trip.burstSkip))
            """
        }.joined(separator: "\n")
        + """
        \n
        static let overTheRim: CGFloat = \(g(overTheRim))
        static let bounceResponse: Double = \(g(bounceResponse))
        static let bounceEvery: Double = \(g(bounceEvery))
        """
    }
}

#if DEBUG
/// The three finishes, over the rim, with the dials under them.
///
/// A dunk only exists inside a shot — it replaces the jumper rather than playing on its
/// own — so this drives the real cutscene rather than staging the sprite in a box. What
/// is being judged is whether he *arrives* on the beat the ball does.
struct DunkBench: View {
    @State private var tune = DunkTuning.shared
    @State private var controller = GameController()
    @State private var open = true

    private let rates: [Double] = [4, 7.5, 10, 12, 15, 20, 30]

    var body: some View {
        GameView(controller: controller)
            .overlay(alignment: .bottom) { panel }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    controller.debugDunk(tune.showing, miss: tune.missing)
                } label: {
                    Text(tune.missing == nil ? "THROW IT DOWN" : "BRICK IT")
                        .font(.system(size: 11, weight: .black)).tracking(0.8)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(CardPalette.gold))
                }
                Button("print") {
                    UIPasteboard.general.string = tune.source
                    // The console as well as the clipboard: a device is not always
                    // plugged into the machine the source lives on.
                    DevLog.say(.bench, "DunkStyle\n" + tune.source)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CardPalette.gold)
                Button("reset") { tune.reset() }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(CardPalette.red)
                Spacer()
                Text(String(format: "%.2fs", tune.whole))
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
                        // Which one. They climb differently enough that a number tuned on
                        // one is not tuned on the others — see `Dunk.climb`.
                        row("finish", "") {
                            HStack(spacing: 3) {
                                ForEach(Dunk.allCases, id: \.self) { kind in
                                    Button(Self.label(kind)) { tune.showing = kind }
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 3)
                                            .fill(tune.showing == kind
                                                  ? CardPalette.blue : .white.opacity(0.12)))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        // Down, or one of the three ways it comes apart. A whirlwind
                        // cannot tumble — it is already spinning.
                        row("outcome", "") {
                            HStack(spacing: 3) {
                                chip("down", on: tune.missing == nil) { tune.missing = nil }
                                ForEach(DunkMiss.allCases) { kind in
                                    if kind != .tumbles || tune.showing.canTumble {
                                        chip(kind.title, on: tune.missing == kind) {
                                            tune.missing = kind
                                        }
                                    }
                                }
                            }
                        }
                        heading("the trip")
                        dial("rise (px)", $tune.rise, 0...60)
                        dial("arrives at", $tune.arrivesAt, 0.2...1)
                        time("climb", $tune.climb, 0.1...2)
                        // The opening cells of the climb, held at their own rate.
                        row("lead cells", String(Int(tune.leadCells))) {
                            Slider(value: $tune.leadCells, in: 0...9, step: 1)
                        }
                        rate("lead fps", $tune.leadFPS)
                        rate("burst fps", $tune.burstFPS)
                        // Opening cells of the burst to cut, so the bang is immediate.
                        row("burst skip", String(Int(tune.burstSkip))) {
                            Slider(value: $tune.burstSkip, in: 0...12, step: 1)
                        }
                        // The swing on the rim. A reverse's, but kept out of the trips:
                        // it is what the rim does, not what a finish does.
                        heading("the swing")
                        time("spring", $tune.bounceResponse, 0.2...1.5)
                        time("every", $tune.bounceEvery, 0.2...2.5)
                        // Where the finish lands, in art pixels over the ring. The same
                        // dial the court tuner turns — one number, two screens.
                        row("over rim", String(Int(tune.overTheRim))) {
                            Slider(value: Binding(get: { Double(tune.overTheRim) },
                                                  set: { tune.overTheRim = CGFloat($0) }),
                                   in: -10...10, step: 1)
                        }
                        // Art pixels he comes back down at the end, one per frame.
                        row("sink (px)", String(Int(tune.sink))) {
                            Slider(value: $tune.sink, in: 0...10, step: 1)
                        }
                        heading("the sheets")
                        rate("gather fps", $tune.gatherFPS)
                        rate("finish fps", $tune.finishFPS)
                    }
                    .padding(.horizontal, 10).padding(.bottom, 8)
                }
                .frame(height: 190)
            }
        }
        .background(.black.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    /// One of a row of little buttons that pick between named things.
    private func chip(_ label: String, on: Bool,
                      _ run: @escaping () -> Void) -> some View {
        Button(label, action: run)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3)
                .fill(on ? CardPalette.blue : .white.opacity(0.12)))
            .foregroundStyle(.white)
    }

    static func label(_ dunk: Dunk) -> String {
        switch dunk {
        case .oneHand:   return "1-hand"
        case .reverse:   return "reverse"
        case .whirlwind: return "whirl"
        }
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

#Preview("Dunk bench") { DunkBench() }
#endif
