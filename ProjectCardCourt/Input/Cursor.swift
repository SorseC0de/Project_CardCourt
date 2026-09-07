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
    /// Free Agent's way into somebody else's hand.
    case borrow
    /// The bar's single confirm — a bid, a spend, a toll. There is only ever one of them
    /// on screen, so it needs no name of its own.
    case confirm
    /// Saying no to a question that allows it: stepping aside rather than countering.
    case decline
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
        let hand = controller.shownBag(of: seat).map { PadSpot.card($0.id) }

        switch controller.gate {
        case .awaitingMove:
            let legal = Rules.legalMoves(controller.shown, for: seat)
            // The whole hand, not only what is playable: a card you cannot play is still
            // a card you are allowed to read, exactly as it is on glass.
            var row = hand
            if legal.contains(.shoot) { row.append(.shoot) }
            if legal.contains(where: { if case .borrow = $0 { return true }; return false }) {
                row.append(.borrow)
            }
            return row

        // Every "which of them" the game asks is answered on the floor, and the court
        // already knows who is standing there to be picked.
        case .awaitingInbound, .awaitingTarget:
            return floor(controller)

        // Wide-Open Three names as many as it likes and stops when it stops, so the row
        // carries the way out as well as the men.
        case .awaitingNaming:
            return floor(controller) + [.decline]

        // Cards out of your own hand, and the button that says how many.
        case .awaitingBid, .awaitingDiscard, .awaitingGiveUp:
            return hand + [.confirm]

        case .awaitingCounter(let cards):
            return cards.map { PadSpot.card($0.id) } + [.decline]

        // Answered on a sheet of their own, which the pad does not drive yet.
        case .thinking, .awaitingMode, .awaitingCardFrom, .awaitingInjuryPick,
             .awaitingIntangibleDrop, .awaitingToll, .awaitingFreeThrow, .gameOver:
            return []
        }
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
}
