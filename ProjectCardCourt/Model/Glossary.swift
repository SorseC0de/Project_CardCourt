import Foundation

/// **What a mechanic means, in one sentence, for somebody who has just met it.**
///
/// The cards name these in their own words — `#[Draw]`, `#[Clamp]` — and marking one is
/// what makes it a mechanic rather than a noun. A player can press one on a raised card
/// and be told what it is; see `CardText`, which turns the marked span into the tap.
///
/// **Written for the table, not for the code.** Each is what somebody would say if you
/// asked mid-game, so no entry names a rule the player cannot see, and none of them is
/// longer than a breath.
enum Glossary {
    /// The mechanic, with its plural folded in — a card says Draws as readily as Draw.
    static func meaning(of word: String) -> (title: String, says: String)? {
        let key = singular(word)
        guard let says = table[key] else { return nil }
        return (key, says)
    }

    /// Whether there is anything to say about it, which is what decides if it is worth
    /// making tappable.
    static func knows(_ word: String) -> Bool { table[singular(word)] != nil }

    /// "Draws" and "Draw" are one entry. Done by hand rather than by chopping an s: the
    /// list is fifteen long and every irregular one would need an exception anyway.
    private static func singular(_ word: String) -> String {
        switch word {
        case "Draws":       return "Draw"
        case "Discards":    return "Discard"
        case "Locks":       return "Lock"
        case "Clamps":      return "Clamp"
        case "Whistles":    return "Whistle"
        case "Injuries":    return "Injury"
        case "Game Breaks": return "Game Break"
        default:            return word
        }
    }

    private static let table: [String: String] = [
        "Draw": "Take that many cards off the deck. Anything you turn up that is not a "
              + "card for your hand goes off once the whole draw has finished.",
        "Discard": "Put that many cards from your hand into the pile. At random unless "
                 + "the card says you choose.",
        "Lock": "The card stays in your hand but cannot be played this possession. Which "
              + "one is picked when the Clamp lands, and it does not change.",
        "Clamp": "Defenders standing on whoever has the ball next. They lower SHOT while "
               + "they are there, and some of them take cards instead.",
        "Clear": "Send the defenders away before they land, or off you if they already "
               + "have.",
        "Target": "You choose which player it goes to, rather than the card choosing.",
        "Rebound": "A missed shot is up for grabs. Everyone bids cards, and the most "
                 + "cards takes the ball.",
        "Shot Clock": "How long the possession has left. It ticks on most plays, and "
                    + "reaching zero is a turnover.",
        "TOV": "A turnover. The ball goes back in from the sideline and the round starts "
             + "over.",
        "AST": "An assist. Credited to whoever passed to the man who scored.",
        "FT": "A free throw. A trip to the line, shot on its own, worth a point each.",
        "Whistle": "A card set down face up that waits for something to happen, then "
                 + "fires. Nobody plays it when it goes off.",
        "Game Break": "Something that happens *to* the table, turned up in a draw rather "
                    + "than played. Nobody chooses one.",
        "Injury": "A Game Break that stays on you rather than firing and going. It costs "
                + "you something every round until it is cleared.",
        "Intangible": "A passive that sits face up in front of you and changes how you "
                    + "play. You only hold so many.",
        "Cancel": "The card is stopped. It does nothing at all, and it is still spent.",
    ]
}
