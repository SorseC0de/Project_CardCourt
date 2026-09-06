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
        case front, lobby, game, gallery, hooper
    }

    @State private var screen: Screen = .front

    /// **The session, and nothing until somebody asks for one.**
    ///
    /// A `GameController` deals a game the moment it exists, so one held here while the
    /// front screen is up is a game being played behind a menu — which is what backing
    /// out of a failed match used to reveal. It is made when a game is asked for and
    /// dropped when one is quit, and the front screen means there is no game at all.
    @State private var game: GameController?
#if DEBUG
    @State private var bench = false
#endif

    /// Deals a session and shows it. The only place a game begins.
    private func open(_ next: Screen) {
        game?.quit()
        game = GameController()
        screen = next
    }

    /// Ends it and unloads it. Coming back means dealing again.
    private func quit() {
        game?.quit()
        game = nil
        Table.shared.seatSolo()
        screen = .front
    }

    var body: some View {
        ZStack {
            switch screen {
            case .front:
                EntryScreenView(
                    onPlay: { open(.game) },
                    onLobby: { open(.lobby) },
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
                if let game {
                    MatchLobbyView(controller: game,
                                   onLeave: { quit() },
                                   onStart: { screen = .game })
                        .transition(.opacity)
                }
            case .game:
                if let game {
                    GameView(controller: game,
                             onQuit: { quit() },
                             onRunItBack: { open(.game) })
                        .transition(.opacity)
                }
            case .gallery:
                CardGalleryView(onDismiss: { screen = .front })
                    .transition(.opacity)
            case .hooper:
                HooperView(onDismiss: { screen = .front })
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
