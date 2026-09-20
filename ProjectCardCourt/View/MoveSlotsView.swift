import SwiftUI

/// **How many Moves this possession has left**, as a plate like the two it stands with.
///
/// It was a row of pips beside an arrow — the Move icon's own dashes, made into a gauge.
/// Read at a glance beside the Intangibles and the Clamps it belongs with, three plates
/// saying what is working for you, what is working against you, and how much running you
/// have left.
///
/// **The plate says the rate as a colour.** Green whatever happens, with a drop that goes
/// from cloud through gold and orange to red as the possession spends its Moves — so the
/// thing that changes is the shadow under the plate rather than the plate itself.
struct MoveSlotsView: View {
    /// How many have been spent this possession.
    let played: Int
    /// How many there is room for — the match's limit, or an official's tighter one.
    var slots: Int = 3
    /// Both on the bench while the plate is being looked at — see `SlantPanel`.
    var lean: CGFloat = 0.30
    var titleSize: CGFloat = 20
    var titleY: CGFloat = -0.300
    var edge: HorizontalEdge = .trailing
    /// The plate's size as one factor — see `SlantPanel.unit`.
    var unit: CGFloat = 1

    /// **The drop, by how much running is gone.** Cloud with the whole possession ahead,
    /// and red once there is none left.
    private var shade: Color {
        switch played {
        case 0:  return CardPalette.cloud
        case 1:  return CardPalette.gold
        case 2:  return CardPalette.orange
        default: return CardPalette.red
        }
    }

    private var side: CGSize {
        CGSize(width: Well.side.width * unit, height: Well.side.height * unit)
    }

    var body: some View {
        SlantPanel(title: "Moves", fill: CardPalette.green,
                   shade: shade, titleDrop: CardPalette.green,
                   titleSize: titleSize, titleY: titleY, lean: lean,
                   edge: edge, unit: unit) {
            HStack(spacing: 4 * unit) {
                ForEach(0..<max(1, slots), id: \.self) { index in
                    slot(spent: index < played)
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: played)
    }

    /// One Move: the subject the cards are printed with, on a rounded slab. Spent, it
    /// takes the plate's own drop; still there, it sits in the quiet the empty wells wear.
    private func slot(spent: Bool) -> some View {
        let corner = side.width * CardLayout.cornerFraction
        return ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(spent ? shade : CardPalette.navy)
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(spent ? CardPalette.navy : CardPalette.green.opacity(0.6),
                              lineWidth: max(1, 1.5 * unit))
            Image("TypeMoveFront")
                .resizable()
                .scaledToFit()
                .padding(side.width * 0.16)
                .foregroundStyle(spent ? CardPalette.navy : CardPalette.green)
                .opacity(spent ? 1 : 0.55)
        }
        .frame(width: side.width, height: side.height)
    }
}

#if DEBUG
#Preview("Moves") {
    VStack(spacing: 14) {
        ForEach(0..<4, id: \.self) { played in
            MoveSlotsView(played: played)
        }
    }
    .padding(30)
    .background(Theme.sceneGround)
}
#endif
