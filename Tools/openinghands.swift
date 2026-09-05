import Foundation

/// What an opening hand actually looks like.
///
/// The target is a hand you can *play*: a pass is the only card that moves the ball, so a
/// hand without one is a hand that shoots from wherever it is standing or does nothing.
/// The weighting question is how often a fresh hand holds two or three of them.
enum OpeningHands {
    static func run(_ games: Int = 5000, pool: [CardDescriptor] = CardLibrary.standardPool) {
        var rules = MatchRules.standard
        rules.cardPool = pool
        let size = rules.startingBagSize

        var passes: [Int: Int] = [:]
        var byType: [CardType: Int] = [:]
        var hands = 0

        for seed in 0..<games {
            let state = Rules.newGame(seed: UInt64(seed), rules: rules).0
            for seat in Seat.allCases {
                let bag = state[seat].bag
                hands += 1
                passes[bag.filter(\.descriptor.isPass).count, default: 0] += 1
                for card in bag { byType[card.descriptor.type, default: 0] += 1 }
            }
        }

        print("pool: \(pool.count) descriptors, \(Rules.deckSize(pool: pool)) cards")
        print("\(hands) opening hands of \(size)\n")

        print("passes in hand:")
        let inBand = (2...3).reduce(0) { $0 + (passes[$1] ?? 0) }
        for count in passes.keys.sorted() {
            let n = passes[count] ?? 0
            let share = Double(n) / Double(hands) * 100
            let bar = String(repeating: "█", count: Int(share / 2))
            let mark = (2...3).contains(count) ? " ←" : "  "
            print(String(format: "  %d  %5.1f%%%@ %@", count, share, mark, bar))
        }
        print(String(format: "\n  2-3 passes: %.1f%%   (target >= 90%%)",
                     Double(inBand) / Double(hands) * 100))
        print(String(format: "  at least 1: %.1f%%",
                     Double(hands - (passes[0] ?? 0)) / Double(hands) * 100))

        print("\nwhat a hand is made of:")
        let cards = byType.values.reduce(0, +)
        for (type, n) in byType.sorted(by: { $0.value > $1.value }) {
            print(String(format: "  %-14@ %5.1f%%", type.rawValue as NSString,
                         Double(n) / Double(cards) * 100))
        }

        // What the target is actually worth chasing.
        //
        // A five-card hand drawn from a deck that is `p` passes is a binomial, and a
        // binomial on five trials cannot put ninety per cent into two adjacent counts —
        // the most it will ever put into 2-and-3 together is at p = 0.5. Worth printing
        // rather than tuning towards, because no ratio reaches the target asked for.
        func binomial(_ hits: Int, _ n: Int, _ p: Double) -> Double {
            var c = 1.0
            for i in 0..<hits { c *= Double(n - i) / Double(i + 1) }
            return c * pow(p, Double(hits)) * pow(1 - p, Double(n - hits))
        }
        var bestBand = 0.0, bestP = 0.0, needTwo = 0.0
        for step in 1..<1000 {
            let p = Double(step) / 1000
            let band = binomial(2, size, p) + binomial(3, size, p)
            if band > bestBand { bestBand = band; bestP = p }
            if needTwo == 0, 1 - binomial(0, size, p) - binomial(1, size, p) >= 0.9 {
                needTwo = p
            }
        }
        print(String(format: "\nceilings for a %d-card hand:", size))
        print(String(format: "  best possible 2-3:  %.1f%% at a %.0f%% pass deck",
                     bestBand * 100, bestP * 100))
        print(String(format: "  90%% of hands with 2 or more needs a %.0f%% pass deck",
                     needTwo * 100))

        print("\ndeck by type:")
        var deckByType: [CardType: Int] = [:]
        for card in pool { deckByType[card.type, default: 0] += card.numberInDeck }
        let total = deckByType.values.reduce(0, +)
        for (type, n) in deckByType.sorted(by: { $0.value > $1.value }) {
            print(String(format: "  %-14@ %4d  %5.1f%%", type.rawValue as NSString, n,
                         Double(n) / Double(total) * 100))
        }
    }
}

extension Rules {
    static func deckSize(pool: [CardDescriptor]) -> Int {
        pool.reduce(0) { $0 + $1.numberInDeck }
    }
}
