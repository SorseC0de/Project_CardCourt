import Observation

/// Switches for isolating what is costing frames.
///
/// An instrument, not a setting. The deck and the discard are each a full RealityKit
/// renderer, which the Simulator draws in software — turning both off and watching the
/// machine is the only way to know whether they are the reason it is working hard.
@Observable
final class RenderDebug {
    static let shared = RenderDebug()

    /// One court-wide 3D scene instead of a renderer per pile.
    ///
    /// On by default: it is the only place a card can leave the deck and travel, and the
    /// only frame wide enough for a shuffle — a pile in its own small frame clips the
    /// moment a slab is thrown more than a couple of centimetres.
    ///
    var courtStage = true
}
