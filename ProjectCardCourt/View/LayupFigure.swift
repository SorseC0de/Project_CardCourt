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
    /// The rate the layup plays at — the jumper's, so a Lethal Shooter's is quicker here too.
    let fps: Double
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
        showing = .layup
        lifted = LayupStyle.rise
        for step in 0..<Sprite.layup.frames {
            cell = step
            try? await Task.sleep(for: .seconds(1 / fps))
            if Task.isCancelled { return }
        }
        try? await Task.sleep(for: .seconds(LayupStyle.hang))
        if Task.isCancelled { return }
        // Down, onto the landing a short dunk comes down on.
        lifted = 0
        showing = .landBack
        for step in 0..<Sprite.landBack.frames {
            cell = step
            try? await Task.sleep(for: .seconds(1 / DunkStyle.landFPS))
            if Task.isCancelled { return }
        }
    }
}

/// The layup's numbers.
enum LayupStyle {
    /// How far off the floor he goes on the layup, in art pixels.
    static let rise: CGFloat = 3
    /// How long the last cell is held before he comes down.
    static let hang: Double = 0.2
    /// How long the run in to the rim takes.
    static let approachSeconds: Double = 1.0
    /// The cell the ball leaves his hand on: the last of the four has nothing in it.
    static let releaseCell = 3
    /// How small he is by the time he reaches the rim, like a dunk arriving there.
    static let arrivesAt: CGFloat = 0.5
    /// Where the ball is in his hand on the cell before it goes, in art pixels from the
    /// frame's centre — measured off the sheet.
    static let hand = CGPoint(x: 8, y: -11)
    /// How far under the ring his hand is when he lets go, in points.
    static let underRim: CGFloat = 10
    /// How long the ball is up. A layup is laid in, not lofted.
    static let flightSeconds: Double = 0.35
    /// How high over the ring the ball's short arc peaks, as a share of the scene.
    static let arc: CGFloat = 0.06
    /// **Round the defenders.** The wall stands this far to the right of his line, and his
    /// run bends this far out to the left of it on the way past them.
    static let wallAside: CGFloat = 90
    static let aroundX: CGFloat = 70
}
