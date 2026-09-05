import Foundation

/// Every card the game has, for checking the sheet against.
func listNames() {
    for card in CardLibrary.standardPool.sorted(by: { $0.name < $1.name }) {
        print("\(card.name)\t\(card.type)\t\(card.numberInDeck)")
    }
}
