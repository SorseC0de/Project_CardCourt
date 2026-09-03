import SwiftUI

/// The top-right readout: what the referees are doing, and the SHOT.
///
/// Pictures rather than words — a struck-through whistle says "silenced" faster than the
/// sentence did, and the referee says he is watching without naming whose trap it is.
///
/// SHOT is always the last element, so its place on screen never shifts as the others
/// come and go. Everything is sized off the ball, and the icons carry the badge's own
/// hard blue drop so the row reads as one instrument.
struct StatusHUDView: View {
    let state: GameState
    var ballSize: CGFloat = 58

    /// Each icon gets its own multiplier. The art is trimmed to its own subject rather
    /// than squared off, so two SVGs at the same width do not read at the same size.
    private var whistleSide: CGFloat { ballSize * 0.50 }
    private var refereeSide: CGFloat { ballSize * 0.60 }
    private var drop: CGFloat { ballSize * 0.06 }

    var body: some View {
        HStack(alignment: .center, spacing: ballSize * 0.16) {
            if state.whistlesSilenced { silenced }
            if !state.armedWhistles.isEmpty { watching }
            ShotBadgeView(shot: state.shot, ballSize: ballSize)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.7),
                   value: state.whistlesSilenced)
        .animation(.spring(response: 0.32, dampingFraction: 0.7),
                   value: state.armedWhistles.isEmpty)
    }

    /// No Whistle can be called this round. The flat icon, struck out.
    private var silenced: some View {
        SlashedMark(side: whistleSide, slash: CardPalette.red) {
            Image("WhistleIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                // Mirrored to match the referee, as everywhere else the icon appears.
                .scaleEffect(x: -1)
                .foregroundStyle(.white)
        }
        .drawingGroup()
        .shadow(color: CardPalette.blue, radius: 0, x: drop, y: drop)
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }

    /// A Whistle is armed. Deliberately says nothing about whose or what it watches for.
    private var watching: some View {
        Image("RefereeIcon")
            .resizable()
            .scaledToFit()
            .frame(width: refereeSide, height: refereeSide)
            .drawingGroup()
            .shadow(color: CardPalette.blue, radius: 0, x: drop, y: drop)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
    }
}
