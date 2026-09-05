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
    /// **Held.** Something has the screen — a sheet, a browser, a question — and a deck
    /// drifting about behind it is the floor carrying on without the player.
    var frozen = false

    private enum Stage {
        /// How much floor the view spans, in metres, measured across the middle.
        static let courtWidth: Float = 0.1876
        /// Looking down at the floor, in degrees.
        static let pitch: Float = 34
        static let fieldOfView: Float = 28
        static let slab: Float = 0.0016
        /// How many slabs each pile is built with — the ceiling the bench's own slider
        /// stops at. Every one of them is two entities that exist from the first frame
        /// whether the pile is that tall or not, and at forty that was a hundred and sixty
        /// of them standing on the floor for a pile that never shows more than eight.
        static let maxLayers = 20

        /// How wide a pile should read, as a share of the view.
        ///
        /// Measured, not assumed. `DeckStackView` asks for a 138pt *frame*, and the old
        /// per-pile camera framed the card inside it — at a fixed distance of 0.30 in a
        /// 138×172 frame the card came out about 77pt, not 138. Sizing to the frame made
        /// the deck 1.8× too big; this is the card.
        static let cardShare = Float(Perspective.pileCardShare)

        /// The card's size in the world, in one place.
        ///
        /// Two copies of this is what made the deck giant twice over: the meshes were
        /// built from a literal while `fit` sized against `cardShare`, so changing the
        /// share only taught `fit` a card size the geometry did not have — and it scaled
        /// up to make up the difference.
        static var cardWidth: Float { courtWidth * cardShare }
        static var cardDepth: Float { cardWidth / Float(CardMetrics.aspect) }
        /// How far above the floor the deck rides while it is working.
        static let hover: Float = 0.030
        /// How much bigger a card in the air is than one in the pile. A dealt card is the
        /// thing being watched; a slab the size of the ones it came off is a chip.
        static let dealtCard: Float = 1.8
        /// How far out of its place the deck leans to hand one over, as a share of the
        /// way to whoever is drawing. Not the whole trip — that is a lot of deck for one
        /// card — but far enough that it is plainly reaching out to them.
        static let lean: Float = 0.22
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
                DevLog.say(.deck, "stage: building the scene")
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

                // The printed back, grown by however much artboard sits outside the card
                // so it lands exactly on the slab beneath it.
                var facing = UnlitMaterial(color: UIColor(CardPalette.navy))
                if let art = DeckBody.printedBack(),
                   let texture = try? await TextureResource(image: art, withName: "card-back",
                                                            options: .init(semantic: .color)) {
                    facing.color = .init(tint: .white, texture: .init(texture))
                    facing.blending = .transparent(opacity: 1.0)
                }
                let faceMesh = MeshResource.generatePlane(
                    width: Stage.cardWidth
                        * Float(CardMetrics.artboard.width / CardMetrics.backShape.width),
                    depth: Stage.cardDepth
                        * Float(CardMetrics.artboard.height / CardMetrics.backShape.height))

                for index in 0..<Stage.maxLayers {
                    let card = ModelEntity(mesh: mesh,
                                           materials: [index.isMultiple(of: 2) ? gold : navy])
                    card.name = "slab\(index)"
                    deck.adopt(card, face: ModelEntity(mesh: faceMesh, materials: [facing]),
                               at: index, thickness: Stage.slab)

                    let spent = ModelEntity(mesh: mesh,
                                            materials: [index.isMultiple(of: 2) ? gold : navy])
                    spent.name = "spent\(index)"
                    discard.adopt(spent, face: ModelEntity(mesh: faceMesh, materials: [facing]),
                                  at: index, thickness: Stage.slab)
                }
                dealer.build(mesh: dealtMesh(), material: gold)

                DevLog.say(.deck, "stage: built")
                deck.ground = floorPoint(deckAt, in: geo.size)
                deck.pile.position = deck.ground
                discard.ground = floorPoint(discardAt, in: geo.size)
                discard.pile.position = discard.ground
                // Half a lap behind the live pile, so the two do not breathe in step.
                discard.phase = 0.5
                place(camera: camera, in: geo.size)
            } update: { content in
                guard let camera = content.entities
                    .first(where: { $0.name == "camera" }) as? PerspectiveCamera else { return }
                place(camera: camera, in: geo.size)

                deck.show(deckLayers, of: Stage.maxLayers, thickness: Stage.slab)
                discard.show(discardLayers, of: Stage.maxLayers, thickness: Stage.slab)
                // The idle owns where the deck actually is — it is never sitting
                // still — so the court hands it a home point rather than a position.
                deck.ground = floorPoint(deckAt, in: geo.size)
                if !deck.travelling { fit(deck.pile, in: geo.size) }
                // The same for the spent pile, now that it drifts too. Setting its
                // position outright while `idle` was also writing one left the drift
                // reading a home point of zero — so the pile flew off to the middle of
                // the world and only its shadow was left on the floor.
                discard.ground = floorPoint(discardAt, in: geo.size)
                if !discard.travelling { fit(discard.pile, in: geo.size) }
            }
            .task(id: deckRoutine) { await deck.perform(deckRoutine) }
            // Runs for as long as the court is on screen. Cancelled with the view, and
            // it stands aside on its own whenever a routine takes the deck over.
            .task(id: frozen) {
                guard !frozen else { return }
                await deck.idle(across: Stage.courtWidth)
            }
            // The spent pile breathes with the live one. A deck that floats beside a pile
            // that does not reads as one of them being broken.
            .task(id: frozen) {
                guard !frozen else { return }
                await discard.idle(across: Stage.courtWidth)
            }
            .task(id: flight?.id) {
                guard let flight else { return }
                let home = floorPoint(flight.from, in: geo.size)
                let to = floorPoint(flight.to, in: geo.size)
                // **It leans out to hand the card over, and goes back.** Not the whole
                // trip — that is a lot of deck for one card — but far enough that it is
                // plainly reaching towards whoever is drawing, and `travel` banks into
                // the move rather than sliding square-on.
                let out = home + (to - home) * Stage.lean + SIMD3(0, Stage.hover, 0)
                await deck.travel(to: out, seconds: 0.18, curve: .easeOut)
                await deck.bow(toward: to)
                await dealer.fly(from: out, to: to, seconds: flight.seconds)
                await deck.straighten()
                await deck.travel(to: home, seconds: 0.24)
                deck.settle()
            }
            .task(id: opening?.id) {
                guard let opening else { return }
                await open(opening, in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    /// The card in the air, bigger than the ones in the pile it came off.
    private func dealtMesh() -> MeshResource {
        RoundedSlab.mesh(width: Stage.cardWidth * Stage.dealtCard,
                         depth: Stage.cardDepth * Stage.dealtCard,
                         thickness: Stage.slab * Stage.dealtCard,
                         radius: Stage.cardWidth * Stage.dealtCard * 0.08)
    }

    private func slabMesh() -> MeshResource {
        // The card's own eight per cent. A fixed radius was being shared with `DeckBody`,
        // whose card is nearly twice as wide — the same number rounded these far harder.
        RoundedSlab.mesh(width: Stage.cardWidth, depth: Stage.cardDepth,
                         thickness: Stage.slab, radius: Stage.cardWidth * 0.08)
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
            // Zippy between players. The beat of the opening is the dealing, not the
            // getting there.
            await deck.travel(to: stand + hover * 1.6, seconds: 0.22)
            await deck.bow(toward: stand)
            for _ in 0..<deal.each {
                await dealer.fly(from: stand + hover * 1.6, to: stand, seconds: 0.34)
            }
            await deck.straighten()
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

    /// Sizes a pile so it reads at `cardShare` of the view wherever it is standing.
    ///
    /// A card's apparent size falls off with its distance from the camera, and a pile's
    /// court point can unproject anywhere on the floor — the deck's landed well forward,
    /// which is why it came out enormous. Normalising against its own distance keeps a
    /// pile the size the court drew it before this scene existed.
    private func fit(_ pile: Entity, in size: CGSize) {
        let eye = Self.cameraTransform(for: size).translation
        let away = distance(eye, pile.position)
        let aspect = Float(size.width / max(size.height, 1))
        let across = 2 * away * tan(Stage.fieldOfView * .pi / 360) * aspect
        let scale = Stage.cardShare * Float(tuning.size) * across / Stage.cardWidth
        pile.scale = .one * scale

        // Reported once per change, not per frame: the arithmetic says this lands at the
        // court's own 138 of 390, so if the pile is not that size on screen the number
        // here says whether the sizing is wrong or something downstream is.
        if abs(scale - Self.lastFit) > 0.01 {
            Self.lastFit = scale
            DevLog.say(.deck, String(
                format: "fit %@  scale %.3f  away %.3f  view %.0fx%.0f  → card reads %.0fpt",
                pile.name, scale, away, size.width, size.height,
                Double(Stage.cardWidth * scale / across) * size.width))
        }
    }

    /// The last scale reported, so the console is not filled with the same line.
    private static var lastFit: Float = 0

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
