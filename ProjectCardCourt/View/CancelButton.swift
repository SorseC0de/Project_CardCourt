import SwiftUI

/// **Taking it back.**
///
/// Every question the game asks before it resolves anything wears this: a card held up
/// waiting for a target, a payment being counted out of the hand, a "you may" nobody
/// wants. One mark for one meaning — the word CANCEL was doing the job in three
/// different sizes of type.
struct CancelButton: View {
    var side: CGFloat = Mark.side
    let press: () -> Void

    enum Mark {
        static let side: CGFloat = 34
        /// The drop it casts, in points. Hard, like everything else on the floor.
        static let drop: CGFloat = 2
    }

    var body: some View {
        Button(action: press) {
            Image("CancelButton")
                .interpolation(.none)
                .resizable()
                .frame(width: side, height: side)
                .shadow(color: CardPalette.black, radius: 0, x: Mark.drop, y: Mark.drop)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cancel")
    }
}

#if DEBUG
#Preview("Cancel") {
    HStack(spacing: 20) {
        CancelButton {}
        CancelButton(side: 64) {}
    }
    .padding(24)
    .background(Theme.sceneGround)
}
#endif
