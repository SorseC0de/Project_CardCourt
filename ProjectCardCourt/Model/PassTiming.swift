import Foundation

/// How long a pass takes, in the three parts the engine actually waits on.
///
/// Moved out of `Theme.Pass`, which keeps the *geometry* — where the ball sits in a hand.
/// Where it sits is a drawing; how long it is in the air is a beat the game is paced by,
/// and `GameController` has no business importing SwiftUI to find one out.
enum PassTiming {
    /// How long the ball takes to cross.
    static let flight: Double = 0.26
    /// How long it stays in the receiver's hands before the sprite's own ball takes over.
    static let hold: Double = 0.08

    /// How fast the catch sheet plays — see `Theme.Figure` on rates.
    static let catchFPS: Double = 20
    /// And so how long a catch takes: sixteen cells at that rate. **This direction, not
    /// the other one.** It was written the other way round — a duration was chosen and
    /// the rate fell out of it at 17.8 a second, which is not a rate anybody draws for
    /// and holds cells for an uneven number of screen refreshes.
    static var catchSeconds: Double { Double(Sprite.catchBall.frames) / catchFPS }
}
