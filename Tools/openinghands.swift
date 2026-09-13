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
        // **Hypergeometric, not binomial.** Five cards are drawn without replacement, and
        // the deck that matters is only the bag-able part — Breaks and Intangibles fire or
        // slot on the way past and the deal keeps drawing. A finite deck is tighter than
        // an infinite one, so the band holds a little more than the binomial says.
        //
        // Swept over every pass share rather than reasoned about, because the answer
        // depends on the deck's actual size and that changes every time a count does.
        let bagable = pool.filter { $0.gameBreak == nil && $0.injury == nil && $0.intangible == nil }
        let deck = bagable.reduce(0) { $0 + $1.numberInDeck }
        func logChoose(_ n: Int, _ k: Int) -> Double {
            guard k >= 0, k <= n else { return -.infinity }
            var total = 0.0
            for i in 0..<k { total += log(Double(n - i)) - log(Double(i + 1)) }
            return total
        }
        func band(passes: Int) -> Double {
            (2...3).reduce(0.0) { running, hits in
                let p = exp(logChoose(passes, hits) + logChoose(deck - passes, size - hits)
                            - logChoose(deck, size))
                return running + (p.isFinite ? p : 0)
            }
        }
        var best = (share: 0.0, value: 0.0, count: 0)
        for passes in 0...deck {
            let value = band(passes: passes)
            if value > best.value {
                best = (Double(passes) / Double(deck), value, passes)
            }
        }
        let passesNow = bagable.filter(\.isPass).reduce(0) { $0 + $1.numberInDeck }
        print(String(format: "\nthe band, over a %d-card bag-able deck:", deck))
        print(String(format: "  now:  %d passes (%.0f%%) -> %.1f%%",
                     passesNow, Double(passesNow) / Double(deck) * 100,
                     band(passes: passesNow) * 100))
        print(String(format: "  best: %d passes (%.0f%%) -> %.1f%%   <- the ceiling",
                     best.count, best.share * 100, best.value * 100))
        print("  the band is two of six outcomes, so it cannot hold much more than this")
        print("  at a hand of \(size). Widening it to \"2 or more\" is a different sum.")

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
