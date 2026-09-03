import SwiftUI

/// The three passive slots, bottom-left. Empty slots stay visible so the ceiling is
/// legible before it is ever reached.
struct IntangibleSlotsView: View {
    let held: [CardDescriptor]
    var dormant: Set<String> = []
    let slots: Int
    var onSelect: (CardDescriptor, CGPoint) -> Void = { _, _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("INTANGIBLES")
                .font(.system(size: 6.5, weight: .heavy)).tracking(0.9)
                .foregroundStyle(Theme.inkDim)
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
    }

    private func slot(_ card: CardDescriptor?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(card == nil ? Color.white.opacity(0.04) : Theme.panelRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(card == nil ? Theme.inkDim.opacity(0.35) : Theme.clockAmber,
                                      style: StrokeStyle(lineWidth: 1,
                                                         dash: card == nil ? [2.5, 2.5] : []))
                }
            if let card {
                Text(card.name.uppercased())
                    .font(.system(size: 5.5, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(3)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 2)
            }
        }
        .frame(width: 30, height: 40)
        .grayscale(card.map { dormant.contains($0.id) } ?? false ? 1 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: card)
    }
}
