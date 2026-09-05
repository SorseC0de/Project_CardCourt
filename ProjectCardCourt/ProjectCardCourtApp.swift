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
        case front, game, gallery, hooper
    }

    @State private var screen: Screen = .front
    /// Whether the game was entered to play online. The lobby needs the controller
    /// `GameView` owns, so this rides in with it.
    @State private var straightToLobby = false
#if DEBUG
    @State private var bench = false
#endif

    var body: some View {
        ZStack {
            switch screen {
            case .front:
                EntryScreenView(
                    onPlay: { straightToLobby = false; screen = .game },
                    onLobby: { straightToLobby = true; screen = .game },
                    onGallery: { screen = .gallery },
                    onHooper: { screen = .hooper },
                    onSettings: {
#if DEBUG
                        bench = true
#endif
                    })
                    .transition(.opacity)
                    // The court is a RealityKit scene, and the first one in a process
                    // costs seconds to bring up. Spent here, under the menu.
                    .overlay(alignment: .bottomLeading) { RealityWarmup() }
            case .game:
                GameView(opensLobby: straightToLobby).transition(.opacity)
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
