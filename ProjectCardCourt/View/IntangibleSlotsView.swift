import SwiftUI

/// The three passive slots, bottom-left. Empty wells stay visible so the ceiling is
/// legible before it is ever reached.
struct IntangibleSlotsView: View {
    let held: [CardDescriptor]
    var dormant: Set<String> = []
    let slots: Int
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
        SlantPanel(title: "Intangibles", fill: CardPalette.blue,
                   shade: CardPalette.gold, titleDrop: CardPalette.blue,
                   titleSize: titleSize, titleY: titleY, lean: lean) {
            HStack(spacing: 4) {
                ForEach(0..<slots, id: \.self) { index in
                    let card = held.indices.contains(index) ? held[index] : nil
                    slot(card)
                        .contentShape(Rectangle())
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
        // Only when there is something to say. An empty rank of dotted boxes taught the
        // ceiling once and then sat there for the rest of the game.
        .opacity(held.isEmpty ? 0 : 1)
        .animation(.easeOut(duration: 0.25), value: held.isEmpty)
    }

    private func slot(_ card: CardDescriptor?) -> some View {
        SlotWell(tint: CardPalette.blue, card: card, wash: wash,
                 sideLip: sideLip, topLip: topLip)
            // A passive that currently pays nothing, drained rather than dimmed.
            .grayscale(card.map { dormant.contains($0.id) } ?? false ? 1 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: card)
    }
}
