import Foundation

/// A decision a seat can be asked for. Rebound bids are simultaneous, so they go
/// through `Rules.resolveRebound` rather than being applied one seat at a time.
/// One card out of a set that is partly face up and partly not.
///
/// A passive on a board can be named; a card in a hand can only be pointed at. Both are
/// answers to the same question, so they are one type.
enum CardPick: Hashable, Codable {
    case named(String)
    case position(Int)
}

enum Move: Hashable, Codable {
    case inbound(to: Seat)
    case play(Card.ID)
    /// Free Agent: a card out of somebody else's bag, taken at random. He names the
    /// player — and that is a *target*, so Floor General names him instead.
    case borrow(from: Seat)
    case shoot
}
