import Foundation

// Moved out of View/ActionCallView.swift. **What is being called** is a fact about
// the game; what colour it is called in is not. The three Color members stay behind
// as an extension on the view side.

/// A phase or event announcing itself across the screen.
///
/// The bars are Project Stars' — see `ModeCardView` — and the lettering is ours. What is
/// different here is that nothing is being chosen: a mode card in Stars waits for a Start
/// button, and this one is telling you what just happened, so it leaves on its own.
enum ActionCall: String, Identifiable, Equatable, CaseIterable {
    case inbound, gameBreak, whistle, clamped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbound:   return "Inbound"
        case .gameBreak: return "Game Break!"
        case .whistle:   return "Whistle"
        case .clamped:   return "Clamped!"
        }
    }

    /// The line under it. What the call means, not what it is called.
    var blurb: String {
        switch self {
        case .inbound:   return "Put the ball back in play"
        // Deliberately silent. It says nothing a player needs and reads as an
        // explanation of something that has not happened yet.
        case .gameBreak: return ""
        // The whistle says it with the whistle. See `emblem`.
        case .whistle:   return ""
        case .clamped:   return "Defenders are guarding you closely"
        }
    }

    /// Whether the bars cross without stopping.
    ///
    /// A Game Break is the game telling you something happened, not asking anything, and
    /// it fires often enough that a card holding its position is a card in the way. The
    /// rest have something to read on them — a whistle, a roster of Clamps — and are held.
    var passesThrough: Bool { self == .gameBreak }

    /// A call that shows a picture rather than a word. The gold whistle is the same art
    /// the reveal opens with, moved up onto the call so the two are one moment instead of
    /// the whistle being announced and then shown.
    var emblem: String? { self == .whistle ? "GoldWhistle" : nil }

    /// Whether the call darkens the floor behind it. All of them but the inbound, which
    /// already sits on a court the inbound pose has dimmed — a second scrim over that one
    /// multiplies into near-black.
    var dims: Bool { self != .inbound }

}
