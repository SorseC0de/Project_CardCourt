import RealityKit
import SwiftUI

/// The draw pile as actual geometry: a stack of rounded slabs with the card back laid
/// over the top.
///
/// Flat rectangles standing in for card edges only hold up from one angle — the moment
/// the pile turns, the trick shows. These are real boxes, so the deck can be spun and
/// tilted and keeps its body from every side.
///
/// One renderer for one deck. Do not reach for this per card: a fanned hand would be ten
/// renderers, and it would undo the `.drawingGroup()` flattening the cards already pay for.
struct DeckBody: View {
    /// How many slabs to show. Each stands for several cards.
    var layers: Int
    /// Turned about its own axis, in degrees. Square-on reads as a slab; a quarter turn
    /// shows two edges at once, which is what makes it look like a stack of cards.
    var spin: Float = 45
    /// How far above the deck the camera sits, in degrees. 90 is straight down.
    var pitch: Float = DeckBody.defaultPitch
    /// How thick one slab is. The discard uses thinner ones, so a handful of cards is a
    /// handful of cards rather than a shrunken deck.
    var thickness: Float = 0.0016

    /// What the deck should be doing. Changing it starts that routine.
    var routine: DeckStage.Routine = .rest

    /// Owns the slabs, so a routine can be danced across frames without the view
    /// rebuilding underneath it.
    @State private var stage = DeckStage()

    /// How tall a frame the renderer needs, as a share of its width.
    ///
    /// The camera's field of view is fixed, so this is what sets the rendered size —
    /// shrinking the frame to close a gap under the pile shrinks the pile with it.
    static let frameHeight: CGFloat = 1.25
    /// How much of that frame is empty below the pile, which is centred in it. Anything
    /// putting a label underneath has to close this or it sits a long way clear. Derived,
    /// so changing the frame keeps the label where it belongs.
    static var labelGap: CGFloat { frameHeight * 0.253 }

    /// Where the camera sits unless something says otherwise. Public so anything that has
    /// to sit on the same floor can work back from it rather than eyeballing a match —
    /// see `DiscardPileView`.
    static let defaultPitch: Float = 34
    /// The most layers a pile can ask for.
    static var maxLayers: Int { Slab.maxLayers }

    /// Everything in metres, at the proportions of a CardCourt card.
    private enum Slab {
        static let cardDepth: Float = 0.0889
        /// Derived from the game's own card, not a real one. A real deck is 0.714 wide to
        /// tall and CardCourt's cards are 0.747, so a fixed width left every slab narrower
        /// than the back printed over it.
        static var cardWidth: Float { cardDepth * Float(CardMetrics.aspect) }
        /// The card's own eight per cent — the radius its artwork is drawn with, which
        /// is what a slab under it has to wear to disappear behind it.
        static var corner: Float { cardWidth * 0.08 }
        /// Takes the hard edge off the thin side. Kept under half the slab's thickness,
        /// which is the most a box will accept.
        static let bevel: Float = 0.0003
        static let distance: Float = 0.30
        /// Built once and switched on and off, so `update` never has to make geometry.
        /// High because a layer is nearly free — every slab shares one mesh, and the
        /// entities exist whether or not they are shown. Sized for a 400-card pool at one
        /// layer per ten, so the rule never runs into the ceiling.
        static let maxLayers = 20
    }

    var body: some View {
        RealityView { content in
            content.camera = .virtual

            let pile = stage.pile
            pile.name = "pile"
            content.add(pile)

            let camera = PerspectiveCamera()
            camera.name = "camera"
            camera.camera.fieldOfViewInDegrees = 28
            content.add(camera)

            // Unlit, so the deck reads as flat colour beside the pixel art rather than as
            // a shiny object dropped into it. The alternating slabs give the edges their
            // definition, which is what lighting would otherwise be for.
            let gold = UnlitMaterial(color: UIColor(CardPalette.gold))
            let dark = UnlitMaterial(color: UIColor(CardPalette.navy))

            var facing = UnlitMaterial(color: UIColor(CardPalette.navy))
            if let art = Self.printedBack(),
               let texture = try? await TextureResource(image: art, withName: "card-back",
                                                        options: .init(semantic: .color)) {
                facing.color = .init(tint: .white, texture: .init(texture))
                facing.blending = .transparent(opacity: 1.0)
            }
            // Grown by however much artboard sits outside the printed card, so the card
            // lands exactly on the slab under it.
            let faceMesh = MeshResource.generatePlane(
                width: Slab.cardWidth
                    * Float(CardMetrics.artboard.width / CardMetrics.backShape.width),
                depth: Slab.cardDepth
                    * Float(CardMetrics.artboard.height / CardMetrics.backShape.height))

            for index in 0..<Slab.maxLayers {
                let card = ModelEntity(mesh: Self.slab(thickness: thickness),
                                       materials: [index.isMultiple(of: 2) ? gold : dark])
                card.name = "slab\(index)"
                stage.adopt(card, face: ModelEntity(mesh: faceMesh, materials: [facing]),
                            at: index, thickness: thickness)
            }

            arrange(pile: pile, camera: camera)
        } update: { content in
            guard let pile = content.entities.first(where: { $0.name == "pile" }),
                  let camera = content.entities
                      .first(where: { $0.name == "camera" }) as? PerspectiveCamera
            else { return }
            arrange(pile: pile, camera: camera)
        }
        // Runs whenever the asked-for routine changes, and only then.
        .task(id: routine) { await stage.perform(routine) }
    }

    /// The card back, rasterised for a texture.
    ///
    /// The catalog entry is vector art, so this renders it at a size chosen for the
    /// texture rather than taking whatever @2x bitmap the catalog would otherwise hand
    /// over — which is why the deck can wear the drawn back and not the pixel one.
    static func printedBack() -> CGImage? {
        guard let art = UIImage(named: "CardBackFull") else { return nil }
        let width: CGFloat = 512
        let size = CGSize(width: width,
                          height: width * CardMetrics.artboard.height / CardMetrics.artboard.width)
        return UIGraphicsImageRenderer(size: size)
            .image { _ in art.draw(in: CGRect(origin: .zero, size: size)) }
            .cgImage
    }

    /// One slab, at the card's own proportions and corner.
    ///
    /// Written out by hand — see `RoundedSlab` for why none of RealityKit's own boxes
    /// can make this shape.
    private static func slab(thickness: Float) -> MeshResource {
        RoundedSlab.mesh(width: Slab.cardWidth, depth: Slab.cardDepth,
                         thickness: thickness, radius: Slab.corner)
    }

    /// Everything that changes with the deck's height or its turn.
    private func arrange(pile: Entity, camera: PerspectiveCamera) {
        let shown = max(1, min(Slab.maxLayers, layers))
        pile.transform.rotation = simd_quatf(angle: spin * .pi / 180, axis: [0, 1, 0])

        // The top card is drawn from the artwork's own proportions and never from these,
        // so the slabs can be matched to it without moving it.
        for index in 0..<Slab.maxLayers {
            pile.findEntity(named: "slab\(index)")?.isEnabled = index < shown
        }
        // Does nothing unless the height has actually moved.
        stage.rehome(thickness: thickness)
        let height = Float(shown) * thickness
        let target = SIMD3<Float>(0, height / 2, 0)
        let angle = pitch * .pi / 180
        let eye = target + SIMD3<Float>(0,
                                        sin(angle) * Slab.distance,
                                        cos(angle) * Slab.distance)
        camera.position = eye
        camera.look(at: target, from: eye, relativeTo: nil)
    }
}

#if DEBUG
#Preview("Deck body") {
    DeckSpinPreview()
}

/// Turns it, which is the whole reason for the geometry.
private struct DeckSpinPreview: View {
    @State private var spin: Double = 45
    @State private var pitch: Double = 34
    @State private var layers: Double = 10

    var body: some View {
        VStack {
            DeckBody(layers: Int(layers), spin: Float(spin), pitch: Float(pitch))
                .frame(height: 280)

            VStack(alignment: .leading) {
                Text("spin \(Int(spin))°").font(.caption.monospaced())
                Slider(value: $spin, in: 0...360)
                Text("pitch \(Int(pitch))°").font(.caption.monospaced())
                Slider(value: $pitch, in: 0...90)
                Text("layers \(Int(layers))").font(.caption.monospaced())
                Slider(value: $layers, in: 1...20)
            }
            .padding()
        }
        .background(Theme.courtFloor)
    }
}
#endif
