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
        // Trailing, so the deck sits under the SHOT badge and neither moves when a
        // referee comes or goes on the left of the row.
        VStack(alignment: .trailing, spacing: ballSize * 0.10) {
            HStack(alignment: .center, spacing: ballSize * 0.16) {
                if state.whistlesSilenced { silenced }
                if !state.armedWhistles.isEmpty { watching }
                ShotBadgeView(shot: state.shot, ballSize: ballSize)
            }
            remaining
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.7),
                   value: state.whistlesSilenced)
        .animation(.spring(response: 0.32, dampingFraction: 0.7),
                   value: state.armedWhistles.isEmpty)
    }

    /// How many cards are left, over the pixel deck.
    ///
    /// The number used to sit on the floor under the pile, which stopped working the
    /// moment the pile started flying about. Drawn at the sheet's own size rather than
    /// off `ballSize`: this is pixel art, and half a pixel is worse than a size that does
    /// not quite match its neighbour.
    private var remaining: some View {
        Image("Deck")
            .interpolation(.none)
            .resizable()
            .frame(width: Deck.side, height: Deck.side)
            .overlay {
                Text("\(state.deck.count)")
                    .font(.custom("AvenirNextCondensed-Heavy", size: Deck.number))
                    .foregroundStyle(.white)
                    .shadow(color: CardPalette.blue, radius: 0, x: Deck.drop, y: Deck.drop)
                    .contentTransition(.numericText())
                    .offset(y: -Deck.numberLift)
            }
            .offset(x: Deck.nudgeX)
            .animation(.easeOut(duration: 0.25), value: state.deck.count)
    }

    private enum Deck {
        /// The sheet is 48 pixels square. 64 points is four device pixels per art pixel on
        /// a 3× screen — the sizes that come out exact on 2× as well are only the multiples
        /// of 48, and 96 is far too much deck for a corner of the HUD.
        static let side: CGFloat = 64
        static let number: CGFloat = 18
        static let drop: CGFloat = 3
        /// Out past the badge above it. The row is trailing-aligned, so this is measured
        /// from the SHOT's own right edge.
        static let nudgeX: CGFloat = 8
        /// Off the middle of the sheet — the count reads better sitting on the top card
        /// than centred on the whole stack.
        static let numberLift: CGFloat = 4
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
