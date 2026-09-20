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
    /// **What losing a rebound bid pays.** Everybody who went up for the board except the
    /// man who took it: a bid is cards out of the hand, and three of the four spend them
    /// for nothing at all.
    var lostBidDraw: Int
    /// **How many Move cards a possession holds.** A core rule rather than a card: every
    /// Move draws, so a run of them is a run of cards, and this is what stops the engine
    /// running for ever. The Travel official lowers it by one while he is working.
    var movesPerPossession: Int
    /// **The most cards a hand may hold.** A draw that would take a player past it is
    /// converted instead — see `overflowShot`.
    var handLimit: Int
    /// What a draw past the hand limit is worth instead of a card. Drawing is moving with
    /// the ball; a draw you have no room for is getting open without it.
    var overflowShot: Int
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
    /// How many Clamps one player can be carrying. A fourth is simply not playable — the
    /// floor only holds so many bodies, and an uncapped stack meant a hand could be shut
    /// down entirely before its owner had touched the ball.
    var clampSlots: Int
    /// **How many officials work the game.** The crew is dealt face-up from the officials
    /// deck and belongs to nobody; this is how many of them stand out there at once — a
    /// full crew, which a game works up to rather than opening on. See `crewSize(inRound:)`.
    var refereeSlots: Int
    /// **The crew for a round: one official.** Three of them called over each other and
    /// read as a wall of rules rather than as a man watching the game; one is a rule you
    /// can hold in your head and play around. `refereeSlots` is still what the floor
    /// holds, which is what a Whistle played from a hand fills up to.
    func crewSize(inRound round: Int) -> Int {
        min(refereeSlots, 1)
    }

    /// The officials deck. Shuffled once at the start of the game like the main deck, and
    /// dealt from at the top of every round.
    var officialsPool: [CardDescriptor]
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
            // **Four, so the draw at the top of a possession makes five** — the hand limit
            // — and nobody starts a turn a card up on the table. Yu-Gi-Oh made the same
            // change for the player going first.
            startingBagSize: 4,
            lostBidDraw: 1,
            movesPerPossession: 3,
            handLimit: 5,
            overflowShot: 10,
            shotClockStart: 10,
            startingShot: 0,
            madeShotPoints: 2,
            freeThrowPoints: 1,
            freeThrowChance: 75,
            passShotBonus: 10,
            shotFloor: 0,
            shotCeiling: 100,
            intangibleSlots: 1,
            clampSlots: 1,
            refereeSlots: 3,
            officialsPool: [],
            cardPool: CardLibrary.classicPool)
    }

    /// The full pool. Grows as each card type is built; only `cardPool` differs.
    static var standard: MatchRules {
        var rules = classic
        rules.name = "Standard"
        rules.cardPool = CardLibrary.standardPool
        rules.officialsPool = CardLibrary.officialsPool
        return rules
    }
}
