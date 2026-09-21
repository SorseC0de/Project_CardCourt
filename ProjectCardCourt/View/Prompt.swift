import SwiftUI

/// **What the game is asking, and the card doing the asking.**
///
/// One switch over every gate there is, and **no `default`**: a question whose card
/// nobody named will not compile. That is what makes "every prompt shows the card behind
/// it" a property of the code rather than a promise about it — a new gate cannot be added
/// without answering here.
///
/// It says what is being asked and what asked it. How each answer is *given* is still the
/// picker's business; this is the one place that knows the question.
struct Prompt: Equatable {
    /// The card the question is about, when a card is asking. Nil is a question the game
    /// itself asks — whose turn it is, where to throw it in — and those name themselves
    /// on the floor rather than in a banner.
    let card: CardDescriptor?
    /// The question, in a line. Nil where the floor is the question: picking a man to
    /// throw to is answered by pressing him, and a sentence over it says nothing.
    let ask: String?

    /// Whether there is anything to show at all.
    var isEmpty: Bool { card == nil && ask == nil }

    /// **Read off the gate, and only off the gate.**
    ///
    /// Every case answers, including the ones that answer "nothing" — so the compiler is
    /// the thing that keeps this honest rather than somebody remembering.
    @MainActor
    init(gate: GameController.Gate, state: GameState, for seat: Seat) {
        switch gate {
        // ── Questions a card asks ──────────────────────────────────────
        case .awaitingDiscard(let card, let each):
            self.card = card
            self.ask = Prompt.discardAsk(card, each: each, state: state, for: seat)
        case .awaitingGiveUp(let card, let count):
            self.card = card
            // The Discard Phase is a give-up with a reason of its own: say the reason.
            self.ask = card.id == CardLibrary.discardPhase.id
                ? "Over the limit — retire \(count == 1 ? "a card" : "\(count) cards")"
                : "\(card.name): give up \(count == 1 ? "a card" : "\(count) cards")"
        case .awaitingTarget(let card, _):
            self.card = card
            self.ask = "\(card.name): who?"
        case .awaitingMode(let card):
            self.card = card
            self.ask = "\(card.name): which?"
        case .awaitingChallenge(let card):
            self.card = card
            self.ask = "Throw the call out?"
        case .awaitingRetirement(let card, _):
            self.card = card
            self.ask = "\(card.name): take one out of play"
        case .awaitingRetiredPick(let card, _):
            self.card = card
            self.ask = "\(card.name): choose one from Retirement"
        case .awaitingClampsNamed(let card, _):
            self.card = card
            self.ask = "\(card.name): sell it to your man?"
        case .awaitingCardFrom(let card, let victim):
            self.card = card
            self.ask = "\(card.name): take one from \(victim.playerName)"
        case .awaitingInjuryPick(let card):
            self.card = card
            self.ask = "\(card.name): take one"
        case .awaitingNaming(let card, let named):
            self.card = card
            self.ask = named.isEmpty ? "\(card.name): name a player"
                                     : "\(card.name): name another, or take it"
        case .awaitingOption(let option):
            self.card = option.card
            self.ask = option.question
        // A Clamp standing over somebody, asking what it costs him.
        case .awaitingToll(let victim):
            self.card = state[victim].clamps.first?.card
            self.ask = "Pay the toll, or hand it over"
        // The cards on offer *are* the question; the first one stands for it.
        case .awaitingCounter(let cards):
            self.card = cards.first?.descriptor
            self.ask = cards.count == 1 ? "Play \(cards[0].descriptor.name)?"
                                        : "Answer it?"
        case .awaitingIntangibleDrop(let offered):
            self.card = offered.first
            self.ask = "Your board is full — put one down"

        // ── Questions the floor asks, which name themselves on it ──────
        case .awaitingInbound:
            self.card = nil
            self.ask = nil
        case .awaitingMove:
            self.card = nil
            self.ask = nil
        // **The board says it for itself.** Its own scene carries the words and the ball
        // at the size it wants them; a banner over the top repeated both.
        case .awaitingBid:
            self.card = nil
            self.ask = nil
        case .awaitingFreeThrow:
            self.card = nil
            self.ask = nil
        case .thinking, .gameOver:
            self.card = nil
            self.ask = nil
        }
    }

    /// The discard-for-SHOT question, which has more shapes than the rest put together.
    @MainActor
    private static func discardAsk(_ card: CardDescriptor, each: Int,
                                   state: GameState, for seat: Seat) -> String {
        if state.fourPointOffer {
            return "The Future: retire 1 to make \(card.name) worth 4, at SHOT \(each)%?"
        }
        let most = Rules.legalDiscardForShot(state, for: seat).upperBound
        if most == 1 { return "\(card.name): retire 1 for +\(each)%?" }
        return "\(card.name): retire up to \(most) for +\(each)% each?"
    }
}

/// **The question, over the floor.**
///
/// The card that is asking, its text beside it, and the question in a line. One view, in
/// one place, whatever shape the answer takes below it — see `Prompt`.
struct PromptBanner: View {
    let prompt: Prompt
    var onKeyword: ((String) -> Void)?

    private enum Mark {
        static let card: CGFloat = 54
        static let ask: CGFloat = 12
    }

    var body: some View {
        if !prompt.isEmpty {
            HStack(alignment: .center, spacing: 10) {
                if let card = prompt.card {
                    CardFrontView(descriptor: card, displayWidth: Mark.card,
                                  expanded: true, onKeyword: onKeyword)
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                }
                if let ask = prompt.ask {
                    Text(ask.uppercased())
                        .font(.system(size: Mark.ask, weight: .black)).tracking(1.2)
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.black, radius: 0, x: 2, y: 2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CardPalette.navy.opacity(0.92))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(CardPalette.gold, lineWidth: 2))
            }
            .padding(.horizontal, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
