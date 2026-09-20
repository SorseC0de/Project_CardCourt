import Foundation
import Observation

/// How long a pass takes, in the three parts the engine actually waits on.
///
/// Moved out of `Theme.Pass`, which keeps the *geometry* — where the ball sits in a hand.
/// Where it sits is a drawing; how long it is in the air is a beat the game is paced by,
/// and `GameController` has no business importing SwiftUI to find one out.
/// **The three numbers a pass is paced by, while they are being matched to the sprite.**
///
/// Live, so a slider moves the next throw — see the bench's `pass` door. Freeze them into
/// `PassTiming` once they land.
@Observable
final class PassTuning: @unchecked Sendable {
    static let shared = PassTuning()

    /// How long the ball is in the air.
    var flight: Double = 0.26
    /// How fast the throw sheet plays. Its first cell is him still holding the ball, so
    /// this also sets how long the ball waits in his hands before it leaves.
    var throwRate: Double = 15
    /// How fast the catch sheet plays, and so how long a catch takes.
    var catchRate: Double = 20
}

enum PassTiming {
    /// How long the ball takes to cross.
    /// **Gone the instant it lands**: the catch sheet has the ball in his hands from its
    /// first cell. It used to sit there a further 0.08s, two balls in one pair of hands.
    static var flight: Double { PassTuning.shared.flight * tempo }

    /// How much slower than normal the ball is flying. One, except during a lesson's
    /// slow-motion pass — see `GameController.setLessonSlowMotion(_:)`.
    nonisolated(unsafe) static var tempo: Double = 1
    static let slowMotion: Double = 4

    /// How fast the throw sheet plays, slowed with the ball.
    static var throwFPS: Double { PassTuning.shared.throwRate / tempo }
    /// The throw sheet's first cell, where he still has it. The ball leaves after this.
    static var windup: Double { 1 / throwFPS }
    /// One pass of the throw sheet.
    static var throwSeconds: Double { Double(Sprite.passRight.frames) / throwFPS }

    /// How fast the catch sheet plays — see `Theme.Figure` on rates.
    static var catchFPS: Double { PassTuning.shared.catchRate }
    /// And so how long a catch takes: sixteen cells at that rate. **This direction, not
    /// the other one.** It was written the other way round — a duration was chosen and
    /// the rate fell out of it at 17.8 a second, which is not a rate anybody draws for
    /// and holds cells for an uneven number of screen refreshes.
    static var catchSeconds: Double { Double(Sprite.catchBall.frames) / catchFPS }
}
