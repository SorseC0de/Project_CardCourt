import SwiftUI

/// **The one shot he runs in for.** Dribbling up to the rim, then the layup, then down.
///
/// Where he goes is the scene's business — it moves and shrinks him toward the ring, and
/// round the defenders — see `ShotCutsceneView`. This walks the sheets on the same clock:
/// `Player_Dribble` for the run, `Player_Layup` once he gets there, lifted off the floor
/// from its first cell, and `Player_land_back` when he comes down, like a dunk that
/// fell short.
struct LayupFigure: View {
    let seat: Seat
    /// How long the run in takes. The scene moves him over exactly this long.
    let approachSeconds: Double
    var scale: CGFloat = Theme.Figure.playerScale

    @Environment(\.ballInPlay) private var ballInPlay
    @State private var showing: Sprite = .dribble
    @State private var cell = 0
    /// Art pixels off the floor.
    @State private var lifted: CGFloat = 0

    var body: some View {
        Group {
            if showing == .dribble {
                // The run is a loop, played off the wall clock like any other.
                SpriteAnimation(sprite: .dribble, scale: scale,
                                fps: Theme.Figure.playerFPS,
                                face: PlayerLook.shared.faceOn(seat))
            } else {
                SpriteAnimation(sprite: showing, scale: scale, isPlaying: false,
                                restFrame: cell, face: PlayerLook.shared.faceOn(seat))
            }
        }
        .paletteSwap(PlayerLook.shared.kit(for: seat) + BallInPlay.sprite(for: ballInPlay))
        .offset(y: -lifted * scale)
        .task { await runIn() }
    }

    private func runIn() async {
        try? await Task.sleep(for: .seconds(approachSeconds))
        if Task.isCancelled { return }
        // Up off the floor on the first cell, and he stays up for all of them.
        let tune = LayupTuning.shared
        showing = .layup
        lifted = tune.rise
        for step in 0..<Sprite.layup.frames {
            cell = step
            try? await Task.sleep(for: .seconds(1 / tune.layupFPS))
            if Task.isCancelled { return }
        }
        try? await Task.sleep(for: .seconds(tune.hang))
        if Task.isCancelled { return }
        // Down, onto the landing a short dunk comes down on.
        lifted = -tune.landY
        showing = .landBack
        for step in 0..<Sprite.landBack.frames {
            cell = step
            try? await Task.sleep(for: .seconds(1 / DunkStyle.landFPS))
            if Task.isCancelled { return }
        }
    }
}

/// **The layup's numbers, while they are being tuned** — see `LayupBench`. Freeze the
/// printed answer into the defaults here once it lands.
@Observable
final class LayupTuning {
    static let shared = LayupTuning()

    // The run in.
    /// How big he starts, against the jumper's size where he stands.
    var startScale: CGFloat = 1
    /// How long the run in to the rim takes.
    var approachSeconds: Double = 1.0
    /// How small he is by the time he reaches the rim.
    var arrivesAt: CGFloat = 0.5
    /// **Round the defenders.** A right-handed layup comes in from the right, so the wall
    /// stands this far to the left of his line and his run bends this far out to the right
    /// of it on the way past them. Points.
    var wallAside: CGFloat = 90
    var aroundX: CGFloat = 70
    /// **When he goes behind the defenders**, as a share of the run: nought is at once,
    /// one is as he arrives.
    var behindAt: Double = 0.5

    // The layup.
    /// How far off the floor he goes from the layup's first cell, in art pixels.
    var rise: CGFloat = 3
    /// The rate the layup's four cells play at.
    var layupFPS: Double = 10
    /// How long the last cell is held before he comes down.
    var hang: Double = 0.2
    /// Where he lands, in art pixels below where he took off. Negative lands him higher.
    var landY: CGFloat = 0

    // Where he lets go.
    /// Where the ball is in his hand on the cell before it goes, in art pixels from the
    /// frame's centre.
    var handX: CGFloat = 8
    var handY: CGFloat = -11
    /// **Where his hand is when he lets go**, against the ring, in points: right of it —
    /// the layup is right-handed and goes up leftward — and under it.
    var offRim: CGFloat = 40
    var underRim: CGFloat = 10

    // The ball.
    /// How long the ball is up. A layup is laid in, not lofted.
    var flightSeconds: Double = 0.35
    /// How high over the ring the ball's short arc peaks, as a share of the scene.
    var arc: CGFloat = 0.06

    /// The cell the ball leaves his hand on: the last of the four has nothing in it.
    static let releaseCell = 3

    func reset() {
        let fresh = LayupTuning()
        startScale = fresh.startScale
        approachSeconds = fresh.approachSeconds; arrivesAt = fresh.arrivesAt
        wallAside = fresh.wallAside; aroundX = fresh.aroundX; behindAt = fresh.behindAt
        rise = fresh.rise; layupFPS = fresh.layupFPS; hang = fresh.hang; landY = fresh.landY
        handX = fresh.handX; handY = fresh.handY
        offRim = fresh.offRim; underRim = fresh.underRim
        flightSeconds = fresh.flightSeconds; arc = fresh.arc
    }

    /// The whole set as the defaults above, for pasting back in.
    var source: String {
        func g(_ value: CGFloat) -> String { String(format: "%.2f", Double(value)) }
        func t(_ value: Double) -> String { String(format: "%.2f", value) }
        return """
        var startScale: CGFloat = \(g(startScale))
        var approachSeconds: Double = \(t(approachSeconds))
        var arrivesAt: CGFloat = \(g(arrivesAt))
        var wallAside: CGFloat = \(g(wallAside))
        var aroundX: CGFloat = \(g(aroundX))
        var behindAt: Double = \(t(behindAt))
        var rise: CGFloat = \(g(rise))
        var layupFPS: Double = \(t(layupFPS))
        var hang: Double = \(t(hang))
        var landY: CGFloat = \(g(landY))
        var handX: CGFloat = \(g(handX))
        var handY: CGFloat = \(g(handY))
        var offRim: CGFloat = \(g(offRim))
        var underRim: CGFloat = \(g(underRim))
        var flightSeconds: Double = \(t(flightSeconds))
        var arc: CGFloat = \(g(arc))
        """
    }
}
