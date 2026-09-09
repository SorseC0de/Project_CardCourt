import SwiftUI

/// **Card backs coming out of the wordmark.**
///
/// They emanate in rays from a point behind the mark, travel slowly outward, turn slowly
/// as they go, grow, and fade to nothing before they reach an edge. Drawn behind the
/// wordmark and the buttons, looping for as long as the menu is up.
///
/// **The pixel backs turn counter-clockwise and the drawn one turns clockwise**, which is
/// what keeps two versions of the same object from reading as a mistake.
///
/// Three things about how it is built, all of them the reason it is cheap enough to leave
/// running:
///
/// - **One `Image` per card, animated by modifiers**, not a `TimelineView`. A timeline
///   re-evaluates every card's body sixty times a second; a modifier animation is handed
///   to the render server once and left alone. The stagger is a `delay` on each card's own
///   `repeatForever`, which offsets its phase for good.
/// - **The raster, never the vector.** A vector asset re-rasterises every time its drawn
///   size changes, and every card here is changing size on every frame. `CardBackRaster`
///   is a PNG of the same drawing.
/// - **`drawingGroup` on each card, under the transforms.** The card is rasterised once at
///   the largest size it will ever be drawn, and the animation only ever scales that
///   bitmap *down* — so nothing is redrawn as it grows. No shadow and no blur anywhere:
///   both would cost an offscreen pass per card per frame.
struct FlyingCards: View {
    /// **Where the rays come from — the wordmark's own middle, measured.** Handed over in
    /// the window's coordinates by whoever is drawing the mark, because this view ignores
    /// the safe area and the mark does not: a number written down here is wrong by the
    /// height of the notch, and by a different amount on every phone. Nil until the mark
    /// has been laid out, and nothing is drawn until then.
    var from: CGPoint?
    /// How many directions they go out in.
    var rays = 10
    /// How many are on each ray at once. One leaves every `travel / deep` seconds, and
    /// **they all leave together** — the rays are in step with each other, which is what
    /// makes them read as rays rather than as a scatter.
    var deep = 4
    /// A card's width at the end of the **longest** ray. Every other ray ends smaller, in
    /// proportion to how far it had to go.
    var size: CGFloat = 150

    private enum Flight {
        /// How long a card takes to get wherever it is going. Slow on purpose, and the
        /// same for every ray — a card with less ground to cover crosses it more gently,
        /// which is what a thing further away looks like.
        static let travel: Double = 11
        /// How far it turns over that, in degrees. Slow, and signed by which back it is.
        ///
        /// Small on purpose. A card lies along its own ray, so the ray is a line of cards
        /// pointing the way they are going; turn them far enough and the line stops being
        /// a line and the whole thing swirls.
        static let spin: Double = 30
        /// How big it starts, against the size it ends at.
        static let from: CGFloat = 0.08
        /// How far past the edge the ray runs before it stops. It is long gone by then.
        static let over: CGFloat = 1.12
    }

    var body: some View {
        GeometryReader { geo in
            if let from {
                ZStack {
                    ForEach(0..<(rays * deep), id: \.self) { index in
                        let ray = index / deep
                        let along = index % deep
                        // Evenly spaced, and no jitter: a spoke is only a spoke if the
                        // cards on it are in a line.
                        let turn = Double(ray) / Double(rays) * 360
                        let far = reach(to: turn, in: geo.size, from: from)
                        // **A card grows by how far it has actually gone**, not by how
                        // far through its trip it is. The mark sits high on the screen,
                        // so a ray pointing up has a fifth of the ground to cover that
                        // one pointing into the bottom corner has — and a card reaching
                        // full size in that fifth was a full-size card sitting on the
                        // wordmark. Growing with distance reads as depth instead: the
                        // ones with somewhere to go come forward, and the ones without
                        // stay small and fade out at the top edge.
                        let grows = Flight.from + (1 - Flight.from)
                            * (far / longest(in: geo.size, from: from))
                        FlyingCard(art: art(index),
                                   pixels: isPixels(index),
                                   angle: turn,
                                   reach: far,
                                   size: size * (isPixels(index) ? Self.pixelFrame : 1),
                                   spin: isPixels(index) ? -Flight.spin : Flight.spin,
                                   travel: Flight.travel,
                                   from: Flight.from,
                                   to: grows,
                                   delay: Flight.travel * Double(along) / Double(deep))
                            .position(from)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// **Two in three are pixel backs.** The drawn one is the odd one out, which is why it
    /// is also the one turning the other way.
    private func isPixels(_ index: Int) -> Bool { index % 3 != 2 }
    private func art(_ index: Int) -> String { isPixels(index) ? "CardBack" : "CardBackRaster" }

    /// The pixel back is a card inside a square frame, and the card is half the frame
    /// wide — so it has to be given twice the room to come out the same size as the
    /// drawn one. Measured off the art rather than guessed.
    private static let pixelFrame: CGFloat = 2

    /// How far a ray runs before it is off the screen, measured along its own direction
    /// rather than taken as the diagonal — a card going straight up has a much shorter
    /// way to go than one going into a corner, and one number for both leaves half of
    /// them fading in mid-air.
    /// The longest any ray has to run, which is the corner furthest from the mark. It is
    /// the one that ends at full size; every other is a share of it.
    private func longest(in size: CGSize, from: CGPoint) -> CGFloat {
        hypot(max(from.x, size.width - from.x), max(from.y, size.height - from.y)) * Flight.over
    }

    private func reach(to degrees: Double, in size: CGSize, from: CGPoint) -> CGFloat {
        let radians = degrees * .pi / 180
        let dx = cos(radians), dy = sin(radians)
        let across = dx > 0 ? (size.width - from.x) / dx : (dx < 0 ? -from.x / dx : .infinity)
        let down = dy > 0 ? (size.height - from.y) / dy : (dy < 0 ? -from.y / dy : .infinity)
        return min(across, down) * Flight.over
    }
}

/// One card, on its own loop for the life of the screen.
private struct FlyingCard: View {
    let art: String
    let pixels: Bool
    let angle: Double
    let reach: CGFloat
    let size: CGFloat
    let spin: Double
    /// How long one crossing takes.
    let travel: Double
    /// How big it starts and ends, against the width it is drawn at.
    let from: CGFloat
    let to: CGFloat
    let delay: Double

    /// Flipped once, on appear. Everything the card does is one animation between the two
    /// values of this.
    @State private var out = false

    /// Where the card ends up, along its own ray.
    private var away: CGSize {
        let radians = angle * .pi / 180
        return CGSize(width: cos(radians) * reach, height: sin(radians) * reach)
    }

    var body: some View {
        Image(art)
            .interpolation(pixels ? .none : .high)
            .resizable()
            .scaledToFit()
            // Framed at the size it ends at, and rasterised there, so the trip only ever
            // scales the bitmap down.
            .frame(width: size)
            .drawingGroup()
            // **Lying along its own ray**, so a spoke is a line of cards pointing the way
            // they are going rather than a line of cards at odd angles to it.
            .rotationEffect(.degrees(angle + 90 + (out ? spin : 0)))
            .scaleEffect(out ? to : from)
            .offset(x: out ? away.width : 0, y: out ? away.height : 0)
            .animation(.linear(duration: travel).repeatForever(autoreverses: false)
                .delay(delay), value: out)
            // **Its own curve.** Held near full for most of the trip and gone by the edge;
            // a linear fade over the same distance is half transparent before the card has
            // cleared the wordmark.
            .opacity(out ? 0 : 1)
            .animation(.easeIn(duration: travel).repeatForever(autoreverses: false)
                .delay(delay), value: out)
            .onAppear { out = true }
    }
}

#if DEBUG
#Preview("Flying cards") {
    ZStack {
        CardPalette.blue.ignoresSafeArea()
        FlyingCards(from: CGPoint(x: 196, y: 226))
        SwisshWordmark(size: SwisshWordmark.Mark.size)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 96)
    }
}
#endif
