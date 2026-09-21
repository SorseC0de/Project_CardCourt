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
    /// **What the blocks are showing.** One of the two cards standing on a player, or
    /// the figure he is on — a block has room for one of the three, and a card and a
    /// total fighting over the same corner is what the toggle is for.
    enum Showing: String, CaseIterable {
        case intangibles, clamps, score

        /// The next one round.
        var next: Showing {
            let all = Showing.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }

        /// What the button says it is showing.
        var word: String { rawValue.uppercased() }

        /// The subject printed faintly in an empty slot, for the two that show cards.
        var emptyMark: String? {
            switch self {
            case .intangibles: return "TypeIntangibleFront"
            case .clamps:      return "TypeClampFront"
            case .score:       return nil
            }
        }
    }

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

    /// **A block turned on its own.** Pressing one walks that player through the three;
    /// the toggle under them overrides the lot and puts them back in step, which is what
    /// makes comparing them one press rather than four.
    @State private var turned: [Seat: Showing] = [:]

    private func showing(for seat: Seat) -> Showing { turned[seat] ?? showing }

    private enum Panel {
        static let corner: CGFloat = 9
        static let rim: CGFloat = 2
        static let gap: CGFloat = 4
        static let pad: CGFloat = 5
        /// **Small, because the pixel face is wide.** Every letter is the same width and
        /// there is no condensing it: this is what a long name fits a quarter-screen in.
        static let name: CGFloat = 9
        static let score: CGFloat = 22
        /// The bag count along the bottom edge of a block.
        static let bag: CGFloat = 17
        /// The subject in an empty slot: how much of the slot it takes, and how faint.
        static let emptyMark: CGFloat = 0.6
        static let emptyMarkInk: Double = 0.1
        /// The card in a block, as a share of the block's own width.
        static let card: CGFloat = 0.82
        /// The sum a block opens into.
        static let statLabel: CGFloat = 10
        static let stat: CGFloat = 13
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
        // **The toggle wins.** Whatever anybody turned on their own goes back in step
        // the moment the button under them says what everybody is showing.
        .onChange(of: showing) { turned.removeAll() }
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
                // **No `fixedSize` here.** The pixel face is far wider per letter than
                // the condensed one, and taking its natural width pushed the whole row
                // off the side of the screen — a name shrinks to the room it has.
                StrokedPixelText(text: seat.playerName.uppercased(), size: Panel.name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Spacer(minLength: 0)
                // **What he is on**, lettered the way a card's own $[2X] is: the one
                // figure on the block that is a total rather than a part. Beside his
                // name whatever the block is showing — it is the answer the board is
                // for, and the column under it is the working.
                TwoXMark(size: Panel.score, text: "\(shownScore(seat))")
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

            if !hidesCards {
                if showing(for: seat) == .score {
                    // **Over the slot, not under the block.** The column is what that
                    // space is for while it is up; the placeholder belongs to the cards.
                    sum(seat)
                        .frame(width: card, height: card / CardMetrics.aspect)
                } else {
                    slot(for: seat, width: card)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        // One press walks this block through the three. The toggle underneath puts them
        // all back in step — see `SeatCardsToggle`.
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.18)) {
                turned[seat] = showing(for: seat).next
            }
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
        // **A quarter of the screen each, whoever is in them.** Sized rather than shared
        // out: four blocks dividing whatever is left over come out different widths the
        // moment one of them holds a longer word than the others.
        .frame(width: across, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
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
    }

    /// The one card this block is showing, or the space it would stand in.
    @ViewBuilder private func slot(for seat: Seat, width: CGFloat) -> some View {
        let card: CardDescriptor? = {
            switch showing(for: seat) {
            case .intangibles: return state[seat].intangibles.first
            case .clamps:      return state[seat].clamps.first?.card
            case .score:       return nil
            }
        }()
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
                // **What would stand here**, printed almost out of sight: an empty slot
                // that says what kind of empty it is.
                .overlay {
                    if let mark = showing(for: seat).emptyMark {
                        Image(mark)
                            .resizable()
                            .scaledToFit()
                            .frame(width: width * Panel.emptyMark)
                            .opacity(Panel.emptyMarkInk)
                    }
                }
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
                    //
                    // Set in the same face as the figure beside it: a line of a sum is
                    // one thing, and a label in one lettering against a number in another
                    // reads as two.
                    StrokedPixelText(text: (row.taken ? "-" + row.label : row.label).uppercased(),
                                     size: Panel.statLabel,
                                     ink: row.taken ? Panel.taken : .white)
                        .fixedSize()
                    Spacer(minLength: 0)
                    // Each figure cut out in the pixel face, like every other number
                    // being counted rather than written — see `StrokedPixelText`.
                    StrokedPixelText(text: "\(row.value)", size: Panel.stat,
                                     ink: row.taken ? Panel.taken : .white)
                        .fixedSize()
                }
            }
            // The line a sum is drawn under, in the same ink as the figures over it.
            Rectangle()
                .fill(.white)
                .frame(height: 1.5)
                .padding(.top, 1)
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                StrokedPixelText(text: "\(shownScore(seat))", size: Panel.stat + 3)
                    .fixedSize()
            }
        }
        // **It stands where the card stands**, so it needs no ground of its own and no
        // edge to close it: it was a panel dropping out of the block and is part of it
        // now.
        .padding(.horizontal, Panel.pad + 1)
        .padding(.vertical, Panel.pad)
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

    /// One colour each, so the button says which of the three it is on without reading it.
    private var fill: Color {
        switch showing {
        case .intangibles: return CardPalette.black
        case .clamps:      return CardPalette.red
        case .score:       return CardPalette.navy
        }
    }

    var body: some View {
        Button(action: swap) {
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 11, weight: .black))
                Text(showing.word)
                    .font(.system(size: 10, weight: .black))
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(width: 108, height: 27, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.white, lineWidth: 1.5))
            .shadow(color: CardPalette.gold, radius: 0, x: 2, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Showing \(showing.word.capitalized)")
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
