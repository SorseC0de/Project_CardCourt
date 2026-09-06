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
/// **A card leaving a deck, and nothing more.** It starts on top of the pile, leaning the
/// way the pile leans, at the size of the pile's own top card. On the way over it curls up
/// until it is standing straight, and shrinks until it is not there. That is the whole of
/// it — no arc, no spin, no tumble. Everything else this has ever done read as a card
/// having a fit rather than as a card being dealt.
///
/// Not `@Observable`, for the same reason as `DeckStage` — see the note there.
@MainActor
final class CardDealer {

    let root = Entity()
    private var card: ModelEntity?

    /// How the throw is shaped. Metres and turns.
    /// How the throw is shaped. Metres, radians and turns.
    private enum Throw {
        /// **It leaves at the size of the slab it came off and shrinks into the bag.**
        /// Not to nothing — a scale of zero is a matrix that cannot be inverted, and
        /// RealityKit will not have it — but to near enough that it is gone by the time
        /// it arrives.
        static let leaves: Float = 1.0
        static let arrives: Float = 0.01
        /// How far it rides above the straight line, against the distance covered.
        /// A card picked up off a table, not one lobbed across the room: the hand lifts
        /// it just clear of the pile and turns it over on the way.
        static let lift: Float = 0.07
        /// Where it starts leaning: wherever the deck is leaning. It comes off the top of
        /// a pile that has already bowed toward him.
        static let bowed = DeckStage.bowAngle
        /// **The turn happens, and then the shrink.** Run together they were a card
        /// vanishing while it happened to be rotating — the face never came round,
        /// because by the time it was pointing at you there was nothing left of it to
        /// see. Picked up off a table, a card is turned over at full size and only then
        /// put away.
        static let turnsBy: Float = 0.55
        static let shrinksFrom: Float = 0.60
        /// Steps the trip is walked in. Enough to read as a curl, few enough to be free.
        static let steps = 30
    }

    /// The slab, and the picture printed on the face **away** from you.
    ///
    /// The slab's own mesh carries no texture coordinates, so what a card wears is a thin
    /// plane sitting just clear of it — the same arrangement the piles use, and it rides
    /// along because it is a child.
    ///
    /// **Underneath, not on top.** A card leaves the pile lying face down, and the curl
    /// is what turns it over: printed on the upper face it was face up on the deck and
    /// blank by the time it reached anybody, which is the whole thing backwards.
    ///
    /// The plane is single-sided and looks along +Y, so it is turned right over to be
    /// seen from below. **About X**, not Z: the card finishes at ninety degrees the other
    /// way, and turning the print about Z left it standing on its head at the end of that
    /// — the two rotations have to agree about which edge is the top.
    func build(mesh: MeshResource, material: some RealityKit.Material,
               face: Entity? = nil, back: Entity? = nil, thickness: Float = 0) {
        let card = ModelEntity(mesh: mesh, materials: [material])
        card.isEnabled = false
        // **The printed back on top, the blank front underneath.** A card leaves the pile
        // the way it sat on it — back up — and the curl is what turns it over. Until then
        // what you are watching is the back of a card, not a slab of flat colour.
        if let back {
            back.position = SIMD3(0, thickness / 2 + 0.00005, 0)
            card.addChild(back)
        }
        if let face {
            face.position = SIMD3(0, -(thickness / 2 + 0.00005), 0)
            face.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
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

        // Turned to face him, the way the pile it came off is. One yaw, held for the
        // whole trip — the card does not steer.
        let yaw = simd_quatf(angle: atan2(end.x - start.x, end.z - start.z), axis: [0, 1, 0])
        // Where it finishes. On a dial — see `DealTuning` — because which way a card
        // turns over is the one thing here nobody works out from first principles; the
        // near end is not a choice at all. Read once per throw, on the actor that owns it.
        let upright = Float(DealTuning.shared.endAngle) * .pi / 180
        func lean(_ t: Float) -> simd_quatf {
            yaw * simd_quatf(angle: Throw.bowed + (upright - Throw.bowed) * t,
                             axis: [1, 0, 0])
        }

        // **Whatever was still running, stops.** A flight cancelled part way leaves a
        // `move` in flight on this entity, and assigning a transform under it does not
        // take it off — the two then interpolate against each other, which is a card
        // that grows on its way over and now and then flashes up enormous. The pile had
        // the same fault and the same cure.
        card.stopAllAnimations()

        let lift = distance(start, end) * Throw.lift
        card.isEnabled = true
        card.transform = Transform(scale: SIMD3(repeating: Throw.leaves),
                                   rotation: lean(0), translation: start)

        // Walked rather than tweened: `move(to:)` slerps between two rotations, and a
        // quarter turn slerped in one go swings the card out of the line it is meant to
        // be travelling along.
        // **Walked against the clock, not against a counter.** `Task.sleep` can only ever
        // be late, and thirty of them compound — a trip walked by step index overruns the
        // time it was given and gets cancelled by whatever comes next, which is a card
        // that vanishes in the middle of its own animation. Reading `t` off the clock
        // costs a dropped step under load and finishes on time regardless.
        let step = seconds / Double(Throw.steps)
        let began = Date()
        var t: Float = 0
        while t < 1 {
            if Task.isCancelled { break }
            t = min(1, Float(Date().timeIntervalSince(began) / seconds))
            var next = Transform()
            next.translation = start + (end - start) * t
                + SIMD3(0, lift * sin(t * .pi), 0)
            next.rotation = lean(min(1, t / Throw.turnsBy))
            let gone = max(0, (t - Throw.shrinksFrom) / (1 - Throw.shrinksFrom))
            next.scale = SIMD3(repeating: Throw.leaves
                               + (Throw.arrives - Throw.leaves) * gone)
            card.move(to: next, relativeTo: root, duration: step, timingFunction: .linear)
            if t >= 1 { break }
            try? await Task.sleep(for: .seconds(step))
        }
        card.stopAllAnimations()
        card.isEnabled = false
    }
}
