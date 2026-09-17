import Foundation
import Observation

/// One of the things a pad can be pointing at.
///
/// **Not a view.** A card in the hand, a man on the floor and the button under them are
/// three unrelated pieces of drawing, and what makes them one row is that the table is
/// asking about them — so the row is built from the question, not from the screen.
enum PadSpot: Hashable {
    case card(Card.ID)
    case seat(Seat)
    case shoot
    /// **One of the three buttons.** A shot is a choice of finish now — see `ShotType`.
    case finish(ShotType)
    /// One of the three things beating your man is worth.
    case payoff(ClampPayoff)
    /// Free Agent's way into somebody else's hand.
    case borrow
    /// The bar's single confirm — a bid, a spend, a toll. There is only ever one of them
    /// on screen, so it needs no name of its own.
    case confirm
    /// Saying no to a question that allows it: stepping aside rather than countering.
    case decline
    /// One of the cards a sheet is holding out — named where it can be read, and by its
    /// place in the row where it cannot. See `CardChoiceView`.
    case offer(CardPick)
    /// One of the ways a card can be played, on the card that offers a choice.
    case mode(Int)
    /// One of the crew, when a card is naming which official goes.
    case official(UUID)
}

/// Everything the pad may point at, in the order it is walked.
///
/// **Built from the gate and the rules, never from the view.** The buttons are drawn from
/// `Rules.legalMoves` too, so a spot can never be walked onto that could not have been
/// tapped — which is the whole reason this is not a list of the views that happen to be on
/// screen. A gate with nothing here is a gate a pad cannot yet answer; see `GameView`.
@MainActor
enum Row {
    static func at(_ controller: GameController) -> [PadSpot] {
        let seat = GameRules.localSeat
        // **Your hand is always yours.** A card you cannot play is still a card you are
        // allowed to read, and so is one it is not your turn to play — exactly as it is
        // on glass, where nothing ever stops a finger raising one.
        // **Not the ones already played.** For the beat between the rules taking a card
        // and the fan losing it the card is still drawn, at nothing — and a ring that can
        // walk onto it is a ring on a card nobody can see. See `GameController.justPlayed`.
        let spent = controller.justPlayed
        let hand = controller.shownBag(of: seat)
            .filter { !spent.contains($0.id) }
            .map { PadSpot.card($0.id) }

        switch controller.gate {
        case .awaitingMove:
            let legal = Rules.legalMoves(controller.shown, for: seat)
            var row = hand
            // A lesson has no Shoot button to walk onto.
            if !controller.isLesson {
                for case .shootAs(let finish) in legal { row.append(.finish(finish)) }
            }
            if legal.contains(where: { if case .borrow = $0 { return true }; return false }) {
                row.append(.borrow)
            }
            return row

        // Every "which of them" the game asks is answered on the floor, and the court
        // already knows who is standing there to be picked. The hand comes after the men,
        // so the ring starts on the question and the cards are still there to be read.
        case .awaitingInbound, .awaitingTarget:
            return floor(controller) + hand

        // The crew stands where it stands, so they walk in the order they were dealt.
        // Leaving them alone is an answer, so decline is on the row with them.
        case .awaitingOfficialTarget(_, let choices):
            return choices.map(PadSpot.official) + [.decline] + hand

        // Wide-Open Three names as many as it likes and stops when it stops. Stopping is
        // circle rather than a spot — see `GameView.take(_:)`.
        case .awaitingNaming:
            return floor(controller) + hand

        // Cards out of your own hand, and the pill that says how many.
        case .awaitingBid, .awaitingDiscard, .awaitingGiveUp:
            return hand + [.confirm]

        // **The sheets.** Every one of them is the same shape — a row of cards held out,
        // one taken, and a button or two underneath. **The buttons are in the row**: a
        // shortcut that takes what is picked is not the same as being able to see where
        // the answer goes, and a sheet whose buttons cannot be walked onto is a sheet
        // that never highlights the thing it wants pressed.
        case .awaitingCounter(let cards):
            return cards.map { PadSpot.offer(.named($0.descriptor.id)) }
                + [.confirm, .decline]

        case .awaitingOption(let option):
            return [PadSpot.offer(.named(option.card.id)), .confirm, .decline]

        case .awaitingToll(let victim):
            let board = controller.shown[victim].intangibles.map {
                PadSpot.offer(.named($0.id))
            }
            // His hand is face down, so it is answered by position rather than by name.
            return board + controller.shown[victim].bag.indices.map {
                PadSpot.offer(.position($0))
            } + [.confirm, .decline]

        case .awaitingIntangibleDrop(let offered):
            return offered.map { PadSpot.offer(.named($0.id)) } + [.confirm]

        case .awaitingInjuryPick:
            return controller.shown.injuriesOffered.map { PadSpot.offer(.named($0.id)) }
                + [.confirm]

        case .awaitingCardFrom(_, let victim):
            return controller.shown[victim].bag.indices.map { PadSpot.offer(.position($0)) }
                + [.confirm]

        case .awaitingMode(let card):
            return card.modes.indices.map(PadSpot.mode)

        case .awaitingPayoff:
            return ClampPayoff.allCases.map(PadSpot.payoff)

        // The emblem, and the button that lets the call stand.
        case .awaitingChallenge:
            return [.confirm, .decline]

        // Nothing to walk. A free throw is a pull rather than a choice, and a finished
        // game is three buttons on three buttons — see `GameView.takeOnFinalCard(_:)`.
        case .awaitingFreeThrow, .gameOver:
            return []

        // Somebody else's turn. **The hand is still yours to read.**
        case .thinking:
            return hand
        }
    }

    /// Whether this row is stacked rather than laid out.
    ///
    /// **A list of options runs down the screen**, so up and down walk it and left and
    /// right — and the bumpers with them — mean the same thing they do everywhere else.
    /// Everything else in the game is a row of cards or a line of men on a floor.
    static func runsDown(_ controller: GameController) -> Bool {
        if case .awaitingMode = controller.gate { return true }
        if case .awaitingPayoff = controller.gate { return true }
        return false
    }

    /// The men on the floor who can be picked, walked in seating order so the ring goes
    /// round the table rather than round a set's own idea of an order.
    private static func floor(_ controller: GameController) -> [PadSpot] {
        let choosable = CourtView.choosable(at: controller.gate, in: controller.shown)
        return Seat.allCases.filter(choosable.contains).map(PadSpot.seat)
    }
}

/// Where the pad is pointing.
///
/// **It keeps its place across a redraw and loses it across a question.** A hand that
/// gains a card should not move the ring; a new gate should put it back at the start,
/// because the row it was walking no longer exists.
@Observable
@MainActor
final class Cursor {
    private(set) var at: PadSpot?

    /// Puts the ring somewhere legal. Called every time the row is rebuilt: the spot it
    /// was on survives if it is still in the row, and otherwise it starts again.
    func settle(on row: [PadSpot]) {
        guard !row.isEmpty else { at = nil; return }
        guard let at, row.contains(at) else { self.at = row.first; return }
    }

    /// One along, and no further. **It does not wrap**: a hand is a line of cards on a
    /// table, and running off the end of it to reappear at the other is a menu's idea of
    /// a row rather than a hand's.
    func walk(_ way: Pad.Action, along row: [PadSpot]) {
        guard let here = at, let index = row.firstIndex(of: here) else {
            at = row.first
            return
        }
        let next = way == .previous ? index - 1 : index + 1
        guard row.indices.contains(next) else { return }
        at = row[next]
    }

    /// Puts it somewhere directly — what a tap on glass does to the ring, so the two ways
    /// of playing never disagree about where the player's attention is.
    func point(at spot: PadSpot?) { at = spot }

    var card: Card.ID? { if case .card(let id) = at { return id } else { return nil } }
    var seat: Seat? { if case .seat(let seat) = at { return seat } else { return nil } }
    var official: UUID? { if case .official(let id) = at { return id } else { return nil } }
}


extension Seat {
    /// **The face button drawn where this player is drawn.**
    ///
    /// The four face buttons are a diamond and so are four players round a table, so a
    /// prompt asking which of them needs no cursor at all: the man on your left is the
    /// button on the left. Square is west, circle east, cross south, triangle north —
    /// off `slot(viewedFrom:)`, so the button follows the drawing rather than the
    /// compass, and a player sitting north still presses square for the man on their
    /// left.
    func face(viewedFrom viewer: Seat) -> Pad.Face {
        switch slot(viewedFrom: viewer) {
        case .west:  return .square
        case .south: return .cross
        case .east:  return .circle
        case .north: return .triangle
        }
    }
}
