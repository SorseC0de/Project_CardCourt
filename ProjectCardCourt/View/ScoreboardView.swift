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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("").frame(width: 74, alignment: .leading)
                ForEach(["PTS", "AST", "REB", "TOV"], id: \.self) { column in
                    Text(column).frame(maxWidth: .infinity)
                }
                Text(totalLabel).frame(width: 34, alignment: .trailing)
            }
            .font(.system(size: 8, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.inkDim)
            .padding(.bottom, 3)

            ForEach(ranked) { player in
                row(player)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.panelRaised)
    }

    private func row(_ player: PlayerState) -> some View {
        let isLocal = player.seat == GameRules.localSeat
        let isCalledOut = highlighted.contains(player.seat)
        let tint = Theme.color(for: player.seat)
        return HStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                Text(PlayerLook.shared.billing(for: player.seat))
                    .font(.system(size: 12, weight: isLocal || isCalledOut ? .bold : .regular))
                    .foregroundStyle(isLocal || isCalledOut ? Theme.ink : Theme.inkDim)
            }
            .frame(width: 74, alignment: .leading)

            ForEach(Array(stats(player).enumerated()), id: \.offset) { column, value in
                StatCell(value: value,
                         accent: Self.accents[column],
                         rest: isCalledOut ? tint : Theme.ink,
                         isCalledOut: isCalledOut)
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
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(isLocal || isCalledOut ? tint : Theme.ink)
                .frame(width: 34, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .padding(.vertical, isCalledOut ? 4 : 2)
        .padding(.horizontal, 6)
        .background {
            if isCalledOut {
                RoundedRectangle(cornerRadius: 6)
                    .fill(tint.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(tint.opacity(0.5), lineWidth: 1))
            }
        }
    }

    /// What each column flashes when it goes up, in the order they are drawn.
    private static let accents: [Color] = [
        CardPalette.gold, CardPalette.blue, CardPalette.green, CardPalette.red,
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
    let accent: Color
    let rest: Color
    let isCalledOut: Bool

    @State private var earned = false

    var body: some View {
        Text("\(value)")
            .font(.system(size: 12, weight: isCalledOut ? .heavy : .medium, design: .rounded))
            .foregroundStyle(earned ? accent : rest)
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
