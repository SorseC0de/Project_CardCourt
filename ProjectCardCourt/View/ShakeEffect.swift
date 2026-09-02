import SwiftUI

/// A quick side-to-side refusal. Driven by an animatable value so the whole shake is one
/// interpolation rather than a chain of scheduled animations.
struct ShakeEffect: GeometryEffect {
    var progress: CGFloat
    var travel: CGFloat = 7
    var shakes: CGFloat = 3

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        // Damped, so it settles rather than stopping dead mid-swing.
        let decay = 1 - progress
        let offset = sin(progress * .pi * 2 * shakes) * travel * decay
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
