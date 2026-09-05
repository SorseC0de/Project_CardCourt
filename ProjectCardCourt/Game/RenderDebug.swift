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
    /// It is the only place a card can leave the deck and travel, and the only frame wide
    /// enough for a shuffle — a pile in its own small frame clips the moment a slab is
    /// thrown more than a couple of centimetres. It is also, on device, a `RealityView`
    /// whose first draw wedges the main thread: the view appears, `.task` runs, and then
    /// nothing else on the main actor ever gets a slot again. A game that does not start
    /// is worse than a flat pile, so **off until that is understood**, and the gear on the
    /// front screen turns it back on.
    ///
    /// **Kept across launches**, because the thing it is for is a device that will not get
    /// as far as the bench. Turning it off in a match you cannot reach is no use; turning
    /// it off from the front screen and having it stay off is.
    var courtStage = UserDefaults.standard.object(forKey: Key.courtStage) as? Bool ?? false {
        didSet { UserDefaults.standard.set(courtStage, forKey: Key.courtStage) }
    }

    private enum Key {
        static let courtStage = "render.courtStage"
    }
}
