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
    /// How much of the run the combs are spread across. Zero is every column leaving in
    /// step, which reads as one thing sliding rather than a body coming apart.
    var stagger: Double = 0.10
    /// **Rolled fresh for every warp.** The same body leaving the same way twice reads as
    /// a canned animation; the whole effect is that it comes apart differently each time.
    /// Held by whoever starts the warp so it does not change mid-flight — see
    /// `AnyTransition.columnWarp` and `CourtView.warpSeed`.
    var seed: UInt64 = 0

    /// How many combs the columns are dealt into.
    static let combs = 6
    /// How far into a comb's own travel the bands have finished narrowing.
    ///
    /// **The splay.** At rest the bands are two pixels wide and touching, which is a solid
    /// sprite; as the warp starts they thin to one and the gaps open between them. So the
    /// figure is seen to come apart into columns rather than arriving already in pieces.
    static let thinBy: CGFloat = 0.35

    /// So a change of `progress` is a movement rather than a jump.
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        ZStack {
            if progress <= 0 {
                content
            } else {
                ForEach(0..<Self.combs, id: \.self) { comb in
                    let along = share(for: comb)
                    let thinning = min(1, along / Self.thinBy)
                    content
                        .mask {
                            Comb(pixel: pixel, index: comb, of: Self.combs,
                                 width: pixel * (2 - thinning))
                        }
                        // **Up, and only up.** Out is the columns leaving overhead; in is
                        // this run backwards, which is them coming down into place.
                        .offset(x: nudge(comb) * pixel * along,
                                y: -reach * pixel * along)
                }
            }
        }
    }

    /// How far along this comb is, given the whole warp's progress.
    ///
    /// Its start is drawn from the seed rather than from its place in the row, so the
    /// order the columns leave in is different every time.
    private func share(for comb: Int) -> CGFloat {
        let start = stagger * roll(comb, 1)
        guard stagger < 1 else { return CGFloat(progress) }
        return CGFloat(min(1, max(0, (progress - start) / (1 - stagger))))
    }

    /// A one-pixel step sideways, on some of them.
    ///
    /// One pixel, and not all of them: any more reads as the sprite being torn up rather
    /// than a body flickering out, and every comb doing it reads as a lean.
    private func nudge(_ comb: Int) -> CGFloat {
        let r = roll(comb, 2)
        return r < 0.34 ? -1 : (r < 0.66 ? 0 : 1)
    }

    /// A fixed number in `0..<1` for this comb and this question, off the warp's own seed.
    private func roll(_ comb: Int, _ question: UInt64) -> Double {
        var x = seed &+ UInt64(comb) &* 0x9E37_79B9_7F4A_7C15 &+ question &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((x ^ (x >> 31)) >> 11) / Double(1 << 53)
    }
}

/// One comb: every `of × 2`-th column, drawn `width` wide.
private struct Comb: View {
    let pixel: CGFloat
    let index: Int
    let of: Int
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            let stride = CGFloat(of * 2) * pixel
            var x = CGFloat(index * 2) * pixel
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)),
                             with: .color(.black))
                x += stride
            }
        }
    }
}

extension View {
    /// Warps out — or, run backwards, in. `pixel` is the sprite's own scale.
    func columnWarp(_ progress: Double, pixel: CGFloat = Theme.Figure.playerScale,
                    reach: CGFloat = 40, seed: UInt64 = 0) -> some View {
        modifier(ColumnWarp(progress: progress, pixel: pixel, reach: reach, seed: seed))
    }
}

extension AnyTransition {
    /// Arriving and leaving in columns, for anything that appears on the floor rather than
    /// walking on to it — a referee taking the court, a player stepping off it to throw
    /// the ball back in.
    ///
    /// One seed for both ends, rolled where the transition is built: the two instances are
    /// what SwiftUI interpolates between, so they have to agree on how this one comes
    /// apart.
    static func columnWarp(pixel: CGFloat = Theme.Figure.playerScale,
                           reach: CGFloat = 40) -> AnyTransition {
        let seed = UInt64.random(in: UInt64.min...UInt64.max)
        return .modifier(
            active: ColumnWarp(progress: 1, pixel: pixel, reach: reach, seed: seed),
            identity: ColumnWarp(progress: 0, pixel: pixel, reach: reach, seed: seed))
    }
}

#if DEBUG
/// The warp with its two numbers on sliders, and a button to run it.
struct ColumnWarpBench: View {
    @State private var progress: Double = 0
    @State private var pixel: CGFloat = 7
    @State private var reach: CGFloat = 40
    @State private var seconds: Double = 0.14
    @State private var stagger: Double = 0.10
    @State private var seed: UInt64 = .random(in: .min ... .max)

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Theme.courtFloor
                SpriteAnimation(sprite: .front, scale: pixel, isPlaying: false, restFrame: 0)
                    .paletteSwap(PlayerLook.shared.kit(for: .east))
                    .modifier(ColumnWarp(progress: progress, pixel: pixel,
                                         reach: reach, stagger: stagger, seed: seed))
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
                dial("stagger", $stagger, 0...0.4)
                HStack(spacing: 12) {
                    Button("warp out") {
                        seed = .random(in: .min ... .max)
                        progress = 0
                        withAnimation(.easeIn(duration: seconds)) { progress = 1 }
                    }
                    Button("warp in") {
                        seed = .random(in: .min ... .max)
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
