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
/// **A card leaving a deck, and nothing more.** It starts on top of the pile at the size
/// of the pile's own top card, rises a little on the way over, grows as it comes towards
/// you, and pitches from lying flat to facing you. It does not spin, tumble or bow off the
/// line — that was a card being thrown by somebody showing off, and what it read as was a
/// card having a fit.
///
/// Not `@Observable`, for the same reason as `DeckStage` — see the note there.
@MainActor
final class CardDealer {

    let root = Entity()
    private var card: ModelEntity?

    /// How the throw is shaped. Metres and turns.
    private enum Throw {
        /// How high the card rides at the top of its arc, against the distance covered.
        /// Barely: a card sliding off a pile leaves the table, it does not lob.
        static let lift: Float = 0.05
        /// How big it is leaving the pile and how big it is arriving. **The same, and the
        /// same as the slab it came off.** It is a card the whole way over; the only
        /// thing that changes on the trip is which way it faces.
        static let leaves: Float = 1.0
        static let arrives: Float = 1.0
        /// How far it turns out of the floor's plane on the way, in turns. The pile lies
        /// flat and the camera looks down at it from thirty-four degrees, so this is what
        /// takes the card the rest of the way to facing you.
        static let pitch: Float = (90 - 34) / 360
        /// Steps the arc is walked in. Enough to read as a curve, few enough to be free.
        static let steps = 30
    }

    /// The slab, and the picture printed on its top face.
    ///
    /// The slab's own mesh carries no texture coordinates, so what a card wears is a thin
    /// plane sitting just clear of it — the same arrangement the piles use, and it rides
    /// along because it is a child.
    func build(mesh: MeshResource, material: some RealityKit.Material,
               face: Entity? = nil, thickness: Float = 0) {
        let card = ModelEntity(mesh: mesh, materials: [material])
        card.isEnabled = false
        if let face {
            face.position = SIMD3(0, thickness / 2 + 0.00005, 0)
            card.addChild(face)
        }
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
        // **Nothing here may be divided or normalised through zero.** A throw whose two
        // ends are the same point — one built from a view that has not been laid out —
        // makes a NaN, and one NaN in a transform is an entity RealityKit refuses to
        // write: it keeps what it had, and the pile stretches and shudders.
        guard start.isFinite, end.isFinite, distance(start, end) > .ulpOfOne else { return }

        let lift = distance(start, end) * Throw.lift
        card.isEnabled = true
        card.transform = Transform(scale: SIMD3(repeating: Throw.leaves),
                                   rotation: .init(angle: 0, axis: [1, 0, 0]),
                                   translation: start)

        // Walked rather than tweened: `move(to:)` interpolates between two transforms in
        // a straight line, which is the one shape a thrown card never travels in.
        let step = seconds / Double(Throw.steps)
        for i in 1...Throw.steps {
            let t = Float(i) / Float(Throw.steps)

            var next = Transform()
            next.translation = start + (end - start) * t + SIMD3(0, lift * sin(t * .pi), 0)
            next.rotation = simd_quatf(angle: -Throw.pitch * 2 * .pi * t, axis: [1, 0, 0])
            next.scale = SIMD3(repeating: Throw.leaves
                               + (Throw.arrives - Throw.leaves) * t)

            card.move(to: next, relativeTo: root, duration: step, timingFunction: .linear)
            try? await Task.sleep(for: .seconds(step))
            if Task.isCancelled { break }
        }
        card.isEnabled = false
    }
}
