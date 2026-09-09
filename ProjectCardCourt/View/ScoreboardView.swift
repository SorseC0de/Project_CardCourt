import SwiftUI

/// Where each row's PTS cell sits, in the screen's own space.
///
/// Reported rather than worked out. The three's celebration flew its number to
/// `(78, 96 + 24 × row)` — the board's rough shape written down as arithmetic — which
/// lands near the right cell and not on it, and stops being true the moment a row's
/// height or the board's place changes.
struct PointsCells: PreferenceKey {
    static let defaultValue: [Seat: CGPoint] = [:]
    static func reduce(value: inout [Seat: CGPoint], nextValue: () -> [Seat: CGPoint]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// **The board, built out of the menus' own pieces.**
///
/// It used to be a table: hairline columns, system type, two greys. Everything else in
/// the game is flat colour with a heavy rim and a hard drop — see `Chrome` — and a
/// scoreboard drawn as a spreadsheet was the one place the game stopped looking like
/// itself.
///
/// **A row is a slab.** `black` rather than navy: it is the palette's tone for a surface
/// that has to sit *beside* the dark rather than under it, which is exactly what a row on
/// the game screen's ground is. The rim says who the row is — grey for a table you are
/// only watching, your own seat's colour for yours — and a called-out row drops the black
/// and is filled with the seat outright.
///
/// **Everything is a share of `Board.row`.** The board is glanced at over the court at
/// one size and read on the results screen at another, and one number moving its weight
/// is the whole reason the kit is written this way.
struct ScoreboardView: View {
    let state: GameState
    /// Points already in the state but not yet shown — a three still flying to the board.
    var withheld: (seat: Seat, amount: Int)?
    /// Rows to call out — the winners, on the results screen.
    var highlighted: Set<Seat> = []
    /// What the last column is called. Blank in play, where the board is glanced at and
    /// the big number on the right needs no telling; named on the results screen, which
    /// is read rather than glanced at.
    var totalLabel = ""
    /// **How tall one row is, which is the only number this view is set by.**
    ///
    /// Glanced at over a live court at one size and read on the results screen at
    /// another. Everything else is a share of it, so the board changes weight as one
    /// thing rather than as thirteen.
    var row: CGFloat = 26

    /// The board's weights, all off the height of one row.
    ///
    /// The kit's own six-point rim and six-point drop are right on a lobby chair and far
    /// too heavy on a strip four rows tall over a live court, so they are taken as shares
    /// here rather than as the constants — the same thing `Chip` does.
    private struct Board {
        let row: CGFloat
        var rim: CGFloat { row * 0.08 }
        var drop: CGFloat { row * 0.09 }
        var corner: CGFloat { row * 0.28 }
        var gap: CGFloat { row * 0.15 }
        /// The seat's square at the head of a row.
        var seat: CGFloat { row * 0.52 }
        var name: CGFloat { row * 0.56 }
        var stat: CGFloat { row * 0.52 }
        var total: CGFloat { row * 0.76 }
        var label: CGFloat { row * 0.36 }
        /// The name column, wide enough for a billing at its own size.
        var billing: CGFloat { row * 3.0 }
        /// The score column.
        var score: CGFloat { row * 1.4 }
        /// The whole of the left-hand column: the seat's square, the air after it, and
        /// the billing. Written once because the header has to line up with it.
        var head: CGFloat { seat + gap + billing }
    }

    private var board: Board { Board(row: row) }

    /// Ordered by the score on screen, not the one in state — so a three that is still
    /// flying has not reordered the board yet either.
    private var ranked: [PlayerState] {
        state.players.sorted {
            (shownScore($0), shownPoints($0)) > (shownScore($1), shownPoints($1))
        }
    }

    private func shownScore(_ p: PlayerState) -> Int {
        p.score - (withheld?.seat == p.seat ? withheld!.amount : 0)
    }

    var body: some View {
        VStack(spacing: board.gap) {
            header
            ForEach(ranked) { player in
                row(player)
            }
        }
        .padding(.horizontal, board.gap * 2)
        .padding(.vertical, board.gap * 1.5)
        // **The screen's own ground, not the menus' navy.** The board is a band between
        // the status bar and the log, both of which stand on `Theme.panel`; a navy strip
        // between two grey ones read as a third thing wedged in. The rows do the work.
        .background(Theme.panel)
    }

    /// What the columns are. Small caps in the rim's own grey, so the labels read as part
    /// of the furniture rather than as more numbers.
    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: board.head, height: 1)
            ForEach(Self.columns, id: \.self) { column in
                SmallCapsText(text: column, font: Chrome.display, size: board.label,
                              tracking: board.label * 0.12)
                    .frame(maxWidth: .infinity)
            }
            SmallCapsText(text: totalLabel, font: Chrome.display, size: board.label,
                          tracking: board.label * 0.12)
                .frame(width: board.score, alignment: .trailing)
        }
        .foregroundStyle(Chrome.edge)
    }

    private func row(_ player: PlayerState) -> some View {
        let isLocal = player.seat == GameRules.localSeat
        let isCalledOut = highlighted.contains(player.seat)
        let tint = Theme.color(for: player.seat)
        // A called-out row is the seat itself, wearing the gold rim and orange drop every
        // other thing being offered in this game wears. The rest are black slabs, rimmed
        // in their own colour if you are sitting in them and in grey if you are not.
        let fill = tint//isCalledOut ? tint : CardPalette.black
        let rim = isCalledOut ? CardPalette.gold : (isLocal ? tint : CardPalette.black)
        let shade = isCalledOut ? CardPalette.orange : CardPalette.black
        let headScale = 3.0

        return HStack(spacing: 0) {
            HStack(spacing: board.gap) {
                // The seat, as a square rather than a dot: everything else with an edge
                // in this game is a rounded rectangle, and a circle read as a bullet.
                //
                // Navy on a called-out row, where the row is already the seat's colour
                // and a square of it would be a square of nothing.
                /*RoundedRectangle(cornerRadius: board.seat * Chrome.corner * 2)
                    .fill(isCalledOut ? CardPalette.navy : tint)
                    .frame(width: board.seat, height: board.seat)
                    .overlay(RoundedRectangle(cornerRadius: board.seat * Chrome.corner * 2)
                        .strokeBorder(isCalledOut ? CardPalette.gold : CardPalette.navy,
                                      lineWidth: board.rim))*/
                SpriteAnimation(sprite: .heads, scale: headScale, isPlaying: false,
                                restFrame: PlayerLook.shared.face(for: player.seat))
                .paletteSwap(PlayerLook.shared.skin(for: player.seat))
                SmallCapsText(text: PlayerLook.shared.billing(for: player.seat),
                              font: Chrome.display, size: board.name,
                              tracking: board.name * 0.02)
                    .foregroundStyle(.white)
                    .shadow(color: CardPalette.navy, radius: 0,
                            x: board.drop * 0.5, y: board.drop * 0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .frame(width: board.head, alignment: .leading)

            ForEach(Array(stats(player).enumerated()), id: \.offset) { column, value in
                // **White with a hard navy drop, on every row.** Navy ink on a called-out
                // row was legible and quiet, and the row it sits on is the loudest thing
                // on the screen — the same pair every saturated fill in this game is
                // lettered with.
                StatCell(value: value,
                         size: board.stat,
                         accent: Self.accents[column],
                         rest: .white,
                         drop: CardPalette.navy)
                    // **Where the points actually are.** Anything flying to the board
                    // aims at the cell it is going to change, rather than at a place the
                    // cell is usually near — see `PointsCells`.
                    .background {
                        if column == 0 {
                            GeometryReader { geo in
                                let box = geo.frame(in: .named(Chrome.screen))
                                Color.clear.preference(
                                    key: PointsCells.self,
                                    value: [player.seat: CGPoint(x: box.midX, y: box.midY)])
                            }
                        }
                    }
            }

            Text("\(shownScore(player))")
                .font(.custom(Chrome.display, size: board.total))
                // **White, with the seat's colour behind it.** The score is the number
                // the board is read for, and a seat's colour on a black row is the
                // dimmest thing on it — blue and red especially. So the colour moves to
                // the drop, which is the rule everywhere else in this game: a drop is a
                // second colour, not a darker one. Navy behind a called-out row, whose
                // own fill is the seat already.
                .foregroundStyle(.white)
                .shadow(color: isCalledOut ? CardPalette.navy : tint, radius: 0,
                        x: board.drop * 0.6, y: board.drop * 0.6)
                .frame(width: board.score, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, board.gap * 1.5)
        .frame(height: board.row)
        .background(RoundedRectangle(cornerRadius: board.corner).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: board.corner)
            .strokeBorder(rim, lineWidth: board.rim))
        .compositingGroup()
        .shadow(color: shade, radius: 0, x: board.drop, y: board.drop)
    }

    private static let columns = ["PTS", "AST", "REB", "TOV"]

    /// What each column flashes when it goes up, in the order they are drawn.
    private static let accents: [Color] = [
        CardPalette.gold, CardPalette.lightBlue, CardPalette.green, CardPalette.red,
    ]

    private func stats(_ p: PlayerState) -> [Int] {
        [shownPoints(p), p.assists, p.rebounds, p.turnovers]
    }

    private func shownPoints(_ p: PlayerState) -> Int {
        guard let withheld, withheld.seat == p.seat else { return p.points }
        return p.points - withheld.amount
    }
}


/// One stat, which plumps and flashes its own colour as it is earned.
///
/// Owns its own animation rather than being driven from the board, so a cell only reacts
/// when its own number moves — a rebound cannot make the points twitch.
private struct StatCell: View {
    let value: Int
    let size: CGFloat
    let accent: Color
    let rest: Color
    /// The hard drop under the figure, and nothing at all on a called-out row where the
    /// ink is navy already.
    let drop: Color

    @State private var earned = false

    var body: some View {
        Text("\(value)")
            .font(.custom(Chrome.display, size: size))
            .foregroundStyle(earned ? accent : rest)
            .shadow(color: drop, radius: 0, x: size * 0.08, y: size * 0.08)
            .scaleEffect(earned ? 1.6 : 1)
            .frame(maxWidth: .infinity)
            .contentTransition(.numericText())
            .onChange(of: value) { previous, current in
                // Only upward. A stat that drops is a correction, not something earned.
                guard current > previous else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { earned = true }
                Task { @MainActor in
                    // Held long enough to be seen. A stat is earned once a round at most,
                    // so it can afford to sit there.
                    try? await Task.sleep(for: .milliseconds(900))
                    withAnimation(.easeOut(duration: 0.6)) { earned = false }
                }
            }
    }
}

#if DEBUG
/// A table part-way through a round, so every column has something in it.
private let previewTable = GameState(
    rules: .classic,
    players: [PlayerState(seat: .south, points: 12, assists: 3, rebounds: 4, turnovers: 1),
              PlayerState(seat: .west, points: 9, assists: 5, rebounds: 2, turnovers: 2),
              PlayerState(seat: .north, points: 8, assists: 2, rebounds: 6, turnovers: 3),
              PlayerState(seat: .east, points: 4, assists: 1, rebounds: 3, turnovers: 4)],
    rng: SeededRNG(seed: 1))

#Preview("Scoreboard") {
    let table = previewTable
    VStack(spacing: 30) {
        // Over the court, where it is glanced at.
        ScoreboardView(state: table)
        // And on the results screen, read, with the winner called out.
        ScoreboardView(state: table, highlighted: [.south], totalLabel: "SCORE", row: 34)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 26)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.panel)
}
#endif
