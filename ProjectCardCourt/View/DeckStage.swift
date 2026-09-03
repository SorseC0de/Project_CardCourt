import RealityKit
import SwiftUI

/// The deck's idle float, as a pure function of the clock.
///
/// The pile and the shadow under it are drawn by two unrelated renderers — RealityKit and
/// SwiftUI — and the only thing that can keep a shadow underneath a floating object across
/// that gap is both of them asking the same clock where it is.
///
/// Everything here is a share of the court's own width, so the pile can turn it into the
/// stage's metres and the shadow into screen points, and neither needs a scale the other
/// does not have.
enum DeckDrift {
    /// Tight. About a fiftieth of the court, which is a fifth of a card.
    static let radius: CGFloat = 0.02
    /// How high it floats, and how much of that it gives back at the bottom of a breath.
    static let lift: CGFloat = 0.05
    static let bob: CGFloat = 0.02
    static let seconds: TimeInterval = 4

    /// Where the deck is, as an offset from where the court put it.
    static func offset(at date: Date) -> SIMD3<Float> {
        let turn = angle(at: date)
        // Counter-clockwise as the camera sees it: out to the right first, then upcourt,
        // which is negative z.
        return SIMD3(Float(radius) * cos(turn),
                     Float(lift) + Float(bob) * sin(turn),
                     -Float(radius) * sin(turn))
    }

    /// How high it is riding, 0 at the bottom of the breath and 1 at the top. The shadow
    /// reads this to know how far away the floor is.
    static func rise(at date: Date) -> CGFloat {
        CGFloat((sin(angle(at: date)) + 1) / 2)
    }

    private static func angle(at date: Date) -> Float {
        Float(date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: seconds) / seconds) * 2 * .pi
    }
}

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
    /// The stack height the slabs were last homed to.
    private var homedTo: Float?
    /// A printed back for every slab, parented to it so it travels with it.
    private var faces: [Entity] = []
    /// How many slabs the pile is currently showing.
    private var shown = 0
    /// True while the deck is under its own power. The court stops placing it during a
    /// routine, or it would be snapped home between steps.
    private(set) var travelling = false

    /// Where the court says the pile belongs. The idle orbits this rather than replacing
    /// it, so moving the deck on the bench still moves it while it is floating.
    var ground: SIMD3<Float> = .zero

    // MARK: - Setup

    func adopt(_ slab: ModelEntity, face: Entity, at index: Int, thickness: Float) {
        slab.position = SIMD3(0, Float(index) * thickness, 0)
        // Just clear of its own slab's top, and a child of it — so a thrown slab carries
        // its card with it rather than leaving it behind on the stack.
        face.position = SIMD3(0, thickness / 2 + 0.00005, 0)
        face.isEnabled = false
        slab.addChild(face)

        slabs.append(slab)
        faces.append(face)
        home.append(slab.transform)
        pile.addChild(slab)
    }

    /// Who is wearing a card back.
    ///
    /// At rest only the top of the pile is a card — everything under it is an edge, which
    /// is what a stack looks like. The moment the deck comes apart they all are, because
    /// a shuffle made of coloured slabs reads as blocks rather than cards.
    private func dressFaces() {
        for (index, face) in faces.enumerated() {
            face.isEnabled = performing ? index < shown : index == shown - 1
        }
    }

    /// Shows the bottom `count` slabs and re-homes them. One call, because a pile's
    /// height and where its slabs belong are the same fact.
    func show(_ count: Int, of total: Int, thickness: Float) {
        shown = count
        for (index, slab) in slabs.enumerated() {
            slab.isEnabled = index < count
        }
        dressFaces()
        rehome(thickness: thickness)
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
    ///
    /// It banks first and then goes, the way a carpet leans into a move rather than
    /// arriving in a lean. A slab sliding across the floor square-on reads as a puck being
    /// shoved; turning to face where it is going and tipping into the run is most of what
    /// makes it read as flying under its own power.
    func travel(to point: SIMD3<Float>, seconds: TimeInterval,
                curve: AnimationTimingFunction = .easeInOut) async {
        travelling = true
        let away = point - pile.position
        // Leans harder the faster it is going, up to a limit. A short hop should not tip
        // as far as a run across the court.
        let lean = Timing.lean
            * min(1, length(away) / Float(seconds) / Timing.leanSpeed)
        var banked = pile.transform
        banked.rotation = simd_quatf(angle: atan2(away.x, away.z), axis: [0, 1, 0])
            * simd_quatf(angle: lean, axis: [1, 0, 0])
        pile.move(to: banked, relativeTo: pile.parent,
                  duration: Timing.bank, timingFunction: .easeOut)
        try? await Task.sleep(for: .seconds(Timing.bank))

        var arrived = banked
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

    /// Floats off the floor and drifts counter-clockwise in a tight circle, for as long
    /// as it is left alone.
    ///
    /// The deck is meant to read as an enchanted thing rather than a prop, and a prop is
    /// exactly what it reads as the moment it stops moving. Walked in short straight legs
    /// because RealityKit tweens a line between two transforms — a circle has to be
    /// stepped around.
    func idle(across width: Float) async {
        let leg = DeckDrift.seconds / 24
        var beat = 0
        while !Task.isCancelled {
            // A routine outranks the idle, and the drift is read off the wall clock, so
            // the deck rejoins the circle where it would have been rather than where it
            // left it.
            if !performing && !travelling {
                var drifted = pile.transform
                // Aimed a leg ahead, since that is where it will be when it arrives —
                // otherwise the pile runs one leg behind its own shadow.
                drifted.translation = ground
                    + DeckDrift.offset(at: Date().addingTimeInterval(leg)) * width
                pile.move(to: drifted, relativeTo: pile.parent,
                          duration: leg, timingFunction: .linear)
                if beat.isMultiple(of: 6) { jostle() }
            }
            try? await Task.sleep(for: .seconds(leg))
            beat += 1
        }
    }

    /// A run of slabs shifts off the stack and slides back.
    ///
    /// A chunk rather than a card, and one shove for the whole chunk: cards in a handled
    /// deck move in blocks. Shifting them individually reads as static rather than as a
    /// deck that is not quite square.
    private func jostle() {
        guard shown > 3 else { return }
        let start = Int.random(in: 0..<(shown - 2))
        let length = Int.random(in: 2...min(Timing.chunk, shown - start))
        let shove = SIMD3<Float>(Float.random(in: -Timing.nudge...Timing.nudge), 0,
                                 Float.random(in: -Timing.nudge...Timing.nudge))
        let turn = Float.random(in: -Timing.nudgeTurn...Timing.nudgeTurn)
        let chunk = Array(start..<(start + length))

        for index in chunk {
            var nudged = home[index]
            nudged.translation += shove
            nudged.rotation = simd_quatf(angle: turn, axis: [0, 1, 0])
            slabs[index].move(to: nudged, relativeTo: pile,
                              duration: 0.30, timingFunction: .easeOut)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.4))
            // A routine may have taken the deck over in the meantime, and it owns where
            // every slab is while it runs.
            guard !performing else { return }
            for index in chunk where index < slabs.count {
                slabs[index].move(to: home[index], relativeTo: pile,
                                  duration: 0.5, timingFunction: .easeInOut)
            }
        }
    }

    /// Turns to face a point on the floor and dips toward it.
    ///
    /// A deck that slides over and deals without ever facing anybody reads as a machine
    /// on rails. The bow is the whole difference between an object being moved and one
    /// paying attention to who it is dealing to.
    func bow(toward point: SIMD3<Float>, seconds: TimeInterval = 0.24) async {
        travelling = true
        let away = point - pile.position
        // Yaw to face them, then tip about the axis it is now facing along — the order
        // matters, since the second rotation is taken in the frame the first leaves.
        var turned = pile.transform
        turned.rotation = simd_quatf(angle: atan2(away.x, away.z), axis: [0, 1, 0])
            * simd_quatf(angle: Timing.bow, axis: [1, 0, 0])
        pile.move(to: turned, relativeTo: pile.parent,
                  duration: seconds, timingFunction: .easeOut)
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Straightens up. Stays under its own power — the caller says when it is done.
    func straighten(seconds: TimeInterval = 0.24) async {
        travelling = true
        var square = pile.transform
        square.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
        pile.move(to: square, relativeTo: pile.parent,
                  duration: seconds, timingFunction: .easeInOut)
        try? await Task.sleep(for: .seconds(seconds))
    }

    // MARK: - The repertoire

    func perform(_ routine: Routine) async {
        guard !performing, routine != .rest else { return }
        performing = true
        dressFaces()
        defer {
            performing = false
            dressFaces()
        }

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
        /// The jostle: how far a chunk slides, how far it turns, and how many slabs
        /// move together.
        static let nudge: Float = 0.003
        static let nudgeTurn: Float = 0.10
        static let chunk = 6
        /// How far it tips toward whoever it is dealing to. About seventeen degrees —
        /// a nod, not a stoop.
        static let bow: Float = 0.30
        /// How far it leans into a flight at full tilt, and the speed that counts as full
        /// tilt — a court's width every second.
        static let lean: Float = 0.45
        static let leanSpeed: Float = 0.20
        /// How long it takes to turn into a move before setting off.
        static let bank: TimeInterval = 0.10
    }
}
