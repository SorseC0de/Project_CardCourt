import Foundation

/// How the game talks to the other devices, with no notion of *which* other devices.
///
/// The controller is written against this and never imports GameKit. A match is one
/// implementation; a loopback that hands messages straight back is another, and that is
/// what makes the host and guest paths testable without four phones.
@MainActor
protocol MatchTransport: AnyObject {
    /// True on the one device running the rules.
    var isHost: Bool { get }

    /// Host → one player.
    func send(_ message: HostMessage, to seat: Seat) throws
    /// Host → everyone else at the table.
    func broadcast(_ each: (Seat) throws -> HostMessage) throws
    /// Player → host.
    func send(_ message: ClientMessage) throws

    /// Called on the host when somebody's device has chosen something.
    var onClientMessage: ((Seat, ClientMessage) -> Void)? { get set }
    /// Called on a player's device when the host has said something.
    var onHostMessage: ((HostMessage) -> Void)? { get set }
    /// Called when somebody drops. Their seat carries on under the AI, which is the only
    /// answer that keeps a four-handed game going.
    var onSeatLost: ((Seat) -> Void)? { get set }
}
