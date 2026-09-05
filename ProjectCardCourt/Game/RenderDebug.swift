import Foundation
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
    /// It was turned off for an evening on suspicion of wedging the main thread. It was
    /// not: `drive` had been rewritten into a call to itself, and the recursion took the
    /// thread before anything else got a slot. `FlatPile` stays as the fallback.
    ///
    /// **Kept across launches**, because the thing it is for is a device that will not get
    /// as far as the bench. Turning it off in a match you cannot reach is no use; turning
    /// it off from the front screen and having it stay off is.
    var courtStage = UserDefaults.standard.object(forKey: Key.courtStage) as? Bool ?? true {
        didSet { UserDefaults.standard.set(courtStage, forKey: Key.courtStage) }
    }

    private enum Key {
        static let courtStage = "render.courtStage"
    }
}
