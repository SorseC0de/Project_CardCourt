import Observation

/// Switches for isolating what is costing frames.
///
/// An instrument, not a setting. The deck and the discard are each a full RealityKit
/// renderer, which the Simulator draws in software — turning both off and watching the
/// machine is the only way to know whether they are the reason it is working hard.
@Observable
final class RenderDebug {
    static let shared = RenderDebug()

    /// Draws the piles as flat cards instead of geometry.
    var flatPiles = false
    /// One court-wide 3D scene instead of a renderer per pile. What lets a card leave the
    /// deck and travel — a pile in its own small frame clips at the frame's edge.
    var courtStage = false
}
