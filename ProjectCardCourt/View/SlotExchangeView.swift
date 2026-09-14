import SwiftUI

/// **Varsitile: the floor, the ball or both, out of the discard.** One pick a row, and the
/// swap goes through on Exchange. Two copies of a card in the pile are the same choice, so
/// each kind shows once.
struct SlotExchangeView: View {
    let courts: [Card]
    let balls: [Card]
    let onExchange: (UUID?, UUID?) -> Void
    let onCancel: () -> Void

    @State private var court: UUID?
    @State private var ball: UUID?

    private enum Layout {
        static let card: CGFloat = 66
        static let lift: CGFloat = 12
    }

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 14) {
                SwisshTitle(text: "Exchange", size: 30)
                if !courts.isEmpty { row("Varena", courts, picked: $court) }
                if !balls.isEmpty { row("Variaball", balls, picked: $ball) }
                HStack(spacing: 12) {
                    ChunkyButton(title: "Cancel", fill: CardPalette.red) { onCancel() }
                    ChunkyButton(title: "Exchange", fill: CardPalette.blue) {
                        onExchange(court, ball)
                    }
                    .opacity(court == nil && ball == nil ? 0.4 : 1)
                    .disabled(court == nil && ball == nil)
                }
                .padding(.horizontal, 30)
            }
        }
        .transition(.opacity)
    }

    private func row(_ title: String, _ cards: [Card], picked: Binding<UUID?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black))
                .tracking(1.2)
                .foregroundStyle(.white)
                .padding(.leading, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(oneOfEachKind(cards)) { card in
                        let chosen = picked.wrappedValue == card.id
                        CardFrontView(descriptor: card.descriptor, displayWidth: Layout.card)
                            .overlay {
                                if chosen {
                                    RoundedRectangle(cornerRadius: Layout.card * CardLayout.cornerFraction,
                                                     style: .continuous)
                                        .strokeBorder(CardPalette.gold, lineWidth: 4)
                                }
                            }
                            .offset(y: chosen ? -Layout.lift : 0)
                            .onTapGesture { picked.wrappedValue = chosen ? nil : card.id }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, Layout.lift + 2)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: picked.wrappedValue)
    }

    /// The most recent copy of each card, first.
    private func oneOfEachKind(_ cards: [Card]) -> [Card] {
        var seen: Set<String> = []
        return cards.reversed().filter { seen.insert($0.descriptor.id).inserted }
    }
}
