import Foundation

enum GameEvent: Hashable, Codable {
    case gameBegan(firstInbounder: Seat)
    case roundBegan(round: Int, inbounder: Seat)
    case inbounded(from: Seat, to: Seat)
    /// A card off the deck and into a bag. The physical card's id travels with it so the
    /// table can hold it out of the hand until its flight has actually landed.
    ///
    /// **`opening` is a card you take off the pile yourself**: the one your possession
    /// opens with, and the cards of an opening hand. At a table nobody deals those to
    /// you, and on the screen they wait on your own hand — see `GameController.fly`.
    /// Everything a card draws for you is the card doing it, and comes on its own.
    case drew(seat: Seat, card: CardDescriptor, id: UUID, opening: Bool = false)
    case shotClockSet(Int)
    case shotClockTicked(Int)
    case passed(card: CardDescriptor, from: Seat, to: Seat, shot: Int, returning: Bool = false)
    case movePlayed(seat: Seat, card: CardDescriptor, shot: Int)
    /// `opener` is the card it followed, for the record of combos done — see `DoneCombos`.
    case comboLanded(seat: Seat, card: CardDescriptor, opener: String?, bonus: Int)
    case coinRun(seat: Seat, card: CardDescriptor, heads: Int)
    case discardedForShot(seat: Seat, card: CardDescriptor, count: Int)
    /// A card leaving a hand for the pile, whatever took it. Said once per card, so the
    /// floor can throw one for each rather than watching them vanish — see
    /// `GameController.spend`.
    /// **What went, not how many.** "1 card gone" is a line nobody can act on: a card
    /// taken at random is the one thing in the game a player cannot see happen, so the
    /// log is the only place it exists. The cards are named because they are public the
    /// moment they land in the pile.
    case discarded(seat: Seat, cards: [CardDescriptor])
    case failedReturn(seat: Seat)
    /// `against` is the seat the call was made on — whose card, whose shot, whose Clamp.
    /// Without it the log says a Travel cancelled an Ankle Breaker and leaves you to guess
    /// whose Ankle Breaker it was.
    case whistleBlew(owner: Seat?, card: CardDescriptor, cancelled: String,
                     cancelledCard: CardDescriptor?, against: Seat?, caller: UUID? = nil)
    /// Clear Out: he was not there, and the ball went on to the next man.
    case clearedOut(seat: Seat, to: Seat?)
    case whistleArmed(seat: Seat)
    /// **A call thrown out.** Once a game, and the official goes off with it.
    case challenged(seat: Seat, card: CardDescriptor)
    /// **An official sent off by a card** rather than by a call — the ball got his
    /// attention, and somebody else comes out to take his place.
    case officialDistracted(seat: Seat, card: CardDescriptor)
    /// **The Retiring Official waving a Clamp off** before it lands; the man who played it
    /// draws instead. Not a call, but an official acting, so it is shown as one.
    case clampWavedOff(seat: Seat, clamp: CardDescriptor, official: CardDescriptor,
                       caller: UUID)
    /// **An official's coin toss** on whether he calls it — Traffic Cop, Back Court
    /// Violation. Heads, play on.
    case refereeToss(seat: Seat, card: CardDescriptor, heads: Bool, caller: UUID)
    /// **A defender beaten.** The Clear printed on his card was met, so he is Retired.
    case clampBeaten(seat: Seat, card: CardDescriptor)
    /// A defender who simply ran out of somebody to guard.
    case clampExpired(seat: Seat, cards: [CardDescriptor])
    /// **The crew for the round, turned face-up.** Nobody played these and nobody owns
    /// them: they are the rules everyone is about to play under, so they are announced
    /// rather than hidden the way an armed Whistle was.
    case crewAssigned(cards: [CardDescriptor])
    /// A referee threw it in.
    case refereeInbounded(to: Seat)
    /// **Skyhook: a card pulled back out of Retirement.** Nothing else in the game
    /// reaches in there, which is what makes it the homage it is.
    case drewFromRetirement(seat: Seat, card: CardDescriptor)
    /// A card that would have gone into a full hand, paid as SHOT instead.
    case drawConverted(seat: Seat, card: CardDescriptor, shot: Int)
    /// A Whistle with no trigger — Timeout — which resolves the moment it is played
    /// rather than lying in wait. It appended nothing at all before, so playing one was
    /// silent: four players drew, nothing said why, and the only lines that reached the
    /// log were whatever Game Breaks those draws turned up.
    case whistleUsed(seat: Seat, card: CardDescriptor)
    case whistleRefocused
    case whistlesDismissed
    case whistlesRecalled(count: Int)
    case intangiblesStripped(seat: Seat)
    case gameBreakRevealed(seat: Seat, card: CardDescriptor)
    /// An Injury turning up in a draw. Its own type, so its own event.
    case injuryRevealed(seat: Seat, card: CardDescriptor)
    case intangibleRevealed(seat: Seat, card: CardDescriptor)
    case intangibleDisplaced(seat: Seat, card: CardDescriptor)
    case reinbound(seat: Seat)
    case clampSet(seat: Seat, card: CardDescriptor)
    /// A possession opening with defenders already on the man taking it. Clamps are set
    /// before the ball arrives, so this is the first moment anybody can be told.
    case clampedPossession(seat: Seat, clamps: [ClampBrief])
    case clampBit(seat: Seat, card: CardDescriptor, discarded: Int)
    case shotAttempted(seat: Seat, chance: Int, breakdown: ShotResolution)
    /// `chance` is the number the roll was made against, carried so the line can print
    /// what the shot actually was rather than only whether it went in.
    case shotMade(seat: Seat, points: Int, roll: Int, chance: Int = 0)
    case shotMissed(seat: Seat, roll: Int, chance: Int = 0)
    case assisted(Seat)
    /// Traded Mid-Game: two men swapped hands where they stand.
    case handsTraded(seat: Seat, with: Seat)
    /// **In the order they are read out, not in a dictionary.**
    ///
    /// This was `[Seat: Int]`, and a dictionary whose key is neither `String` nor `Int`
    /// encodes as a flat unkeyed array — the pairs in *iteration* order. Swift seeds its
    /// hasher per process, so two devices wrote the same bids as different bytes, and
    /// `.sortedKeys` cannot help because there are no keys in the JSON to sort. Every
    /// rebound parted the digest, and nothing else ever did.
    case reboundBids(bids: [SeatBid], order: [Seat])
    case rebounded(Seat)
    /// **A called board paying off.** Off the Backboard was drawn a possession ago; this
    /// is the miss it was waiting for, and it names the card so the moment can show it.
    case calledGlass(seat: Seat, card: CardDescriptor)
    /// `cause` is the card that took the ball away, or nil when the clock did. Without
    /// it every turnover in the log claimed to be a shot-clock violation, whatever had
    /// actually happened.
    case turnover(Seat, cause: String? = nil)
    case freeThrowsAwarded(seat: Seat, count: Int, source: String)
    case freeThrowBonus(seat: Seat, count: Int, card: CardDescriptor)
    case freeThrowMade(seat: Seat, points: Int, index: Int, of: Int)
    case freeThrowMissed(seat: Seat, index: Int, of: Int)
    case freeThrowsEnded(seat: Seat, made: Int, of: Int)
    case clampsShaken(seat: Seat, card: CardDescriptor, count: Int)
    case clampVoided(seat: Seat, card: CardDescriptor, count: Int)
    case roundEnded(Int)
    case deckReshuffled
    case halftime
    case gameEnded(winners: [Seat])
    /// A ball put in the slot by something other than a card played — Grayvstone, the
    /// Variaball card's roll — or taken out of it. Nil is a Regulation Ball.
    case ballChanged(card: CardDescriptor?)
    /// Grayvstone, with nothing in the discard to raise.
    case graveyardEmpty
    /// Bench Ball: caught off a pass, straight to the inbound.
    case benched(Seat)
    /// Carousel Court: every hand one seat round.
    case handsRotated(clockwise: Bool)
    /// Traderous Tarmac: a Clamp handed on.
    case clampHandedOff(from: Seat, to: Seat, card: CardDescriptor)
    /// Monster Ball, swallowing somebody's Intangible.
    case intangibleAbsorbed(seat: Seat, card: CardDescriptor)
    /// A Monster Ball board, won.
    case intangibleWon(seat: Seat, card: CardDescriptor)
    /// Clearcoat Court, at the top of a possession.
    case floorWiped
    /// Varsitile: the floor or the ball, swapped for ones out of the discard.
    case slotsExchanged(seat: Seat, cards: [CardDescriptor])
    /// Blight Ball: the TOVs going with the ball.
    case turnoversMoved(from: Seat, to: Seat, count: Int)

    /// True for events the player should see spelled out; draws and clock sets are noise.
    var isLoggable: Bool {
        switch self {
        case .drew, .shotClockSet, .clampedPossession: return false
        default: return true
        }
    }

    var logLine: String {
        switch self {
        case .gameBegan(let seat):
            return "Tip-off. \(seat.playerName) \(seat.verb("inbounds", "inbound")) first."
        case .roundBegan(let round, let inbounder):
            return "— \(Ordinal.plain(round)) Quarter — \(inbounder.playerName) to inbound."
        case .inbounded(let from, let to):
            return "\(from.playerName) \(from.verb("inbounds", "inbound")) to \(to.playerName)."
        case .drew(let seat, let card, _, _):
            return "\(seat.playerName) drew \(card.name)."
        case .shotClockSet(let value):
            return "Shot clock set to \(value)."
        case .shotClockTicked(let value):
            return "Shot clock \(value)."
        case .clearedOut(let seat, let to):
            guard let to else {
                return "\(seat.playerName) \(seat.verb("clears", "clear")) out. "
                    + "Nobody was there to take it."
            }
            return "\(seat.playerName) \(seat.verb("clears", "clear")) out. "
                + "The ball carries on to \(to.playerName)."
        case .passed(let card, let from, let to, let shot, let returning):
            // Nobody played anything on the way home. The card was played once, at the
            // other end, and this leg is the ball being handed straight back — saying
            // the receiver played it credits them with somebody else's card.
            guard !returning else {
                return "\(from.playerName) \(from.verb("gives", "give")) it right back → "
                    + "\(to.playerName). \(Self.shotText(shot))"
            }
            return "\(from.playerName) \(from.verb("plays", "play")) \(card.name) → \(to.playerName). \(Self.shotText(shot))"
        case .movePlayed(let seat, let card, let shot):
            return "\(seat.playerName) \(seat.verb("plays", "play")) \(card.name). \(Self.shotText(shot))"
        case .discardedForShot(let seat, let card, let count):
            return "\(seat.playerName) \(seat.verb("feeds", "feed")) \(count) card\(count == 1 ? "" : "s") into \(card.name)."
        case .coinRun(let seat, let card, let heads):
            // Euro Step counts its Heads; one coin — Bankshot's, No-Look's — is Heads or Tails.
            if (card.special?.coinRunFlips ?? 0) > 1 {
                return "\(seat.playerName): \(card.name) — \(heads) Heads."
            }
            return "\(seat.playerName): \(card.name) — \(heads == 1 ? "Heads" : "Tails")."
        case .comboLanded(let seat, let card, _, let bonus):
            return "\(seat.playerName) \(seat.verb("strings", "string")) it together — \(card.name) +\(bonus)% bonus."
        case .gameBreakRevealed(let seat, let card):
            // Named as the event it is, with whoever turned it up in brackets after. A
            // Game Break is not something a player did, so the line does not read like it.
            return "Game Break! - \(card.name) (\(seat.playerName))"
        case .injuryRevealed(let seat, let card):
            return "Injury! - \(card.name) (\(seat.playerName))"
        case .intangibleRevealed(let seat, let card):
            return "\(seat.playerName) \(seat.verb("reveals", "reveal")) \(card.name)."
        case .intangibleDisplaced(let seat, let card):
            return "\(card.name) drops off \(seat.playerName)'s slots."
        case .intangiblesStripped(let seat):
            return "\(seat.playerName) \(seat.verb("loses", "lose")) every Intangible."
        case .whistleUsed(let seat, let card):
            return "\(seat.playerName) \(seat.verb("calls", "call")) \(card.name)."
        case .whistleArmed:
            // Deliberately says nothing about who or what — the trap is the point.
            return "The Referees are watching intently…"
        case .whistlesDismissed:
            return "The referees leave the floor."
        case .whistlesRecalled(let count):
            return "\(count) whistle\(count == 1 ? "" : "s") back in the deck."
        case .whistleRefocused:
            return "The referees seem to have shifted their focus…"
        case .reinbound:
            return "The ball goes back in. The round carries on."
        case .clampSet(let seat, let card):
            return "\(seat.playerName) \(seat.verb("clamps", "clamp")) down — \(card.name)."
        case .clampBit(let seat, let card, let discarded):
            return "\(card.name) on \(seat.playerName): \(discarded) card\(discarded == 1 ? "" : "s") gone."
        case .whistleBlew(let owner, let card, let cancelled, _, _, _):
            // The crew's calls have no name in front of them — nobody set them down.
            guard let owner else { return "WHISTLE! \(card.name) cancels \(cancelled)." }
            return "WHISTLE! \(owner.playerName)'s \(card.name) cancels \(cancelled)."
        case .challenged(let seat, let card):
            return "\(seat.playerName) \(seat.verb("challenges", "challenge")) — "
                + "\(card.name) is thrown out."
        case .clampWavedOff(let seat, let clamp, let official, _):
            return "\(official.name) waves off \(seat.playerName)'s \(clamp.name) — "
                + "\(seat.verb("draws", "draw")) 1 instead."
        case .refereeToss(let seat, let card, let heads, _):
            return "\(card.name) tosses a coin on \(seat.playerName): "
                + (heads ? "Heads, play on." : "Tails.")
        case .officialDistracted(let seat, let card):
            return "\(seat.playerName) \(seat.verb("waves", "wave")) \(card.name) off."
        case .refereeInbounded(let seat):
            return "The official throws it in to \(seat.playerName)."
        case .crewAssigned(let cards):
            let names = cards.map(\.name).joined(separator: ", ")
            return "Working tonight: \(names)."
        case .drewFromRetirement(let seat, let card):
            return "\(seat.playerName) \(seat.verb("takes", "take")) \(card.name) back out of Retirement."
        case .drawConverted(let seat, _, let shot):
            return "\(seat.playerName) \(seat.verb("is", "are")) full — gets open instead. SHOT +\(shot)%."
        case .clampBeaten(let seat, let card):
            return "\(seat.playerName) \(seat.verb("beats", "beat")) \(card.name)!"
        case .clampExpired(let seat, let cards):
            let names = cards.map(\.name).joined(separator: ", ")
            return "\(names) \(cards.count == 1 ? "has" : "have") nobody to guard on \(seat.playerName)."
        case .failedReturn(let seat):
            return "\(seat.playerName) \(seat.verb("has", "have")) nobody to give it back to!"
        case .shotAttempted(let seat, let chance, let breakdown):
            // The stack is spelled out. A shot coming in at a number nobody expects is
            // otherwise unanswerable after the fact — the whole question is *which* step
            // did or did not happen, and this is the only place that knows.
            let stack = breakdown.steps
                .map { "\($0.label) → \($0.total)%" }
                .joined(separator: " · ")
            let from = breakdown.steps.isEmpty ? "" : "  [\(breakdown.base)% · \(stack)]"
            return "\(seat.playerName) \(seat.verb("pulls", "pull")) up at \(chance)%…\(from)"
        // The roll with the chance, so a run of makes can be checked from the log.
        case .shotMade(let seat, let points, let roll, let chance):
            return "GOOD! \(seat.playerName) +\(points) PTS. (rolled \(roll) on \(chance)%)"
        case .shotMissed(let seat, let roll, let chance):
            return "No good. \(seat.playerName) \(seat.verb("misses", "miss")). (rolled \(roll) on \(chance)%)"
        case .handsTraded(let seat, let other):
            return "\(seat.playerName) \(seat.verb("trades", "trade")) Bags with "
                 + "\(other.playerName)"
        case .assisted(let seat):
            return "\(seat.playerName) +1 AST."
        case .reboundBids(let bids, let order):
            let counts = Dictionary(uniqueKeysWithValues: bids.map { ($0.seat, $0.count) })
            let parts = order.map { "\($0.playerName) \(counts[$0] ?? 0)" }
            return "Crash the glass: " + parts.joined(separator: " · ")
        case .rebounded(let seat):
            return "\(seat.playerName) \(seat.verb("grabs", "grab")) the board. +1 REB."
        case .calledGlass(let seat, let card):
            return "\(seat.playerName) called it off the glass — \(card.name)."
        case .turnover(let seat, let cause):
            return "\(cause ?? "Shot clock violation")! \(seat.playerName) +1 TOV."
        case .freeThrowsAwarded(let seat, let count, let source):
            return "\(source)! \(seat.playerName) \(seat.verb("goes", "go")) to the line for \(count)."
        case .freeThrowBonus(let seat, let count, let card):
            return "\(card.name): \(seat.playerName) +\(count) at the line."
        case .freeThrowMade(let seat, let points, let index, let total):
            return "Free throw \(index) of \(total) — good. \(seat.playerName) +\(points) PTS."
        case .freeThrowMissed(_, let index, let total):
            return "Free throw \(index) of \(total) — off the iron."
        case .freeThrowsEnded(let seat, let made, let total):
            return "\(seat.playerName) \(seat.verb("finishes", "finish")) \(made) of \(total) from the line."
        case .clampVoided(let seat, let card, let count):
            return "\(card.name): the Clamp lands on nothing — \(count) defender\(count == 1 ? "" : "s") waved off \(seat.playerName)."
        case .clampsShaken(let seat, let card, let count):
            return "\(card.name): \(seat.playerName) \(seat.verb("clears", "clear")) \(count) Clamp\(count == 1 ? "" : "s")."
        case .discarded(let seat, let cards):
            let named = cards.map(\.name).joined(separator: ", ")
            return "\(seat.playerName) \(seat.verb("gives", "give")) up \(named)."
        case .roundEnded(let round):
            return "End of round \(round)."
        case .deckReshuffled:
            return "Deck reshuffled."
        case .clampedPossession(let seat, let clamps):
            return "\(seat.playerName) \(seat.verb("opens", "open")) up under \(clamps.count) Clamp\(clamps.count == 1 ? "" : "s")."
        case .halftime:
            return "— HALFTIME — Bags retired, fresh 4 each."
        case .gameEnded(let winners):
            return winners.count == 1
                ? "FINAL. \(winners[0].playerName) \(winners[0].verb("wins", "win"))."
                : "FINAL. Tie: " + winners.map(\.playerName).joined(separator: ", ") + "."
        case .ballChanged(let card):
            return card.map { "The ball is now \($0.name)." } ?? "Back to a Regulation Ball."
        case .graveyardEmpty:
            return "Grayvstone reaches for a ball in Retirement and finds none."
        case .benched(let seat):
            return "Bench Ball! \(seat.playerName) \(seat.verb("is", "are")) benched and \(seat.verb("inbounds", "inbound"))."
        case .handsRotated(let clockwise):
            return "Carousel Court: every Bag moves one seat \(clockwise ? "left" : "right")."
        case .clampHandedOff(let from, let to, let card):
            return "\(from.playerName) \(from.verb("hands", "hand")) \(card.name) off to \(to.playerName)."
        case .intangibleAbsorbed(let seat, let card):
            return "Monster Ball swallows \(seat.playerName)'s \(card.name)."
        case .intangibleWon(let seat, let card):
            return "\(seat.playerName) \(seat.verb("comes", "come")) down with \(card.name)."
        case .floorWiped:
            return "Clearcoat Court: referees, Clamps, Injuries and Intangibles, wiped."
        case .slotsExchanged(let seat, let cards):
            return "\(seat.playerName) \(seat.verb("swaps", "swap")) in \(cards.map(\.name).joined(separator: " and "))."
        case .turnoversMoved(let from, let to, let count):
            return "Blight Ball: \(from.playerName)'s \(count) TOV\(count == 1 ? "" : "s") \(count == 1 ? "goes" : "go") to \(to.playerName)."
        }
    }

    /// SHOT as a line says it. Dim Dome's floor hides it, which the rules mark with a
    /// negative number.
    static func shotText(_ shot: Int) -> String {
        shot < 0 ? "SHOT ??." : "SHOT \(shot)%."
    }

    /// What one seat put in, on a board.
    struct SeatBid: Hashable, Codable {
        let seat: Seat
        let count: Int
    }

    /// What kind of thing this is, without any of what it says.
    ///
    /// **The shape of a batch, for comparing two devices.** Their contents cannot be
    /// diffed — each seat is told a different story on purpose — but the *order and kind*
    /// of what happened is the same game or it is not. A digest says two devices parted;
    /// this says what they parted about.
    var kind: String {
        let mirror = Mirror(reflecting: self)
        return mirror.children.first?.label ?? String(describing: self)
    }
}

extension Array where Element == GameEvent {
    /// Cut in two at the attempt, if there is one.
    ///
    /// A shot is the one thing on the floor everything else waits behind: the rules run
    /// the whole chain past it in a single batch — the round ends, the half turns over, a
    /// new hand is dealt — and every one of those would otherwise be shown while the ball
    /// is still in the air.
    func splitAtTheShot() -> (before: [GameEvent], after: [GameEvent]) {
        guard let at = firstIndex(where: {
            if case .shotAttempted = $0 { return true }
            return false
        }) else { return (self, []) }
        return (Array(self[..<at]), Array(self[at...]))
    }

    /// Whether the ball goes up in here.
    ///
    /// **What the SHOT badge waits on.** The rules settle an attempt in full before a
    /// frame of it is drawn, so the number knows the outcome before the player does: a
    /// make ends the round and takes SHOT back to its opening value. Anything that reads
    /// the board has to hold off until the ball has come down.
    var holdsAShot: Bool {
        contains { if case .shotAttempted = $0 { return true }; return false }
    }
}

extension GameEvent {
    /// **Every card this event names**, read off its own payload rather than matched
    /// against the words of its line — so a new event says which cards it mentions
    /// without anybody having to tell it. The log prints each in its type's colour.
    var cardsNamed: [CardDescriptor] {
        var found: [CardDescriptor] = []
        func dig(_ value: Any, _ depth: Int) {
            if let card = value as? CardDescriptor { found.append(card); return }
            if let cards = value as? [CardDescriptor] { found += cards; return }
            guard depth < 3 else { return }
            for child in Mirror(reflecting: value).children { dig(child.value, depth + 1) }
        }
        dig(self, 0)
        return found
    }
}
