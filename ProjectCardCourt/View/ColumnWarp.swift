import SwiftUI

/// The Mega Man teleport: a sprite cut into one-pixel columns, every other one thrown up
/// and the rest thrown down, until there is nothing left in frame.
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
struct ColumnWarp: ViewModifier {
    /// Nought is whole and untouched; one is fully gone.
    var progress: Double
    /// Points per art pixel — the width of one column.
    var pixel: CGFloat
    /// How far the two combs travel at full progress, in art pixels. Past the top and
    /// bottom of anything it is drawn over, which is the point: it does not fade, it
    /// leaves.
    var reach: CGFloat = 64

    func body(content: Content) -> some View {
        let travel = reach * pixel * CGFloat(progress)
        ZStack {
            content
                .mask { Comb(pixel: pixel, odd: false) }
                .offset(y: -travel)
            content
                .mask { Comb(pixel: pixel, odd: true) }
                .offset(y: travel)
        }
        // Nothing is drawn at all when it is whole, so a figure standing about pays
        // neither mask nor second copy.
        .drawingGroup(opaque: false)
    }
}

/// Every other column, in art pixels.
private struct Comb: View {
    let pixel: CGFloat
    let odd: Bool

    var body: some View {
        Canvas { context, size in
            var x = odd ? pixel : 0
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: pixel, height: size.height)),
                             with: .color(.black))
                x += pixel * 2
            }
        }
    }
}

extension View {
    /// Warps out — or, run backwards, in. `pixel` is the sprite's own scale.
    func columnWarp(_ progress: Double, pixel: CGFloat, reach: CGFloat = 64) -> some View {
        // Whole is whole: no mask, no second copy, no drawing group.
        progress <= 0
            ? AnyView(self)
            : AnyView(modifier(ColumnWarp(progress: progress, pixel: pixel, reach: reach)))
    }
}

#if DEBUG
/// The warp with its two numbers on sliders, and a button to run it.
struct ColumnWarpBench: View {
    @State private var progress: Double = 0
    @State private var pixel: CGFloat = 7
    @State private var reach: CGFloat = 64
    @State private var seconds: Double = 0.45

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Theme.courtFloor
                SpriteAnimation(sprite: .front, scale: pixel, isPlaying: false, restFrame: 0)
                    .paletteSwap(PlayerLook.shared.kit(for: .east))
                    .columnWarp(progress, pixel: pixel, reach: reach)
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
