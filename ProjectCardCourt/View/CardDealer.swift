import RealityKit
import SwiftUI
import Foundation

extension SIMD3 where Scalar == Float {
    /// Every component a real number. A point built from a view that has not been laid
    /// out yet is not, and it poisons whatever it is written into.
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

/// One card at a time, thrown across the court.
///
/// A dealt card is not a straight line and not the same line twice: it lifts, banks, and
/// turns over on its way, and every throw picks its own arc. That variance is most of what
/// separates a deck dealing from a rectangle sliding.
/// Not `@Observable`, for the same reason as `DeckStage` — see the note there.
@MainActor
final class CardDealer {

    let root = Entity()
    private var card: ModelEntity?

    /// How the throw is shaped. Metres and turns.
    private enum Throw {
        /// How high the card rides at the top of its arc, against the distance covered.
        static let lift: ClosedRange<Float> = 0.18...0.34
        /// How far it bows off the straight line between the two points.
        static let bow: ClosedRange<Float> = -0.22...0.22
        /// Turns about its own face on the way over.
        static let spin: ClosedRange<Float> = 0.75...1.6
        /// And how far it tips out of flat while it travels.
        static let tumble: ClosedRange<Float> = 0.15...0.45
        /// How big it is leaving the deck and how big it is arriving, against its own
        /// size. **It grows on the way over**: a card coming to you is a card coming
        /// *towards* you, and a slab that crosses the floor at one size reads as a chip
        /// sliding along it.
        static let leaves: Float = 0.70
        static let arrives: Float = 1.45
        /// Steps the arc is walked in. Enough to read as a curve, few enough to be free.
        static let steps = 36
    }

    func build(mesh: MeshResource, material: some RealityKit.Material) {
        let card = ModelEntity(mesh: mesh, materials: [material])
        card.isEnabled = false
        root.addChild(card)
        self.card = card
    }

    /// A thrown card wears its type's colour. That is all a slab ever needs to be — the
    /// printed card only appears once the flip is past edge-on, where `CardFlip` takes
    /// over, so there is nothing here worth texturing.
    func wear(_ type: CardType) {
        card?.model?.materials = [UnlitMaterial(color: UIColor(CardPalette.body(for: type)))]
    }

    /// Sends the card, and returns when it has landed.
    func fly(from start: SIMD3<Float>, to end: SIMD3<Float>,
             seconds: TimeInterval) async {
        guard let card else { return }

        // **Nothing here may be normalised through zero.** `normalize` of a zero vector is
        // NaN, and one NaN in a transform is `RETransformComponentSetLocalSRT contains
        // NaN` — after which the entity's scale and rotation are rubbish and the pile
        // stretches and shudders rather than simply not moving.
        guard start.isFinite, end.isFinite, distance(start, end) > .ulpOfOne else { return }

        let span = distance(start, end)
        let lift = span * Float.random(in: Throw.lift)
        let bow = span * Float.random(in: Throw.bow)
        let spin = Float.random(in: Throw.spin) * 2 * .pi
        let tumble = Float.random(in: Throw.tumble) * 2 * .pi
        // Sideways from the line of travel, so the bow is always across it.
        let across = normalize(cross(normalize(end - start), SIMD3<Float>(0, 1, 0)))

        card.isEnabled = true
        card.transform = Transform(scale: SIMD3(repeating: Throw.leaves),
                                   rotation: .init(angle: 0, axis: [0, 1, 0]),
                                   translation: start)

        // Walked rather than tweened: `move(to:)` interpolates between two transforms in
        // a straight line, which is the one shape a thrown card never travels in.
        let step = seconds / Double(Throw.steps)
        for i in 1...Throw.steps {
            let t = Float(i) / Float(Throw.steps)
            let arc = sin(t * .pi)

            var next = Transform()
            next.translation = start + (end - start) * t
                + SIMD3(0, lift * arc, 0)
                + across * (bow * arc)
            next.rotation = simd_quatf(angle: spin * t, axis: [0, 1, 0])
                * simd_quatf(angle: tumble * arc, axis: [1, 0, 0])
            // Eased rather than linear, so most of the growth happens over the second
            // half — which is where the eye reads it as approaching rather than inflating.
            let grown = Throw.leaves + (Throw.arrives - Throw.leaves) * (t * t)
            next.scale = SIMD3(repeating: grown)

            card.move(to: next, relativeTo: root, duration: step, timingFunction: .linear)
            try? await Task.sleep(for: .seconds(step))
            if Task.isCancelled { break }
        }
        card.isEnabled = false
    }
}
