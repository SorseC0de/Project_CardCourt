import SwiftUI

/// **The board, as four seats rather than four rows of numbers.**
///
/// A panel each, in the seat's own colour: who they are and what they are on, and under
/// that the two cards that say what is true of them right now — the Intangible they are
/// carrying and the Clamp standing on them. One of each: a board you can read at a glance
/// is worth more than a board that holds everything.
///
/// The table's own reading of a card is a tap away on either of them — see
/// `GameView.inspecting`.
struct SeatPanelsView: View {
    let state: GameState
    /// Points already in the state but not yet shown — a three still flying to the board.
    var withheld: (seat: Seat, amount: Int)?
    var onSelect: (CardDescriptor, CGPoint) -> Void = { _, _ in }

    private enum Panel {
        static let corner: CGFloat = 9
        static let rim: CGFloat = 2
        static let gap: CGFloat = 4
        static let pad: CGFloat = 5
        static let name: CGFloat = 12
        static let score: CGFloat = 17
        /// **Twice a crew card**, which is the size every other card in the furniture is
        /// drawn at — see `StatusHUDView.crewCardWidth`.
        static var card: CGFloat { StatusHUDView.crewCardWidth() * 2 }
    }

    /// Your own seat first, then round the table the way the ball goes.
    private var order: [Seat] { GameRules.localSeat.clockwiseOrderFromHere }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(order, id: \.self) { seat in
                panel(seat)
            }
        }
    }

    private func panel(_ seat: Seat) -> some View {
        let mine = seat == GameRules.localSeat
        return VStack(spacing: Panel.gap) {
            HStack(spacing: 3) {
                SmallCapsText(text: seat.playerName, font: Chrome.display, size: Panel.name,
                              tracking: Panel.name * 0.02)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 0)
                Text("\(shownScore(seat))")
                    .font(.custom(Chrome.display, size: Panel.score))
                    .contentTransition(.numericText())
                    // **Where the points are**, for anything flying to the board — see
                    // `PointsCells`.
                    .background {
                        GeometryReader { geo in
                            let box = geo.frame(in: .named(Chrome.screen))
                            Color.clear.preference(
                                key: PointsCells.self,
                                value: [seat: CGPoint(x: box.midX, y: box.midY)])
                        }
                    }
            }
            .foregroundStyle(.white)
            .shadow(color: CardPalette.black, radius: 0, x: 2, y: 2)

            slot(state[seat].intangibles.first)
            slot(state[seat].clamps.first?.card)
        }
        .padding(Panel.pad)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Panel.corner, style: .continuous)
            .fill(Theme.color(for: seat)))
        // Your own seat is the one wearing the white edge, the way your own row was.
        .overlay(RoundedRectangle(cornerRadius: Panel.corner, style: .continuous)
            .strokeBorder(mine ? .white : CardPalette.navy, lineWidth: Panel.rim))
        .shadow(color: CardPalette.black, radius: 0, x: 2, y: 2)
    }

    /// One card on a seat, or the empty space it would stand in.
    @ViewBuilder private func slot(_ card: CardDescriptor?) -> some View {
        if let card {
            CardFrontView(descriptor: card, displayWidth: Panel.card)
                .overlay {
                    GeometryReader { slot in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let box = slot.frame(in: .global)
                                onSelect(card, CGPoint(x: box.midX, y: box.midY))
                            }
                    }
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            RoundedRectangle(cornerRadius: Panel.card * CardLayout.cornerFraction,
                             style: .continuous)
                .fill(CardPalette.black.opacity(0.35))
                .frame(width: Panel.card, height: Panel.card / CardMetrics.aspect)
        }
    }

    private func shownScore(_ seat: Seat) -> Int {
        state[seat].score - (withheld?.seat == seat ? withheld!.amount : 0)
    }
}

#if DEBUG
#Preview("Seats") {
    var table = Rules.newGame(seed: 7).0
    table[.south].intangibles = [CardLibrary.sniper]
    return SeatPanelsView(state: table)
        .padding(10)
        .background(Theme.sceneGround)
}
#endif
