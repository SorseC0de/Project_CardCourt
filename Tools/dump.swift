import Foundation

func dumpText() {
    for card in CardLibrary.standardPool.sorted(by: { ($0.type.rawValue, $0.name) < ($1.type.rawValue, $1.name) }) {
        let face = card.printedEffect
        let detail = card.detailedEffect
        let badge = card.shotEffect.map { " [badge \($0)]" } ?? ""
        print("\(card.type.rawValue.padding(toLength: 13, withPad: " ", startingAt: 0)) \(card.name.padding(toLength: 22, withPad: " ", startingAt: 0))\(badge)")
        print("      face: \(face.isEmpty ? "—" : face)")
        if detail != face { print("    detail: \(detail)") }
    }
}
