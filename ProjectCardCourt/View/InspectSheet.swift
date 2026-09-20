import SwiftUI

/// What a tap on the floor opens.
///
/// **A player is not one of them any more.** What there was to know about him — his
/// score, his line, the card standing on him, the size of his hand — is all on his own
/// block along the top of the screen, which is where it is read.
enum Inspection: Equatable, Identifiable {
    case referees

    var id: String { "referees" }
}

/// The frame both floor popovers are built in.
///
/// The lobby's vocabulary carried onto the table: a navy slab with a grey rim and a hard
/// drop, a title in the same condensed heavy type, and one red chip to close it. Nothing
/// here knows what it is holding — see `PlayerInspectView` and `RefereeInspectView`.
struct InspectSheet<Content: View>: View {
    let title: String
    var onDismiss: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            // The dim itself takes no taps — see `DimLayer` — so they went straight
            // through to the hand behind it and cards were being played through the
            // sheet. This is the thing that actually catches them.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            Panel(fill: Chrome.ground, stroke: Chrome.edge, shade: CardPalette.black) {
                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        ScreenTitle(text: title, size: 30, drop: CardPalette.blue)
                        Spacer(minLength: 12)
                        Button(action: onDismiss) {
                            Chip(fill: CardPalette.red, stroke: CardPalette.gold,
                                 shade: CardPalette.orange, side: 34) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    content
                }
                .padding(20)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
        }
        .transition(.opacity)
    }
}

/// A reading with its label under it, the way the scoreboard says things.
struct StatReadout: View {
    let label: String
    let value: String
    var ink: Color = .white

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.custom(Chrome.display, size: 24))
                .foregroundStyle(ink)
                .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
                .contentTransition(.numericText())
            SmallCapsText(text: label, font: Chrome.display, size: 11, tracking: 1)
                .foregroundStyle(CardPalette.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A heading over a block inside a sheet.
struct SheetHeading: View {
    let text: String

    var body: some View {
        SmallCapsText(text: text, font: Chrome.display, size: 12, tracking: 1.4)
            .foregroundStyle(CardPalette.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
