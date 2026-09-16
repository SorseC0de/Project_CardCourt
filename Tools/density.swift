import Foundation

/// **How much each card does.**
///
/// Yu-Gi-Oh's answer to a thin hand was not more cards, it was heavier ones: when a card
/// is two to four effects, drawing one is drawing options. Counted here by reflection —
/// every field a card sets away from its default is one thing it does. Identity, wording
/// and artwork are not things it does.
func measureDensity() {
    let skip: Set<String> = ["id", "name", "type", "effect", "numberInDeck", "combo", "bonus",
                             "isDribble", "label", "lasts"]

    func things(_ value: Any, depth: Int = 0) -> Int {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let inner = mirror.children.first?.value else { return 0 }
            // A sub-effect counts as whatever it holds; a plain value counts as one thing.
            let deeper = things(inner, depth: depth + 1)
            return Mirror(reflecting: inner).children.isEmpty ? 1 : deeper
        }
        var count = 0
        for child in mirror.children {
            if let label = child.label, skip.contains(label), depth == 0 { continue }
            switch child.value {
            case let n as Int:      if n != 0 { count += 1 }
            case let d as Double:   if d != 0 { count += 1 }
            case let b as Bool:     if b { count += 1 }
            case let s as String:   if !s.isEmpty { count += 1 }
            case let a as [Any]:    if !a.isEmpty { count += 1 }
            default:
                count += things(child.value, depth: depth + 1)
            }
        }
        return count
    }

    let pool = CardLibrary.standardPool.filter { $0.numberInDeck > 0 }
    var byCard: [(name: String, type: CardType, things: Int, copies: Int)] = []
    for card in pool {
        byCard.append((card.name, card.type, things(card), card.numberInDeck))
    }

    let unique = byCard.count
    let meanUnique = Double(byCard.reduce(0) { $0 + $1.things }) / Double(max(1, unique))
    let copies = byCard.reduce(0) { $0 + $1.copies }
    let meanDrawn = Double(byCard.reduce(0) { $0 + $1.things * $1.copies }) / Double(max(1, copies))

    print("EFFECT DENSITY — \(unique) unique cards, \(copies) in the deck")
    print(String(repeating: "=", count: 66))
    print(String(format: "things a card does: %.2f on the average card · %.2f on the average card you draw",
                 meanUnique, meanDrawn))
    print("")
    print("  things   unique cards   cards in deck   share of the deck")
    print(String(repeating: "-", count: 66))
    for n in 1...8 {
        let matching = byCard.filter { n == 8 ? $0.things >= 8 : $0.things == n }
        guard !matching.isEmpty else { continue }
        let inDeck = matching.reduce(0) { $0 + $1.copies }
        print(String(format: "  %@%-6d %10d %15d %17.1f%%", n == 8 ? "8+" : "  ", n == 8 ? 0 : n,
                     matching.count, inDeck, Double(inDeck) * 100 / Double(copies)))
    }
    print("")
    print("BY TYPE (mean things a card does)")
    print(String(repeating: "-", count: 66))
    let types: [CardType] = [.pass, .move, .specialMove, .clamp, .whistle, .intangible,
                             .varena, .variaball, .injury]
    for type in types {
        let of = byCard.filter { $0.type == type }
        guard !of.isEmpty else { continue }
        print(String(format: "  %-14@ %.2f   (%d unique, %d cards)", "\(type)" as NSString,
                     Double(of.reduce(0) { $0 + $1.things }) / Double(of.count),
                     of.count, of.reduce(0) { $0 + $1.copies }))
    }
    print("")
    print("THE HEAVIEST")
    print(String(repeating: "-", count: 66))
    for card in byCard.sorted(by: { $0.things > $1.things }).prefix(8) {
        print(String(format: "  %-24@ %2d things  ×%d", card.name as NSString, card.things, card.copies))
    }
    print("")
    print("THE LIGHTEST, WEIGHTED BY HOW MANY ARE IN THERE")
    print(String(repeating: "-", count: 66))
    for card in byCard.filter({ $0.things <= 2 }).sorted(by: { $0.copies > $1.copies }).prefix(8) {
        print(String(format: "  %-24@ %2d things  ×%d", card.name as NSString, card.things, card.copies))
    }
}
