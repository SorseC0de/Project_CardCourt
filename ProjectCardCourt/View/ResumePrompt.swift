import SwiftUI

/// **A game left behind, offered back.**
///
/// Shown on the way in when the app was killed mid-game: pick it up where it was, or give
/// it up and stay on the title. Nothing else is asked — see `SavedGame`.
struct ResumePrompt: View {
    let saved: GameState
    let onResume: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("GAME IN PROGRESS")
                    .font(.system(size: 13, weight: .black)).tracking(1.6)
                    .foregroundStyle(CardPalette.gold)
                // Where it was left, in the words the game itself uses.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    OrdinalText(number: saved.round, size: 26)
                    Text("Quarter").font(.custom(Chrome.display, size: 26))
                }
                .foregroundStyle(.white)
                Text(score)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                VStack(spacing: 10) {
                    ChunkyButton(title: "RESUME", fill: CardPalette.green,
                                 stroke: CardPalette.green, shade: CardPalette.black,
                                 size: 18, run: onResume)
                    ChunkyButton(title: "QUIT TO TITLE", fill: CardPalette.gray,
                                 stroke: CardPalette.gray, shade: CardPalette.black,
                                 size: 15, run: onQuit)
                }
                .frame(width: 220)
            }
            .padding(26)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CardPalette.navy))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(CardPalette.gold, lineWidth: 2))
            .padding(30)
        }
    }

    /// Everybody's points, so it is recognisably the game you were playing.
    private var score: String {
        Seat.allCases.map { "\(String($0.playerName.prefix(6))) \(saved[$0].points)" }
            .joined(separator: "  ")
    }
}
