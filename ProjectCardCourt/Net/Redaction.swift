import Foundation

extension GameState {
    /// The board with nothing dealt on it, for a guest that has not been dealt to yet.
    ///
    /// **A controller always deals in `init`** — it has to, since it cannot know yet
    /// whether it is about to be a solo game or a seat at somebody else's table. On a
    /// guest every card of that is wrong, and clearing the *presentation* around it was
    /// not enough: the hands, the deck and the discard are drawn straight off the state,
    /// so until the host's first board arrived the guest sat looking at a hand it had
    /// dealt itself from its own seed. That is a desync you can watch, before a card has
    /// been played.
    ///
    /// The seats, the mode and the phase stand — the court needs somewhere to draw four
    /// men — and everything that was dealt goes.
    func awaitingTheDeal() -> GameState {
        var copy = self
        copy.deck = []
        copy.discard = []
        for index in copy.players.indices {
            copy.players[index].bag = []
            copy.players[index].clamps = []
            copy.players[index].intangibles = []
            copy.players[index].injuries = []
        }
        copy.rng = SeededRNG(seed: 0)
        return copy
    }

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
        // Dim Dome: SHOT is the ball holder's to read, and nobody else's.
        if !copy.canReadShot(seat) { copy.shot = 0 }
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

extension GameEvent {
    /// This event as one seat is allowed to hear it.
    ///
    /// **The state was redacted and the events were not.** `redacted(for:)` face-downs
    /// every other seat's hand and the whole deck, and then the same batch went out to
    /// everybody carrying `.drew(seat:card:id:)` with the card named in full — so a guest
    /// was told, in the same message, that it could not see a hand and exactly what had
    /// just gone into it. Three cases carry a descriptor somebody else is not entitled to.
    ///
    /// **One case, not three.** `.discardedForShot` and `.clampBit` look like they carry
    /// somebody's card and do not: the first names the *shot card that asked*, which the
    /// guest already has because `phase` crosses unredacted, and the second names the
    /// Clamp or Injury doing the biting, which is read off `clamps`/`injuries` — public,
    /// and untouched by `redacted(for:)`. Face-downing them hid nothing and broke two
    /// real things: `CardLibrary.faceDown` is typed `.gameBreak`, so `showClampBite`'s
    /// `card.type == .clamp` filter stopped matching and the guest never saw the defender
    /// walk out and swipe, and both events are loggable, so a guest's log read "East feeds
    /// 3 cards into ." while the host's named the card.
    ///
    /// Your own draws are yours to see, so only the other seats are covered.
    func redacted(for seat: Seat) -> GameEvent {
        guard case .drew(let who, _, let id, let opening) = self, who != seat else { return self }
        return .drew(seat: who, card: CardLibrary.faceDown, id: id, opening: opening)
    }
}
