import RealityKit
import SwiftUI

/// A RealityKit view that draws nothing, so the first one that draws something does not
/// have to wait.
///
/// **Why this exists.** The first `RealityView` in a process brings the whole renderer up
/// with it: Metal pipelines, the shader library, and the render-graph materials the log
/// complains about by name —
/// `engine:BuiltinRenderGraphResources/AR/arInPlacePostProcessCombinedPermute13.rematerial`,
/// which it fails to find in the bundle and then loads the slow way, off the asset path.
/// On device that is seconds, and under the debugger it is worse: Metal's validation layer
/// is on, and every pipeline is compiled with it watching.
///
/// Paid at the front screen, where there is nothing to interrupt, rather than on the first
/// frame of a match. Nothing about the cost changes — it is simply spent while the player
/// is reading a menu instead of after they have asked to play.
///
/// One point square and invisible, but *in the hierarchy*: an off-screen view is never
/// asked to draw, and a renderer nobody asks for is a renderer that never starts.
struct RealityWarmup: View {
    var body: some View {
        RealityView { content in
            content.camera = .virtual
            content.add(PerspectiveCamera())
        }
        .frame(width: 1, height: 1)
        // Not `.hidden` and not zero-sized: either one takes it out of the draw and the
        // work never happens.
        .opacity(0.002)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
