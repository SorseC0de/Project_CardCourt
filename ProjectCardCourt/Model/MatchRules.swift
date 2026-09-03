import Foundation

/// Everything a match is played by, copied into the state when it starts.
///
/// Nothing here is read from a global at play time, so retuning the game or adding cards
/// never reaches back into a match already in progress — which is what makes a saved or
/// networked match safe to resume against a newer build.
///
/// A game mode is a preset of this.
struct MatchRules: Hashable, Codable {
    var name: String
    var roundsPerGame: Int
    var roundsPerHalf: Int
    var startingBagSize: Int
    var shotClockStart: Int
    var startingShot: Int
    var madeShotPoints: Int
    /// One point, the way they are everywhere else.
    var freeThrowPoints: Int
    /// What an opponent shoots from the line. The player shoots theirs by hand, so this
    /// stands in for a generous mini-game rather than for a real free-throw percentage.
    var freeThrowChance: Int
    /// SHOT is a property of passing; a card may override it with its own `shotDelta`.
    var passShotBonus: Int
    var shotFloor: Int
    var shotCeiling: Int
    /// How many passives a player can carry. A fourth pushes the oldest out.
    var intangibleSlots: Int
    /// The cards this match is played with, by value. Editing the library later cannot
    /// change a deck that has already been dealt.
    var cardPool: [CardDescriptor]
}

extension MatchRules {
    /// Pass and Move cards only — the simpler pool.
    static var classic: MatchRules {
        MatchRules(
            name: "Classic",
            roundsPerGame: 8,
            roundsPerHalf: 4,
            startingBagSize: 5,
            shotClockStart: 10,
            startingShot: 0,
            madeShotPoints: 2,
            freeThrowPoints: 1,
            freeThrowChance: 75,
            passShotBonus: 5,
            shotFloor: 0,
            shotCeiling: 100,
            intangibleSlots: 3,
            cardPool: CardLibrary.classicPool)
    }

    /// The full pool. Grows as each card type is built; only `cardPool` differs.
    static var standard: MatchRules {
        var rules = classic
        rules.name = "Standard"
        rules.cardPool = CardLibrary.standardPool
        return rules
    }
}
