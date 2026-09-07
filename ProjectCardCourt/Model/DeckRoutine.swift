import Foundation

// Hoisted out of View/DeckStage.swift. What the pile is *doing* is a fact about the
// game; `DeckStage` is a RealityKit scene and cannot leave the view layer. The
// typealias keeps every existing `DeckStage.Routine` spelling working.

/// Something the deck can be asked to do.
enum DeckRoutine: Equatable {
    case rest
    /// Floats up, breaks apart, gathers, and does it again before settling.
    case shuffle
    /// Drops hard enough to knock itself out of true, then tidies up.
    case landing
    /// A shuffle that finishes by landing — what a fresh deal opens with.
    case deal
}

