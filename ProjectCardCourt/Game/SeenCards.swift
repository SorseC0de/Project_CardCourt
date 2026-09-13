import Foundation
import Observation

/// Which cards this player has met, across every game they have played.
///
/// The first thing in the game that outlives a match. Deliberately a set of descriptor
/// ids rather than anything richer: the card gallery and the New badge both only ask
/// "have I met this", and an id survives a card's effect being rebalanced.
@Observable
final class SeenCards {
    static let shared = SeenCards()

    private static let key = "seenCards"
    private var seen: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.seen = Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    private let defaults: UserDefaults

    func hasSeen(_ id: String) -> Bool { seen.contains(id) }

    /// Records a sighting, and says whether it was the first.
    ///
    /// The caller decides *when* a card counts as met — a Whistle is met when it is
    /// called, not when it is set down face-down, or the badge would give the trap away.
    @discardableResult
    func meet(_ id: String) -> Bool {
        guard seen.insert(id).inserted else { return false }
        defaults.set(Array(seen), forKey: Self.key)
        return true
    }

    /// Debug only: forget everything, to see the first sightings again.
    func forgetAll() {
        seen.removeAll()
        defaults.removeObject(forKey: Self.key)
    }
}

/// Which combos this player has pulled off, across every game — what the COMBO button
/// reveals. One route at a time: a Rhythm Dribble into Drive is not a Dribble into Drive.
@Observable
final class DoneCombos {
    static let shared = DoneCombos()

    private static let key = "doneCombos"
    private var done: Set<String>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.done = Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    func hasDone(_ opener: String, into finisher: String) -> Bool {
        done.contains(Combo.route(opener, into: finisher))
    }

    func record(_ opener: String, into finisher: String) {
        guard done.insert(Combo.route(opener, into: finisher)).inserted else { return }
        defaults.set(Array(done), forKey: Self.key)
    }

    /// Debug only: forget every combo, to see the question marks again.
    func forgetAll() {
        done.removeAll()
        defaults.removeObject(forKey: Self.key)
    }
}
