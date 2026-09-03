import Foundation

/// A trip to the line: one or more attempts, shot one at a time.
///
/// Free throws are free. Nothing in the SHOT stack reaches them — no Clamps, no
/// Intangibles, no accumulated passing — which is what makes being fouled worth
/// something however the possession was going. Every miss is a dead ball, so a trip
/// never turns into a rebound.
struct FreeThrowTrip: Hashable, Codable {
    let shooter: Seat
    /// Who put them on the line. They hand the ball back in once the trip is over.
    /// nil when nobody did — a Foul off the deck has no offender to punish.
    let offender: Seat?
    /// The card that awarded it, named on the banner and in the log.
    let source: String
    var attempted = 0
    var made = 0
    var remaining: Int

    var total: Int { attempted + remaining }
    /// 1-based, for "1 OF 2".
    var index: Int { attempted + 1 }
}
