import SwiftUI

/// The player's own controls, laid straight over the court with no panel behind them.
struct ActionBarView: View {
    let controller: GameController
    @Binding var detail: Card?

    private var state: GameState { controller.state }
    private var bag: [Card] { controller.human.bag }

    /// The rules decide what is playable, not the view. Without this the AI would be
    /// bound by a Clamp and the human would not.
    private var legal: [Move] {
        guard case .awaitingMove = controller.gate else { return [] }
        return Rules.legalMoves(state, for: GameRules.localSeat)
    }

    private var playableCards: Set<Card.ID> {
        Set(legal.compactMap { if case .play(let id) = $0 { return id } else { return nil } })
    }

    private var canShoot: Bool { legal.contains(.shoot) }

    /// What a Clamp is holding down. Marked whether or not it is your turn — a lock is a
    /// standing fact about your hand, not a thing that only exists while you are asked.
    private var lockedCards: Set<Card.ID> {
        Rules.lockedCards(state, for: GameRules.localSeat)
    }

    private var dormantCards: Set<Card.ID> {
        Set(bag.filter { Rules.isDormant($0.descriptor, for: GameRules.localSeat, in: state) }
            .map(\.id))
    }

    /// Bids and Turnaround Three pick cards; a possession plays one.
    private var isSelecting: Bool {
        switch controller.gate {
        case .awaitingBid, .awaitingDiscard: return true
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            FannedBagView(cards: bag,
                          seat: GameRules.localSeat,
                          lastPasser: state.lastPasser,
                          playable: playableCards,
                          dormant: dormantCards,
                          isSelecting: isSelecting,
                          selected: controller.bidSelection,
                          locked: lockedCards,
                          detail: $detail,
                          onCommit: commit)
            if case .awaitingBid = controller.gate, controller.revealedBids == nil { confirmBid }
            if case .awaitingDiscard = controller.gate { confirmDiscard }
            if case .awaitingMove = controller.gate, canShoot { shootButton }
            prompt
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
    }

    /// A drag clear of the log, or a second tap, means this card.
    private func commit(_ card: Card) {
        switch controller.gate {
        case .awaitingMove:
            guard playableCards.contains(card.id) else { return }
            controller.play(card)
        case .awaitingBid, .awaitingDiscard:
            if controller.bidSelection.contains(card.id) {
                controller.bidSelection.remove(card.id)
            } else {
                controller.bidSelection.insert(card.id)
            }
        default:
            break
        }
    }

    // MARK: - Prompt

    /// Only lingering effects get announced. What a card does and how to play it is
    /// the card's job, not a running caption.
    @ViewBuilder private var prompt: some View {
        let standing = standingEffects
        if !standing.isEmpty {
            Text(standing.joined(separator: "  ·  "))
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Theme.ball)
                .shadow(color: .black.opacity(0.85), radius: 3)
                .frame(maxWidth: .infinity)
        }
    }

    private var standingEffects: [String] {
        // The referees say themselves what they are doing — see `StatusHUDView`. Only
        // what is standing on *you* is worth spelling out down here.
        var notes: [String] = []
        for clamp in controller.human.clamps {
            notes.append(clamp.card.name.uppercased() + " ON YOU")
        }
        return notes
    }

    // MARK: - Buttons

    private var shootButton: some View {
        Button { controller.shoot() } label: {
            HStack(spacing: 5) {
                Text("SHOOT").font(.system(size: 19, weight: .black)).tracking(1.2)
                Text("(\(state.shot)%)").font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.ball))
        }
        .frame(width: 190)
    }

    private var confirmDiscard: some View {
        let count = controller.bidSelection.count
        let bonus: Int = {
            if case .awaitingDiscard(_, let each) = controller.gate { return each * count }
            return 0
        }()
        return Button { controller.submitDiscard() } label: {
            Text(count == 0 ? "SHOOT AS IS" : "FEED \(count) → +\(bonus)%")
                .font(.system(size: 14, weight: .black)).tracking(1.1)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(count == 0 ? Theme.ink : Theme.ball))
        }
        .frame(width: 220)
    }

    private var confirmBid: some View {
        Button { controller.submitBid() } label: {
            Text(controller.bidSelection.isEmpty
                 ? "BID NOTHING"
                 : "BID \(controller.bidSelection.count)")
                .font(.system(size: 14, weight: .black))
                .tracking(1.1)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(controller.bidSelection.isEmpty ? Theme.ink : Theme.live))
        }
        .frame(width: 220)
    }
}
