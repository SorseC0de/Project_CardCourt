import Foundation

/// Two devices in one process.
///
/// **The whole point of `MatchTransport` being a protocol.** A desync is the hardest kind
/// of bug to chase across two phones: you cannot step both, the logs are on separate
/// screens, and half the time the fault is a message that arrived before somebody had a
/// handler for it. Here the host and every guest are ordinary controllers in the same
/// process, wired to each other, and the whole exchange can be stepped and diffed.
///
/// **Not a fake.** It carries the same `HostMessage` and `ClientMessage` values through
/// the same `MatchCoder`, so anything that fails to round-trip fails here too — a case
/// added to an enum and not to its `Codable`, a state that will not encode. What it does
/// not model is the wire: nothing is dropped, nothing arrives out of order, and delivery
/// is a hop rather than a flight. Those are real faults and this will not find them.
@MainActor
final class LoopbackMatch: MatchTransport {

    /// Everybody at the table, so a message can be handed to the right one.
    ///
    /// Held by the wire rather than by each other: a match is a thing the devices are
    /// plugged into, and a guest holding the host would be a guest that could read the
    /// state it is supposed to be told about.
    @MainActor
    final class Wire {
        fileprivate var devices: [Seat: LoopbackMatch] = [:]
        fileprivate var hostSeat: Seat = .south
        /// Every message that has crossed, in order, for a test to read back.
        private(set) var traffic: [String] = []

        func record(_ line: String) { traffic.append(line) }
        func clear() { traffic.removeAll() }
    }

    let wire: Wire
    let seat: Seat
    let isHost: Bool
    /// True from the moment the table is wired. A loopback has no queue to sit in.
    var isActive: Bool { !wire.devices.isEmpty }

    var onClientMessage: ((Seat, ClientMessage) -> Void)?
    var onHostMessage: ((HostMessage) -> Void)?
    var onSeatLost: ((Seat) -> Void)?

    private init(wire: Wire, seat: Seat, isHost: Bool) {
        self.wire = wire
        self.seat = seat
        self.isHost = isHost
    }

    /// Wires one host and however many guests, and seats the table the way the real
    /// election would — the host first, then the others in seat order, with the house
    /// taking whatever is left.
    static func table(host: Seat = .south, guests: [Seat]) -> (Wire, [Seat: LoopbackMatch]) {
        let wire = Wire()
        wire.hostSeat = host
        var made: [Seat: LoopbackMatch] = [:]
        for seat in [host] + guests {
            made[seat] = LoopbackMatch(wire: wire, seat: seat, isHost: seat == host)
        }
        wire.devices = made

        var chairs: [Seat: Table.Chair] = [:]
        for seat in [host] + guests {
            chairs[seat] = Table.Chair(
                occupant: seat == host ? .local : .remote(playerID: "loopback-\(seat.rawValue)"),
                name: seat.houseName)
        }
        for seat in Seat.allCases where chairs[seat] == nil {
            chairs[seat] = Table.Chair(occupant: .computer, name: seat.houseName)
        }
        Table.shared.seat(chairs, asLocal: host)
        return (wire, made)
    }

    // MARK: - Talking

    func send(_ message: HostMessage, to seat: Seat) throws {
        guard isHost, let them = wire.devices[seat] else { return }
        // Through the coder, so anything that will not round-trip is caught here rather
        // than on somebody's phone.
        let copy = try MatchCoder.decode(HostMessage.self, from: MatchCoder.encode(message))
        wire.record("host → \(seat.name): \(Self.name(of: message))")
        them.onHostMessage?(copy)
    }

    func broadcast(_ each: (Seat) throws -> HostMessage) throws {
        guard isHost else { return }
        for seat in Table.shared.remotes {
            try send(each(seat), to: seat)
        }
    }

    func send(_ message: ClientMessage) throws {
        guard !isHost, let host = wire.devices[wire.hostSeat] else { return }
        let copy = try MatchCoder.decode(ClientMessage.self, from: MatchCoder.encode(message))
        wire.record("\(seat.name) → host: \(Self.name(of: copy))")
        host.onClientMessage?(seat, copy)
    }

    func leave() {
        wire.devices.removeAll()
        Table.shared.seatSolo()
    }

    /// Pulls a seat off the table, the way a dropped phone does.
    func drop(_ seat: Seat) {
        guard isHost else { return }
        wire.devices[seat] = nil
        wire.record("\(seat.name) dropped")
        onSeatLost?(seat)
    }

    private static func name(of message: HostMessage) -> String {
        switch message {
        case .seated(let seat, _, _):     return "seated(\(seat.name))"
        case .turn(let state, let events): return "turn(\(state.phase.label), \(events.count))"
        case .start:                       return "start"
        }
    }

    private static func name(of message: ClientMessage) -> String {
        switch message {
        case .ready:               return "ready"
        case .move(let move):      return "move(\(move))"
        case .reboundBid(let c):   return "bid(\(c.count))"
        case .discardForShot(let c): return "discardForShot(\(c.count))"
        case .freeThrow(let made): return "freeThrow(\(made))"
        case .decision(let what):  return "decision(\(what))"
        }
    }
}
