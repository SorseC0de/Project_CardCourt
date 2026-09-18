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

    /// **How tall the row stands — the one number the rest is read off.**
    ///
    /// It was sized the other way round, stretched to 185 points wide, and that is what
    /// made the arrow enormous: the drawing's dashes are a sliver of its width, so filling
    /// the row put 150 points of arrow beside 5-point pips. The pips are the reading, so
    /// they set the size now, and the arrow stands the same height beside them.
    static let height: CGFloat = 22

    var body: some View {
        HStack(spacing: Self.height * Dash.gap / Dash.height) {
            ForEach(0..<Dash.count, id: \.self) { index in
                pip(index)
            }
            Image("MoveMeter")
                .resizable()
                .scaledToFit()
                .frame(width: Self.height * Dash.aspect, height: Self.height)
        }
    }

    /// Filled where the possession has spent it, and struck out past a limit an official
    /// has tightened — a slot that is no longer there to spend.
    private func pip(_ index: Int) -> some View {
        let spent = index < played
        let beyond = limit.map { index >= $0 } ?? false
        // Each pip keeps the shape of the dash it stands in for — its own width to height —
        // at the row's height.
        let wide = Self.height * Dash.width / Dash.height
        return RoundedRectangle(cornerRadius: wide * Dash.corner, style: .continuous)
            .fill(spent ? CardPalette.gold : PixelPalette.deepTeal)
            .overlay {
                RoundedRectangle(cornerRadius: wide * Dash.corner, style: .continuous)
                    .strokeBorder(CardPalette.teal, lineWidth: Dash.stroke)
            }
            .frame(width: wide, height: Self.height)
            .opacity(beyond ? Dash.gone : 1)
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
