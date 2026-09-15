import Foundation

/// **What each card's "You may" says on its sheet.** The rules only know the question is
/// there; the words are the table's.
extension CardOption {
    var question: String {
        switch self {
        case .takeBall:       return "Take the Ball?"
        case .flipForDraw:    return "Flip for a card?"
        case .assignClamps:   return "Assign your Clamps?"
        case .resetShotClock: return "Reset the Shot Clock?"
        case .dumpHand:       return "Discard your hand?"
        case .ankleBreaker:   return "Ankle Breaker?"
        }
    }

    var note: String {
        switch self {
        case .takeBall:       return "Lob: the current Ball comes out of play and into your hand"
        case .flipForDraw:    return "No-Look: Heads draws 1 card"
        case .assignClamps:   return "Kick-Out: every Clamp on you goes to the new player"
        case .resetShotClock: return "Outlet Pass: the Shot Clock back to the top"
        case .dumpHand:       return "Turnaround Three: SHOT = 100%"
        case .ankleBreaker:   return "Discard 1 card from a target player's hand"
        }
    }

    var taking: String {
        switch self {
        case .takeBall:       return "Take it"
        case .flipForDraw:    return "Flip"
        case .assignClamps:   return "Assign"
        case .resetShotClock: return "Reset"
        case .dumpHand:       return "Discard"
        case .ankleBreaker:   return "Break ankles"
        }
    }
}
