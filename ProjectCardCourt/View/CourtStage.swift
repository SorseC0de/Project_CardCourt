import RealityKit
import SwiftUI

/// One 3D scene for the whole court.
///
/// The deck and the discard used to be a renderer each, in their own small frames, which
/// meant a card could not leave one — a slab flying to a player would have clipped at the
/// edge of a box a fifth of the screen wide. Here there is a single stage spanning the
/// court, so a card can travel anywhere on it, and the two piles are simply two things
/// standing on the same floor.
///
/// **Where things go.** Everything is placed by the *2D* court: callers pass positions as
/// fractions of the stage's own size, exactly as `CourtGeometry` computes them, and those
/// are fired through the camera onto the floor plane. Nothing here re-derives the court's
/// perspective, so a pile cannot drift away from the sprite standing next to it.
struct CourtStage: View {
    /// Where the piles stand, in fractions of the stage: 0,0 top-left, 1,1 bottom-right.
    var deckAt: CGPoint
    var discardAt: CGPoint
    var deckLayers: Int
    var discardLayers: Int
    var deckRoutine: DeckStage.Routine = .rest
    /// A card on its way somewhere. Setting one sends it.
    var flight: CardFlight?
    /// Where each seat stands, so the deck knows who it is dealing to.
    var seatsAt: [Seat: CGPoint] = [:]
    /// The opening deal. Setting one starts the whole performance.
    var opening: OpeningDeal?

    private enum Stage {
        /// How much floor the view spans, in metres, measured across the middle.
        static let courtWidth: Float = 0.1876
        /// Looking down at the floor, in degrees.
        static let pitch: Float = 34
        static let fieldOfView: Float = 28
        static let slab: Float = 0.0016
        static let maxLayers = 40

        /// How far above the floor the deck rides while it is working.
        static let hover: Float = 0.030
        /// Where it comes in from: high, and beyond the far edge.
        static let entryHeight: Float = 0.090
        static let entryDepth: Float = 1.6
    }

    @State private var deck = DeckStage()
    @State private var discard = DeckStage()
    @State private var dealer = CardDealer()
    @State private var tuning = DeckTuning.shared

    var body: some View {
        GeometryReader { geo in
            RealityView { content in
                content.camera = .virtual

                let camera = PerspectiveCamera()
                camera.name = "camera"
                camera.camera.fieldOfViewInDegrees = Stage.fieldOfView
                content.add(camera)

                content.add(deck.pile)
                content.add(discard.pile)
                content.add(dealer.root)

                let gold = UnlitMaterial(color: UIColor(CardPalette.gold))
                let navy = UnlitMaterial(color: UIColor(CardPalette.navy))
                let mesh = slabMesh()

                for index in 0..<Stage.maxLayers {
                    let card = ModelEntity(mesh: mesh,
                                           materials: [index.isMultiple(of: 2) ? gold : navy])
                    card.name = "slab\(index)"
                    deck.adopt(card, at: index, thickness: Stage.slab)

                    let spent = ModelEntity(mesh: mesh,
                                            materials: [index.isMultiple(of: 2) ? gold : navy])
                    spent.name = "spent\(index)"
                    discard.adopt(spent, at: index, thickness: Stage.slab)
                }
                dealer.build(mesh: mesh, material: gold)

                place(camera: camera, in: geo.size)
            } update: { content in
                guard let camera = content.entities
                    .first(where: { $0.name == "camera" }) as? PerspectiveCamera else { return }
                place(camera: camera, in: geo.size)

                deck.show(deckLayers, of: Stage.maxLayers, thickness: Stage.slab)
                discard.show(discardLayers, of: Stage.maxLayers, thickness: Stage.slab)
                // Left alone while it is performing — see `DeckStage.travelling`.
                if !deck.travelling {
                    deck.pile.position = floorPoint(deckAt, in: geo.size)
                }
                discard.pile.position = floorPoint(discardAt, in: geo.size)
            }
            .task(id: deckRoutine) { await deck.perform(deckRoutine) }
            .task(id: flight?.id) {
                guard let flight else { return }
                await dealer.fly(from: floorPoint(flight.from, in: geo.size),
                                 to: floorPoint(flight.to, in: geo.size),
                                 seconds: flight.seconds)
            }
            .task(id: opening?.id) {
                guard let opening else { return }
                await open(opening, in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func slabMesh() -> MeshResource {
        let depth = Stage.courtWidth * 0.354 / Float(CardMetrics.aspect)
        return RoundedSlab.mesh(width: depth * Float(CardMetrics.aspect), depth: depth,
                                thickness: Stage.slab, radius: tuning.major)
    }

    // MARK: - The opening

    /// In from the horizon, round the table, then home and down hard.
    ///
    /// The order is the choreography and nothing else: each step waits for the last, so
    /// the deck is never in two places at once and the whole thing can be re-timed by
    /// changing one number.
    private func open(_ deal: OpeningDeal, in size: CGSize) async {
        let home = floorPoint(deckAt, in: size)
        let hover = SIMD3<Float>(0, Stage.hover, 0)

        // Waiting off the far edge, high, before it is asked for.
        deck.place(at: SIMD3(home.x, Stage.entryHeight, home.z - Stage.courtWidth * Stage.entryDepth))
        await deck.travel(to: home + hover, seconds: 0.75, curve: .easeOut)

        for seat in deal.order {
            guard let at = seatsAt[seat] else { continue }
            let stand = floorPoint(at, in: size)
            await deck.travel(to: stand + hover * 1.6, seconds: 0.42)
            for _ in 0..<deal.each {
                await dealer.fly(from: stand + hover * 1.6, to: stand, seconds: 0.34)
            }
        }

        await deck.travel(to: home + hover, seconds: 0.55)
        // The hard landing knocks the stack out of true and then squares it away.
        await deck.perform(.landing)
        deck.settle()
    }

    // MARK: - Screen to floor

    /// The camera, framing the floor from the court's own angle.
    private func place(camera: PerspectiveCamera, in size: CGSize) {
        camera.transform = Self.cameraTransform(for: size)
    }

    private static func cameraTransform(for size: CGSize) -> Transform {
        // Far enough back that `courtWidth` of floor fills the view across the middle.
        let aspect = Float(size.width / max(size.height, 1))
        let halfFov = Stage.fieldOfView * .pi / 360
        let distance = (Stage.courtWidth / aspect) / (2 * tan(halfFov))
        let angle = Stage.pitch * .pi / 180

        let eye = SIMD3<Float>(0, sin(angle) * distance, cos(angle) * distance)
        var transform = Transform()
        transform.translation = eye
        transform.rotation = simd_quatf(from: [0, 0, -1], to: normalize(-eye))
        return transform
    }

    /// A point on the court, fired through the camera onto the floor.
    ///
    /// Done by hand rather than with `unproject` so the maths is ours and cannot change
    /// under us: build the ray for that pixel in camera space, turn it into the world,
    /// and meet the plane at y = 0.
    private func floorPoint(_ fraction: CGPoint, in size: CGSize) -> SIMD3<Float> {
        let transform = Self.cameraTransform(for: size)
        let eye = transform.translation
        let aspect = Float(size.width / max(size.height, 1))
        let halfFov = Stage.fieldOfView * .pi / 360

        let forward = normalize(-eye)
        let right = normalize(cross(forward, SIMD3<Float>(0, 1, 0)))
        let up = cross(right, forward)

        let x = (Float(fraction.x) * 2 - 1) * tan(halfFov) * aspect
        let y = (1 - Float(fraction.y) * 2) * tan(halfFov)
        let ray = normalize(x * right + y * up + forward)

        // Anything aimed at or above the horizon never lands; park it far upcourt.
        guard ray.y < -0.0001 else { return SIMD3(0, 0, -Stage.courtWidth) }
        return eye + ray * (-eye.y / ray.y)
    }
}

/// A single card crossing the court.
struct CardFlight: Identifiable, Equatable {
    let id: UUID
    /// Both ends as fractions of the stage, the same way the piles are placed.
    let from: CGPoint
    let to: CGPoint
    var seconds: TimeInterval = 0.55
}

/// The opening deal: who gets cards, and how many each.
struct OpeningDeal: Identifiable, Equatable {
    let id: UUID
    /// Dealt in this order, one player at a time.
    let order: [Seat]
    let each: Int
}
