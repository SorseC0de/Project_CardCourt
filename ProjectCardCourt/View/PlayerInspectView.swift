import SwiftUI

/// Everything the table can see about one player, on a tap.
///
/// Public information only. The bag is a count and never its contents, and a Whistle set
/// face down belongs to the referees' sheet rather than this one — see
/// `RefereeInspectView`. Your own chair opens the same sheet as anybody else's, because
/// the thing being answered is "where does this player stand", and that question does not
/// change depending on whose it is.
struct PlayerInspectView: View {
    let state: GameState
    let seat: Seat
    var onDismiss: () -> Void

    private enum Figure {
        /// Art pixels per point. Whole numbers only — this is pixel art.
        static let scale: CGFloat = 7
        static let ball: CGFloat = 40
    }

    private var player: PlayerState { state[seat] }
    private var hasBall: Bool { state.ball == seat }

    /// The round it went in, or the fact that nothing has. Written as the table would say
    /// it out loud rather than as a field.
    private var lastMake: String {
        guard let make = player.lastMake else { return "N/A" }
        let when = make.round == state.round ? "This round" : "Round \(make.round)"
        return "\(when) · \(make.chance)%"
    }

    var body: some View {
        InspectSheet(title: seat.playerName, onDismiss: onDismiss) {
            VStack(spacing: 16) {
                // The player is the subject of the sheet, not an icon on it. Big enough
                // to be looked at, with the readings underneath rather than beside.
                figure

                HStack(spacing: 0) {
                    StatReadout(label: "PTS", value: "\(player.points)")
                    StatReadout(label: "AST", value: "\(player.assists)")
                    StatReadout(label: "REB", value: "\(player.rebounds)")
                    StatReadout(label: "TO", value: "\(player.turnovers)",
                                ink: CardPalette.red)
                    StatReadout(label: "Score", value: "\(player.score)",
                                ink: CardPalette.gold)
                    StatReadout(label: "In bag", value: "\(player.bag.count)")
                }

                VStack(spacing: 3) {
                    SheetHeading(text: "Last make")
                    Text(lastMake)
                        .font(.custom(Chrome.display, size: 19))
                        .foregroundStyle(player.lastMake == nil ? CardPalette.gray : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !player.intangibles.isEmpty {
                    VStack(spacing: 6) {
                        SheetHeading(text: "Intangibles")
                        HStack(spacing: 8) {
                            ForEach(player.intangibles) { card in
                                CardFrontView(descriptor: card, displayWidth: 46)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !player.clamps.isEmpty {
                    VStack(spacing: 6) {
                        SheetHeading(text: "Clamped by")
                        ClampRosterView(clamps: player.clamps.map(\.brief))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                VStack(spacing: 6) {
                    SheetHeading(text: "Passes")
                    PassCompass(seat: seat)
                }
            }
        }
    }

    /// The front pose, wearing this seat's kit — and the ball beside him if he has it.
    private var figure: some View {
        SpriteAnimation(sprite: .front, scale: Figure.scale, isPlaying: false, restFrame: 0)
            .paletteSwap(PlayerLook.shared.kit(for: seat))
            .overlay(alignment: .topTrailing) {
                if hasBall {
                    BallView(diameter: Figure.ball)
                        .shadow(color: CardPalette.navy, radius: 0, x: 3, y: 3)
                        .offset(x: Figure.ball * 0.6, y: -Figure.ball * 0.2)
                }
            }
    }
}
