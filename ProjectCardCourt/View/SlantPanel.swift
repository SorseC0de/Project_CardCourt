import SwiftUI

private enum Plate {
    /// Room for a slot and the title sitting across the top edge.
    static let height: CGFloat = 56
    static let titleSize: CGFloat = 20
    /// Where the word sits against the top edge, as a share of its own size. Zero puts
    /// its middle on the edge.
    static let titleY: CGFloat = -0.300
    static let drop: CGFloat = 5
    /// Space either side of the content, beyond what the slant already takes.
    static let pad: CGFloat = 8

    /// **Its own rake, not the name plate's.**
    ///
    /// `ModeCardStyle.lean` is 0.97 of the height, which is a handsome angle on a band
    /// 390 long and 62 tall. On a panel a third that long it is a 54pt slant across 150pt
    /// of plate: the top and bottom edges barely overlap, and what is left in the middle
    /// cannot hold a card. Same shape, an angle that suits the size it is drawn at.
    static let lean: CGFloat = 0.30

    /// How far a plate runs past the edge of the screen. It is coming *from* the side
    /// rather than sitting near it, and a plate that stops just short of the edge reads
    /// as a badge that has been placed there.
    static let overhang: CGFloat = 20
}

/// A recess cut into a plate, and whatever is standing in it.
///
/// **The well is the empty slot.** Three flat shapes and nothing else: a navy back, the
/// plate's own colour laid over it and pushed into the bottom-right corner so a lip of
/// the back survives along the top and leading edges, and a wash over the lot. The lip is
/// the shadow an inset casts with the light where every drop in this game puts it,
/// north-west; the wash is what puts the well behind the plate it is cut into rather than
/// on top of it.
///
/// A card slots in over the **whole** well, edge to edge — a slab dropped into a slot,
/// not a picture pasted into the recess. The lips are what give the empty slot its depth;
/// once a slab is in there they are behind it and there is nothing left to see through.
/// It sits above the wash, because a card in a slot is a card, not a card in shadow.
///
/// No blur and no gradient. The whole look is flat colour with hard edges, and a soft
/// inner shadow would be the one place that stopped being true.
struct SlotWell: View {
    /// The plate this is cut into. The well wears the same colour, knocked back.
    var tint: Color
    /// What is standing in it, if anything.
    var card: CardDescriptor?
    var side: CGSize = Well.side
    /// How far the navy is pulled back over the face. On the bench.
    var wash: Double = Well.wash
    var sideLip: CGFloat = Well.sideLip
    var topLip: CGFloat = Well.topLip

    /// The card's own corner, so a well cannot drift out of shape with what stands in it.
    private var corner: CGFloat { side.width * CardLayout.cornerFraction }
    /// The face: what is left of the well once the lips have taken their share. The empty
    /// slot's floor, and nothing else — a card covers the whole unit.
    private var face: CGSize {
        CGSize(width: side.width - side.width * sideLip,
               height: side.height - side.height * topLip)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: corner).fill(CardPalette.navy)

            RoundedRectangle(cornerRadius: corner)
                .fill(tint)
                .frame(width: face.width, height: face.height)

            RoundedRectangle(cornerRadius: corner)
                .fill(CardPalette.navy)
                .opacity(wash)

            if let card {
                CardFrontView(descriptor: card, displayWidth: side.width)
                    .frame(width: side.width, height: side.height)
            }
        }
        .frame(width: side.width, height: side.height)
    }
}

enum Well {
    /// **A card-shaped hole, by construction.** How tall a well is is the only choice
    /// here; its width is the card's own aspect and its corner is the card's own corner,
    /// so a well cannot drift out of shape with the thing that stands in it. It was
    /// 30 by 40 — an aspect of 0.750 against the card's 0.7474, right by luck.
    static let height: CGFloat = 40
    static var side: CGSize {
        CGSize(width: (height * CardMetrics.aspect).rounded(), height: height)
    }

    /// **The top lip is the deeper one.** The light is north-west, and an inset lit from
    /// above casts more shadow down its top edge than across its side. Shares of the
    /// well's own width and height, so a bigger slot is the same drawing.
    static let sideLip: CGFloat = 0.100
    static let topLip: CGFloat = 0.120
    /// What puts the well behind the plate rather than on top of it. Half was right at
    /// the size it was drawn and far too dark once the whole thing came down to card size.
    static let wash: Double = 0.33
}

/// A slanted plate for the things standing on the floor beside your hand.
///
/// The same parallelogram the name call flies in on — see `NameCallView` — standing still.
/// One shape across the whole game reads as one game speaking, where a rounded box down
/// here and a slanted plate up there reads as two.
///
/// What a plate *is* is the colour it wears: blue over gold is what is working for you,
/// red over purple is what is working against you. Nothing else distinguishes them, and
/// nothing else needs to.
struct SlantPanel<Content: View>: View {
    let title: String
    /// The plate, and the hard drop under it.
    let fill: Color
    let shade: Color
    /// What falls behind the word. The plate's own colour, so the title reads as cut out
    /// of the thing it names.
    let titleDrop: Color
    /// How big the word on the edge is. On the bench with the rest of it.
    var titleSize: CGFloat = Plate.titleSize
    /// Where the word sits against the top edge, as a share of its own size.
    var titleY: CGFloat = Plate.titleY
    /// The rake, as a share of the height. On the bench while it is being looked at.
    var lean: CGFloat = Plate.lean
    /// Which side of the screen it comes in from. The rake mirrors with it, so both
    /// plates rake toward the middle rather than both leaning the same way.
    var edge: HorizontalEdge = .leading
    @ViewBuilder var content: Content

    /// How far the top edge is pushed along.
    private var slant: CGFloat { Plate.height * lean }

    /// Content has to clear the slant on **both** sides, not just the leading one: the
    /// top edge starts inset on the left and the bottom edge ends inset on the right, so
    /// a card padded on one side only hangs off the other corner. Which it did.
    private var inset: CGFloat { slant + Plate.pad }

    /// +1 when it comes in from the left, -1 from the right.
    private var facing: CGFloat { edge == .leading ? 1 : -1 }

    var body: some View {
        content
            .frame(height: Plate.height, alignment: .center)
            // The outer side carries the overhang too, so the plate grows off the screen
            // and the content it holds does not move.
            .padding(.leading, inset + (edge == .leading ? Plate.overhang : 0))
            .padding(.trailing, inset + (edge == .trailing ? Plate.overhang : 0))
            .background {
                Parallelogram(lean: lean)
                    .fill(fill)
                    // Mirrored for the right-hand plate, and its drop mirrors with it:
                    // south-east on the one that comes in from the left, south-west on
                    // the one from the right. The drop falls away from the edge the plate
                    // arrived through, so neither one throws its shadow back off screen.
                    .scaleEffect(x: facing, y: 1)
                    .shadow(color: shade, radius: 0, x: facing * Plate.drop, y: Plate.drop)
            }
            .overlay(alignment: .top) {
                // Straddling the edge: half the word on the plate and half off it, which
                // is what stops it reading as a caption sitting inside a box. Nudged by
                // half the slant toward the end the top edge actually starts at.
                ActionText(title, size: titleSize, ink: .white, drop: titleDrop)
                    .fixedSize()
                    .alignmentGuide(.top) { $0[VerticalAlignment.center] }
                    .offset(x: facing * slant / 2, y: titleY * titleSize)
            }
            .fixedSize()
            // And out past the edge it came from.
            .offset(x: -facing * Plate.overhang)
    }
}

#if DEBUG
/// The two floor plates, side by side, with everything still being looked at on a dial.
#Preview("Floor plates") {
    struct Bench: View {
        @State private var lean: CGFloat = 0.30
        @State private var titleSize: CGFloat = 20
        @State private var titleY: CGFloat = -0.300
        @State private var wash: Double = Well.wash
        @State private var sideLip: CGFloat = Well.sideLip
        @State private var topLip: CGFloat = Well.topLip
        @State private var slots = 2

        var body: some View {
            VStack(spacing: 26) {
                Spacer()
                HStack(alignment: .bottom) {
                    IntangibleSlotsView(held: Array(held.prefix(slots)), slots: 3,
                                        lean: lean, titleSize: titleSize,
                                        titleY: titleY, wash: wash, sideLip: sideLip, topLip: topLip)
                    Spacer(minLength: 0)
                    DebuffSlotsView(cards: Array(clamps.prefix(slots)),
                                    lean: lean, titleSize: titleSize,
                                    titleY: titleY, wash: wash, sideLip: sideLip, topLip: topLip)
                }

                VStack(spacing: 10) {
                    dial("lean", value: $lean, range: 0...1)
                    dial("title", value: $titleSize, range: 8...34)
                    dial("title y", value: $titleY, range: -1.2...1.2)
                    dial("side lip", value: $sideLip, range: 0...0.30)
                    dial("top lip", value: $topLip, range: 0...0.30)
                    HStack(spacing: 10) {
                        Text(String(format: "wash %.3f", wash))
                            .font(.custom(Chrome.display, size: 15))
                            .foregroundStyle(.white)
                            .frame(width: 110, alignment: .leading)
                        Slider(value: $wash, in: 0...1)
                    }
                    Stepper("cards \(slots)", value: $slots, in: 0...3)
                        .font(.custom(Chrome.display, size: 15))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.courtFloor)
        }

        private var held: [CardDescriptor] {
            [CardLibrary.hotHand, CardLibrary.shotCreator, CardLibrary.freethrowMerchant]
        }
        private var clamps: [CardDescriptor] {
            [CardLibrary.doubleTeam, CardLibrary.trap, CardLibrary.contest]
        }

        private func dial(_ name: String, value: Binding<CGFloat>,
                          range: ClosedRange<CGFloat>) -> some View {
            HStack(spacing: 10) {
                Text(String(format: "%@ %.3f", name, value.wrappedValue))
                    .font(.custom(Chrome.display, size: 15))
                    .foregroundStyle(.white)
                    .frame(width: 110, alignment: .leading)
                Slider(value: value, in: range)
            }
        }
    }
    return Bench()
}
#endif
