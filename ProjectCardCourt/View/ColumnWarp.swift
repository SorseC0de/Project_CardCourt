import SwiftUI

/// The teleport: a sprite cut into one-pixel columns, every other one thrown up and the
/// rest thrown down, until there is nothing left in frame.
///
/// **Mega Man's technique at a ninja's speed.** The columns are his; the timing is the one
/// anime uses for a body that was there a frame ago and is not now — it does not dissolve,
/// it goes. Slow it down and it stops reading as a teleport and starts reading as a wipe,
/// so the duration is short enough that the strips are a shear rather than a journey.
///
/// ## How it is drawn
///
/// Not thirty-two layers. The odd columns all travel together and so do the even ones, so
/// it is two copies of the same view, each masked to its own comb of stripes and offset
/// the opposite way. The mask does the cutting; nothing has to know what the sprite is.
///
/// ## Why the stripe width is handed in
///
/// One *art* pixel, not one point. A stripe of any other width lands on a fraction of a
/// pixel and the comb crawls as the figure scales — see the note on `SpriteAnimation.scale`,
/// which is the same number: points per art pixel.
struct ColumnWarp: ViewModifier, Animatable {
    /// Nought is whole and untouched; one is fully gone.
    var progress: Double
    /// Points per art pixel — the width of one column.
    var pixel: CGFloat
    /// How far the columns travel at full progress, in art pixels. Enough to clear the
    /// figure and no more — at this speed the eye reads the shear, not the trip.
    var reach: CGFloat = 40
    /// How far apart the combs start, as a share of the whole. Zero is every column
    /// leaving in step, which reads as one thing sliding rather than a body coming apart.
    var stagger: Double = 0.06

    /// How many combs the columns are dealt into.
    ///
    /// Each comb is every twelfth column, so only the even ones are ever drawn — the odd
    /// ones are the gaps the effect is made of — and six of them is enough variation that
    /// no two neighbours leave together.
    static let combs = 6

    /// Which combs take a one-pixel step sideways on the way out, and which way.
    ///
    /// **One pixel, and not all of them.** Any more reads as the sprite being torn up
    /// rather than a body flickering out, and every comb doing it reads as a lean.
    private static let nudge: [CGFloat] = [0, 1, 0, -1, 0, 1]

    /// So a change of `progress` is a movement rather than a jump — the whole point is
    /// that SwiftUI walks it from nought to one and the columns travel while it does.
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        // One stack either way, so the view's own type never changes under an animation.
        ZStack {
            if progress <= 0 {
                // Whole is whole: a figure standing about pays neither mask nor a copy
                // of itself.
                content
            } else {
                ForEach(0..<Self.combs, id: \.self) { comb in
                    let along = share(for: comb)
                    content
                        .mask { Comb(pixel: pixel, index: comb, of: Self.combs) }
                        // **Up, and only up.** Out is the columns leaving overhead; in is
                        // this run backwards, which is them coming down into place. Two
                        // directions at once is a thing splitting, not a thing going.
                        .offset(x: Self.nudge[comb % Self.nudge.count] * pixel * along,
                                y: -reach * pixel * along)
                }
            }
        }
    }

    /// How far along this comb is, given the whole warp's progress. The last one starts
    /// when the first is already `stagger × combs` of the way gone.
    private func share(for comb: Int) -> CGFloat {
        let spread = stagger * Double(Self.combs - 1)
        let start = stagger * Double(comb)
        guard spread < 1 else { return CGFloat(progress) }
        return CGFloat(min(1, max(0, (progress - start) / (1 - spread))))
    }
}

/// One comb: every `stride`-th column, in art pixels, starting at `index`.
private struct Comb: View {
    let pixel: CGFloat
    let index: Int
    let of: Int

    var body: some View {
        Canvas { context, size in
            // Twice the comb count, so the columns between them are never drawn at all —
            // the gaps are half the effect.
            let stride = CGFloat(of * 2) * pixel
            var x = CGFloat(index * 2) * pixel
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: pixel, height: size.height)),
                             with: .color(.black))
                x += stride
            }
        }
    }
}

extension View {
    /// Warps out — or, run backwards, in. `pixel` is the sprite's own scale.
    func columnWarp(_ progress: Double, pixel: CGFloat = Theme.Figure.playerScale,
                    reach: CGFloat = 40) -> some View {
        modifier(ColumnWarp(progress: progress, pixel: pixel, reach: reach))
    }
}

extension AnyTransition {
    /// Arriving and leaving in columns, for anything that appears on the floor rather than
    /// walking on to it — a referee taking the court, a player stepping off it to throw
    /// the ball back in.
    static func columnWarp(pixel: CGFloat = Theme.Figure.playerScale,
                           reach: CGFloat = 40) -> AnyTransition {
        .modifier(active: ColumnWarp(progress: 1, pixel: pixel, reach: reach),
                  identity: ColumnWarp(progress: 0, pixel: pixel, reach: reach))
    }
}

#if DEBUG
/// The warp with its two numbers on sliders, and a button to run it.
struct ColumnWarpBench: View {
    @State private var progress: Double = 0
    @State private var pixel: CGFloat = 7
    @State private var reach: CGFloat = 40
    @State private var seconds: Double = 0.14
    @State private var stagger: Double = 0.06

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Theme.courtFloor
                SpriteAnimation(sprite: .front, scale: pixel, isPlaying: false, restFrame: 0)
                    .paletteSwap(PlayerLook.shared.kit(for: .east))
                    .modifier(ColumnWarp(progress: progress, pixel: pixel,
                                         reach: reach, stagger: stagger))
            }
            .frame(height: 320)
            .clipped()

            VStack(spacing: 6) {
                dial("progress", $progress, 0...1)
                dial("pixel", Binding(get: { Double(pixel) },
                                      set: { pixel = CGFloat($0.rounded()) }), 1...12)
                dial("reach", Binding(get: { Double(reach) },
                                      set: { reach = CGFloat($0.rounded()) }), 8...160)
                dial("seconds", $seconds, 0.1...2)
                dial("stagger", $stagger, 0...0.16)
                HStack(spacing: 12) {
                    Button("warp out") {
                        progress = 0
                        withAnimation(.easeIn(duration: seconds)) { progress = 1 }
                    }
                    Button("warp in") {
                        progress = 1
                        withAnimation(.easeOut(duration: seconds)) { progress = 0 }
                    }
                }
                .font(.custom(Chrome.display, size: 15))
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CardPalette.black)
        }
        .ignoresSafeArea()
    }

    private func dial(_ name: String, _ value: Binding<Double>,
                      _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 10) {
            Text(String(format: "%@ %.2f", name, value.wrappedValue))
                .font(.custom(Chrome.display, size: 15))
                .foregroundStyle(.white)
                .frame(width: 130, alignment: .leading)
            Slider(value: value, in: range)
        }
    }
}

#Preview("Column warp") { ColumnWarpBench() }
#endif
