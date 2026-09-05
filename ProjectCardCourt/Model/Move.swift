import Foundation

/// A decision a seat can be asked for. Rebound bids are simultaneous, so they go
/// through `Rules.resolveRebound` rather than being applied one seat at a time.
enum Move: Hashable, Codable {
    case inbound(to: Seat)
    case play(Card.ID)
    /// Free Agent: a card out of somebody else's bag, taken at random. He names the
    /// player — and that is a *target*, so Floor General names him instead.
    case borrow(from: Seat)
    case shoot
}
