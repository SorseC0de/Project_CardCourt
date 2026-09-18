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
        answer(&state, &ai) != nil
    }

    /// The same answers, with what they cost — nil when there was nothing to answer.
    ///
    /// **One owner.** `step` is this, read as a yes or no: a measurement that wants to
    /// know what a question took off a hand cannot have a second copy of the answers,
    /// or the harness and the game drift apart question by question.
    static func answer(_ state: inout GameState, _ ai: inout AITable) -> [GameEvent]? {
        switch state.phase {
        // Nobody decides a referee's throw-in; the floor shows it and it lands.
        case .refereeInbound:
            return Rules.completeRefereeInbound(state: &state)
        case .awaitingTarget(let seat, _, let choices):
            // Whoever holds the most: the man worth finding, and the man worth taking
            // from. The same rule either way, because the AI has no reason to prefer one.
            let worth = Rules.sensibleTargets(choices, for: state.pendingActor ?? seat,
                                              in: state)
            let pick = worth.max { state[$0].bag.count < state[$1].bag.count } ?? worth[0]
            _ = seat
            return Rules.resolveTarget(pick, state: &state)
        case .awaitingCounter(let seat, _):
            // Worth it for what is about to land on him, and nothing otherwise.
            _ = seat
            // A Lob's "Dunk It?" is always worth taking.
            return Rules.resolveCounter(!state.pendingClamps.isEmpty
                                        || state.heldPossession == nil, state: &state)
        case .awaitingOption(let seat, let option):
            return Rules.resolveOption(Rules.houseTakes(option, for: seat, in: state),
                                       state: &state)
        case .awaitingDiscard(let seat, _, _):
            // Stepback and Turnaround Three ask the same question. Nothing fed in is
            // always a legal answer, which is what an absent player gives.
            return Rules.resolveDiscardForShot(ai.discardForShot(state, for: seat),
                                               state: &state)
        case .awaitingMode(let seat, let card):
            return Rules.resolveMode(ai.mode(of: card, state, for: seat), state: &state)
        case .awaitingChallenge(let seat, _):
            // **Spend it where it is worth spending.** A call that costs the ball is worth
            // a challenge; one that costs a card is not, and the official going off with
            // it is worth something on its own.
            return Rules.resolveChallenge(AIPolicy.challenges(state, for: seat),
                                          state: &state)
        case .awaitingClampsNamed(let seat, let card, let named):
            // **Sell it to as many as the clock can pay for.** Every one is SHOT; the
            // cost is ticks, so it stops while there is still a clock to shoot on.
            let clock = state.shotClock ?? 99
            let room = clock + card.clockPerClampNamed * (named.count + 1) > 1
            let next = state[seat].clamps.first { !named.contains($0.id) }
            return Rules.resolveClampNamed(room ? next?.id : nil, state: &state)
        case .awaitingRetirement(let seat, _, let choices):
            // The same read the shot takes, spent a step earlier.
            return Rules.resolveRetirement(AIPolicy.retires(choices, state, for: seat),
                                           state: &state)
        case .awaitingCardFrom(_, _, let victim):
            // Face down to everybody, so there is nothing to be clever about — and an
            // empty hand is answered too, by taking nothing.
            return Rules.resolveCardFrom(state[victim].bag.randomElement()?.id ?? UUID(),
                                         state: &state)
        case .awaitingNaming(_, _, let named):
            // Everyone but the leader. The SHOT is worth having; handing the man in front
            // an assist is not.
            let shooter = state.ball
            let best = Seat.allCases.max { state[$0].score < state[$1].score }
            let next = Seat.allCases.first {
                $0 != shooter && $0 != best && !named.contains($0)
            }
            return Rules.resolveNaming(next, state: &state)
        case .awaitingToll(_, let victim):
            // A passive is worth more than a card off a hand nobody can read.
            let pick: CardPick = state[victim].intangibles.first.map { .named($0.id) }
                ?? .position(Int.random(in: 0..<max(1, state[victim].bag.count)))
            return Rules.resolveToll(pick, state: &state)
        case .awaitingIntangibleDrop(_, let offered):
            // A passive that only hurts is the one to give up; failing that, the oldest,
            // which is what the rule used to do on its own.
            let worst = offered.first { ($0.intangible?.shotBonus ?? 0) < 0
                                        || $0.intangible?.blocksMoves == true }
            return Rules.resolveIntangibleDrop(worst?.id ?? offered[0].id, state: &state)
        case .awaitingInjuryPick:
            // Whatever is face up and mildest; failing that, whatever is on offer.
            let offered = state.injuriesOffered
            let seen = offered.filter { !state.injuriesHidden.contains($0.id) }
            guard let pick = (seen.first ?? offered.first)?.id else { return nil }
            return Rules.resolveInjuryPick(pick, state: &state)
        case .awaitingGiveUp(let seat, _, let count):
            let chosen = Array(ai.discardForShot(state, for: seat).prefix(count))
            return Rules.resolveGiveUp(chosen, state: &state)
        default:
            return nil
        }
    }
}
