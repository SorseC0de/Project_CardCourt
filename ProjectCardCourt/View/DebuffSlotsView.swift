import SwiftUI

/// Everything working against you this possession, mirroring the Intangible slots on the
/// other side. Cards overlap so a Triple-Team reads as a stack rather than a row.
struct DebuffSlotsView: View {
    let cards: [CardDescriptor]
    var onSelect: (CardDescriptor, CGPoint) -> Void = { _, _ in }

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("AGAINST YOU")
                .font(.system(size: 6.5, weight: .heavy)).tracking(0.9)
                .foregroundStyle(Theme.inkDim)
            HStack(spacing: -10) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    slot(card)
                        .zIndex(Double(index))
                        .contentShape(Rectangle())
                        // Inside a reader, so the tap knows where on screen it happened
                        // and the raised card can grow out of this slot.
                        .overlay {
                            GeometryReader { slot in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        onSelect(card, CGPoint(x: slot.frame(in: .global).midX,
                                                               y: slot.frame(in: .global).midY))
                                    }
                            }
                        }
                }
            }
            .frame(height: 40, alignment: .bottom)
        }
        .opacity(cards.isEmpty ? 0 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: cards)
    }

    private func slot(_ card: CardDescriptor) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.panelRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Theme.color(for: card.type), lineWidth: 1)
                }
            VStack(spacing: 1) {
                Image(systemName: card.symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.color(for: card.type))
                Text(card.name.uppercased())
                    .font(.system(size: 5, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 1)
            }
        }
        .frame(width: 30, height: 40)
        .shadow(color: .black.opacity(0.5), radius: 2, x: -1)
        .transition(.scale(scale: 0.01).combined(with: .opacity))
    }
}
