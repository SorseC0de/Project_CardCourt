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
                    Text("Nobody has called for one.")
                        .font(.custom(Chrome.display, size: 17))
                        .foregroundStyle(CardPalette.gray)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(whistles) { whistle in
                            VStack(spacing: 4) {
                                held(whistle)
                                PlayerNameText(seat: whistle.owner, size: 13)
                            }
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

    /// Face up when it is yours, and a back with a question mark when it is not. Never the
    /// card itself for somebody else's — the local state knows what an opponent set down,
    /// and this is the sheet that would give it away.
    private func held(_ whistle: ArmedWhistle) -> some View {
        ZStack {
            if whistle.owner.isLocal {
                CardFrontView(descriptor: whistle.card.descriptor, displayWidth: Held.width)
            } else {
                Image("CardBackFull")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Held.width)
                    .overlay {
                        Text("?")
                            .font(.custom(Chrome.display, size: Held.width * 0.62))
                            .foregroundStyle(.white)
                            .shadow(color: CardPalette.navy, radius: 0, x: 3, y: 3)
                    }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Held.width * CardLayout.cornerFraction,
                             style: .continuous)
                .strokeBorder(Theme.color(for: whistle.owner), lineWidth: Held.stroke)
        }
    }
}
