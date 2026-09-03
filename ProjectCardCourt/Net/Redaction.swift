import Foundation

extension GameState {
    /// A copy of the state safe to hand to one seat.
    ///
    /// The host holds the only complete state and never sends it. What a player is
    /// entitled to see is exactly what they could see at a table: their own hand, the
    /// discard, everyone's scores and clamps, and how many cards everybody is holding —
    /// but not *which* cards, not the order of the draw pile, and not a Whistle anybody
    /// has set down in front of them.
    ///
    /// Face-down cards keep their real ids. The id is a bare UUID and says nothing about
    /// what the card is, and keeping it means a hand does not change identity every time
    /// a snapshot arrives — which would restart every animation in the fan.
    func redacted(for seat: Seat) -> GameState {
        var copy = self
        for other in Seat.allCases where other != seat {
            copy[other].bag = copy[other].bag.map(Card.faceDown)
        }
        // The size of the deck is public. Its order is the future.
        copy.deck = copy.deck.map(Card.faceDown)
        // A Whistle is private knowledge until it is called — at a table it is a card
        // sitting face down in front of its owner.
        copy.armedWhistles = copy.armedWhistles.filter { $0.owner == seat }
        // Which armed Whistle is waiting on a Clamp names one of them.
        if let pending = pendingClampVoid,
           !copy.armedWhistles.contains(where: { $0.id == pending }) {
            copy.pendingClampVoid = nil
        }
        // Handing over the generator hands over every roll it has left.
        copy.rng = SeededRNG(seed: 0)
        return copy
    }
}

extension Card {
    /// The same card, face down. Keeps its id — see `redacted(for:)`.
    static func faceDown(_ card: Card) -> Card {
        Card(CardLibrary.faceDown, id: card.id)
    }

    /// True for a card this device has been told nothing about.
    var isFaceDown: Bool { descriptor.id == CardLibrary.faceDown.id }
}
