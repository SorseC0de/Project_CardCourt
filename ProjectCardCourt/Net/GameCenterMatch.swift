import GameKit
import Observation

/// A real-time match over Game Center.
///
/// **Who is the host.** Everybody sorts the player ids and the first one wins. It is the
/// same list on every device, so all four reach the same answer without a round of
/// messages to decide it — and if the host drops, the match ends rather than trying to
/// hand the game to somebody mid-possession.
///
/// **Who sits where.** The host assigns seats from that same sorted list and tells each
/// device which chair is theirs. Absolute seats do not matter to anybody: every court is
/// drawn relative to `GameRules.localSeat`, so all four players see themselves at the
/// near edge whatever chair they were given.
@MainActor
@Observable
final class GameCenterMatch: NSObject, MatchTransport {
    enum Status: Equatable {
        case signedOut
        case signingIn
        /// Signed in and idle. `player` is the local Game Center name.
        case ready(player: String)
        case searching
        case playing
        case failed(String)
    }

    private(set) var status: Status = .signedOut

    /// Set once the match is seated. Until then nothing knows who anybody is.
    private(set) var seats: [String: Seat] = [:]

    private var match: GKMatch?
    private var hostID: String?

    var onClientMessage: ((Seat, ClientMessage) -> Void)?
    var onHostMessage: ((HostMessage) -> Void)?
    var onSeatLost: ((Seat) -> Void)?

    var isHost: Bool { hostID != nil && hostID == GKLocalPlayer.local.gamePlayerID }

    // MARK: - Signing in

    /// Game Center will not talk to an app that has not been authenticated, and it only
    /// authenticates once per launch however many times this is called.
    func signIn() {
        guard case .signedOut = status else { return }
        status = .signingIn
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            Task { @MainActor in
                if let viewController {
                    // Handed to the UI to present — the sign-in sheet is Apple's own.
                    self.pendingSignIn = SignIn(controller: viewController)
                    return
                }
                if let error {
                    self.status = .failed(error.localizedDescription)
                    return
                }
                self.pendingSignIn = nil
                self.status = GKLocalPlayer.local.isAuthenticated
                    ? .ready(player: GKLocalPlayer.local.displayName)
                    : .signedOut
            }
        }
    }

    /// Apple's sign-in sheet, when one is waiting to be shown. Identifiable so SwiftUI
    /// can present it — a bare view controller is not.
    struct SignIn: Identifiable {
        let id = UUID()
        let controller: UIViewController
    }

    var pendingSignIn: SignIn?

    // MARK: - Finding a game

    /// Looks for a table. Two players is a game; four is the game.
    func findMatch(players: ClosedRange<Int> = 2...4) async {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        status = .searching
        let request = GKMatchRequest()
        request.minPlayers = players.lowerBound
        request.maxPlayers = players.upperBound
        do {
            let match = try await GKMatchmaker.shared().findMatch(for: request)
            adopt(match)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func leave() {
        match?.disconnect()
        match = nil
        hostID = nil
        seats = [:]
        Table.shared.seatSolo()
        status = GKLocalPlayer.local.isAuthenticated
            ? .ready(player: GKLocalPlayer.local.displayName)
            : .signedOut
    }

    private func adopt(_ match: GKMatch) {
        self.match = match
        match.delegate = self
        status = .playing
        elect(among: match)
    }

    /// Everybody runs this and everybody gets the same answer.
    private func elect(among match: GKMatch) {
        let ids = ([GKLocalPlayer.local] + match.players)
            .map(\.gamePlayerID)
            .sorted()
        hostID = ids.first

        // Seats go out in the same sorted order, so a device can work out its own chair
        // without being told — but the host tells it anyway, since only the host knows
        // which empty chairs the computer is taking.
        seats = Dictionary(uniqueKeysWithValues:
            zip(ids, Seat.allCases.prefix(ids.count)))

        guard isHost else { return }
        var chairs: [Seat: Table.Chair] = [:]
        for player in [GKLocalPlayer.local] + match.players {
            guard let seat = seats[player.gamePlayerID] else { continue }
            chairs[seat] = Table.Chair(
                occupant: player == GKLocalPlayer.local
                    ? .local : .remote(playerID: player.gamePlayerID),
                name: player.displayName)
        }
        // Anybody who did not turn up is played by the house.
        for seat in Seat.allCases where chairs[seat] == nil {
            chairs[seat] = Table.Chair(occupant: .computer, name: seat.houseName)
        }
        Table.shared.seat(chairs, asLocal: seats[GKLocalPlayer.local.gamePlayerID] ?? .south)

        for player in match.players {
            guard let seat = seats[player.gamePlayerID] else { continue }
            // Each device is told its own chair, and the same table.
            try? send(.seated(seat: seat, chairs: chairs), to: seat)
        }
    }

    // MARK: - Talking

    func send(_ message: HostMessage, to seat: Seat) throws {
        guard let match, let id = seats.first(where: { $0.value == seat })?.key,
              let player = match.players.first(where: { $0.gamePlayerID == id })
        else { return }
        try match.send(MatchCoder.encode(message), to: [player], dataMode: .reliable)
    }

    func broadcast(_ each: (Seat) throws -> HostMessage) throws {
        for seat in Table.shared.remotes {
            try send(each(seat), to: seat)
        }
    }

    func send(_ message: ClientMessage) throws {
        guard let match, let hostID,
              let host = match.players.first(where: { $0.gamePlayerID == hostID })
        else { return }
        try match.send(MatchCoder.encode(message), to: [host], dataMode: .reliable)
    }
}

extension GameCenterMatch: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data,
                           fromRemotePlayer player: GKPlayer) {
        let id = player.gamePlayerID
        Task { @MainActor in
            // Which way a message is read depends only on who this device is. The host
            // hears choices; everybody else hears the game.
            if self.isHost {
                guard let seat = self.seats[id],
                      let message = try? MatchCoder.decode(ClientMessage.self, from: data)
                else { return }
                self.onClientMessage?(seat, message)
            } else {
                guard id == self.hostID,
                      let message = try? MatchCoder.decode(HostMessage.self, from: data)
                else { return }
                self.onHostMessage?(message)
            }
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer,
                           didChange state: GKPlayerConnectionState) {
        guard state == .disconnected else { return }
        let id = player.gamePlayerID
        Task { @MainActor in
            guard let seat = self.seats[id] else { return }
            self.onSeatLost?(seat)
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: (any Error)?) {
        Task { @MainActor in
            self.status = .failed(error?.localizedDescription ?? "The match ended.")
        }
    }
}
