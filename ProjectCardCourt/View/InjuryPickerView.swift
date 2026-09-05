import SwiftUI

/// The Injuries on the floor, and the one you are taking.
///
/// Wet Spot lays out everything hurt in the pile and everything still in the deck. What
/// is in the pile you can read; what is in the deck you cannot — knowing an Injury is in
/// there is not the same as knowing which — so those come up face down.
struct InjuryPickerView: View {
    let card: CardDescriptor
    let offered: [CardDescriptor]
    let hidden: Set<String>
    var onPick: (String) -> Void

    @State private var chosen: String?

    private enum Table {
        static let card: CGFloat = 66
        static let lift: CGFloat = 18
    }

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()

            ModeCardView(title: card.name,
                         subtitle: "Take one",
                         ink: .white,
                         subtitleInk: CardPalette.red,
                         accessory: AnyView(table),
                         isLeaving: false,
                         onLanded: {},
                         onFinished: {})
        }
        .transition(.opacity)
    }

    private var table: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(offered, id: \.id) { injury in
                        face(injury)
                            .offset(y: chosen == injury.id ? -Table.lift : 0)
                            .onTapGesture { chosen = injury.id }
                    }
                }
                .padding(.vertical, Table.lift)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 320)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: chosen)

            ChunkyButton(title: chosen == nil ? "Pick one" : "Take it",
                         fill: chosen == nil ? CardPalette.gray : CardPalette.red,
                         stroke: CardPalette.gold, shade: CardPalette.orange,
                         size: 18, isEnabled: chosen != nil) {
                if let chosen { onPick(chosen) }
            }
            .frame(width: 200)
        }
        .fixedSize()
    }

    @ViewBuilder private func face(_ injury: CardDescriptor) -> some View {
        let on = chosen == injury.id
        Group {
            if hidden.contains(injury.id) {
                Image("CardBackFull")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Table.card)
            } else {
                CardFrontView(descriptor: injury, displayWidth: Table.card)
            }
        }
        .overlay {
            if on {
                RoundedRectangle(cornerRadius: Table.card * CardLayout.cornerFraction,
                                 style: .continuous)
                    .strokeBorder(CardPalette.gold, lineWidth: 4)
            }
        }
        .shadow(color: .black.opacity(0.5), radius: on ? 10 : 4, y: on ? 6 : 2)
    }
}
