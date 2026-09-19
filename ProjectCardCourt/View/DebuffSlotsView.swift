import SwiftUI

/// Everything working against you this possession, mirroring the Intangible slots on the
/// other side.
///
/// A fixed rank of wells rather than a row that grows: Clamps are capped at three a
/// player — see `MatchRules.clampSlots` — so the two plates are the same object twice, and
/// neither one changes width as the game goes on.
struct DebuffSlotsView: View {
    let cards: [CardDescriptor]
    /// **What the plate is called and what it is made of.** Clamps by default, because
    /// that is what it was built for; Injuries wear the same plate in their own colours,
    /// stacked behind it — see `GameView.debuffPlates`.
    var title: String = "Clamps"
    var fill: Color = CardPalette.red
    var shade: Color = CardPalette.purple
    /// The cap, so the plate is the same size whatever is standing in it.
    var slots: Int = 3
    var onSelect: (CardDescriptor, CGPoint) -> Void = { _, _ in }
    /// Both on the bench while the plate is being looked at — see `SlantPanel`.
    var lean: CGFloat = 0.30
    /// The word on the plate's edge, and where it sits against it.
    var titleSize: CGFloat = 20
    var titleY: CGFloat = -0.300
    var wash: Double = Well.wash
    var sideLip: CGFloat = Well.sideLip
    var topLip: CGFloat = Well.topLip
    /// Which side it comes in from. The HUD stands it under the Intangibles, so it comes
    /// in from the left the way they do.
    var edge: HorizontalEdge = .trailing
    /// The plate's size as one factor — see `SlantPanel.unit`.
    var unit: CGFloat = 1

    var body: some View {
        SlantPanel(title: title, fill: fill,
                   shade: shade, titleDrop: fill,
                   titleSize: titleSize, titleY: titleY, lean: lean,
                   edge: edge, unit: unit) {
            HStack(spacing: 4 * unit) {
                ForEach(0..<slots, id: \.self) { index in
                    let card = cards.indices.contains(index) ? cards[index] : nil
                    slot(card)
                        .contentShape(Rectangle())
                        // Inside a reader, so the tap knows where on screen it happened
                        // and the raised card can grow out of this slot.
                        .overlay {
                            GeometryReader { slot in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        guard let card else { return }
                                        onSelect(card, CGPoint(x: slot.frame(in: .global).midX,
                                                               y: slot.frame(in: .global).midY))
                                    }
                            }
                        }
                }
            }
        }
        .opacity(cards.isEmpty ? 0 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: cards)
    }

    private func slot(_ card: CardDescriptor?) -> some View {
        SlotWell(tint: CardPalette.red, card: card,
                 side: CGSize(width: Well.side.width * unit, height: Well.side.height * unit),
                 wash: wash, sideLip: sideLip, topLip: topLip)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: card)
    }
}
