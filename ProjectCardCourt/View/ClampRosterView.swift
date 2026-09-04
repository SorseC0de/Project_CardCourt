import SwiftUI

/// Who is on you, held up as the possession opens.
///
/// A Clamp is set before the ball reaches the man it lands on, so by the time he has it
/// the cards that did it are already spent and gone from the table. This is the only
/// place they are shown together, and each one is ringed and named so the answer to
/// "who did this" is on the card rather than somewhere in the log.
struct ClampRosterView: View {
    let clamps: [ClampBrief]

    private enum Roster {
        static let cardWidth: CGFloat = 46
        static let gap: CGFloat = 10
        /// Thick on purpose. This is a jersey, not a hairline.
        static let stroke: CGFloat = 4
        static let nameSize: CGFloat = 13
    }

    var body: some View {
        HStack(alignment: .top, spacing: Roster.gap) {
            ForEach(clamps) { clamp in
                VStack(spacing: 4) {
                    CardFrontView(descriptor: clamp.card, displayWidth: Roster.cardWidth)
                        .overlay {
                            RoundedRectangle(cornerRadius: Roster.cardWidth
                                                           * CardLayout.cornerFraction,
                                             style: .continuous)
                                .strokeBorder(Theme.color(for: clamp.from),
                                              lineWidth: Roster.stroke)
                        }
                    PlayerNameText(seat: clamp.from, size: Roster.nameSize)
                }
            }
        }
        .fixedSize()
    }
}
