import SwiftUI

/// The player's own controls, laid straight over the court with no panel behind them.
struct ActionBarView: View {
    let controller: GameController
    /// What a controller is pointing at. Nothing when nobody has one — see `PadRing`.
    var ringed: PadSpot?
    /// Handed the mechanic a reader pressed on a raised card.
    var onKeyword: ((String) -> Void)?
    @Binding var detail: Card?
    var onInspectReferees: () -> Void = {}
    /// Held down: every name on the floor, for as long as it is held.
    var onNames: ((Bool) -> Void)?
    var onCombo: (CardDescriptor) -> Void = { _ in }
    var onBonus: (CardDescriptor, CGPoint) -> Void = { _, _ in }
    /// Traderous Tarmac and Varsitile open their own sheets, which the screen owns.
    var onHandOff: () -> Void = {}
    var onExchange: () -> Void = {}
    /// Off in a lesson, which teaches the cards and never the shot.
    var allowsShooting = true
    /// The log and the pause, either end of the shot row. Nil in a lesson, which leaves
    /// by its own button.
    var onOpenLog: (() -> Void)?
    var onPause: (() -> Void)?
    @Environment(\.floorIsHidden) private var floorIsHidden

    private var state: GameState { controller.shown }
    /// What the table has seen arrive, not what the rules have dealt — see
    /// `GameController.undelivered`.
    private var bag: [Card] { controller.shownBag(of: GameRules.localSeat) }

    /// The rules decide what is playable, not the view. Without this the AI would be
    /// bound by a Clamp and the human would not.
    private var legal: [Move] {
        guard case .awaitingMove = controller.gate else { return [] }
        return Rules.legalMoves(state, for: GameRules.localSeat)
    }

    private var playableCards: Set<Card.ID> {
        Set(legal.compactMap { if case .play(let id) = $0 { return id } else { return nil } })
    }

    /// **The finishes on offer**, in the order the buttons are laid out. A defender who
    /// forces one has already taken the others out of `legalMoves`.
    private var finishes: [ShotType] {
        ShotType.allCases.filter { type in
            legal.contains { if case .shootAs(let offered) = $0 { return offered == type }
                              return false }
        }
    }

    private var canShoot: Bool { !finishes.isEmpty }

    /// Whether anybody's hand is on offer — Free Agent, and nothing else so far.
    private var canBorrow: Bool {
        legal.contains { if case .borrow = $0 { return true }; return false }
    }

    /// What the rules will not take right now, while they are being asked for a move at
    /// all. Empty at every other gate, or a hand nobody is being asked about would black
    /// out entirely.
    private var barredCards: Set<Card.ID> {
        guard case .awaitingMove = controller.gate else { return [] }
        let allowed = playableCards
        return Set(bag.map(\.id).filter { !allowed.contains($0) })
    }

    /// The court is asking who to throw to, so the hand is not the question.
    private var isChoosingInbound: Bool {
        if case .awaitingInbound = controller.gate { return true }
        return false
    }

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
        case .awaitingBid, .awaitingDiscard, .awaitingGiveUp: return true
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
                          barred: barredCards,
                          wash: isChoosingInbound ? CourtView.Court.cardWash : nil,
                          justPlayed: controller.justPlayed,
                          activeReferees: controller.shown.armedWhistles.count,
                          onInspectReferees: onInspectReferees,
                          ringed: { if case .card(let id) = ringed { return id }
                                    else { return nil } }(),
                          onKeyword: onKeyword,
                          onCombo: onCombo,
                          onBonus: onBonus,
                          detail: $detail,
                          onCommit: commit)
            asking
            if case .awaitingBid = controller.gate, controller.revealedBids == nil { confirmBid }
            if case .awaitingDiscard = controller.gate { confirmDiscard }
            if case .awaitingGiveUp(let card, let count) = controller.gate {
                confirmInjuryDiscard(card, count: count)
            }
            if case .awaitingMove = controller.gate, canHandOff || canExchange {
                HStack(spacing: 8) {
                    if canHandOff { sideButton("HAND OFF", run: onHandOff) }
                    if canExchange { sideButton("EXCHANGE", run: onExchange) }
                }
            }
            bottomRow
            prompt
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
    }

    /// A drag clear of the log, or a second tap, means this card. **The rules of it live
    /// on the controller**, because up on a pad means exactly the same thing and the two
    /// must not be able to disagree — see `GameController.commit(_:)`.
    private func commit(_ card: Card) { controller.commit(card) }

    // MARK: - Prompt

    /// What the game is asking for, when it is asking for cards out of your own hand.
    ///
    /// The opponent's hand gets a title on a mode card and a dimmed floor behind it; your
    /// own hand was getting neither, so a card that asks for a discard read as the shoot
    /// button vanishing rather than as a question.
    private var asking: AnyView {
        AnyView(Group {
            if let ask {
                Text(ask.uppercased())
                    .font(.system(size: 12, weight: .black)).tracking(1.2)
                    .foregroundStyle(.white)
                    .shadow(color: CardPalette.black, radius: 0, x: 2, y: 2)
                    .frame(maxWidth: .infinity)
            }
        })
    }

    private var ask: String? {
        switch controller.gate {
        case .awaitingDiscard(let card, let each):
            if state.fourPointOffer {
                return "The Future: retire 1 to make \(card.name) worth 4, at SHOT \(each)%?"
            }
            let most = Rules.legalDiscardForShot(state, for: GameRules.localSeat).upperBound
            if most == 1 { return "\(card.name): retire 1 for +\(each)%?" }
            if let limit = card.special?.discardForShotLimit {
                let beyond = card.special?.discardBeyondLimitBonus ?? 0
                return Rules.discardsPastLimit(card, in: state)
                    ? "\(card.name): +\(each)% each for \(limit), then +\(beyond)% each"
                    : "\(card.name): retire up to \(limit), +\(each)% each"
            }
            return "\(card.name): feed it as many as you like, +\(each)% each"
        case .awaitingGiveUp(let card, let count):
            return "\(card.name): give up \(count)"
        case .awaitingBid:
            return "Crash the glass: bid what you dare"
        default:
            return nil
        }
    }

    /// Only lingering effects get announced. What a card does and how to play it is
    /// the card's job, not a running caption.
    private var prompt: AnyView {
        AnyView(Group {
            let standing = standingEffects
            if !standing.isEmpty {
                Text(standing.joined(separator: "  ·  "))
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ball)
                    .shadow(color: .black.opacity(0.85), radius: 3)
                    .frame(maxWidth: .infinity)
            }
        })
    }

    private var standingEffects: [String] {
        // The referees say themselves what they are doing — see `StatusHUDView`. Only
        // what is standing on *you* is worth spelling out down here.
        var notes: [String] = []
        for clamp in controller.human.clamps {
            notes.append(clamp.card.name.uppercased() + " ON YOU")
        }
        // An Injury is carried rather than played, so nothing else on screen says it is
        // there — and a hand that keeps losing cards needs a reason printed somewhere.
        for injury in controller.human.injuries {
            notes.append(injury.name.uppercased())
        }
        return notes
    }

    // MARK: - Buttons

    private enum Act {
        static let width: CGFloat = 190
        static let height: CGFloat = 42
        /// **Two of the old buttons wide.** With all three showing, each was a third of
        /// `width` plus 18, with six between them — so this is exactly the room two of
        /// them took, and the three finishes fold into it.
        static let capsule: CGFloat = 2 * (width / 3 + 18) + 6
        /// The ball at the head of the capsule, and the room either side of it.
        static let ballInset: CGFloat = 10
        static let ballGap: CGFloat = 6
        /// The word in each segment — smaller than the old lone button's, since three
        /// share the room one used to have.
        static let segmentWord: CGFloat = 12
        /// The seam between segments, and the white edge round the whole capsule.
        static let seam: CGFloat = 1.5
        static let capsuleStroke: CGFloat = 1.5
        /// How much of the word a greyed segment keeps.
        static let greyedInk: Double = 0.45
        /// The word, in the game's own lettering. The figure beside it is not — a
        /// percentage squeezed through `minimumScaleFactor` comes out unreadable, and it
        /// is a reading rather than a call.
        static let word: CGFloat = 19
        static let figure: CGFloat = 14
        static let ball: CGFloat = 22
        /// **Each finish gets the same room**: what is left of the capsule after the ball
        /// and the two seams, in thirds. Left to the stack, a longer word took more.
        static var segment: CGFloat {
            (capsule - ballInset - ball - ballGap - 2 * seam) / 3
        }
        static let drop: CGFloat = 2
        /// The pill's own drop, deeper than its lettering's.
        static let pillDrop: CGFloat = 4
        /// **What counts as a special shot.** An override always does; a bonus has to be
        /// bigger than an ordinary card's to be worth lighting the button for. Twenty-five
        /// is the deck's own line — Hot Hand, Sniper and Skyhook sit there, and no
        /// ordinary Move reaches it.
        static let armedAt: Double = 25
        /// The card shown beside the button when one is armed.
        static let armedCard: CGFloat = 34
        /// `ActionText` spends tracking as a share of each letter's own size, not in
        /// points — 1.2 there is more than a letter of air between every pair.
        static let letterGap: CGFloat = 0.02
        /// The button's own word is set in plain type, so its tracking is points like
        /// everything else's.
        static let wordGap: CGFloat = 0.5
        /// The second button is three quarters of the first, at the same height.
        static let secondShare: CGFloat = 0.75

        /// **The pill each finish wears.** Orange is the shot that is always there;
        /// the two that have to be earned say so by not being it.
        static func pill(for finish: ShotType) -> Color {
            switch finish {
            case .layup: return CardPalette.orange
            case .dunk:  return CardPalette.red
            case .three: return CardPalette.gold
            }
        }
    }

    /// Orange, dropped in red; everything standing on it dropped in blue.
    /// **What is making this shot special, if anything is.**
    ///
    /// An override standing on the board — Lethal Shooter off your own glass, Splash
    /// Cousin from three — or a passive paying more than an ordinary card does. It is the
    /// card's own name, so the button can show the card that armed it.
    private var armed: CardDescriptor? {
        let board = controller.shown
        let seat = GameRules.localSeat
        let modifiers = board.shotModifiers(for: seat)
        let named = modifiers.override?.label
            ?? modifiers.adds.first(where: { $0.amount >= Act.armedAt })?.label
        guard let named else { return nil }
        return board[seat].intangibles.first { $0.name == named }
    }

    /// Sixth Man's offer while a six is showing: the card it comes from, and its SHOT.
    private var offer: (card: CardDescriptor, override: ShotOverride)? {
        let seat = GameRules.localSeat
        guard legal.contains(.shootAtOffer), let override = state.shotOffer(for: seat),
              let card = state[seat].intangibles.first(where: { $0.intangible?.offersShotAt != nil })
        else { return nil }
        return (card, override)
    }

    private var shootButton: AnyView {
        AnyView(Group {
            HStack(spacing: 8) {
                if let offer {
                    offerPill(offer.card, at: offer.override)
                        .transition(.scale.combined(with: .opacity))
                }
                // **The card that armed it, beside the button.** A HUD glyph says *something*
                // is on; the card says which, and it is the same drawing the player already
                // knows from their own board.
                if let armed {
                    CardFrontView(descriptor: armed, displayWidth: Act.armedCard)
                        .transition(.scale.combined(with: .opacity))
                }
                shootPill
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: armed)
        })
    }

    /// **One capsule, three segments, all of them always there.** The ball leads, then a
    /// layup, a dunk and a three. A finish that is not on offer is greyed in place rather
    /// than taken away, so the shape of the choice never changes under your thumb and you
    /// can see what you are working toward.
    ///
    /// **Three fixed slots, never a `ForEach`.** Each segment's `SpectrumFill` has `@State`
    /// of its own, and a list whose members come and go hands one child's state box to
    /// another — a crash rather than a glitch. They never come and go now, but they stay
    /// fixed so nothing can reintroduce it.
    private var shootPill: AnyView {
        AnyView(Group {
            HStack(spacing: 0) {
                Image("BallVector")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Act.ball)
                    .shadow(color: CardPalette.blue, radius: 0, x: Act.drop, y: Act.drop)
                    .padding(.leading, Act.ballInset)
                    .padding(.trailing, Act.ballGap)
                finishPill(.layup)
                segmentRule
                finishPill(.dunk)
                segmentRule
                finishPill(.three)
            }
            .frame(width: Act.capsule, height: Act.height)
            .background(Capsule().fill(CardPalette.orange))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white, lineWidth: Act.capsuleStroke))
            .background(Capsule().fill(CardPalette.blue)
                .offset(x: Act.pillDrop, y: Act.pillDrop))
        })
    }

    /// The seam between two segments.
    private var segmentRule: some View {
        Rectangle()
            .fill(CardPalette.blue.opacity(0.6))
            .frame(width: Act.seam)
    }

    /// **One segment.** On offer, it is the finish's own colour — lit when the shot is
    /// special. Off offer, it is greyed where it stands and cannot be pressed.
    private func finishPill(_ finish: ShotType) -> AnyView {
        AnyView(Group {
            let open = finishes.contains(finish)
            return Button { controller.shoot(as: finish) } label: {
                // Plain type, not `ActionText`, with the same drop as the ball beside it.
                Text(finish.name.uppercased())
                    .font(.system(size: Act.segmentWord, weight: .heavy, design: .rounded))
                    .tracking(Act.wordGap)
                    .foregroundStyle(open ? .white : Color.white.opacity(Act.greyedInk))
                    .shadow(color: CardPalette.blue.opacity(open ? 1 : 0),
                            radius: 0, x: Act.drop, y: Act.drop)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: Act.segment)
                    .frame(maxHeight: .infinity)
                    .background {
                        if open {
                            // **Lit when the shot is special** — Project Stars' Start
                            // button, which is what this game reaches for when something
                            // is *ready* rather than merely available. See `SpectrumFill`.
                            // No `fill`: a filled shape ignores `foregroundStyle`.
                            SpectrumFill(isLive: armed != nil && !floorIsHidden,
                                         resting: Act.pill(for: finish)) {
                                Rectangle()
                            }
                        } else {
                            Rectangle().fill(CardPalette.gray)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(!open)
            .padRing(ringed == .finish(finish), corner: Act.height / 2)
        })
    }

    /// **Sixth Man's second Shoot button.** The card dimmed, beside the SHOT it offers.
    /// Pressed only when that beats the board, so it sits beside Shoot rather than in place
    /// of it.
    private func offerPill(_ card: CardDescriptor, at override: ShotOverride) -> AnyView {
        AnyView(Group {
            Button { controller.shootAtOffer() } label: {
                HStack(spacing: 6) {
                    CardFrontView(descriptor: card, displayWidth: Act.ball)
                        .opacity(0.5)
                    Text("SHOOT")
                        .font(.system(size: Act.word, weight: .heavy, design: .rounded))
                        .tracking(Act.wordGap)
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.blue, radius: 0, x: Act.drop, y: Act.drop)
                    Text("(\(Int(override.amount))%)")
                        .font(.system(size: Act.figure, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.blue, radius: 0, x: Act.drop, y: Act.drop)
                }
                .frame(maxWidth: .infinity)
                .frame(height: Act.height)
                .background(Capsule().fill(CardPalette.orange)
                    .shadow(color: CardPalette.blue, radius: 0, x: Act.pillDrop, y: Act.pillDrop))
            }
            .frame(width: Act.width * Act.secondShare)
        })
    }

    /// Traderous Tarmac: Clamps on you, and somebody to hand them to.
    private var canHandOff: Bool {
        !Rules.handOffTargets(state, for: GameRules.localSeat).isEmpty
    }

    /// Varsitile: something in Retirement to exchange for.
    private var canExchange: Bool {
        !Rules.exchangeOptions(state, for: GameRules.localSeat).isEmpty
    }

    /// **The bottom row: the log, the shot, the pause.** The shot is up for every
    /// possession of yours, whether or not anything can go — a Zone that forbids shooting
    /// greys all three rather than taking the capsule away.
    private var bottomRow: AnyView {
        AnyView(HStack(spacing: 8) {
            if let onOpenLog { logButton(onOpenLog) }
            if let onNames { namesButton(onNames) }
            Spacer(minLength: 0)
            if case .awaitingMove = controller.gate, allowsShooting {
                shootButton
                if canBorrow { borrowButton }
            }
            // **A card asking who can be taken back**, from the middle of the row.
            if case .awaitingTarget = controller.gate, Rules.canCancelAim(state) {
                sideButton("CANCEL") { controller.cancelAim() }
            }
            Spacer(minLength: 0)
            if let onPause { pauseButton(onPause) }
        })
    }

    /// **Opens the log.** The pause button's twin: somewhere to step out of the game and
    /// look, not a play — and it says what it is.
    private func logButton(_ open: @escaping () -> Void) -> some View {
        Button(action: open) {
            HStack(spacing: 5) {
                Image(systemName: "text.alignleft")
                Text("LOG").tracking(1)
            }
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 27)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(CardPalette.blue))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.white, lineWidth: 1.5))
            .shadow(color: CardPalette.gold, radius: 0, x: 2, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Game log")
    }

    /// **Held, not tapped.** The floor goes unlabelled so the game can be looked at;
    /// holding this says who everybody is for as long as you want it said.
    private func namesButton(_ show: @escaping (Bool) -> Void) -> some View {
        Image(systemName: "person.text.rectangle.fill")
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 27, height: 27)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(CardPalette.blue))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.white, lineWidth: 1.5))
            .shadow(color: CardPalette.gold, radius: 0, x: 2, y: 2)
            .contentShape(Rectangle())
            // A press rather than a tap: `onChanged` fires the moment a finger lands.
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in show(true) }
                .onEnded { _ in show(false) })
            .accessibilityLabel("Hold for names")
    }

    private func pauseButton(_ pause: @escaping () -> Void) -> some View {
        Button(action: pause) {
            Image(systemName: "pause.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 27, height: 27)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(CardPalette.blue))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(.white, lineWidth: 1.5))
                .shadow(color: CardPalette.gold, radius: 0, x: 2, y: 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pause")
    }

    /// A white pill beside the shot, for a thing the floor lets you do that is not a card.
    private func sideButton(_ word: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            ActionText(word, size: Act.word * 0.8, ink: CardPalette.blue,
                       drop: CardPalette.blue.opacity(0.35), taper: 0,
                       tracking: Act.letterGap)
                .frame(maxWidth: .infinity)
                .frame(height: Act.height)
                .background(Capsule().fill(.white))
        }
        .frame(width: Act.width * Act.secondShare)
    }

    /// Free Agent plays out of somebody else's hand, so it needs a way in that is not a
    /// card of your own — the hand in front of you is not where the play is.
    private var borrowButton: AnyView {
        AnyView(Group {
            Button { controller.beginBorrow() } label: {
                ActionText("CHOOSE CARD", size: Act.word * 0.8, ink: CardPalette.blue,
                           drop: CardPalette.blue.opacity(0.35), taper: 0,
                           tracking: Act.letterGap)
                    .frame(maxWidth: .infinity)
                    .frame(height: Act.height)
                    .background(Capsule().fill(.white))
            }
            .padRing(ringed == .borrow, corner: Act.height / 2)
            .frame(width: Act.width * Act.secondShare)
        })
    }

    private var confirmDiscard: AnyView {
        AnyView(Group {
            let count = controller.bidSelection.count
            var bonus = 0
            var shoots = false
            if case .awaitingDiscard(let card, let bonusEach) = controller.gate {
                bonus = count == 0 ? 0 : Rules.shotBought(discarding: count, card: card,
                                                           bonusEach: bonusEach, in: state)
                // Only a card that takes the shot itself can be shot as is. The rest are
                // Moves, and declining one of those is declining the extra, not the attempt.
                shoots = card.special?.shootsImmediately == true
            }
            return Button { controller.submitDiscard() } label: {
                Text(count == 0 ? (shoots ? "SHOOT AS IS" : "NO THANKS")
                                : "\(shoots ? "FEED" : "SPEND") \(count) → \(bonus >= 0 ? "+" : "")\(bonus)%")
                    .font(.system(size: 14, weight: .black)).tracking(1.1)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(count == 0 ? Theme.ink : Theme.ball))
            }
            .padRing(ringed == .confirm, corner: 22)
            .frame(width: 220)
        })
    }

    /// The Injury's toll. Named, because a hand losing a card for no visible reason is
    /// the game taking something rather than a card doing something.
    private func confirmInjuryDiscard(_ card: CardDescriptor, count: Int) -> AnyView {
        AnyView(Group {
            let chosen = controller.bidSelection.count
            let ready = chosen == count
            return Button { controller.submitGiveUp() } label: {
                Text(ready ? "\(card.name.uppercased()): GIVE UP \(chosen)"
                           : "\(card.name.uppercased()): PICK \(count - chosen)")
                    .font(.system(size: 14, weight: .black)).tracking(1.1)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(ready ? Theme.danger : Theme.ink))
            }
            .padRing(ringed == .confirm, corner: 22)
            .frame(width: 240)
            .disabled(!ready)
            .opacity(ready ? 1 : 0.6)
        })
    }

    private var confirmBid: AnyView {
        AnyView(Group {
            // **In, and waiting on the rest of them.** The board asks all four at once, so
            // answering does not close the question — it only settles your half of it.
            let waiting = controller.bidPlaced
            return Button { controller.submitBid() } label: {
                Text(waiting ? "WAITING ON THE OTHERS"
                     : (controller.bidSelection.isEmpty
                        ? "BID NOTHING" : "BID \(controller.bidSelection.count)"))
                    .font(.system(size: 14, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(waiting ? Theme.ink
                                               : (controller.bidSelection.isEmpty
                                                  ? Theme.ink : Theme.live)))
            }
            .padRing(ringed == .confirm, corner: 22)
            .frame(width: 220)
            .disabled(waiting)
            .opacity(waiting ? 0.55 : 1)
        })
    }
}
