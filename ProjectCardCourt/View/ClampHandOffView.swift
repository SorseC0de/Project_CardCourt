import SwiftUI

/// **Traderous Tarmac: handing the Clamps on you to other players.** Each Clamp stands over
/// a button for everyone with room for it, and a tap sends it. Any split is yours: all of
/// them at one player, one each, or anything between.
struct ClampHandOffView: View {
    let clamps: [ActiveClamp]
    let receivers: [Seat]
    let onHandOff: (UUID, Seat) -> Void
    let onDone: () -> Void

    private enum Layout {
        static let card: CGFloat = 86
        static let button: CGFloat = 26
    }

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture(perform: onDone)

            VStack(spacing: 16) {
                SwisshTitle(text: "Hand Off", size: 30)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(clamps) { clamp in
                            VStack(spacing: 8) {
                                CardFrontView(descriptor: clamp.card, displayWidth: Layout.card)
                                ForEach(receivers, id: \.self) { seat in
                                    Button { onHandOff(clamp.id, seat) } label: {
                                        PlayerNameText(seat: seat, size: 12)
                                            .frame(width: Layout.card, height: Layout.button)
                                            .background(Capsule()
                                                .fill(Theme.color(for: seat).opacity(0.85)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .fixedSize(horizontal: false, vertical: true)
                ChunkyButton(title: "Done", fill: CardPalette.blue) { onDone() }
                    .padding(.horizontal, 90)
            }
        }
        .transition(.opacity)
    }
}
