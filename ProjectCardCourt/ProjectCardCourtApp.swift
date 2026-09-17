import SwiftUI

@main
struct ProjectCardCourtApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}

/// What the app opens on, and where every screen hangs off.
///
/// The game is one destination among several rather than the app itself. Everything is
/// held here rather than pushed, so leaving a match does not tear the controller down —
/// `GameView` owns its own and would start a fresh game every time you came back.
struct RootView: View {
    private enum Screen {
        case front, lobby, game, gallery, hooper, howToPlay
    }

    @State private var screen: Screen = .front

    /// **The game, and nothing until there is one to play.** make it 1.5 
    ///
    /// A `GameController` deals the moment it exists — it has to, since it cannot know
    /// yet whether it is about to be a match — so one held while a menu is up is a deck
    /// shuffled and a hand dealt behind that menu. It is made when a game actually
    /// starts, and dropped when one is quit.
    @State private var game: GameController?
    /// The match, which outlives no game and starts none. Made when the lobby is opened
    /// and put down when it is left.
    @State private var session: GameCenterMatch?
#if DEBUG
    @State private var bench = false
#endif

    /// Deals a game and shows it. The only place one begins.
    private func deal() {
        game?.quit()
        game = GameController()
        screen = .game
    }

    /// Opens the queue. **No game is dealt here** — there is nothing to deal for yet, and
    /// a deck shuffled behind the lobby is a game being played in the dark.
    private func lobby() {
        game?.quit()
        game = nil
        session = GameCenterMatch()
        screen = .lobby
    }

    /// The match is on. Now there is something to deal for.
    ///
    /// **It does not begin the game.** `GameView` does that when it appears, the way it
    /// always has for a solo one — the opening deal has to fly across a court that
    /// exists. Beginning it here as well dealt the table twice: two shuffles, two seeds,
    /// and the second one cancelling the first mid-broadcast.
    private func startMatch() {
        // **One controller per match.** The lobby says the game has started twice — the
        // status changing, and the button that changes it — and a second controller here
        // is a second game dealt against the same wire.
        guard let session, game == nil else { return }
        let controller = GameController()
        controller.join(session)
        game = controller
        screen = .game
    }

    /// Ends it and unloads it. Coming back means dealing again.
    private func quit() {
        game?.quit()
        game = nil
        session?.leave()
        session = nil
        Table.shared.seatSolo()
        screen = .front
    }

    var body: some View {
        ZStack {
            switch screen {
            case .front:
                EntryScreenView(
                    onPlay: { deal() },
                    onHowToPlay: { screen = .howToPlay },
                    onLobby: { lobby() },
                    onGallery: { screen = .gallery },
                    onHooper: { screen = .hooper },
                    onSettings: {
#if DEBUG
                        bench = true
#endif
                    })
                    .transition(.opacity)
            case .lobby:
                // A screen of its own rather than a sheet over the court. Over the court
                // it was sitting on a game that had already been dealt, and closing it
                // put you in the middle of one you never asked to play.
                if let session {
                    MatchLobbyView(session: session,
                                   onLeave: { quit() },
                                   onStart: { startMatch() })
                        .transition(.opacity)
                }
            case .game:
                if let game {
                    GameView(controller: game,
                             onQuit: { quit() },
                             onRunItBack: { deal() })
                        // **A new game is a new screen.** Run It Back swaps the controller
                        // with the screen still on `.game`, and without this SwiftUI kept
                        // the old view — its `.task` never ran again, so the new game was
                        // never begun and nothing was dealt.
                        .id(ObjectIdentifier(game))
                        .transition(.opacity)
                }
            case .gallery:
                CardGalleryView(onDismiss: { screen = .front })
                    .transition(.opacity)
            case .hooper:
                HooperView(onDismiss: { screen = .front })
                    .transition(.opacity)
            case .howToPlay:
                HowToPlayView(onDismiss: { screen = .front })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screen)
#if DEBUG
        // The switches that have to be reachable before a match, since the bench itself
        // is on the floor of one.
        .sheet(isPresented: $bench) { FrontBenchView(onDismiss: { bench = false }) }
#endif
    }
}
