import RealityKit
import SwiftUI

/// The deck as a performer.
///
/// The pile is not a prop that sits there — it is meant to read as something enchanted,
/// so it has a small repertoire it can be asked for by name. A caller says
/// `stage.perform(.shuffle)`; how a shuffle is danced is this file's business and nobody
/// else's.
///
/// Every slab remembers where it belongs, so any routine can be interrupted and the deck
/// will still find its way back to a square stack.
/// Deliberately **not** `@Observable`. Its state is written from inside a `RealityView`
/// update — `rehome` runs every time the pile's height is set — and writing an observed
/// property during an update invalidates the view, which runs the update again, which
/// writes again. That loop pegs the main thread and freezes the whole app, which is what
/// "the deck animations freeze the game" was. Nothing here needs observing: the entities
/// are the state, and SwiftUI only has to keep the object alive.
@MainActor
final class DeckStage {

    /// Something the deck can be asked to do.
    enum Routine: Equatable {
        case rest
        /// Floats up, breaks apart, gathers, and does it again before settling.
        case shuffle
        /// Drops hard enough to knock itself out of true, then tidies up.
        case landing
        /// A shuffle that finishes by landing — what a fresh deal opens with.
        case deal
    }

    /// The whole pile, moved as one when the deck travels.
    let pile = Entity()

    private var slabs: [ModelEntity] = []
    /// Where each slab sits when the deck is square. Kept so a routine can always undo
    /// itself, whatever it did.
    private var home: [Transform] = []
    private var performing = false
    /// The shape the slabs were last built with, so a mesh is only generated when one of
    /// those numbers moves.
    private var builtFrom: SIMD4<Float>?
    private var builtMesh: MeshResource?
    /// The stack height the slabs were last homed to.
    private var homedTo: Float?
    /// True while the deck is under its own power. The court stops placing it during a
    /// routine, or it would be snapped home between steps.
    private(set) var travelling = false

    // MARK: - Setup

    func adopt(_ slab: ModelEntity, at index: Int, thickness: Float) {
        slab.position = SIMD3(0, Float(index) * thickness, 0)
        slabs.append(slab)
        home.append(slab.transform)
        pile.addChild(slab)
    }

    /// Shows the bottom `count` slabs and re-homes them. One call, because a pile's
    /// height and where its slabs belong are the same fact.
    func show(_ count: Int, of total: Int, thickness: Float) {
        for (index, slab) in slabs.enumerated() {
            slab.isEnabled = index < count
        }
        rehome(thickness: thickness)
    }

    /// Hands every slab a mesh, building one only when the shape has moved.
    ///
    /// This used to generate a fresh mesh on **every** `RealityView` update — which is
    /// every SwiftUI state change in the whole app, twice over for the two piles. Building
    /// a couple of hundred triangles and handing them to the GPU at that rate is what had
    /// the fans running; the slider that needed it moves perhaps a hundred times in a
    /// session, and nothing else ever changes it at all.
    func wear(radius: Float, thickness: Float, width: Float, depth: Float,
              make: (Float, Float, Float, Float) -> MeshResource) {
        let key = SIMD4<Float>(radius, thickness, width, depth)
        if builtFrom != key || builtMesh == nil {
            builtFrom = key
            builtMesh = make(radius, thickness, width, depth)
        }
        guard let mesh = builtMesh else { return }
        for slab in slabs { slab.model?.mesh = mesh }
    }

    /// Re-homes every slab after the deck's height changes, so a routine that runs later
    /// returns to the stack as it is now rather than as it was when it was built.
    func rehome(thickness: Float) {
        // Where a slab belongs depends only on the stack's thickness, so this is a
        // once-per-pile job rather than a once-per-update one.
        guard homedTo != thickness else { return }
        homedTo = thickness
        for (index, slab) in slabs.enumerated() {
            var rest = Transform()
            rest.translation = SIMD3(0, Float(index) * thickness, 0)
            home[index] = rest
            guard !performing else { continue }
            slab.transform = rest
        }
    }

    /// Moves the whole pile somewhere, in the scene's own space.
    func travel(to point: SIMD3<Float>, seconds: TimeInterval,
                curve: AnimationTimingFunction = .easeInOut) async {
        travelling = true
        var arrived = pile.transform
        arrived.translation = point
        pile.move(to: arrived, relativeTo: pile.parent,
                  duration: seconds, timingFunction: curve)
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Hands the deck back to the court.
    func settle() { travelling = false }

    /// Puts it somewhere with no travel at all, for starting a routine off screen.
    func place(at point: SIMD3<Float>) {
        travelling = true
        pile.transform.translation = point
    }

    // MARK: - The repertoire

    func perform(_ routine: Routine) async {
        guard !performing, routine != .rest else { return }
        performing = true
        defer { performing = false }

        switch routine {
        case .rest:     break
        case .shuffle:  await shuffle()
        case .landing:  await land()
        case .deal:     await shuffle(); await land()
        }
    }

    /// Up, apart, together — three times, tightening each round like something making up
    /// its mind. The staggering is what stops it reading as one object scaling.
    private func shuffle(rounds: Int = 3) async {
        await lift(to: Timing.hover, seconds: 0.42, curve: .easeOut)

        for round in 0..<rounds {
            // Later rounds throw the cards less far, so the deck visibly settles down
            // rather than stopping because the loop ran out.
            let spread = Timing.spread * (1 - Float(round) / Float(rounds) * 0.55)
            scatter(by: spread, turn: Timing.turn, seconds: Timing.out)
            try? await Task.sleep(for: .seconds(Timing.out + Timing.stagger))
            gather(seconds: Timing.back)
            try? await Task.sleep(for: .seconds(Timing.back))
        }
    }

    /// The hard landing: down fast, everything knocked out of line, then squared away.
    private func land() async {
        await lift(to: Timing.hover, seconds: 0.28, curve: .easeInOut)
        await lift(to: 0, seconds: 0.16, curve: .easeIn)

        // Knocked loose by the impact — small, and never off the vertical, since the
        // stack is still a stack.
        scatter(by: Timing.jolt, turn: Timing.joltTurn, seconds: 0.10)
        try? await Task.sleep(for: .seconds(0.16))
        gather(seconds: 0.5)
        try? await Task.sleep(for: .seconds(0.5))
    }

    // MARK: - Moves

    private func lift(to height: Float, seconds: TimeInterval,
                      curve: AnimationTimingFunction) async {
        var raised = pile.transform
        raised.translation.y = height
        pile.move(to: raised, relativeTo: pile.parent,
                  duration: seconds, timingFunction: curve)
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Throws every slab off its mark, each a little later than the one below it.
    private func scatter(by spread: Float, turn: Float, seconds: TimeInterval) {
        for (index, slab) in slabs.enumerated() where slab.isEnabled {
            var thrown = home[index]
            thrown.translation += SIMD3(Float.random(in: -spread...spread),
                                        Float.random(in: 0...spread * 0.35),
                                        Float.random(in: -spread...spread))
            // Turned about the vertical only. A card tipping onto its edge reads as a
            // dropped deck rather than a shuffled one.
            thrown.rotation = simd_quatf(angle: Float.random(in: -turn...turn),
                                         axis: [0, 1, 0])
            slab.move(to: thrown, relativeTo: pile,
                      duration: seconds, timingFunction: .easeOut)
        }
    }

    /// Everything back to square, bottom first — the stack builds rather than snapping.
    private func gather(seconds: TimeInterval) {
        for (index, slab) in slabs.enumerated() where slab.isEnabled {
            slab.move(to: home[index], relativeTo: pile,
                      duration: seconds, timingFunction: .easeInOut)
        }
    }

    /// Everything in metres and seconds. Small numbers: the deck is 9cm long.
    private enum Timing {
        static let hover: Float = 0.045
        static let spread: Float = 0.022
        static let turn: Float = 0.5
        static let out: TimeInterval = 0.26
        static let back: TimeInterval = 0.30
        static let stagger: TimeInterval = 0.05
        static let jolt: Float = 0.006
        static let joltTurn: Float = 0.14
    }
}
