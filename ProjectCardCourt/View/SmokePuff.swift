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

    /// Half the frame, less the empty rows the sheets leave under a player's feet: how
    /// far a bottom-aligned puff has to come down for its middle to land on the floor.
    private var footLift: CGFloat {
        Sprite.smoke.frameSize / 2 - Sprite.smoke.frameSize * Theme.Figure.spriteFootPadding
    }

    var body: some View {
        if let since, since >= 0,
           since < Double(Sprite.smoke.frames) / Theme.Figure.smokeFPS {
            let cell = min(Sprite.smoke.frames - 1,
                           Int(since * Theme.Figure.smokeFPS))
            // Thinning as it spreads, so what is left when the drawing runs out is
            // already faint. The sheet's last cell is empty; this reaches its floor on it.
            let fade = 1 - (1 - Theme.Figure.smokeFade)
                * Double(cell) / Double(max(1, Sprite.smoke.frames - 1))
            SpriteAnimation(sprite: .smoke, scale: scale, isPlaying: false, restFrame: cell)
                .opacity(fade)
                .offset(x: at.x * scale, y: (footLift - at.y) * scale)
                .allowsHitTesting(false)
        }
    }
}

/// A puff raised at a known moment, played once and gone.
struct SmokePuff: View {
    var startedAt: Date?
    var scale: CGFloat = Theme.Figure.playerScale
    var at: CGPoint = Theme.Figure.landingDust

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / Theme.Figure.smokeFPS,
                                paused: startedAt == nil)) { timeline in
            SmokeCell(since: startedAt.map { timeline.date.timeIntervalSince($0) },
                      scale: scale, at: at)
        }
    }
}

/// The dust a dribble raises, on the two cells the ball is on the floor for.
///
/// **Off the same wall clock the sprite is drawn from**, rather than a timer of its own:
/// the bounce is a cell of a looping sheet nobody starts or stops, so a puff on its own
/// clock drifts out of step with it within seconds. Asked the same way
/// `SpriteAnimation.cell(of:at:fps:phase:)` asks it, and answered the same.
struct DribbleDust: View {
    var scale: CGFloat = Theme.Figure.playerScale
    /// The figure's own offset into the sprite clock, so this lands on *his* bounce.
    var phase: TimeInterval

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / Theme.Figure.smokeFPS)) { timeline in
            SmokeCell(since: sinceTheBounce(at: timeline.date),
                      scale: scale * Theme.Figure.dribbleDustScale,
                      at: Theme.Figure.dribbleDust)
        }
    }

    /// How long ago the ball last met the floor.
    private func sinceTheBounce(at date: Date) -> TimeInterval {
        let fps = Theme.Figure.playerFPS
        let cycle = Double(Sprite.dribble.frames) / fps
        let strikes = Theme.Figure.dribbleStrikes.map { Double($0) / fps }
        let within = (date.timeIntervalSinceReferenceDate + phase)
            .truncatingRemainder(dividingBy: cycle)
        // The last strike at or before now — or the previous cycle's last, when the
        // sheet has come round but not yet reached the first of them.
        let past = strikes.last { $0 <= within } ?? ((strikes.last ?? 0) - cycle)
        return within - past
    }
}
