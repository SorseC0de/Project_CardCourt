import SwiftUI

/// One cell of the deck sheet, cut out the way `SpriteAnimation` cuts a frame — drawn at
/// full height behind a clip rather than scaled, so the art stays exact.
///
/// Anything drawing the deck goes through here, because the sheet has two cells and an
/// `Image("Deck")` on its own gets both of them squashed into one square.
struct DeckGlyph: View {
    /// Cell 0 is the deck standing on edge — portrait, and the default. Cell 1 is the
    /// same deck lying down, which only the `over` readout wants.
    var cell: Int = 0
    /// **Which deck.** The main deck is the first column; the officials deck, in its
    /// stripes, is the second.
    var deck: Which = .main
    var side: CGFloat

    enum Which: Int { case main, officials }

    /// The sheet's columns: one per deck.
    static let columns = 2

    var body: some View {
        Image("Deck")
            .interpolation(.none)
            .resizable()
            .frame(width: side * CGFloat(Self.columns),
                   height: side * CGFloat(DeckReadout.cells))
            .offset(x: -CGFloat(deck.rawValue) * side, y: -CGFloat(cell) * side)
            .frame(width: side, height: side, alignment: .topLeading)
            .clipped()
    }
}

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
            // The lying-down cell, so a count sitting on the deck has a face to sit on. Drawn upright — the turn was only ever standing in for a
            // sprite that did not exist yet.
            return Metrics(x: -4, y: -4, side: 48, textX: 0, textY: -2, number: 14, cell: 1,
                           rotation: 30)
        case .beside:
            return Metrics(x: -30, y: 2, side: 34, textX: 30, textY: -4, number: 18,
                           rotation: 30)
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
    /// What the board should read, which is not always what the rules have already
    /// decided — see `GameController.shownShot`. Defaults to the live number for anything
    /// drawn outside a beat.
    var shot: Int?
    /// What the pile should read — see `GameController.shownDeck`.
    var deck: Int?
    var ballSize: CGFloat = 58
    /// Tapping the referee opens the crew's sheet, the same as tapping one on the floor.
    /// **One official, raised from where he sits.** Each card in the crew row opens itself,
    /// the way a passive in the slots does — no sheet of all three in between, since you
    /// tapped the one you wanted to read.
    var onInspectReferee: (CardDescriptor, CGPoint) -> Void = { _, _ in }
    /// The spent pile, opened — see `DiscardBrowserView`. Handed the mark's own frame,
    /// so the cards fan out of the thing that was pressed.
    var onOpenDiscard: (CGRect) -> Void = { _ in }
    /// **Spread across the screen** — the main HUD: SHOT and the deck count in the
    /// middle, the crew and the two decks to the right of them. Off, it is the one row it
    /// always was.
    var spread = false

    /// Which way the count is arranged against the deck. A setting, so it is kept.
    @AppStorage(DeckReadout.setting) private var layout = DeckReadout.beside

    private var readout: DeckReadout.Metrics { layout.metrics }
    /// Where the spent pile's mark is standing, for the fan-out — see `iMAPicker`.
    @State private var discardFrame: CGRect = .zero

    /// Never over the ceiling — Med Ball's 50 included, whatever the holder carries.
    private var shownShot: Int { min(shot ?? state.shot, state.baseShotCeiling) }

    /// Each icon gets its own multiplier. The art is trimmed to its own subject rather
    /// than squared off, so two SVGs at the same width do not read at the same size.
    private var whistleSide: CGFloat { ballSize * 0.50 }
    private var refereeSide: CGFloat { ballSize * 0.60 }
    private var drop: CGFloat { ballSize * 0.06 }

    var body: some View {
        if spread { spreadOut } else { row }
    }

    /// **The two piles and the crew, in the bar along the top.** The decks stand one over
    /// the other, the main one first, and the officials working the round are drawn big
    /// enough to be read where they stand rather than tapped open to be.
    private var spreadOut: some View {
        HStack(alignment: .center, spacing: ballSize * 0.24) {
            // What is left to draw and what has already been spent, together at the head
            // of the bar — the two halves of one pile. The officials' deck keeps the far
            // end to itself.
            // The two halves of one pile, close enough together to read as a pair —
            // the room between the two *decks* is what `Deck.pair` is for, and it left a
            // hole here that looked like the spacer.
            HStack(alignment: .center, spacing: ballSize * 0.16) {
                remaining
                discarded
            }
            Spacer(minLength: 0)
            officialsRemaining
            HStack(alignment: .center, spacing: ballSize * 0.16) {
                if owed > 0 { pending }
                if state.freeRebound[GameRules.localSeat] != nil { calledGlass }
                if state.whistlesSilenced { silenced }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.7),
                   value: state.whistlesSilenced)
        .animation(.spring(response: 0.32, dampingFraction: 0.7),
                   value: state.armedWhistles.isEmpty)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: owed)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: state.freeRebound)
    }

    /// **The officials deck, counted the way the main deck is** — its own striped deck,
    /// with a card-black drop under the number.
    private var officialsRemaining: some View {
        DeckGlyph(cell: readout.cell, deck: .officials, side: readout.side)
            .background {
                GeometryReader { box in
                    let screen = box.frame(in: .named(Chrome.screen))
                    Color.clear.preference(key: OfficialsPoint.self,
                                           value: CGPoint(x: screen.midX, y: screen.midY))
                }
            }
            .rotationEffect(.degrees(readout.rotation))
            .offset(x: -Deck.tilt, y: -Deck.tilt)
            .overlay {
                // **Its own width.** An overlay is offered the frame it sits on, and a
                // mark that letters wider than a deck glyph was being cut off inside it.
                TwoXMark(size: readout.number, text: "\(state.officials.count)")
                    .fixedSize()
                    .offset(x: readout.textX, y: readout.textY)
            }
            .offset(x: readout.x, y: readout.y)
            .animation(.easeOut(duration: 0.25), value: state.officials.count)
    }

    private var row: some View {
        // Trailing, so the deck sits under the SHOT badge and neither moves when a
        // referee comes or goes on the left of the row.
        VStack(alignment: .trailing, spacing: ballSize * 0.10) {
            HStack(alignment: .center, spacing: ballSize * 0.16) {
                if owed > 0 { pending }
                if state.freeRebound[GameRules.localSeat] != nil { calledGlass }
                if state.whistlesSilenced { silenced }
                if !state.armedWhistles.isEmpty { crew }
                ShotBadgeView(shot: shownShot, ballSize: ballSize,
                              hidden: !state.canReadShot(GameRules.localSeat))
                    .tutorialTarget(.shotHUD)
            }
            remaining
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.7),
                   value: state.whistlesSilenced)
        .animation(.spring(response: 0.32, dampingFraction: 0.7),
                   value: state.armedWhistles.isEmpty)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: owed)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: state.freeRebound)
    }

    /// How many cards are left, over the pixel deck.
    ///
    /// The number used to sit on the floor under the pile, which stopped working the
    /// moment the pile started flying about. Drawn at the sheet's own size rather than
    /// off `ballSize`: this is pixel art, and half a pixel is worse than a size that does
    /// not quite match its neighbour.
    private var remaining: some View {
        DeckGlyph(cell: readout.cell, side: readout.side)
            // Before the overlay, so the deck turns and the count does not. The frame is
            // square, so a right angle costs no layout.
            .rotationEffect(.degrees(readout.rotation))
            .offset(x: -Deck.tilt, y: -Deck.tilt)
            .overlay {
                TwoXMark(size: readout.number, text: "\(deck ?? state.deck.count)")
                    .fixedSize()
                    .offset(x: readout.textX, y: readout.textY)
            }
            .offset(x: readout.x, y: readout.y)
            .animation(.easeOut(duration: 0.25), value: deck ?? state.deck.count)
            .animation(.easeOut(duration: 0.25), value: layout)
    }

    /// **What has been spent**, beside what is left. The top card of the pile shrunk to
    /// a mark, with the count over it: an empty pile is no card at all, which is exactly
    /// what it says.
    private var discarded: some View {
        let across = readout.side * Deck.discard
        return Group {
            if let top = state.discard.last?.descriptor {
                CardFrontView(descriptor: top, displayWidth: across)
            } else {
                // **Nothing spent yet**: the shape of the card that would stand here,
                // dashed round, the way the Variaball slot says the same thing.
                RoundedRectangle(cornerRadius: across * CardLayout.cornerFraction,
                                 style: .continuous)
                    .strokeBorder(CardPalette.cloud.opacity(0.7),
                                  style: StrokeStyle(lineWidth: Deck.dash,
                                                     dash: [Deck.dash * 2, Deck.dash * 1.4]))
                    .frame(width: across, height: across / CardMetrics.aspect)
            }
        }
        // Turned with the deck it stands beside — the pair reads as two piles on one
        // table rather than one pile and one card.
        .rotationEffect(.degrees(readout.rotation))
        .overlay {
            TwoXMark(size: readout.number, text: "\(state.discard.count)")
                .fixedSize()
        }
        // **What makes it the spent pile at a glance.** Two piles of cards side by side
        // are two piles of cards; the cross is the whole difference.
        .overlay(alignment: .topTrailing) {
            Image(systemName: "xmark")
                .font(.system(size: readout.number * Deck.cross, weight: .black))
                .foregroundStyle(.white)
                .padding(readout.number * 0.12)
                .background(Circle().fill(CardPalette.red))
                .overlay(Circle().strokeBorder(CardPalette.black, lineWidth: 1.5))
                .offset(x: readout.number * 0.3, y: -readout.number * 0.3)
        }
        .contentShape(Rectangle())
        .background {
            GeometryReader { box in
                let screen = box.frame(in: .named(Chrome.screen))
                Color.clear
                    .preference(key: DiscardPoint.self,
                                value: CGPoint(x: screen.midX, y: screen.midY))
                    .onAppear { discardFrame = box.frame(in: .global) }
                    .onChange(of: box.frame(in: .global)) { _, now in discardFrame = now }
            }
        }
        .onTapGesture { onOpenDiscard(discardFrame) }
        .animation(.easeOut(duration: 0.25), value: state.discard.count)
    }

    private enum Deck {
        static let drop: CGFloat = 3
        /// The spent pile's own mark, against the deck glyph beside it.
        static let discard: CGFloat = 0.62
        /// The dashes round an empty one.
        static let dash: CGFloat = 2
        /// The cross on it, against the count it is standing beside.
        static let cross: CGFloat = 0.42
        /// **The turned deck, drawn up and left of its count** by this much: turned, the
        /// sheet sat low and to the right of the number it carries.
        static let tilt: CGFloat = 4
        /// The room between the two decks, as a share of the ball. They carry their own
        /// offsets for the turn, which brought them together.
        static let pair: CGFloat = 0.95
    }

    /// **Off the Backboard, still owed.** The card itself, shrunk to a mark, held in the
    /// corner until the miss it is waiting for. A Break that has already happened but has
    /// not happened *yet* is the only kind the player needs reminding of.
    private var calledGlass: some View {
        CardFrontView(descriptor: CardLibrary.offTheBackboard,
                      displayWidth: ballSize * 0.62)
            .shadow(color: CardPalette.navy, radius: 0, x: drop, y: drop)
            .transition(.scale.combined(with: .opacity))
    }

    /// No Whistle can be called this round. The flat icon, struck out.
    private var silenced: some View {
        SlashedMark(side: whistleSide, slash: CardPalette.red) {
            Image("WhistleIcon")
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

    /// Cards this player is owed on their next make — All-Swish Selection.
    private var owed: Int { state[GameRules.localSeat].drawsOwedOnMake }

    /// What is waiting on a make. It says a number because the number is the whole of it.
    private var pending: some View {
        ZStack {
            Image("PendingDrawIcon")
                .resizable()
                .scaledToFit()
                .frame(width: refereeSide, height: refereeSide)
                .foregroundStyle(CardPalette.gold)
            Text("\(owed)")
                .font(.custom("AvenirNextCondensed-Heavy", size: refereeSide * 0.5))
                .foregroundStyle(.white)
        }
        .drawingGroup()
        .shadow(color: CardPalette.blue, radius: 0, x: drop, y: drop)
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }

    /// **The crew working this round**, as their three cards rather than as one whistle.
    ///
    /// The old icon said only that somebody was watching, which was right when a Whistle
    /// was a trap nobody could see. They are dealt face up now and everyone plays under
    /// them, so the HUD says *which three* — small, because it is a reminder of something
    /// already read rather than the reading itself. Tapping opens them at a size that can
    /// be read.
    private var crew: some View {
        HStack(spacing: refereeSide * Crew.gap) {
            // Outside the cards' drop, which would fall under the word too.
            FloorName(text: "Refs:")
            HStack(spacing: refereeSide * Crew.gap) {
                ForEach(state.armedWhistles) { whistle in
                    CardFrontView(descriptor: whistle.card.descriptor,
                                  displayWidth: Self.crewCardWidth(ballSize: ballSize),
                                  expanded: true)
                        // Its own tap, reporting where it sits so the card rises from there.
                        .overlay {
                            GeometryReader { geo in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        let at = geo.frame(in: .global)
                                        onInspectReferee(whistle.card.descriptor,
                                                         CGPoint(x: at.midX, y: at.midY))
                                    }
                            }
                        }
                }
            }
            .shadow(color: CardPalette.blue, radius: 0, x: drop, y: drop)
        }
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }

    /// **How wide the working official's card is drawn: the size it is read at.**
    ///
    /// One official works the round and everybody plays under him, so his card is printed
    /// where it stands rather than tapped open — and the words are a share of the card's
    /// own width, so the card has to be this big for them to be worth printing.
    static func crewCardWidth(ballSize: CGFloat = 58) -> CGFloat { 88 }

    /// **And its words, bigger than the card's own share.** A card's printing is a share
    /// of its width, and the width that makes an official's words readable is a card that
    /// takes half the screen. So the card stays the size of a card and the words are set
    /// up to where they can be read.
    static let crewTextScale: CGFloat = 1.6

    private enum Crew {
        /// **Against the referee icon that stood here**, which is itself smaller than the
        /// ball. Three cards in the space one icon had, so the row does not grow.
        static let share: CGFloat = 0.62
        /// The room between two of them, as a share of the icon's side.
        static let gap: CGFloat = 0.30
    }
}
