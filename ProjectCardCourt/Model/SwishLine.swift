import Foundation

// Moved out of View/SwishTitle.swift. What a make is called is a fact about the
// make; `SwishTitle` is how it is lettered.

/// What a made shot says, and what it throws.
///
/// The word itself never changes — it is the game's name. These set it inside a sentence,
/// with the emoji the hoop throws back chosen to match rather than picked at random.
struct SwishLine: Equatable {
    /// When a line is allowed out. nil is any day of the year.
    enum Season: Equatable { case christmas, halloween, thanksgiving }

    /// Sits north-west of the word.
    let before: String?
    /// Sits south-east of it.
    let after: String?
    /// What bursts on the make. Empty leaves the usual spoils; more than one and the
    /// burst throws a mix.
    let emoji: [String]
    /// **Disarmed while this is set.** `roll` will not pick a seasonal line until there is
    /// something that knows what day it is — see `isArmed`.
    let season: Season?

    init(before: String? = nil, after: String? = nil,
         emoji: [String] = [], season: Season? = nil) {
        self.before = before
        self.after = after
        self.emoji = emoji
        self.season = season
    }

    static let plain = SwishLine()

    static let all: [SwishLine] = [
        SwishLine(after: "upon a star!", emoji: ["💫"]),
        SwishLine(after: "cheese!", emoji: ["🧀"]),
        // No lamp emoji reads as a genie's, so this one takes the genie and the second
        // genie line goes, per the rule set when they were written.
        SwishLine(before: "As you", emoji: ["🧞‍♂️"]),
        SwishLine(after: "a ninja would!", emoji: ["🥷", "🪵"]),
        SwishLine(before: "Going", after: "-ing!", emoji: ["🎣"]),

        // Seasonal, and disarmed until the calendar is wired up. Written now so the
        // catalogue is complete rather than remembered later.
        SwishLine(before: "Merry", after: "-mas!",
                   // No gingerbread man exists, so the cookie stands in for it — which
                   // is the one left out for Santa anyway.
                   emoji: ["🎄", "🎅", "🎁", "❄️", "⛄", "🛷", "🍪"],
                   season: .christmas),
        SwishLine(after: "or Treat!",
                   emoji: ["🎃", "🐈‍⬛", "🦇", "🕸️", "👻", "🍬"],
                   season: .halloween),
        SwishLine(before: "Happy Thanks", after: "-ing!",
                   emoji: ["🦃", "🍗", "🍁", "🥧", "🌽", "🍠"],
                   season: .thanksgiving),
    ]

    /// True for a line that may be rolled today.
    ///
    /// Every seasonal line is out of bounds for now. When there is a calendar this becomes
    /// "in season or no season", and nothing else here has to change.
    var isArmed: Bool { season == nil }

    /// Most makes are the plain word. A line is a treat, not the default.
    static func roll() -> SwishLine {
        guard Int.random(in: 0..<3) == 0 else { return .plain }
        return all.filter(\.isArmed).randomElement() ?? .plain
    }
}
