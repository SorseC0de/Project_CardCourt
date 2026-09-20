import SwiftUI

/// **How the kanji lands**, while it is being eyeballed. Freeze into `FinKanji` once it
/// does — see the bench at the bottom of this file.
@Observable
@MainActor
final class FinTuning {
    static let shared = FinTuning()

    /// How long the whole thing takes. **One number for two things**: the sheet's thirty-
    /// five cells are paced to fill it and the travel runs over it, so the brush finishes
    /// its last stroke exactly as the kanji comes to rest.
    var seconds: Double = 1.6

    /// When the man starts appearing, and how long he takes, measured from the start.
    var playerIn: Double = 0.25
    var playerFade: Double = 0.5
    /// When the black starts coming off him, and how long that takes. Meant to finish as
    /// the kanji does.
    var colourIn: Double = 0.7
    var colourFade: Double = 0.9

    /// Where it starts: a share of the frame it is drawn at, and points from the man's
    /// own middle. Roughly a 32-pixel kanji at the scale the player is drawn at.
    var startScale: CGFloat = 1
    var startX: CGFloat = 0
    var startY: CGFloat = -26

    /// And where it comes to rest — on the back of the shirt.
    var endScale: CGFloat = 0.3
    var endX: CGFloat = 0
    var endY: CGFloat = -34
}

/// **The winner's kanji.**
///
/// 死 is written across the screen a stroke at a time while the man fades up out of
/// nothing as a black silhouette; the kanji shrinks onto the back of his shirt as the
/// colour comes into him, and the last stroke lands as it settles.
struct FinKanjiView: View {
    var pose: Kit.Pose = .fierce
    var kit: HooperKit?
    var seat: Seat = GameRules.localSeat
    var scale: CGFloat = Winner.portraitScale
    /// Restart the whole thing by handing this a new value.
    var run: Int = 0

    @State private var tuning = FinTuning.shared
    /// Nil until it starts, so nothing is drawn mid-air on the first frame.
    @State private var startedAt: Date?

    private enum Mark {
        /// The kanji's own cell, in art pixels — twice a player's.
        static let cell: CGFloat = 64
    }

    var body: some View {
        // Its own clock rather than a spring: three things move on it — the brush, the
        // scale and the colour — and they have to agree about where they are.
        TimelineView(.animation) { tick in
            let t = elapsed(at: tick.date)
            ZStack(alignment: .center) {
                man(at: t)
                kanji(at: t)
            }
            .frame(width: Theme.Figure.headDiameter * scale,
                   height: Theme.Figure.height * scale, alignment: .bottom)
        }
        .onAppear { startedAt = Date() }
        .onChange(of: run) { startedAt = Date() }
    }

    /// How far in we are, in seconds. Held at the end rather than looping.
    private func elapsed(at now: Date) -> Double {
        guard let startedAt else { return 0 }
        return min(tuning.seconds, now.timeIntervalSince(startedAt))
    }

    /// **The man, coming up out of nothing and then out of black.** Drawn twice: himself,
    /// and a flat black copy of himself over the top that is taken away rather than lit.
    /// A silhouette is the same shape as the man, so it has to *be* the man.
    private func man(at t: Double) -> some View {
        let shown = ramp(t, from: tuning.playerIn, over: tuning.playerFade)
        let black = 1 - ramp(t, from: tuning.colourIn, over: tuning.colourFade)
        return HooperPortrait(pose: pose, kit: kit, seat: seat, scale: scale)
            .overlay {
                HooperPortrait(pose: pose, kit: kit, seat: seat, scale: scale)
                    // Every colour in him taken to nothing, his own shape kept.
                    .colorMultiply(.black)
                    .opacity(black)
            }
            .opacity(shown)
    }

    /// The brush, and where it has got to.
    private func kanji(at t: Double) -> some View {
        let through = tuning.seconds > 0 ? min(1, t / tuning.seconds) : 1
        let size = Mark.cell * scale * mix(tuning.startScale, tuning.endScale, through)
        return SpriteAnimation(sprite: .finKanji, scale: scale,
                               fps: Double(Sprite.finKanji.frames) / max(0.01, tuning.seconds),
                               playsOnce: true,
                               startedAt: startedAt)
            .frame(width: size, height: size)
            .offset(x: mix(tuning.startX, tuning.endX, through) * scale,
                    y: mix(tuning.startY, tuning.endY, through) * scale)
    }

    /// Nought before it starts, one after it has finished, and the line between.
    private func ramp(_ t: Double, from: Double, over: Double) -> Double {
        guard over > 0 else { return t >= from ? 1 : 0 }
        return min(1, max(0, (t - from) / over))
    }

    private func mix(_ a: CGFloat, _ b: CGFloat, _ through: Double) -> CGFloat {
        a + (b - a) * CGFloat(through)
    }
}

#if DEBUG
/// **The bench.** Everything about the kanji on a slider — how long it takes, when the
/// man arrives, when the colour does, and where it starts and finishes.
struct FinKanjiBench: View {
    @State private var tuning = FinTuning.shared
    @State private var run = 0

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Color.black
                FinKanjiView(run: run)
            }
            .frame(height: 260)

            Button("replay") { run += 1 }
                .buttonStyle(.borderedProminent)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    group("Timing")
                    dial("seconds", $tuning.seconds, 0.4...4)
                    dial("player in", $tuning.playerIn, 0...3)
                    dial("player fade", $tuning.playerFade, 0.05...3)
                    dial("colour in", $tuning.colourIn, 0...3)
                    dial("colour fade", $tuning.colourFade, 0.05...3)

                    group("Kanji — start")
                    dial("scale", $tuning.startScale, 0.1...3)
                    dial("x", $tuning.startX, -80...80)
                    dial("y", $tuning.startY, -120...60)

                    group("Kanji — end")
                    dial("scale", $tuning.endScale, 0.05...2)
                    dial("x", $tuning.endX, -80...80)
                    dial("y", $tuning.endY, -120...60)
                }
                .padding(.horizontal, 14)
            }
        }
        .background(Theme.sceneGround)
    }

    private func group(_ name: String) -> some View {
        Text(name.uppercased())
            .font(.system(size: 10, weight: .black)).tracking(1.2)
            .foregroundStyle(Theme.inkDim)
            .padding(.top, 8)
    }

    private func dial(_ name: String, _ value: Binding<Double>,
                      _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: -2) {
            Text("\(name)  \(String(format: "%.2f", value.wrappedValue))")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
            Slider(value: value, in: range).tint(CardPalette.gold)
        }
    }

    private func dial(_ name: String, _ value: Binding<CGFloat>,
                      _ range: ClosedRange<Double>) -> some View {
        dial(name, Binding(get: { Double(value.wrappedValue) },
                           set: { value.wrappedValue = CGFloat($0) }), range)
    }
}

#Preview("FIN kanji") {
    FinKanjiBench()
}
#endif
