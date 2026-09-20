import SwiftUI

/// One cell of the dust sheet, at the moment it is due.
///
/// Everything that raises dust knows *when* it happened, so the cell is arithmetic off
/// that rather than a frame index somebody has to keep — which is what lets a puff be
/// laid over a looping sprite without the two sharing a clock.
private struct SmokeCell: View {
    /// How long ago the dust was raised. Nil, negative, or past the end draws nothing.
    var since: TimeInterval?
    var scale: CGFloat
    /// Where it sits, in art pixels from the middle of the sprite's foot line — right
    /// and up positive.
    var at: CGPoint
    /// The sheet's rate here, and how faint it has gone by its last cell. **Per puff, not
    /// per sheet**: a body arriving and a ball glancing off share a drawing and nothing
    /// else. See `SmokeTuning`.
    var fps: Double
    var fade: Double

    /// Half the frame, less the empty rows the sheets leave under a player's feet: how
    /// far a bottom-aligned puff has to come down for its middle to land on the floor.
    private var footLift: CGFloat {
        Sprite.smoke.frameSize / 2 - Sprite.smoke.frameSize * Theme.Figure.spriteFootPadding
    }

    var body: some View {
        if let since, since >= 0, since < Double(Sprite.smoke.frames) / fps {
            let cell = min(Sprite.smoke.frames - 1, Int(since * fps))
            // Thinning as it spreads, so what is left when the drawing runs out is
            // already faint. The sheet's last cell is empty; this reaches its floor on it.
            let thinned = 1 - (1 - fade)
                * Double(cell) / Double(max(1, Sprite.smoke.frames - 1))
            SpriteAnimation(sprite: .smoke, scale: scale, isPlaying: false, restFrame: cell)
                .opacity(thinned)
                .offset(x: at.x * scale, y: (footLift - at.y) * scale)
                .allowsHitTesting(false)
        }
    }
}

/// A puff raised at a known moment, played once and gone.
struct SmokePuff: View {
    var startedAt: Date?
    var scale: CGFloat = Theme.Figure.playerScale
    /// Overrides where it sits. Nil takes the dial's, which is what the court wants.
    var at: CGPoint?

    @State private var dust = SmokeTuning.shared
    /// **The puff that has played out.** The clock stopped only while nothing had ever
    /// raised dust, so after a man's first landing it ticked for the rest of the game,
    /// drawing nothing.
    @State private var settled: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / dust.landFPS,
                                paused: startedAt == nil || settled == startedAt)) { timeline in
            // **Nothing once it has settled.** Pausing a timeline freezes its date at the
            // last tick, and that tick is *inside* the sheet — so the puff held its final
            // cell for the rest of the game rather than clearing.
            SmokeCell(since: settled == startedAt ? nil
                      : startedAt.map { timeline.date.timeIntervalSince($0) },
                      scale: scale * dust.landScale,
                      at: at ?? CGPoint(x: dust.landX, y: dust.landY),
                      fps: dust.landFPS, fade: dust.landFade)
        }
        .task(id: startedAt) {
            guard let startedAt else { return }
            let left = Double(Sprite.smoke.frames) / dust.landFPS
                - Date().timeIntervalSince(startedAt)
            if left > 0 { try? await Task.sleep(for: .seconds(left)) }
            if !Task.isCancelled { settled = startedAt }
        }
    }
}

/// The dust a dribble raises, on the two cells the ball is on the floor for.
///
/// **Off the same wall clock the sprite is drawn from**, rather than a timer of its own:
/// the bounce is a cell of a looping sheet nobody starts or stops, so a puff on its own
/// clock drifts out of step with it within seconds. Asked the same way
/// `SpriteAnimation.cell(of:at:fps:phase:)` asks it, and answered the same.
///
/// TODO: Recolour the bounce smoke to the Variaball in play, the way the pixel ball is —
/// see `BallInPlay.sprite(for:)`. Project Stars' smoke sheets slot in once they are turned
/// from horizontal strips to vertical ones.
struct DribbleDust: View {
    var scale: CGFloat = Theme.Figure.playerScale
    /// The figure's own offset into the sprite clock, so this lands on *his* bounce.
    var phase: TimeInterval

    @State private var dust = SmokeTuning.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / dust.ballFPS)) { timeline in
            SmokeCell(since: sinceTheBounce(at: timeline.date),
                      scale: scale * dust.ballScale,
                      at: CGPoint(x: dust.ballX, y: dust.ballY),
                      fps: dust.ballFPS, fade: dust.ballFade)
        }
    }

    /// How long ago the ball last met the floor.
    private func sinceTheBounce(at date: Date) -> TimeInterval {
        let fps = Theme.Figure.playerFPS
        let cycle = Double(Sprite.dribble.frames) / fps
        let strikes = dust.strikes.map { Double($0) / fps }
        let within = (date.timeIntervalSinceReferenceDate + phase)
            .truncatingRemainder(dividingBy: cycle)
        // The last strike at or before now — or the previous cycle's last, when the
        // sheet has come round but not yet reached the first of them.
        let past = strikes.last { $0 <= within } ?? ((strikes.last ?? 0) - cycle)
        return within - past
    }
}
