import Foundation

/// How long a rebound takes, end to end.
///
/// The dials that tune it are `ReboundTuning` on the bench; **this is the arithmetic**,
/// and it lives here because `GameController` waits on the answer and has no business
/// importing SwiftUI to get one. Every part is `frames / rate` off `Sprite`, which is why
/// the frame table had to come across first.
enum ReboundTiming {
    static let flight: Double = 0.25
    static let vanish: Double = 0.30
    static let riseFPS: Double = 12
    static let landFPS: Double = 15
    static let hang: Double = 0.35
    static let drop: Double = 0.25

    /// The climb, which is the sheet's own length at its own rate.
    static var rise: Double { Double(Sprite.rebound.frames - 1) / riseFPS }
    static var landing: Double { Double(Sprite.land.frames) / landFPS }
    /// When his hands close on it — the top of the leap, whichever of the two takes longer.
    static var catchAt: Double { max(rise, flight) }
    /// The whole trip, which is what the engine sleeps for.
    static var whole: Double { catchAt + hang + max(drop + landing, vanish) }

    /// What the bench is showing right now, when the bench is open.
    ///
    /// **A seam, not a global.** The engine needs one number and the tuner needs to be
    /// able to move it, and the alternative — the engine reaching into an `@Observable`
    /// dial object in the view layer — is what kept the whole controller out of the
    /// headless harness. The bench installs this; nothing else ever sets it, and with it
    /// unset the baked arithmetic above is the answer.
    nonisolated(unsafe) static var live: (() -> Double)?

    /// What to wait for. The dials if somebody is turning them, the bake otherwise.
    static var run: Double { live?() ?? whole }
}
