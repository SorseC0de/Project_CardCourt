import SwiftUI

/// **The board, as four seats rather than four rows of numbers.**
///
/// One block each, flush against its neighbours in the seat's own colour: who they are,
/// what they are on, and under that the one card that says what is true of them right
/// now — the Intangible they carry, or the Clamp standing on them, whichever the floor is
/// being asked for. One of each: a board you can read at a glance is worth more than a
/// board that holds everything.
///
/// **Pressed, a block opens downward** into that player's full line, stacked and added up
/// the way a sum is — the total under a rule at the bottom.
struct SeatPanelsView: View {
    /// Which of a player's two cards the blocks are showing.
    enum Showing: String { case intangibles, clamps }

    let state: GameState
    /// Points already in the state but not yet shown — a three still flying to the board.
    var withheld: (seat: Seat, amount: Int)?
    var showing: Showing = .intangibles
    /// **The cards are down while a card is being read**, since the words of that card
    /// are standing over them — see `GameView`.
    var hidesCards = false
    /// Whose card is being read, if it is anybody's: the others go back while it is up.
    var lit: Seat?
    /// Cards the rules have dealt that the table has not shown arriving — a card still
    /// in the air is not in a hand yet, and the count must not say it is.
    var undelivered: Set<UUID> = []
    var onSelect: (CardDescriptor, CGPoint) -> Void = { _, _ in }

    /// **Whether the lines are out.** All four or none: comparing them is the whole
    /// reason to look, and one column at a time is four presses to do it.
    @State private var opened = false

    private enum Panel {
        static let corner: CGFloat = 9
        static let rim: CGFloat = 2
        static let gap: CGFloat = 4
        static let pad: CGFloat = 5
        static let name: CGFloat = 15
        static let score: CGFloat = 22
        /// The bag count along the bottom edge of a block.
        static let bag: CGFloat = 17
        /// The card in a block, as a share of the block's own width.
        static let card: CGFloat = 0.82
        /// The sum a block opens into.
        static let statLabel: CGFloat = 10
        static let stat: CGFloat = 13
        /// The figure under the rule, which is the point of opening the column.
        static let total: CGFloat = 18
        /// What is taken off the total rather than added to it.
        static let taken = Color(red: 1, green: 0.62, blue: 0.62)
    }

    /// Your own seat first, then round the table the way the ball goes.
    private var order: [Seat] { GameRules.localSeat.clockwiseOrderFromHere }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(order, id: \.self) { seat in
                panel(seat, across: across)
            }
        }
        .frame(height: height)
    }

    /// **One block's width, off the screen's own.** Measured rather than read from a
    /// container: the block's height is worked out from it, and a reader that answers
    /// only after layout left the row the wrong height — which is what let the blocks
    /// hang over the card under them.
    private var across: CGFloat { Self.blockWidth }
    private var height: CGFloat { Self.height }
    private var cardWidth: CGFloat { Self.cardWidth }
    private var cardHeight: CGFloat { Self.cardHeight }

    @MainActor static var blockWidth: CGFloat { Chrome.screenWidth / CGFloat(Seat.allCases.count) }
    @MainActor static var cardWidth: CGFloat { blockWidth * Panel.card }
    @MainActor static var cardHeight: CGFloat { cardWidth / CardMetrics.aspect }

    /// A block's own height: the line of type, the card under it, and the padding.
    @MainActor static var height: CGFloat {
        Panel.pad * 2 + Panel.score * 1.2 + Panel.gap + cardHeight
    }

    /// **The band under the name row**, which is where a card's words stand while one is
    /// being read: it begins under the names and ends where the blocks do, so what it
    /// covers is exactly what the blocks' own cards were standing in.
    @MainActor static var readingBand: CGFloat { Panel.gap + cardHeight + Panel.pad }

    private func panel(_ seat: Seat, across: CGFloat) -> some View {
        let mine = seat == GameRules.localSeat
        let card = across * Panel.card
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
                        GeometryReader { box in
                            let frame = box.frame(in: .named(Chrome.screen))
                            Color.clear.preference(
                                key: PointsCells.self,
                                value: [seat: CGPoint(x: frame.midX, y: frame.midY)])
                        }
                    }
            }
            .foregroundStyle(.white)
            .shadow(color: CardPalette.black, radius: 0, x: 2, y: 2)

            if !hidesCards { slot(for: seat, width: card) }
            Spacer(minLength: 0)
        }
        .padding(Panel.pad)
        // **How many cards he is holding**, along the bottom edge of his own block. It
        // hung over his head on the floor, where it had his name and his Clamps to stay
        // clear of.
        .overlay(alignment: .bottom) {
            if !hidesCards {
                HandCountBadge(count: state[seat].bag.count { !undelivered.contains($0.id) },
                               side: Panel.bag)
                    .padding(.bottom, Panel.pad)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.color(for: seat))
        // Whoever's card is being read keeps the light; the rest stand back.
        .saturation(lit == nil || lit == seat ? 1 : 0.35)
        .opacity(lit == nil || lit == seat ? 1 : 0.55)
        // Your own block is the one wearing the white edge, as your own row did.
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(mine ? .white : .clear)
                .frame(height: Panel.rim)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { opened.toggle() }
        }
        // **Opened downward**, over the floor rather than pushing it: the overlay's top
        // is pinned to the block's bottom edge.
        .overlay(alignment: .bottom) {
            if opened {
                sum(seat)
                    .alignmentGuide(VerticalAlignment.bottom) { $0[.top] }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .zIndex(opened ? 1 : 0)
    }

    /// The one card this block is showing, or the space it would stand in.
    @ViewBuilder private func slot(for seat: Seat, width: CGFloat) -> some View {
        let card = showing == .intangibles
            ? state[seat].intangibles.first
            : state[seat].clamps.first?.card
        if let card {
            CardFrontView(descriptor: card, displayWidth: width)
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
            RoundedRectangle(cornerRadius: width * CardLayout.cornerFraction,
                             style: .continuous)
                .fill(CardPalette.black.opacity(0.3))
                .frame(width: width, height: width / CardMetrics.aspect)
        }
    }

    /// **The player's line, added up.** Each figure on its own row, then a rule, then the
    /// total under it — a sum rather than a table.
    private func sum(_ seat: Seat) -> some View {
        let player = state[seat]
        return VStack(spacing: 2) {
            ForEach(Array(Self.line(player).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    // **The minus belongs to the line, not to the figure.** It is the
                    // turnovers that come off, and "-2" read as a count of minus two.
                    SmallCapsText(text: row.taken ? "-" + row.label : row.label,
                                  font: Chrome.display,
                                  size: Panel.statLabel, tracking: Panel.statLabel * 0.1)
                        .foregroundStyle(row.taken ? Panel.taken : .white.opacity(0.8))
                    Spacer(minLength: 0)
                    Text("\(row.value)")
                        .font(.custom(Chrome.display, size: Panel.stat))
                        .foregroundStyle(row.taken ? Panel.taken : .white)
                }
            }
            Rectangle()
                .fill(.white)
                .frame(height: 1.5)
                .padding(.top, 1)
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                // The figure the whole column adds up to, lettered the way a card's own
                // $[2X] is — the one number here that is not a component.
                TwoXMark(size: Panel.total, text: "\(shownScore(seat))")
            }
        }
        // Black under every figure, which is what makes a light number on a seat's own
        // colour readable — the drop the names already wear.
        .shadow(color: CardPalette.black, radius: 0, x: 1.5, y: 1.5)
        .padding(.horizontal, Panel.pad + 1)
        .padding(.vertical, Panel.pad)
        .background(Theme.color(for: seat))
        .overlay(alignment: .bottom) {
            Rectangle().fill(CardPalette.navy).frame(height: 1)
        }
        .shadow(color: CardPalette.black.opacity(0.5), radius: 4, y: 3)
    }

    /// What a line is made of, in the order it is added up. Turnovers come off it, which
    /// is why the total is a sum rather than four numbers side by side.
    private static func line(_ player: PlayerState)
    -> [(label: String, value: Int, taken: Bool)] {
        [("Pts", player.points, false), ("Ast", player.assists, false),
         ("Reb", player.rebounds, false), ("Tov", player.turnovers, true)]
    }

    private func shownScore(_ seat: Seat) -> Int {
        state[seat].score - (withheld?.seat == seat ? withheld!.amount : 0)
    }
}

/// **What the blocks are showing.** Intangibles or Clamps, one press apart, and standing
/// directly under the blocks it changes rather than down among the shot controls.
struct SeatCardsToggle: View {
    let showing: SeatPanelsView.Showing
    let swap: () -> Void

    var body: some View {
        let intangibles = showing == .intangibles
        Button(action: swap) {
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 11, weight: .black))
                Text(intangibles ? "INTANGIBLES" : "CLAMPS")
                    .font(.system(size: 10, weight: .black))
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(width: 108, height: 27, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(intangibles ? CardPalette.black : CardPalette.red))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.white, lineWidth: 1.5))
            .shadow(color: CardPalette.gold, radius: 0, x: 2, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(intangibles ? "Showing Intangibles" : "Showing Clamps")
    }
}

#if DEBUG
#Preview("Seats") {
    var table = Rules.newGame(seed: 7).0
    table[.south].intangibles = [CardLibrary.sniper]
    return VStack {
        SeatPanelsView(state: table)
        Spacer()
    }
    .background(Theme.sceneGround)
}
#endif
