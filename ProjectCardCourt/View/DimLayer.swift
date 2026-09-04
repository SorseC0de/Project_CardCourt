import SwiftUI

/// The wash behind anything that takes over the screen.
///
/// **Always present, and animated by opacity alone.** A scrim added to the hierarchy is
/// laid out as it arrives, and a `Color` has no size of its own until it is — so for a
/// frame or two it reads as a black rectangle growing across the screen rather than as
/// the screen going dark. Keeping it there and turning it up costs nothing and has no
/// such moment.
struct DimLayer: View {
    var on: Bool
    var colour: Color = .black
    var amount: Double
    /// How long it takes to come up. The same going down.
    var seconds: Double = 0.25
    /// False for a wash that belongs to one part of the screen rather than all of it —
    /// the inbound dims the court and leaves the cards to their own.
    var full = true

    var body: some View {
        colour
            .opacity(on ? amount : 0)
            .ignoresSafeArea(full ? .all : [])
            .allowsHitTesting(false)
            .animation(.easeOut(duration: seconds), value: on)
    }
}
