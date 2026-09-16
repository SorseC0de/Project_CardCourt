import SwiftUI

/// **How many Moves are left before it is a travel.**
///
/// The Move icon's own dashes, made into a gauge. Three of them come off the drawing —
/// see `Move_meter.svg`, which is the subject with its two leading dashes cut away — and
/// the HUD draws three in their place, filling as the possession spends them. What is
/// left is the arrow, so the row reads as one mark: the dashes are the arrow's, and the
/// arrow is the Move.
///
/// Three Moves a possession is a rule of the match rather than something a card brings —
/// see `MatchRules.movesPerPossession` — so this stands whatever the crew is watching for.
struct TravelMeter: View {
    /// How many have been spent.
    var played: Int
    /// How many there is room for. Three, unless an official is working tighter or a ball
    /// has lifted the limit — see `GameState.moveLimit`.
    var limit: Int?

    /// **The width of three cards in a hand.** A three-card fan spreads 21 degrees on a
    /// 300 radius, which puts its outer edges 185 points apart — so the gauge is the width
    /// of the hand it sits over rather than a number picked to look right.
    static let width: CGFloat = 185

    var body: some View {
        HStack(spacing: Dash.gap * scale) {
            ForEach(0..<Dash.count, id: \.self) { index in
                pip(index)
            }
            Image("MoveMeter")
                .resizable()
                .scaledToFit()
                .frame(width: scale, height: scale / Dash.aspect)
        }
    }

    /// Filled where the possession has spent it, and struck out past a limit an official
    /// has tightened — a slot that is no longer there to spend.
    private func pip(_ index: Int) -> some View {
        let spent = index < played
        let beyond = limit.map { index >= $0 } ?? false
        return RoundedRectangle(cornerRadius: Dash.width * scale * Dash.corner,
                                style: .continuous)
            .fill(spent ? CardPalette.gold : PixelPalette.deepTeal)
            .overlay {
                RoundedRectangle(cornerRadius: Dash.width * scale * Dash.corner,
                                 style: .continuous)
                    .strokeBorder(CardPalette.teal, lineWidth: Dash.stroke)
            }
            .frame(width: Dash.width * scale, height: Dash.height * scale)
            .opacity(beyond ? Dash.gone : 1)
    }

    /// The drawing's width, worked back from the row's.
    private var scale: CGFloat {
        Self.width / (1 + CGFloat(Dash.count) * (Dash.width + Dash.gap))
    }

    /// **Measured off the drawing**, as shares of what is left of it once the two dashes
    /// are gone — so the pips are the size the dashes were and stand the distance apart
    /// they stood. See `Tools/icons.py`, which trims the icon to that ink.
    private enum Dash {
        static let count = 3
        static let width: CGFloat = 0.032
        static let height: CGFloat = 0.129
        static let gap: CGFloat = 0.045
        static let aspect: CGFloat = 705.3375 / 448.5802
        static let corner: CGFloat = 0.3
        static let stroke: CGFloat = 1
        /// A slot an official has taken away.
        static let gone: Double = 0.3
    }
}
