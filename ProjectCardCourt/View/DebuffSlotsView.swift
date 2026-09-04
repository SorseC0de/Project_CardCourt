import SwiftUI

/// Everything working against you this possession, mirroring the Intangible slots on the
/// other side.
///
/// A fixed rank of wells rather than a row that grows: Clamps are capped at three a
/// player — see `MatchRules.clampSlots` — so the two plates are the same object twice, and
/// neither one changes width as the game goes on.
struct DebuffSlotsView: View {
    let cards: [CardDescriptor]
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

    var body: some View {
        SlantPanel(title: "Clamps", fill: CardPalette.red,
                   shade: CardPalette.purple, titleDrop: CardPalette.red,
                   titleSize: titleSize, titleY: titleY, lean: lean,
                   edge: .trailing) {
            HStack(spacing: 4) {
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
        SlotWell(tint: CardPalette.red, card: card, wash: wash,
                 sideLip: sideLip, topLip: topLip)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: card)
    }
}
