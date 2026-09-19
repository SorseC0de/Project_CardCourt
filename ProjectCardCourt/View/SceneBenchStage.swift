import SwiftUI

#if DEBUG
/// **A shot scene on its own, for a bench.** No game behind it and no transition in or
/// out of it — the scene is simply there, at its first frame, until it is played. When a
/// take ends it resets to the first frame again, ready for the next.
///
/// What it replaces: the benches drove the real game and let the cutscene transition in
/// over the floor, and that transition is what made a take start late.
@MainActor
@Observable
final class SceneReplay {
    /// Bumped for every new take, so the scene is a new view with fresh state.
    private(set) var take = 0
    private(set) var playing = false
    private(set) var scene: ShotCutscene

    init(_ scene: ShotCutscene) { self.scene = scene }

    /// Stood at the start of this scene, not playing — a change of settings between takes.
    func stage(_ scene: ShotCutscene) {
        guard !playing else { return }
        self.scene = scene
        take += 1
    }

    func play(_ scene: ShotCutscene) {
        self.scene = scene
        take += 1
        playing = true
        let thisTake = take
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Pacing.cutscene + scene.drama.seconds))
            guard take == thisTake else { return }
            playing = false
            take += 1
        }
    }
}

struct SceneBenchStage: View {
    let replay: SceneReplay

    var body: some View {
        ZStack {
            Chrome.ground.ignoresSafeArea()
            ShotCutsceneView(scene: replay.scene, holdsAtStart: !replay.playing)
                .id(replay.take)
        }
    }
}
#endif
