import Foundation

/// **What the deck offers against what it takes**, counted the way a player meets it: by
/// what the card says, weighted by how many copies of it are in there.
///
/// Read off the printed words rather than the fields behind them, because the question is
/// how the deck *feels* to hold — a card that says "Discard 1" is a card taken off you
/// whatever the rules call the field.
func measureTilt() {
    let pool = CardLibrary.standardPool.filter { $0.numberInDeck > 0 }

    /// What a card says it does. A card can say several things, so these are not exclusive.
    struct Mark {
        let name: String
        let test: (String) -> Bool
    }
    let marks: [Mark] = [
        Mark(name: "hands cards out", test: { $0.contains("#[draw") }),
        Mark(name: "takes cards off you", test: { $0.contains("#[discard") || $0.contains("give up")
                                                  || $0.contains("hand limit") }),
        Mark(name: "SHOT up", test: { $0.contains("shot +") || $0.contains("shot =") }),
        Mark(name: "SHOT down", test: { $0.contains("shot -") || $0.contains("shot −") }),
        Mark(name: "turnover", test: { $0.contains("#[tov") || $0.contains("turnover") }),
        Mark(name: "cancels or blocks", test: { $0.contains("#[cancel") || $0.contains("cannot")
                                                || $0.contains("never") || $0.contains("no ") }),
        Mark(name: "free throws", test: { $0.contains("free throw") || $0.contains("#[ft") }),
    ]

    func words(_ card: CardDescriptor) -> String {
        ((card.effect) + " " + (card.bonus ?? "")).lowercased()
    }

    var copiesBy: [String: Int] = [:]
    var uniqueBy: [String: Int] = [:]
    var byTypeGives: [CardType: Int] = [:]
    var byTypeTakes: [CardType: Int] = [:]
    var givers: [(String, Int)] = []
    var takers: [(String, Int)] = []

    var copies = 0
    for card in pool {
        copies += card.numberInDeck
        let said = words(card)
        for mark in marks where mark.test(said) {
            copiesBy[mark.name, default: 0] += card.numberInDeck
            uniqueBy[mark.name, default: 0] += 1
        }
        let gives = marks[0].test(said)
        let takes = marks[1].test(said)
        if gives {
            byTypeGives[card.type, default: 0] += card.numberInDeck
            givers.append((card.name, card.numberInDeck))
        }
        if takes {
            byTypeTakes[card.type, default: 0] += card.numberInDeck
            takers.append((card.name, card.numberInDeck))
        }
    }

    print("DECK TILT — \(pool.count) unique, \(copies) cards")
    print(String(repeating: "=", count: 62))
    for mark in marks {
        let cards = copiesBy[mark.name] ?? 0
        print(String(format: "  %-22@ %4d cards (%4.1f%%)   %3d unique",
                     mark.name as NSString, cards,
                     Double(cards) * 100 / Double(max(1, copies)), uniqueBy[mark.name] ?? 0))
    }
    print("")
    print("GIVING AND TAKING, BY TYPE (cards, not unique)")
    print(String(repeating: "-", count: 62))
    let types: [CardType] = [.pass, .move, .specialMove, .clamp, .whistle, .intangible,
                             .varena, .variaball, .injury]
    for type in types {
        let gives = byTypeGives[type] ?? 0
        let takes = byTypeTakes[type] ?? 0
        guard gives + takes > 0 else { continue }
        print(String(format: "  %-14@ gives %3d   takes %3d   net %+4d",
                     "\(type)" as NSString, gives, takes, gives - takes))
    }
    let gives = byTypeGives.values.reduce(0, +)
    let takes = byTypeTakes.values.reduce(0, +)
    print(String(format: "  %-14@ gives %3d   takes %3d   net %+4d",
                 "ALL" as NSString, gives, takes, gives - takes))
    // **A Draw 1 is not a gift.** Playing the card spends it, so drawing one back only
    // keeps the hand where it was — growth comes from the ones that draw two or more.
    var replaces = 0, grows = 0, drawnTotal = 0
    for card in pool where marks[0].test(words(card)) {
        let amount = max(card.drawCount, 1)
        drawnTotal += amount * card.numberInDeck
        if amount > 1 { grows += card.numberInDeck } else { replaces += card.numberInDeck }
    }
    print("")
    print(String(format: "OF THE %d CARDS THAT DRAW: %d replace themselves (Draw 1), "
                 + "%d grow the hand (Draw 2+)", replaces + grows, replaces, grows))
    print(String(format: "  cards handed out across the whole deck: %d", drawnTotal))
    print("")
    print("EVERY CARD THAT DRAWS")
    print(String(repeating: "-", count: 62))
    let drawing = pool.filter { marks[0].test(words($0)) }
        .map { (card: $0, amount: max($0.drawCount, 1)) }
        .sorted { ($0.amount, $0.card.numberInDeck) > ($1.amount, $1.card.numberInDeck) }
    for entry in drawing {
        print(String(format: "  %-22@ %-12@ draw %d  ×%d",
                     entry.card.name as NSString, "\(entry.card.type)" as NSString,
                     entry.amount, entry.card.numberInDeck))
    }
    print("")
    print("BIGGEST GIVERS: " + givers.sorted { $0.1 > $1.1 }.prefix(8)
            .map { "\($0.0) ×\($0.1)" }.joined(separator: " · "))
    print("BIGGEST TAKERS: " + takers.sorted { $0.1 > $1.1 }.prefix(8)
            .map { "\($0.0) ×\($0.1)" }.joined(separator: " · "))
}
