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
        case .awaitingClearOut(let seat, _):
            // Worth it for what is about to land on him, and nothing otherwise.
            _ = seat
            Rules.resolveClearOut(!state.pendingClamps.isEmpty, state: &state)
            return true
        case .awaitingDiscard(let seat, _, _):
            // Stepback and Turnaround Three ask the same question. Nothing fed in is
            // always a legal answer, which is what an absent player gives.
            Rules.resolveDiscardForShot(ai.discardForShot(state, for: seat), state: &state)
            return true
        case .awaitingMode(let seat, let card):
            Rules.resolveMode(ai.mode(of: card, state, for: seat), state: &state)
            return true
        case .awaitingCardFrom(_, _, let victim):
            // Face down to everybody, so there is nothing to be clever about — and an
            // empty hand is answered too, by taking nothing.
            Rules.resolveCardFrom(state[victim].bag.randomElement()?.id ?? UUID(), state: &state)
            return true
        case .awaitingNaming(_, _, let named):
            // Everyone but the leader. The SHOT is worth having; handing the man in front
            // an assist is not.
            let shooter = state.ball
            let best = Seat.allCases.max { state[$0].score < state[$1].score }
            let next = Seat.allCases.first {
                $0 != shooter && $0 != best && !named.contains($0)
            }
            Rules.resolveNaming(next, state: &state)
            return true
        case .awaitingToll(_, let victim):
            // A passive is worth more than a card off a hand nobody can read.
            let pick: CardPick = state[victim].intangibles.first.map { .named($0.id) }
                ?? .position(Int.random(in: 0..<max(1, state[victim].bag.count)))
            Rules.resolveToll(pick, state: &state)
            return true
        case .awaitingIntangibleDrop(_, let offered):
            // A passive that only hurts is the one to give up; failing that, the oldest,
            // which is what the rule used to do on its own.
            let worst = offered.first { ($0.intangible?.shotBonus ?? 0) < 0
                                        || $0.intangible?.blocksMoves == true }
            Rules.resolveIntangibleDrop(worst?.id ?? offered[0].id, state: &state)
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
