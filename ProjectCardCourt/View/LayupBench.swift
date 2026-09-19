import SwiftUI

#if DEBUG
/// **The layup, run in over and over, with the dials under it.** The real shot scene on
/// its own stage — see `SceneBenchStage` — so a take starts the moment it is asked for.
struct LayupBench: View {
    @State private var tune = LayupTuning.shared
    @State private var replay = SceneReplay(Self.scene(defenders: 2, made: true))
    @State private var open = true
    @State private var defenders = 2
    @State private var made = true

    private let rates: [Double] = [4, 7.5, 10, 12, 15, 20, 30]

    var body: some View {
        SceneBenchStage(replay: replay)
            .overlay(alignment: .bottom) { panel }
            .onChange(of: defenders) { replay.stage(Self.scene(defenders: defenders, made: made)) }
            .onChange(of: made) { replay.stage(Self.scene(defenders: defenders, made: made)) }
    }

    private static func scene(defenders: Int, made: Bool) -> ShotCutscene {
        var scene = ShotCutscene(shooter: GameRules.localSeat,
                                 chance: Int(ShotTuning.shared.debugChance),
                                 made: made, defenders: defenders)
        scene.isLayup = true
        return scene
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    replay.play(Self.scene(defenders: defenders, made: made))
                } label: {
                    Text("RUN IT IN")
                        .font(.system(size: 11, weight: .black)).tracking(0.8)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(CardPalette.gold))
                }
                Button("print") {
                    UIPasteboard.general.string = tune.source
                    DevLog.say(.bench, "LayupTuning\n" + tune.source)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CardPalette.gold)
                Button("reset") { tune.reset() }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(CardPalette.red)
                Spacer()
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
                        row("outcome", "") {
                            HStack(spacing: 3) {
                                chip("made", on: made) { made = true }
                                chip("miss", on: !made) { made = false }
                            }
                        }
                        row("defenders", "") {
                            HStack(spacing: 3) {
                                ForEach(0...3, id: \.self) { count in
                                    chip("\(count)", on: defenders == count) { defenders = count }
                                }
                            }
                        }
                        heading("the run in")
                        dial("start size", $tune.startScale, 0.3...1.5)
                        time("run", $tune.approachSeconds, 0.2...2.5)
                        dial("arrives at", $tune.arrivesAt, 0.2...1)
                        dial("wall aside", $tune.wallAside, 0...200)
                        dial("around", $tune.aroundX, 0...200)
                        row("behind at", String(format: "%.2f", tune.behindAt)) {
                            Slider(value: $tune.behindAt, in: 0...1)
                        }
                        heading("the layup")
                        row("rise (px)", String(Int(tune.rise))) {
                            Slider(value: $tune.rise, in: 0...12, step: 1)
                        }
                        rate("layup fps", $tune.layupFPS)
                        time("hang", $tune.hang, 0...0.8)
                        row("land y (px)", String(Int(tune.landY))) {
                            Slider(value: $tune.landY, in: -20...40, step: 1)
                        }
                        heading("the release")
                        row("hand x", String(Int(tune.handX))) {
                            Slider(value: $tune.handX, in: -16...16, step: 1)
                        }
                        row("hand y", String(Int(tune.handY))) {
                            Slider(value: $tune.handY, in: -16...16, step: 1)
                        }
                        dial("off rim", $tune.offRim, -100...150)
                        dial("under rim", $tune.underRim, -60...60)
                        heading("the ball")
                        time("flight", $tune.flightSeconds, 0.1...1.2)
                        dial("arc", $tune.arc, 0...0.3)
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

    private func chip(_ label: String, on: Bool,
                      _ run: @escaping () -> Void) -> some View {
        Button(label, action: run)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3)
                .fill(on ? CardPalette.blue : .white.opacity(0.12)))
            .foregroundStyle(.white)
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

#Preview("Layup bench") { LayupBench() }
#endif
