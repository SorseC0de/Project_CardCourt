import SwiftUI

/// The crew on the floor, and what they are holding.
///
/// One sheet for all of them, because a referee is not a person here — he is the fact
/// that a Whistle is armed, and there is one of him per armed Whistle. Yours are face up
/// to be read again; everybody else's is a back with a question mark, which is the whole
/// point of a trap.
struct RefereeInspectView: View {
    let state: GameState
    var onDismiss: () -> Void

    private var whistles: [ArmedWhistle] { state.armedWhistles }

    var body: some View {
        InspectSheet(title: whistles.count == 1 ? "Referee" : "Referees",
                     onDismiss: onDismiss) {
            VStack(spacing: 16) {
                Image("RefereeIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96)
                    .shadow(color: CardPalette.blue, radius: 0, x: 3, y: 3)

                if whistles.isEmpty {
                    Text("No crew is working.")
                        .font(.custom(Chrome.display, size: 17))
                        .foregroundStyle(CardPalette.gray)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(whistles) { whistle in
                            held(whistle)
                        }
                    }
                }
            }
        }
    }

    private enum Held {
        static let width: CGFloat = 60
        static let stroke: CGFloat = 4
    }

    /// **Face up, always.** A referee is not a trap somebody set: the crew is dealt out
    /// of the officials deck at the top of the round and everybody plays under it, so the
    /// whole point is being able to read what they are watching for.
    private func held(_ whistle: ArmedWhistle) -> some View {
        CardFrontView(descriptor: whistle.card.descriptor, displayWidth: Held.width)
            .overlay {
                RoundedRectangle(cornerRadius: Held.width * CardLayout.cornerFraction,
                                 style: .continuous)
                    .strokeBorder(CardFace.whistle.colour.colour, lineWidth: Held.stroke)
            }
    }
}
