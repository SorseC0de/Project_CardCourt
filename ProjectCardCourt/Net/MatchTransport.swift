import Foundation

/// How the game talks to the other devices, with no notion of *which* other devices.
///
/// The controller is written against this and never imports GameKit. A match is one
/// implementation; a loopback that hands messages straight back is another, and that is
/// what makes the host and guest paths testable without four phones.
@MainActor
protocol MatchTransport: AnyObject {
    /// True once a match is actually running. Before that the game is solo, whatever
    /// else is wired up — without this, a transport attached early makes every local
    /// game think it is a guest with no host to talk to.
    var isActive: Bool { get }
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
    /// Puts the match down for good. A game that has been quit is not a game somebody
    /// else is still waiting on.
    /// Say the seating again, to everybody.
    ///
    /// **On the protocol rather than reached for by downcast.** The controller used to
    /// write `(match as? GameCenterMatch)?.reseatEveryone()`, which is the one place it
    /// named a concrete transport — so the loopback, the only way to run a match without
    /// two phones, silently did nothing here. A default no-op keeps every transport that
    /// has nothing to re-say honest about it.
    func reseatEveryone()

    func leave()

    /// Called when somebody drops. Their seat carries on under the AI, which is the only
    /// answer that keeps a four-handed game going.
    var onSeatLost: ((Seat) -> Void)? { get set }
}


extension MatchTransport {
    /// Nothing to re-say. A transport whose seating cannot go stale — a loopback, a
    /// test double — inherits this.
    func reseatEveryone() {}
}
