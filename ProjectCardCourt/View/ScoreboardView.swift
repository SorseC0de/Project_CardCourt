import SwiftUI

struct ScoreboardView: View {
    let state: GameState
    /// Points already in the state but not yet shown — a three still flying to the board.
    var withheld: (seat: Seat, amount: Int)?
    /// Rows to call out — the winners, on the results screen.
    var highlighted: Set<Seat> = []

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
                Text("").frame(width: 34, alignment: .trailing)
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
        let isHuman = player.seat == GameRules.humanSeat
        let isCalledOut = highlighted.contains(player.seat)
        let tint = Theme.color(for: player.seat)
        return HStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                Text(player.seat.playerName)
                    .font(.system(size: 12, weight: isHuman || isCalledOut ? .bold : .regular))
                    .foregroundStyle(isHuman || isCalledOut ? Theme.ink : Theme.inkDim)
            }
            .frame(width: 74, alignment: .leading)

            ForEach(Array(stats(player).enumerated()), id: \.offset) { _, value in
                Text("\(value)")
                    .font(.system(size: 12, weight: isCalledOut ? .heavy : .medium, design: .rounded))
                    .foregroundStyle(isCalledOut ? tint : Theme.ink)
                    .frame(maxWidth: .infinity)
            }

            Text("\(shownScore(player))")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(isHuman || isCalledOut ? tint : Theme.ink)
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

    private func stats(_ p: PlayerState) -> [Int] {
        [shownPoints(p), p.assists, p.rebounds, p.turnovers]
    }

    private func shownPoints(_ p: PlayerState) -> Int {
        guard let withheld, withheld.seat == p.seat else { return p.points }
        return p.points - withheld.amount
    }
}
