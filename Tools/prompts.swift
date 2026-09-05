import Foundation

/// The phases that ask a question rather than accept a move.
///
/// The headless harness has six loops that drive a game, and every one of them steps the
/// state by asking the AI for a `Move`. A prompt phase has no move — it is answered by
/// its own resolver — so without this a game reaching one simply stopped, and every
/// simulation quietly ran short.
///
/// One place, so a new prompt is taught to all six at once.
enum Prompts {
    /// Answers whatever the state is waiting on. True if it answered something.
    @discardableResult
    static func step(_ state: inout GameState, _ ai: inout AITable) -> Bool {
        switch state.phase {
        case .awaitingTarget(let seat, _, let choices):
            // Whoever holds the most: the man worth finding, and the man worth taking
            // from. The same rule either way, because the AI has no reason to prefer one.
            let pick = choices.max { state[$0].bag.count < state[$1].bag.count } ?? choices[0]
            _ = seat
            Rules.resolveTarget(pick, state: &state)
            return true
        case .awaitingMode(let seat, let card):
            Rules.resolveMode(ai.mode(of: card, state, for: seat), state: &state)
            return true
        case .awaitingCardFrom(_, _, let victim):
            // Face down to everybody, so there is nothing to be clever about.
            let hand = state[victim].bag
            guard let pick = hand.first else { return false }
            Rules.resolveCardFrom(hand.randomElement()?.id ?? pick.id, state: &state)
            return true
        case .awaitingInjuryPick:
            // Whatever is face up and mildest; failing that, whatever is on offer.
            let offered = state.injuriesOffered
            let seen = offered.filter { !state.injuriesHidden.contains($0.id) }
            guard let pick = (seen.first ?? offered.first)?.id else { return false }
            Rules.resolveInjuryPick(pick, state: &state)
            return true
        case .awaitingInjuryDiscard(let seat, let count):
            let chosen = Array(ai.discardForShot(state, for: seat).prefix(count))
            Rules.resolveInjuryDiscard(chosen, state: &state)
            return true
        default:
            return false
        }
    }
}
