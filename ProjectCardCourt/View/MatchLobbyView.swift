import GameKit
import SwiftUI

/// The way into a match.
///
/// Built as the table itself rather than as a form: four chairs down the screen, each one
/// a panel in that seat's own colour, filling with names as people arrive. Whoever is
/// still missing is the house, and a chair says so — you can see the whole game before you
/// are in it, which is the only thing a lobby is really for.
struct MatchLobbyView: View {
    var controller: GameController
    @State private var session = GameCenterMatch()
    @State private var table = Table.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // The court's own streaks, well behind everything. The menus are the same
            // place as the game, seen from the tunnel.
            Chrome.ground.ignoresSafeArea()
            CourtStreaks()
                .opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 16) {
                        ScreenTitle(text: "Pickup Game", drop: CardPalette.blue)
                            .padding(.top, 22)
                        Text(caption)
                            .font(.custom(Chrome.display, size: 17))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        ForEach(Seat.allCases, id: \.self) { chair($0) }
                            .padding(.horizontal, 22)
                    }
                    .padding(.bottom, 20)
                }
                actions
                    .padding(.horizontal, 22)
                    .padding(.bottom, 26)
            }
        }
        .onAppear { session.signIn() }
        // Apple's own sign-in, handed over rather than reimplemented. Without this the
        // whole thing stalls silently on a device that is not already signed in.
        .sheet(item: $session.pendingSignIn) { sheet in
            SignInSheet(controller: sheet.controller).ignoresSafeArea()
        }
        .onChange(of: session.status) { _, status in
            guard status == .playing else { return }
            controller.join(session)
            controller.begin()
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
            // How many of the four chairs have somebody in them. The game's own face
            // rather than a symbol — a deck was standing in here and said nothing about
            // people at all.
            StatPill(reading: "\(seated)/4") {
                SpriteAnimation(sprite: .faces, scale: 4, isPlaying: false, restFrame: 0)
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

    // MARK: - The chairs

    private func chair(_ seat: Seat) -> some View {
        // Yours is blue and the other three are red — one line between you and everybody
        // else, rather than four colours that read as four teams.
        Panel(fill: seat.isLocal ? CardPalette.blue : CardPalette.red) {
            HStack(spacing: 14) {
                Chip {
                    Image(systemName: glyph(for: seat))
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 6) {
                    SmallCapsText(text: table.name(at: seat), font: Chrome.display,
                                  size: 28, tracking: 1)
                        .foregroundStyle(.white)
                        // Heavy. A name is the only thing on a chair worth reading from
                        // across the room, and the drop is what gives it that weight.
                        .shadow(color: Chrome.shade, radius: 0, x: 5, y: 5)
                    RibbonTag(text: standing(at: seat), fill: badge(for: seat),
                              ink: seat.isLocal ? .white : CardPalette.navy)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: table.chairs)
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
        case .signingIn, .searching:
            ChunkyButton(title: session.status == .searching ? "Searching…" : "Locking in…",
                         fill: CardPalette.gray, isEnabled: false) {}
        case .ready:
            ChunkyButton(title: "Find players") { Task { await session.findMatch() } }
        case .playing:
            VStack(spacing: 12) {
                ChunkyButton(title: "Take the floor", fill: CardPalette.gold) { dismiss() }
                Button {
                    session.leave()
                    dismiss()
                } label: {
                    SmallCapsText(text: "Leave the table", font: Chrome.display, size: 15)
                        .foregroundStyle(CardPalette.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var caption: String {
        switch session.status {
        case .signedOut:          return "Game Center handles the accounts and the invites."
        case .signingIn:          return "Locking in…"
        case .ready:              return "Two makes a game. Four makes the game."
        case .searching:          return "Looking for a table."
        case .playing:            return "Seated. Any empty chair is played by the house."
        case .failed(let reason): return reason
        }
    }

    private var signedInAs: String {
        if case .ready(let player) = session.status { return player }
        if case .playing = session.status { return GKLocalPlayer.local.displayName }
        return "Signed out"
    }

    private var seated: Int {
        Seat.allCases.filter { table.occupant(at: $0) != .computer }.count
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
