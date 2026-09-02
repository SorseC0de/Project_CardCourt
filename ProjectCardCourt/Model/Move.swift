import Foundation

/// A decision a seat can be asked for. Rebound bids are simultaneous, so they go
/// through `Rules.resolveRebound` rather than being applied one seat at a time.
enum Move: Hashable {
    case inbound(to: Seat)
    case play(Card.ID)
    case shoot
}
