import Foundation

/// Every card's whole text, one JSON object a line, for audits read against the sheet.
func dumpCardTexts() {
    struct Row: Encodable {
        let name: String
        let type: String
        let count: Int
        let effect: String
        let combo: String?
        let bonus: String?
        let shotEffect: Int?
        let marks: [String]
    }
    let encoder = JSONEncoder()
    for card in CardLibrary.standardPool {
        let row = Row(name: card.name, type: card.type.rawValue, count: card.numberInDeck,
                      effect: card.effect, combo: card.combo, bonus: card.bonus,
                      shotEffect: card.shotEffect,
                      marks: [card.isThree ? "three" : nil,
                              card.takesShot ? (card.special?.dunks == true ? "dunk" : "shoot") : nil]
                          .compactMap { $0 })
        print(String(decoding: try! encoder.encode(row), as: UTF8.self))
    }
}
