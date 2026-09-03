import SwiftUI

/// Carries the ball along its arc.
///
/// `.position(pointFor(t))` cannot do this: SwiftUI animates the resulting `CGPoint`, so
/// it interpolates straight from the start point to the end point and the curve is never
/// travelled — the shot comes out flat however high the arch is set. Making `t` the
/// animatable value instead means the curve is evaluated every frame.
///
/// `t` runs 0...2 — the first half is the flight to the rim, the second is what happens
/// after it gets there — so one value drives both phases.
struct BallFlight: GeometryEffect {
    var t: CGFloat
    let start: CGPoint
    let control: CGPoint
    let rim: CGPoint
    let after: CGPoint

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let point = position(at: t)
        return ProjectionTransform(
            CGAffineTransform(translationX: point.x - start.x, y: point.y - start.y))
    }

    private func position(at t: CGFloat) -> CGPoint {
        guard t > 1 else { return quadratic(min(max(t, 0), 1)) }
        let settle = min(t - 1, 1)
        return CGPoint(x: rim.x + (after.x - rim.x) * settle,
                       y: rim.y + (after.y - rim.y) * settle)
    }

    private func quadratic(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * start.x + 2 * u * t * control.x + t * t * rim.x,
                       y: u * u * start.y + 2 * u * t * control.y + t * t * rim.y)
    }
}
