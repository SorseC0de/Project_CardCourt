import SwiftUI

/// Where the deck count sits against the deck.
///
/// Two arrangements, both dialled in by eye rather than derived, which is why they are
/// written out rather than computed from one another.
///
/// `x` and `y` move the icon and the count together — the count is an overlay on the deck
/// and rides with it — so `textX` and `textY` are the count's place *on* the deck, not on
/// the screen.
enum DeckReadout: String, CaseIterable {
    /// The count on the deck, the way a dealer's hand covers the cards under it.
    case over
    /// The count out beside it, with a smaller deck. Reads faster at a glance and takes
    /// more room.
    case beside

    static let setting = "hud.deckReadout"

    /// The sheet is two cells stacked: the deck from above, and the deck from the side.
    static let cells = 2

    struct Metrics {
        var x: CGFloat
        var y: CGFloat
        var side: CGFloat
        var textX: CGFloat
        var textY: CGFloat
        var number: CGFloat
        /// Which of the sheet's cells this arrangement wears.
        var cell: Int = 0
        /// Turns the sheet only. The count is laid on afterwards and stays upright.
        var rotation: Double = 0
    }

    var metrics: Metrics {
        switch self {
        case .over:
            // The side-on cell, so a count sitting on the deck sits on something with a
            // face to sit on. Drawn upright — the turn was only ever standing in for a
            // sprite that did not exist yet.
            return Metrics(x: -4, y: -4, side: 48, textX: 0, textY: -2, number: 14, cell: 1)
        case .beside:
            return Metrics(x: -30, y: 2, side: 34, textX: 30, textY: -4, number: 18)
        }
    }

    var next: DeckReadout { self == .over ? .beside : .over }
}

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

    /// Which way the count is arranged against the deck. A setting, so it is kept.
    @AppStorage(DeckReadout.setting) private var layout = DeckReadout.beside

    private var readout: DeckReadout.Metrics { layout.metrics }

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
        sheet
            // Before the overlay, so the deck turns and the count does not. The frame is
            // square, so a right angle costs no layout.
            .rotationEffect(.degrees(readout.rotation))
            .overlay {
                Text("\(state.deck.count)")
                    .font(.custom("AvenirNextCondensed-Heavy", size: readout.number))
                    .foregroundStyle(.white)
                    .shadow(color: CardPalette.blue, radius: 0, x: Deck.drop, y: Deck.drop)
                    .contentTransition(.numericText())
                    .offset(x: readout.textX, y: readout.textY)
            }
            .offset(x: readout.x, y: readout.y)
            .animation(.easeOut(duration: 0.25), value: state.deck.count)
            .animation(.easeOut(duration: 0.25), value: layout)
    }

    /// One cell of the deck sheet, cut out the way `SpriteAnimation` cuts a frame —
    /// drawn at full height behind a clip rather than scaled, so the art stays exact.
    private var sheet: some View {
        Image("Deck")
            .interpolation(.none)
            .resizable()
            .frame(width: readout.side,
                   height: readout.side * CGFloat(DeckReadout.cells))
            .offset(y: -CGFloat(readout.cell) * readout.side)
            .frame(width: readout.side, height: readout.side, alignment: .top)
            .clipped()
    }

    private enum Deck {
        static let drop: CGFloat = 3
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
