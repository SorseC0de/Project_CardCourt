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
    var seconds: Double = 2.0

    /// When the man starts appearing, and how long he takes, measured from the start.
    /// **His fade outlasts the brush**: he is still arriving after the kanji has settled.
    var playerIn: Double = 0
    var playerFade: Double = 3.0
    /// When the black starts coming off him, and how long that takes. These two add up
    /// to the length of the whole thing, so the colour is in him as the last stroke lands.
    var colourIn: Double = 0.5
    var colourFade: Double = 1.5

    /// Where it starts: a share of the frame it is drawn at, and points from the man's
    /// own middle. Roughly a 32-pixel kanji at the scale the player is drawn at.
    var startScale: CGFloat = 1.0
    var startX: CGFloat = 0
    var startY: CGFloat = 20.0

    /// And where it comes to rest — on the back of the shirt.
    var endScale: CGFloat = 0.10
    var endX: CGFloat = 0
    var endY: CGFloat = 16.0
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
    /// **Big.** The results card stands its men at a reading size; this is a scene, and
    /// he is the whole of it.
    var scale: CGFloat = FinKanjiView.playerScale
    /// Restart the whole thing by handing this a new value.
    var run: Int = 0

    @State private var tuning = FinTuning.shared
    /// Nil until it starts, so nothing is drawn mid-air on the first frame.
    @State private var startedAt: Date?

    /// How big the man stands in the scene. The results card draws its winners at eight
    /// to the pixel and then halves them again; this is a scene, not a row of portraits.
    static let playerScale: CGFloat = 10

    private enum Mark {
        /// The kanji's own cell, in art pixels — twice a player's.
        static let cell: CGFloat = 64
    }

    var body: some View {
        // Its own clock rather than a spring: three things move on it — the brush, the
        // scale and the colour — and they have to agree about where they are.
        TimelineView(.animation) { tick in
            let t = elapsed(at: tick.date)
            // **He stands on the floor of the scene**, rather than hanging in the middle
            // of it: a portrait sizes itself and a centred stack left him floating.
            ZStack(alignment: .bottom) {
                man(at: t)
                kanji(at: t)
            }
            // **The sheet's own size at this scale.** `Theme.Figure.height` already has
            // the court's scale baked into it — multiplying by another one framed him at
            // a thousand points and stood him well below the bottom of the screen.
            .frame(width: Sprite.akuma.frameSize * scale,
                   height: Sprite.akuma.frameSize * scale, alignment: .bottom)
        }
        .onAppear { startedAt = Date() }
        .onChange(of: run) { startedAt = Date() }
    }

    /// **How far in we are, and it keeps running.** The kanji's own travel is finished at
    /// `seconds` and holds there; the fades are not tied to it, so a man who takes longer
    /// to arrive than the brush takes to write is allowed to.
    private func elapsed(at now: Date) -> Double {
        guard let startedAt else { return 0 }
        return now.timeIntervalSince(startedAt)
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
    ///
    /// **Scaled rather than framed.** A sprite sizes itself off its own `scale`, so a
    /// frame around it only changes the box it sits in — the drawing inside stayed
    /// exactly as big, which is a scale dial that does nothing.
    private func kanji(at t: Double) -> some View {
        let through = tuning.seconds > 0 ? min(1, t / tuning.seconds) : 1
        return SpriteAnimation(sprite: .finKanji, scale: scale,
                               fps: Double(Sprite.finKanji.frames) / max(0.01, tuning.seconds),
                               playsOnce: true,
                               startedAt: startedAt)
            .scaleEffect(mix(tuning.startScale, tuning.endScale, through))
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
            // Tall enough for a man drawn at five, and no taller: given the whole
            // preview it pushed every dial off the bottom of it.
            .frame(height: 380)

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
