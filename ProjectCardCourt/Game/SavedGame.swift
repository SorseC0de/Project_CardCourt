import Foundation

/// **The game in progress, kept across the app being killed.**
///
/// A game is one value — `GameState`, which already crosses the wire whole — so keeping
/// it is writing that value down. Solo games only: a match is other devices' game as much
/// as this one's, and one of them coming back on its own would be a table of one.
///
/// Written to a file rather than to `UserDefaults`: it is a whole deck and four hands, and
/// defaults are for switches.
enum SavedGame {
    private static var file: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory,
                                              in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("game-in-progress.json")
    }

    /// Whether there is a game to come back to.
    static var exists: Bool { FileManager.default.fileExists(atPath: file.path) }

    /// Keeps it. **Quietly**: a save that fails is a game that will not resume, not a game
    /// that stops, so nothing here is allowed to interrupt the one being played.
    static func save(_ state: GameState) {
        guard !state.isOver else { return clear() }
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: file, options: .atomic)
    }

    /// The game that was being played, if one was and it still reads.
    static func load() -> GameState? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        // A save from before the rules changed shape will not decode, and is simply gone:
        // a game that cannot be read cannot be resumed, and should not be offered.
        guard let state = try? JSONDecoder().decode(GameState.self, from: data) else {
            clear()
            return nil
        }
        return state.isOver ? nil : state
    }

    static func clear() {
        try? FileManager.default.removeItem(at: file)
    }
}
