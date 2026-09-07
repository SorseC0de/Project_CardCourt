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
        /// Signed in with nothing going on.  `player` is the local Game Center name.
        case ready(player: String)
        /// In the queue, waiting to be paired.
        case searching
        /// Paired, and waiting for everybody to actually connect. **Not the same as
        /// seated**: GameKit hands back a match the moment it has found people for it,
        /// and they arrive one connection at a time after that.
        case connecting
        /// Paired and seated, but the game has not been started yet.
        case seated
        case playing
        case failed(String)
    }

    private(set) var status: Status = .signedOut

    /// Set once the match is seated. Until then nothing knows who anybody is.
    private(set) var seats: [String: Seat] = [:]

    private var match: GKMatch?
    private var hostID: String?
    /// Whether GameKit picked the host or whether it was sorted for. If it never picks,
    /// every device falls back to comparing ids and the whole thing turns on two phones
    /// agreeing about a string — which is the fault this replaced.
    private(set) var chosenByGameKit = "?"
    /// The roll that decides how everybody nobody is playing looks. Made by the host and
    /// sent with the table — see `HostMessage.seated`.
    private var crew: UInt64 = 0

    /// Tells the table where everybody is sitting, again.
    ///
    /// Harmless to repeat, and it is what stands between a guest and playing a solo game
    /// by mistake. Sent to everybody rather than to one seat, because the thing that
    /// usually prompts it is somebody's own look arriving — and the other guests have to
    /// draw that man too.
    func reseatEveryone() {
        guard isHost, !seats.isEmpty else { return }
        // Straight off the table rather than from a copy kept here. The looks land on
        // `Table.shared` as they arrive, and a second record of who is sitting where is a
        // second answer to a question with one.
        var chairs = Table.shared.chairs
        // Named by id on the way out, own chair included — see `Table.seat(_:asLocal:)`.
        chairs[GameRules.localSeat]?.occupant =
            .remote(playerID: GKLocalPlayer.local.gamePlayerID)
        for seat in Table.shared.remotes {
            try? send(.seated(seat: seat, chairs: chairs, crew: crew), to: seat)
        }
    }

    var onClientMessage: ((Seat, ClientMessage) -> Void)?
    var onHostMessage: ((HostMessage) -> Void)?
    var onSeatLost: ((Seat) -> Void)?

    var isActive: Bool { match != nil && !seats.isEmpty }

    /// **What this device thinks the match is**, short enough to read off a screen.
    ///
    /// The election turns entirely on whether two phones see the same string for the same
    /// person. If they do not, both sort themselves to the front and both decide they are
    /// the host — and two hosts is two games. Printed as the tail of each id, which is
    /// the part that differs.
    var summary: String {
        guard match != nil else { return "no match" }
        let tail = { (id: String) in String(id.suffix(6)) }
        let mine = GKLocalPlayer.local.gamePlayerID
        let peers = seats
            .sorted { $0.value.rawValue < $1.value.rawValue }
            .map { "\($0.value.name.prefix(1))=\(tail($0.key))\($0.key == mine ? "*" : "")" }
            .joined(separator: " ")
        return "\(isHost ? "HOST" : "guest") peers=\(match?.players.count ?? 0)"
            + " me=\(tail(mine)) host=\(hostID.map(tail) ?? "-")"
            + " chose=\(chosenByGameKit) | \(peers)"
    }
    /// How many people are in the match, the local player included.
    var seated: Int { seats.count }
    var isHost: Bool { hostID != nil && hostID == GKLocalPlayer.local.gamePlayerID }

    /// The chair the rules are running in, off the same seating everybody else reads.
    var hostSeat: Seat? { hostID.flatMap { seats[$0] } }

    // MARK: - Signing in

    /// Game Center will not talk to an app that has not been authenticated, and it only
    /// authenticates once per launch however many times this is called.
    func signIn() {
        // **A failure is something to try again, not a state to be stuck in.** This
        // refused anything but `signedOut`, and the button calling it is shown on
        // `failed` too — so the one press that could recover a dropped session did
        // nothing at all, and the only way back was killing the app from the switcher.
        switch status {
        // Already asking, or busy with a match. Neither wants interrupting.
        case .signingIn, .searching, .connecting, .seated, .playing: return
        default: break
        }
        // **Often there is nothing wrong but what we last wrote down.** Game Center drops
        // a spurious failure now and then while the account is perfectly good, so the
        // cheapest refresh is to look again before asking anybody to sign in.
        if GKLocalPlayer.local.isAuthenticated {
            status = .ready(player: GKLocalPlayer.local.displayName)
            DevLog.say(.net, "already signed in — refreshed rather than re-asked")
            return
        }
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
                    self.status = .failed(Self.describe(error))
                    DevLog.say(.net, "sign-in failed — \(Self.describe(error))")
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
        // Not just `isAuthenticated`: a player can be signed in and still barred from
        // multiplayer by Screen Time, and GameKit reports that as an opaque transport
        // failure rather than as a restriction. Saying so plainly is worth the two lines.
        guard GKLocalPlayer.local.isAuthenticated else {
            status = .failed("Not signed in to Game Center. Settings → Game Center.")
            return
        }
        if GKLocalPlayer.local.isMultiplayerGamingRestricted {
            status = .failed("Multiplayer is switched off for this Apple Account. "
                             + "Settings → Screen Time → Content & Privacy Restrictions "
                             + "→ Game Center → Multiplayer Games.")
            return
        }
        status = .searching
        let request = GKMatchRequest()
        request.minPlayers = players.lowerBound
        request.maxPlayers = players.upperBound
        do {
            let match = try await GKMatchmaker.shared().findMatch(for: request)
            adopt(match)
        } catch {
            // Backing out of the queue is spelled as a cancellation, and is not a failure.
            if (error as NSError).code == GKError.Code.cancelled.rawValue {
                status = GKLocalPlayer.local.isAuthenticated
                    ? .ready(player: GKLocalPlayer.local.displayName) : .signedOut
                return
            }
            status = .failed(Self.describe(error))
            DevLog.say(.net, "findMatch failed — \(Self.describe(error))")
        }
    }

    /// Steps back out of the queue, or out of a match that has not started.
    func stop() {
        GKMatchmaker.shared().cancel()
        leave()
    }

    /// The host says everyone is in. Nothing else can start a game.
    func startPlaying() {
        guard isHost else { return }
        status = .playing
        try? broadcast { _ in .start }
        DevLog.say(.net, "starting with \(seated) player(s)")
    }

    /// What GameKit actually said.
    ///
    /// `localizedDescription` on a GameKit error is almost always "The operation couldn't
    /// be completed", which names nothing. The domain and code are the part worth reading,
    /// and a `GKError` code is worth translating outright.
    static func describe(_ error: any Error) -> String {
        let ns = error as NSError
        if ns.domain == GKErrorDomain, let code = GKError.Code(rawValue: ns.code) {
            switch code {
            case .cancelled:              return "Cancelled."
            case .notAuthenticated:       return "Not signed in to Game Center."
            case .matchRequestInvalid:    return "Game Center refused the match request."
            case .communicationsFailure:  return "Could not reach Game Center."
            case .gameUnrecognized:
                return "Game Center does not recognise this app — the bundle id, the "
                     + "capability, or the App Store Connect record do not agree."
            case .invitationsDisabled:    return "Invitations are switched off."
            case .restrictedToAutomatch:  return "This account is limited to auto-match."
            default:                      return "Game Center error \(ns.code)."
            }
        }
        return "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
    }

    func leave() {
        match?.disconnect()
        match = nil
        hostID = nil
        settled = false
        seats = [:]
        held.removeAll()
        Table.shared.seatSolo()
        status = GKLocalPlayer.local.isAuthenticated
            ? .ready(player: GKLocalPlayer.local.displayName)
            : .signedOut
    }

    private func adopt(_ match: GKMatch) {
        self.match = match
        match.delegate = self
        settled = false
        status = .connecting
        // **Matched is not connected.** `findMatch` returns as soon as GameKit has found
        // people for the match; they connect afterwards, one at a time, and until
        // `expectedPlayerCount` reaches nought `match.players` is empty. Seating here
        // gave every device a table of one — itself — so every device elected itself
        // host, and two hosts is two games that never agree about anything again.
        settleIfEveryoneIsHere()
    }

    /// True once the table has been elected and seated, so a later connection does not
    /// do it a second time.
    private var settled = false

    /// Seats the table, once and only once everybody has actually arrived.
    private func settleIfEveryoneIsHere() {
        guard let match, !settled else { return }
        guard match.expectedPlayerCount == 0 else {
            DevLog.say(.net, "matched — waiting on \(match.expectedPlayerCount) more")
            return
        }
        settled = true
        // Seated, not playing. The host still has to say go.
        status = .seated
        // **Asked, not worked out.** GameKit picks one player and gives every device the
        // same answer; it is the only way to elect a host that does not turn on two
        // phones agreeing about a string. Nil means it could not decide, and then there
        // is nothing left but to sort.
        match.chooseBestHostingPlayer { [weak self] best in
            // **The match is read on the main actor, not carried to it.** `GKMatch`
            // predates Sendable, so handing this one across the hop is a promise nobody
            // can keep — and it is already ours, sitting on the property.
            Task { @MainActor in
                guard let self, let mine = self.match else { return }
                self.elect(among: mine, host: best)
            }
        }
    }

    /// Everybody runs this and everybody gets the same answer.
    ///
    /// **The host is compared as a player, never as a string.** `gamePlayerID` is the id
    /// *this* device has for somebody, and it is not guaranteed to be the string that
    /// person's own device reports for themselves. When the two disagree, every device
    /// sorts itself to the front of the list and every device decides it is the host —
    /// and two hosts is two games running side by side with nothing in common, which is
    /// exactly what it looked like: both players holding a Start button, and no two
    /// numbers on the two screens ever matching again.
    private func elect(among match: GKMatch, host chosen: GKPlayer? = nil) {
        let everyone = [GKLocalPlayer.local] + match.players
        let host = chosen ?? everyone.min { $0.gamePlayerID < $1.gamePlayerID }
        let amHost = host.map { $0 == GKLocalPlayer.local } ?? false
        // Its own id as this device sees it, which is the same view the delegate reads
        // incoming messages against.
        hostID = amHost ? GKLocalPlayer.local.gamePlayerID : host?.gamePlayerID
        chosenByGameKit = chosen == nil ? "no" : "yes"
        DevLog.say(.net, "elected \(amHost ? "me" : "them") as host"
                   + " — \(match.players.count) peer(s)"
                   + (chosen == nil ? " (sorted — GameKit would not choose)" : ""))
        let ids = everyone.map(\.gamePlayerID).sorted()

        // Seats go out in the same sorted order, so a device can work out its own chair
        // without being told — but the host tells it anyway, since only the host knows
        // which empty chairs the computer is taking.
        seats = Dictionary(uniqueKeysWithValues:
            zip(ids, Seat.allCases.prefix(ids.count)))

        // **Everybody seats themselves.** The sorted list is the same on every device, so
        // a guest knows its own chair without being told — and a device waiting to be
        // told is a device playing as South while the host has it down as East, which is
        // two games rather than one. The host's `seated` still follows and refines this
        // with the real names and whichever chairs the house is taking.
        let me = GKLocalPlayer.local.gamePlayerID
        if !isHost {
            var provisional: [Seat: Table.Chair] = [:]
            for (id, seat) in seats {
                let name = ([GKLocalPlayer.local] + match.players)
                    .first { $0.gamePlayerID == id }?.displayName ?? seat.houseName
                provisional[seat] = Table.Chair(
                    occupant: .remote(playerID: id),
                    name: id == me && !HooperKit.shared.name.isEmpty
                        ? HooperKit.shared.name : name,
                    look: id == me ? Table.shared.myLook : nil)
            }
            for seat in Seat.allCases where provisional[seat] == nil {
                provisional[seat] = Table.Chair(occupant: .computer, name: seat.houseName)
            }
            // **Provisional.** Worked out from this device's own view of who is here, so
            // it is a guess at best — the host's `seated` is the answer and always
            // overrides it. It is here so a guest that never hears that message is
            // sitting somewhere rather than silently playing as South.
            Table.shared.seat(provisional, asLocal: seats[me] ?? .south)
            DevLog.say(.net, "provisionally at \(seats[me]?.name ?? "?") — host is them")
            // Anything the host said while this device was still working out who it was.
            flushHeldMessages()
            return
        }
        // Made here and sent with the table: the host decides once what everybody nobody
        // is playing looks like, and every device draws the same crew off it.
        crew = UInt64.random(in: 1...9_999_999)
        Table.shared.setCrew(crew)
        var chairs: [Seat: Table.Chair] = [:]
        for player in [GKLocalPlayer.local] + match.players {
            guard let seat = seats[player.gamePlayerID] else { continue }
            let mine = player == GKLocalPlayer.local
            chairs[seat] = Table.Chair(
                // Everybody by id; `seat(_:asLocal:)` promotes this device's own.
                occupant: .remote(playerID: player.gamePlayerID),
                name: mine && !HooperKit.shared.name.isEmpty
                    ? HooperKit.shared.name : player.displayName,
                // The host's own man goes out with the table. Everybody else's arrives
                // with their `ready`, which is the first thing their device says.
                look: mine ? Table.shared.myLook : nil)
        }
        // Anybody who did not turn up is played by the house, and the house has no look.
        for seat in Seat.allCases where chairs[seat] == nil {
            chairs[seat] = Table.Chair(occupant: .computer, name: seat.houseName)
        }
        Table.shared.seat(chairs, asLocal: seats[me] ?? .south)
        reseatEveryone()
        DevLog.say(.net, "seated \(chairs.count) — host is \(isHost ? "me" : "them")")
        // Anything anybody said while this device was still working out who it was.
        flushHeldMessages()
    }

    /// **Messages that arrived before this device knew who the host was.**
    ///
    /// `chooseBestHostingPlayer` answers when it answers, and the other phone's may come
    /// back first — so the host's `seated` can land while `hostID` is still nil, and a
    /// message from nobody-in-particular is dropped. A guest that drops that one plays
    /// the whole match in a chair it worked out for itself. Held instead, and read the
    /// moment there is somebody to check them against.
    private var held: [(id: String, data: Data)] = []

    private func flushHeldMessages() {
        let waiting = held
        held.removeAll()
        for message in waiting { read(message.data, from: message.id) }
    }

    /// One message off the wire, read the only way this device can read it.
    ///
    /// **Which way depends entirely on who this device turns out to be**, and until the
    /// election has answered it is neither — so a message that lands in that gap is held
    /// rather than guessed at. The gap is real: `chooseBestHostingPlayer` answers when it
    /// answers, and the other phone's can come back first.
    private func read(_ data: Data, from id: String) {
        guard hostID != nil else {
            held.append((id: id, data: data))
            DevLog.say(.net, "held a message — no host elected yet")
            return
        }
        // The host hears choices; everybody else hears the game.
        guard isHost else { return readAsGuest(data, from: id) }
        guard let seat = seats[id],
              let message = try? MatchCoder.decode(ClientMessage.self, from: data)
        else { return }
        onClientMessage?(seat, message)
    }

    /// One message, as somebody who is not running the rules.
    ///
    /// **Read here as well as passed on.** Until the game starts there is no controller to
    /// pass anything to — one is not made until there is a match to play, or opening the
    /// lobby deals a game behind it — so the messages that arrive before that point are
    /// acted on by the wire itself.
    private func readAsGuest(_ data: Data, from id: String) {
        guard id == hostID,
              let message = try? MatchCoder.decode(HostMessage.self, from: data)
        else { return }
        switch message {
        case .start:
            status = .playing
        case .seated(let seat, let chairs, let crew):
            Table.shared.seat(chairs, asLocal: seat)
            // Your own man is the one thing you already know, and the host's copy of the
            // table is a beat behind on it until your `ready` gets there.
            Table.shared.setLook(Table.shared.myLook, at: seat)
            Table.shared.setCrew(crew)
            self.crew = crew
            DevLog.say(.net, "seated at \(seat.name) by the host")
        default:
            break
        }
        onHostMessage?(message)
    }

    // MARK: - Talking

    func send(_ message: HostMessage, to seat: Seat) throws {
        guard let match, let id = seats.first(where: { $0.value == seat })?.key,
              let player = match.players.first(where: { $0.gamePlayerID == id })
        else { return }
        let data = try MatchCoder.encode(message)
        do {
            try match.send(data, to: [player], dataMode: .reliable)
        } catch {
            // GameKit refuses a reliable send over roughly 87 KB, and says so only here.
            DevLog.say(.net, "send to \(seat.name) FAILED at \(data.count) bytes: \(error)")
            throw error
        }
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
        let data = try MatchCoder.encode(message)
        do {
            try match.send(data, to: [host], dataMode: .reliable)
        } catch {
            DevLog.say(.net, "send to the host FAILED at \(data.count) bytes: \(error)")
            throw error
        }
    }
}

extension GameCenterMatch: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data,
                           fromRemotePlayer player: GKPlayer) {
        let id = player.gamePlayerID
        Task { @MainActor in
            self.read(data, from: id)
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer,
                           didChange state: GKPlayerConnectionState) {
        let id = player.gamePlayerID
        let name = player.displayName
        Task { @MainActor in
            switch state {
            case .connected:
                // The other half of the handshake, and it was being thrown away.
                DevLog.say(.net, "\(name) connected")
                self.settleIfEveryoneIsHere()
            case .disconnected:
                DevLog.say(.net, "\(name) dropped")
                guard let seat = self.seats[id] else { return }
                self.onSeatLost?(seat)
            default:
                break
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: (any Error)?) {
        Task { @MainActor in
            self.status = .failed(error?.localizedDescription ?? "The match ended.")
        }
    }
}
