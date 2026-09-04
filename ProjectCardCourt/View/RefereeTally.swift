import SwiftUI

/// How many referees are already watching, hung off a Whistle being read.
///
/// A Whistle you are thinking about playing is a decision about the crew: a fourth one on
/// a floor that already has three is a card with nowhere to stand. Never shown at zero —
/// an empty floor has nothing to say about it.
struct RefereeTally: View {
    let count: Int
    var side: CGFloat = 18
    var onOpen: () -> Void = {}

    var body: some View {
        HStack(spacing: side * 0.18) {
            Image("RefereeIcon")
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
            Text("×\(count)")
                .font(.custom(Chrome.display, size: side * 0.78))
                .foregroundStyle(.white)
        }
        .shadow(color: CardPalette.blue, radius: 0, x: side * 0.13, y: side * 0.13)
        .padding(.horizontal, side * 0.34)
        .padding(.vertical, side * 0.16)
        .background(Capsule().fill(CardPalette.navy))
        .overlay(Capsule().strokeBorder(CardPalette.gray, lineWidth: side * 0.11))
        .contentShape(Capsule())
        // High priority, or the fan's own drag swallows it — the card under this is
        // sitting inside a `DragGesture` that plays it.
        .highPriorityGesture(TapGesture().onEnded { onOpen() })
    }
}
