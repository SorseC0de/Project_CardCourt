import GameKit
import SwiftUI

/// The way into a match.
///
/// **There are no rooms.** Game Center pairs you with whoever else is searching at that
/// moment; it has no notion of an open room and no way to list one over the internet,
/// because that would need a server it does not provide. So the screen says what is
/// actually happening — you join a queue, and people arrive — rather than dressing a
/// queue up as a lobby you are choosing from.
///
/// The table stays empty until somebody is really in it. Showing three computers in the
/// chairs before a match exists made it look like a game was already under way.
struct MatchLobbyView: View {
    var controller: GameController
    @State private var session = GameCenterMatch()
    @State private var table = Table.shared
    /// Held between the clasp and the table appearing, so the shake gets its moment
    /// rather than being cut off by the thing it was waiting for.
    @State private var shaking = false
    @Environment(\.dismiss) private var dismiss

    private enum Beat {
        /// How long the full handshake holds before the table comes up.
        static let clasp = 1.2
    }

    var body: some View {
        ZStack {
            Chrome.ground.ignoresSafeArea()
            CourtStreaks().opacity(0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 16) {
                        ScreenTitle(text: "Pickup Game", drop: CardPalette.blue)
                            .padding(.top, 22)
                        Text(shaking ? "Matched." : caption)
                            .font(.custom(Chrome.display, size: 17))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        chairs.padding(.horizontal, 22)
                    }
                    .padding(.bottom, 20)
                }
                if !shaking {
                    actions.padding(.horizontal, 22).padding(.bottom, 26)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            // Wired before signing in, so the handlers are live before the first message
            // can arrive. `isActive` keeps a solo game solo until a match is running.
            controller.join(session)
            session.signIn()
        }
        .sheet(item: $session.pendingSignIn) { sheet in
            SignInSheet(controller: sheet.controller).ignoresSafeArea()
        }
        .onChange(of: session.status) { _, status in
            // Matched. The hands come together before the table is shown — the shake is
            // the moment the two of you met, and it is over in a second and a bit.
            if status == .seated {
                withAnimation(.easeOut(duration: 0.3)) { shaking = true }
                Task {
                    try? await Task.sleep(for: .seconds(Beat.clasp))
                    withAnimation(.easeOut(duration: 0.3)) { shaking = false }
                }
            }
            // The host starts it; everybody else is told. Either way the lobby's job is
            // done the moment the game is running.
            guard status == .playing else { return }
            if session.isHost { controller.begin() }
            dismiss()
        }
    }

    // MARK: - The bar

    private var topBar: some View {
        HStack(spacing: 10) {
            StatPill(reading: signedInAs) {
                Image(systemName: "person.fill")
                    .resizable().scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(CardPalette.gold)
            }
            Spacer()
            if session.isActive {
                StatPill(reading: "\(session.seated)/4") {
                    SpriteAnimation(sprite: .heads, scale: 4, isPlaying: false, restFrame: 0)
                }
            }
            Button { dismiss() } label: {
                Chip(fill: CardPalette.red, stroke: CardPalette.gold,
                     shade: CardPalette.orange, side: 38) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Chrome.ground)
    }

    // MARK: - The table

    /// Nothing at all until there is a match, then a chair for every seat.
    ///
    /// The empty ones are drawn as empty rather than filled with the house, because until
    /// the game starts they might still be somebody. They only become the house when the
    /// host starts with the table short.
    @ViewBuilder private var chairs: some View {
        if shaking {
            // The clasp, alone on the screen. Whatever it was waiting for can wait.
            HandshakeView(clasped: true)
                .padding(.vertical, 30)
                .transition(.opacity)
        } else if session.isActive {
            ForEach(Seat.allCases, id: \.self) { chair($0) }
        } else if case .searching = session.status {
            waiting
        }
    }

    private func chair(_ seat: Seat) -> some View {
        let taken = table.occupant(at: seat) != .computer
        return Panel(fill: seat.isLocal ? CardPalette.blue
                     : (taken ? CardPalette.red : Chrome.ground)) {
            HStack(spacing: 14) {
                Chip {
                    Image(systemName: taken ? glyph(for: seat) : "person.fill.badge.plus")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(taken ? .white : .white.opacity(0.35))
                }
                VStack(alignment: .leading, spacing: 6) {
                    SmallCapsText(text: taken ? table.name(at: seat) : "Open",
                                  font: Chrome.display, size: 28, tracking: 1)
                        .foregroundStyle(taken ? .white : .white.opacity(0.4))
                        .shadow(color: Chrome.shade, radius: 0, x: 5, y: 5)
                    if taken {
                        RibbonTag(text: standing(at: seat), fill: badge(for: seat),
                                  ink: seat.isLocal ? .white : CardPalette.navy)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: table.chairs)
    }

    /// What the queue looks like from inside it.
    private var waiting: some View {
        Panel(fill: Chrome.ground) {
            VStack(spacing: 14) {
                // Your half of it, with nothing yet to hold.
                HandshakeView(clasped: false, side: 180)
                SmallCapsText(text: "Waiting for players", font: Chrome.display, size: 22)
                    .foregroundStyle(.white)
                Text("You will be paired with anyone else searching right now. "
                     + "There is no room to pick — Game Center does the matching.")
                    .font(.custom(Chrome.display, size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(26)
            .frame(maxWidth: .infinity)
        }
    }

    private func glyph(for seat: Seat) -> String {
        switch table.occupant(at: seat) {
        case .local:    return "figure.basketball"
        case .remote:   return "person.fill"
        case .computer: return "desktopcomputer"
        }
    }

    private func standing(at seat: Seat) -> String {
        switch table.occupant(at: seat) {
        case .local:    return "You"
        case .remote:   return "Ready"
        case .computer: return "House"
        }
    }

    private func badge(for seat: Seat) -> Color {
        switch table.occupant(at: seat) {
        case .local:    return CardPalette.orange
        case .remote:   return CardPalette.gold
        case .computer: return .white
        }
    }

    // MARK: - What you can do about it

    @ViewBuilder
    private var actions: some View {
        switch session.status {
        case .signedOut, .failed:
            ChunkyButton(title: "Sign in", fill: CardPalette.orange) { session.signIn() }
        case .signingIn:
            ChunkyButton(title: "Signing in…", fill: CardPalette.gray, isEnabled: false) {}
        case .ready:
            ChunkyButton(title: "Find a game") { Task { await session.findMatch() } }
        case .searching:
            ChunkyButton(title: "Cancel", fill: CardPalette.red) { session.stop() }
        case .seated:
            VStack(spacing: 12) {
                if session.isHost {
                    // Only the host can start, and starting is what fills the rest of the
                    // table with the house.
                    ChunkyButton(title: "Start game") { session.startPlaying() }
                } else {
                    ChunkyButton(title: "Waiting for the host", fill: CardPalette.gray,
                                 isEnabled: false) {}
                }
                Button { session.stop() } label: {
                    SmallCapsText(text: "Leave the table", font: Chrome.display, size: 15)
                        .foregroundStyle(CardPalette.red)
                }
                .buttonStyle(.plain)
            }
        case .playing:
            ChunkyButton(title: "Take the floor", fill: CardPalette.gold) { dismiss() }
        }
    }

    private var caption: String {
        switch session.status {
        case .signedOut:          return "Game Center handles the accounts and the matching."
        case .signingIn:          return "Signing in…"
        case .ready:              return "Two makes a game. Any empty chair is played by the house."
        case .searching:          return "Looking for somebody else who is looking."
        case .seated:
            return session.isHost
                ? "Start when you are ready. Empty chairs go to the house."
                : "\(hostName) starts the game."
        case .playing:            return "Seated."
        case .failed(let reason): return reason
        }
    }

    private var hostName: String {
        Seat.allCases.first { table.isRemote($0) }.map { table.name(at: $0) } ?? "The host"
    }

    private var signedInAs: String {
        if case .ready(let player) = session.status { return player }
        if case .signedOut = session.status { return "Signed out" }
        if case .signingIn = session.status { return "Signing in" }
        return GKLocalPlayer.local.displayName
    }
}

#if DEBUG
#Preview("Lobby") {
    MatchLobbyView(controller: GameController())
}
#endif

/// Game Center's sign-in, which arrives as a plain view controller.
private struct SignInSheet: UIViewControllerRepresentable {
    let controller: UIViewController

    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
