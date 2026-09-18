import Foundation

/// A Clamp sitting on a player for the duration of their possession.
struct ActiveClamp: Hashable, Codable, Identifiable {
    /// Which cards this Clamp is holding down, chosen when it lands and then left alone.
    /// A lock that moved every time the hand was looked at could not be played around.
    var locked: [UUID] = []
    /// Whether its man has had his possession under it. A Clamp on the ball-holder bites the
    /// moment it lands; one Gravity pulled on to somebody else waits for his.
    var bitten = false

    let id: UUID
    let card: CardDescriptor
    let from: Seat

    init(card: CardDescriptor, from: Seat, id: UUID = UUID()) {
        self.id = id; self.card = card; self.from = from
    }
}

/// A Clamp named for the scene that announces it: which card, and who set it. Carried on
/// the event rather than read back off the board, because the board is cleared by the
/// time some of these are read.
struct ClampBrief: Hashable, Codable, Identifiable {
    let id: UUID
    let card: CardDescriptor
    let from: Seat
}

extension ActiveClamp {
    var brief: ClampBrief { ClampBrief(id: id, card: card, from: from) }
}

/// The last shot a player made: which round it went in, and what its chance had been
/// talked up to. Public — everybody watched it happen.
struct Make: Hashable, Codable {
    let round: Int
    let chance: Int
}

struct PlayerState: Hashable, Identifiable, Codable {
    let seat: Seat
    var bag: [Card] = []
    /// **One a game.** Called for a violation, a player may throw the call out and send the
    /// official who made it off with it — see `Rules.resolveChallenge`. Spent whether it
    /// helps or not, which is what makes choosing the moment the whole of it.
    var challenged = false
    /// Lasts exactly one possession — see Rules.beginPossession.
    var clamps: [ActiveClamp] = []
    /// Passives in play, oldest first. Capped by MatchRules.intangibleSlots.
    var intangibles: [CardDescriptor] = []
    /// Drives Hot Hand. Rolled over when a round ends.
    /// Injuries carried right now.
    ///
    /// **Not in the discard.** An Injury is on the man, which is what keeps a Devastating
    /// one out of the halftime shuffle — that gathers the deck, the pile and every bag,
    /// and a card sitting here is in none of them. A round Injury is shed into the pile
    /// when the round ends, so the shuffle does pick it up.
    var injuries: [CardDescriptor] = []
    /// Torn Achilles: the cards that survived this turn's lock, rolled once per
    /// possession and then left alone.
    var injuryUnlocked: [UUID] = []
    /// The Zone, if this player has popped one — see `SwisshUp`. One at a time.
    var swisshUp: ActiveSwisshUp?
    /// All-Swissh Selection: cards owed on the next make, and shown in the HUD until they
    /// are paid. Survives the round — it is a selection, not a hot streak.
    var drawsOwedOnMake = 0
    var lastMake: Make?
    var scoredThisRound = false
    var scoredLastRound = false
    var points = 0
    var assists = 0
    var rebounds = 0
    var turnovers = 0
    /// **Kept, not shown.** The first of the quiet ones: nothing on the board reads it,
    /// and it is here so the breakdown at the end of a game and the all-time page on My
    /// Hooper have something to count when they arrive.
    var dunks = 0
    /// Outlet Pass: owed the chance to Reset the Shot Clock as his next possession opens.
    var mayResetShotClock = false
    /// **Hot Hand: which ball he last scored with.** The run is the ball's, so this is
    /// checked against whatever is in play rather than against a round number — and a
    /// player who has never scored has nil, which matches no ball.
    var scoredWithBall: UUID?

    /// Where he plays. The local seat's is what he built; the rest are rolled with the
    /// deal, so every device agrees on who finishes at the rim.
    var position: Position = .pointGuard

    var id: Seat { seat }
    var score: Int { points + assists + rebounds - turnovers }
}

enum Phase: Hashable, Codable {
    case inbound(inbounder: Seat)
    /// **A referee putting the ball in play.** Nobody decides anything: he holds it, then
    /// throws it to the man already named. The top of every round, and the throw-in after
    /// a turnover his own call caused. The floor plays the hold and the throw, then
    /// completes it — see `Rules.completeRefereeInbound`.
    case refereeInbound(official: UUID, to: Seat)
    case possession(holder: Seat)
    case awaitingRebound(shooter: Seat)
    /// Turnaround Three: pick any number to discard, then the shot goes up.
    case awaitingDiscard(seat: Seat, card: CardDescriptor, bonusEach: Int)
    /// A card that names a player: which one, and who is being asked.
    ///
    /// One phase for every kind of it — a pass of choice, a Nutmeg's two, an Ankle
    /// Breaker's victim. What the choice *does* is on the card; this only collects it.
    case awaitingTarget(seat: Seat, card: CardDescriptor, choices: [Seat])
    /// **Something in play, named to be taken out of it.** One question for every card
    /// that says *you may Retire target …*: an official, the ball, somebody's passive.
    /// The crew and the board are face-up, so this is a real read rather than a guess —
    /// and declining is always an answer.
    case awaitingRetirement(seat: Seat, card: CardDescriptor, choices: [RetirementTarget])
    /// Triple Threat: one of the card's own branches.
    case awaitingMode(seat: Seat, card: CardDescriptor)
    /// **A call, and the man it is against.** Once a game he may throw it out and send the
    /// official who made it off with it.
    case awaitingChallenge(seat: Seat, card: CardDescriptor)
    /// **You beat your man.** The defender whose printed counter has just been met, and
    /// the three things blowing by him is worth.
    case awaitingPayoff(seat: Seat, clamp: CardDescriptor)
    /// A card taken out of somebody else's hand, chosen rather than rolled for. The hand
    /// is face down — picking one is a guess, which is the point.
    case awaitingCardFrom(seat: Seat, card: CardDescriptor, victim: Seat)
    /// Wet Spot: one Injury off the table, some of them face down.
    case awaitingInjuryPick(seat: Seat, card: CardDescriptor)
    /// A fourth passive arriving on a full board: which of the four goes.
    case awaitingIntangibleDrop(seat: Seat, offered: [CardDescriptor])
    /// Wide-Open Three: naming the others, one at a time, until you stop.
    case awaitingNaming(seat: Seat, card: CardDescriptor, named: [Seat])
    /// **Pump Fake: how many of them you sell it to.** Named one at a time until you
    /// stop, because each one is more SHOT and less clock — the decision is where to
    /// stop, and stopping early is how you stay off a Shot Clock Violation.
    case awaitingClampsNamed(seat: Seat, card: CardDescriptor, named: [UUID])
    /// Franchise Player: something off the man who just took the pass. His passives are
    /// face up and his hand is not, so this is one question over two kinds of card.
    case awaitingToll(seat: Seat, victim: Seat)
    /// Bone Bruise: the turn opens by giving one up, and the sheet says whose choice it
    /// is. Its own phase rather than `awaitingDiscard`, which is a price paid for a shot
    /// and resolves into one.
    /// Cards off your own hand, chosen by you, because some card said so. An Injury's
    /// toll each turn asks this, and so does anything that says discard without saying
    /// at random — which is most of them.
    case awaitingGiveUp(seat: Seat, card: CardDescriptor, count: Int)
    /// Clear Out: asked the moment the ball arrives, before the defenders land on him.
    /// Answering no puts the card down for the possession; answering yes spends it and the
    /// ball carries on without him.
    /// **All of them, not the first that matched.** A hand can hold more than one answer
    /// — a Clear Out to step away and a Spin Move to take the defenders out of the air —
    /// and which one you spend is the decision.
    case awaitingCounter(seat: Seat, cards: [Card])
    /// A card's "You may": one yes or no, asked of the man whose card it is.
    case awaitingOption(seat: Seat, option: CardOption)
    /// At the line. One attempt at a time until the trip runs out.
    case freeThrows(trip: FreeThrowTrip)
    case gameOver

    /// **A card that is still being played.**
    ///
    /// It has been laid down and has asked its own question, and nothing it does is
    /// settled until that question is answered — so the board holds what it showed
    /// before. Dime's ten per cent was landing while the prompt naming who to pass it to
    /// was still open, which read as the card paying out before it had been played.
    var isMidPlay: Bool {
        switch self {
        case .awaitingTarget, .awaitingMode, .awaitingCardFrom, .awaitingInjuryPick,
             .awaitingNaming, .awaitingToll, .awaitingIntangibleDrop, .awaitingPayoff,
             .awaitingRetirement:
            return true
        default:
            return false
        }
    }

    /// The seat that owes a decision, if any.
    /// A short name for the phase, for logs.
    var label: String {
        switch self {
        case .inbound(let s): return "inbound(\(s))"
        case .possession(let s): return "possession(\(s))"
        default: return "\(self)".prefix(while: { $0 != "(" }).description
        }
    }

    var actingSeat: Seat? {
        switch self {
        case .inbound(let seat):    return seat
        case .possession(let seat): return seat
        case .awaitingDiscard(let seat, _, _): return seat
        case .awaitingGiveUp(let seat, _, _): return seat
        case .awaitingTarget(let seat, _, _): return seat
        case .awaitingRetirement(let seat, _, _): return seat
        case .awaitingMode(let seat, _): return seat
        case .awaitingPayoff(let seat, _): return seat
        case .awaitingChallenge(let seat, _): return seat
        case .awaitingCardFrom(let seat, _, _): return seat
        case .awaitingInjuryPick(let seat, _): return seat
        case .awaitingIntangibleDrop(let seat, _): return seat
        case .awaitingToll(let seat, _): return seat
        case .awaitingCounter(let seat, _): return seat
        case .awaitingOption(let seat, _): return seat
        case .awaitingNaming(let seat, _, _): return seat
        case .awaitingClampsNamed(let seat, _, _): return seat
        case .freeThrows(let trip): return trip.shooter
        default:                    return nil
        }
    }

    var isAwaitingRebound: Bool {
        if case .awaitingRebound = self { return true }
        return false
    }
}

/// **A card's "You may"** — the optional halves the SHOT audit wrote in.
/// **A thing on the table that a card can take off it.**
///
/// Officials, the ball and passives are all face-up and all replaceable, so the cards that
/// reach for them are asking one question with three kinds of answer rather than three
/// questions. Clamps are here too: Spin Move moves one rather than retiring it, and the
/// pick is the same pick.
enum RetirementTarget: Hashable, Codable {
    /// One of the crew, by his armed id.
    case official(UUID)
    /// Whatever Variaball is in play. Regulation is the absence of one, so there is
    /// nothing to name when the slot is empty.
    case ball
    /// A passive on somebody's board, by whose it is and which one.
    case intangible(seat: Seat, id: String)
    /// A defender, for the cards that move or clear one rather than Retiring it.
    case clamp(id: UUID)
}

enum CardOption: String, Hashable, Codable {
    /// Lob: the current Ball comes out of play and into your hand as you pass.
    case takeBall
    /// No-Look: a coin as you pass. Heads draws a card.
    case flipForDraw
    /// Kick-Out: every Clamp on you goes to the new player.
    case assignClamps
    /// Outlet Pass: the Shot Clock back to the top as your next possession opens.
    case resetShotClock
    /// Turnaround Three: the whole hand, for SHOT = 100%.
    case dumpHand
    /// The Ankle Breaker combo: a card out of another player's hand.
    case ankleBreaker

    /// The card doing the asking.
    var card: CardDescriptor {
        switch self {
        case .takeBall:       return CardLibrary.lob
        case .flipForDraw:    return CardLibrary.noLook
        case .assignClamps:   return CardLibrary.kickOut
        case .resetShotClock: return CardLibrary.outletPass
        case .dumpHand:       return CardLibrary.turnaroundThree
        case .ankleBreaker:   return CardLibrary.crossover
        }
    }
}

/// A Game Break taken off the deck and held until the draw that turned it up is done.
///
/// It carries its own depth, because resolving it can draw again and the run of Breaks
/// still has to be bounded — see `Rules.draw`.
struct PendingBreak: Codable, Hashable {
    let seat: Seat
    let card: Card
    let depth: Int
    /// Whether the draw that turned it up was itself replacing a waved Break. Play-On is
    /// spent on the first one and the run carries on without it.
    let waving: Bool
}

struct GameState: Codable {
    /// Frozen at creation — see MatchRules.
    let rules: MatchRules
    var players: [PlayerState]
    var deck: [Card] = []
    var discard: [Card] = []
    /// **The officials deck.** Shuffled once at the start of the game, like the main deck,
    /// and dealt from at the top of every round. Nobody is ever dealt one into a hand and
    /// nothing shuffles it back into the main pile — the crew is its own pile all game.
    var officials: [Card] = []
    /// The officials who have already worked a round. The crew deck comes back off this
    /// when it runs dry, the same way the main deck does.
    var officialsDiscard: [Card] = []
    /// **Passes thrown this round**, by anybody. Open Three is paid for the floor having
    /// been swung, and swinging it is something the whole table does.
    var passesThisRound = 0
    /// Bankshot: defenders this shot steps around, named as the coin lands.
    var ignoredClamps: Set<UUID> = []
    /// **Stepback: cards the next Three may be short by.** A stepback is separation, and
    /// separation is what people take threes off — so the card that makes it lets you
    /// rise from a thinner hand, for that shot and no other.
    var threeDiscount = 0
    /// **Who a Clamp being played is going on**, chosen before the play is shown to the
    /// crew. The officials who judge a Clamp judge its *victim* — Flagrant Foul II, Clear
    /// Path, Blocking Foul — and before targeting the victim was whoever held the ball,
    /// which is the man playing it. Named first, so the call reads the right person.
    var clampTarget: Seat?
    /// The Clamp whose target is being asked for, so the answer knows to assign rather
    /// than to rotate a beaten defender — the other thing a Clamp and a target mean.
    var assigningClamp: Card.ID?
    /// Misdirection: this swing was turned round by the Crossover in front of it, so it
    /// also knocks a card loose on the way past.
    var misdirected = false
    /// Rookie Official has already traded for this player this possession — the first
    /// card only, or a pair of Moves would fish the same two out all night.
    var rookieSwapped: Seat?
    /// From the Logo has reached for the table once already this play — see
    /// `Rules.resolveRetirement`. "And/or" is two reaches, never three.
    var reachedTwice = false
    var phase: Phase = .inbound(inbounder: .south)
    var round = 1
    /// What a shooting Special Move is paying for the attempt it is about to take.
    ///
    /// Not part of SHOT: it is spent on that one shot and cleared, so a cancelled attempt
    /// leaves the board exactly where it was. See the note in `Rules.apply`.
    var pendingShotBonus = 0
    /// Attempts already taken this round, so Sixth Man can count to six.
    var shotsThisRound = 0
    /// How the attempt on its way up is being finished, when it is finished at the rim.
    /// Set as the shot goes up and read by the cutscene; nothing about scoring reads it.
    var dunking: Dunk?
    /// Rock Fight: nobody shoots from a look this good, for the rest of the round.
    var shotCeilingThisRound: Int?
    /// Fundamentalist: which Moves have already been played this possession.
    var movesPlayedThisPossession: Set<String> = []
    /// Triple Threat: no more Moves for the rest of it.
    var movesClosed = false
    /// Lob: the man it found owes a shot before anything else.
    var mustShootFirst: Seat?
    /// Dime: who threw it, so a make pays them the extra assist.
    var dimeFrom: Seat?
    /// Gravity: where the pending Clamps are actually going to land.
    var clampMagnet: Seat?
    /// The card waiting on an answer, and the seat that played it — which is not always
    /// the seat being asked. Floor General aims other people's passes.
    var pendingPlay: CardDescriptor?
    var pendingActor: Seat?
    /// Nutmeg: where the card taken is headed, rather than to the pile.
    var stealTravelsTo: Seat?
    /// Wide-Open Three: who has been named so far, and who is owed an assist if it drops.
    var namedForAssist: [Seat] = []
    /// Kick-Out: the next basket this possession is worth one more.
    var pendingBonusPoint = 0
    /// Whether the last play was itself a combo — a Drive off a Dribble is a dribble
    /// drive, and a card can ask for that rather than for a Drive.
    var lastPlayWasCombo = false
    /// **Everything the play still owes**, in one list — see `Step`, which is where the
    /// five fields that used to hold these went and why.
    var pending: [Step] = []

    /// Owes it. **The only way to owe anything** — see `Step`.
    mutating func owe(_ step: Step) { pending.append(step) }

    /// Whether one of a kind is owed, and the first of it.
    func owes(_ kind: Step.Kind) -> Step? { pending.first { $0.kind == kind } }

    /// Drops every step of a kind, for a break in the play that outranks them: a Whistle
    /// taking the ball off the floor outranks a return leg owed to the play it stopped.
    mutating func forget(_ kinds: Step.Kind...) {
        pending.removeAll { kinds.contains($0.kind) }
    }
    /// Fresh Ball: the next possession opens without its draw.
    var skipsNextDraw = false
    /// How many draws are still open. The queue is drained when the last one closes.
    var drawChain = 0
    /// Set by anything that ends the possession the draws belonged to, which throws the
    /// rest of the chain away — see `Whistle.endsPossessionOnDraw`.
    var chainBroken = false
    /// **Off the Backboard: whose next miss comes straight back to them.** No bid and no
    /// scramble — the shooter takes his own board. Spent the moment it is used, and shown
    /// in the corner of the HUD until then.
    /// **Who has called the glass, and with what.** The card is kept rather than a bare
    /// seat so the moment it pays can show the card that paid — see `GameEvent.calledGlass`.
    var freeRebound: [Seat: CardDescriptor] = [:]
    /// Boards holding more passives than the rules allow, waiting to be asked which goes.
    /// Queued for the same reason a hand is: the phase set where the overflow happens is
    /// overwritten by whatever the draw chain does next.
    var overflowing: Set<Seat> = []
    /// Wet Spot: what is on offer, and which of them the picker cannot see.
    var injuriesOffered: [CardDescriptor] = []
    var injuriesHidden: Set<String> = []
    var inbounder: Seat = .south
    var ball: Seat?
    /// nil while the inbounder decides — the UI shows "--".
    var shotClock: Int?
    var shot = 0
    /// **The Varena on the floor**, as the card that was played there. Nil is the table's own
    /// Cardwood: the floor every game opens on, which nobody was dealt and nobody discards.
    var courtCard: Card?
    /// **The Variaball in play.** Nil is a Regulation Ball, which is not a card at all.
    var ballCard: Card?
    /// One of each a possession — see `Rules.legalMoves`.
    var playedVarenaThisPossession = false
    var playedVariaballThisPossession = false
    /// **A call being challenged**, held while its man decides.
    ///
    /// The call has not been made yet: everything it does is waiting on the answer, so a
    /// challenge that is taken means the call never happened rather than being undone.
    struct PendingCall: Hashable, Codable {
        let whistle: UUID
        let action: PendingAction
    }
    var challengedCall: PendingCall?
    /// **A call already answered for the play in flight.** Turning a challenge down lets
    /// the call land — and a call that does not cancel the card leaves the play still to
    /// resolve, so the play is run again with this set and the official who already spoke
    /// stays quiet. Cleared the moment the play finishes.
    var callsAnswered: Set<UUID> = []

    /// **Whether a round is in the middle of ending.** Ending one pays what it owes and
    /// deals the next hand, and both settle hands — which is where a stranded man is
    /// checked for, and a stranded man ends the round. Without this the check calls the
    /// thing it is inside and the stack runs out.
    var roundEnding = false
    /// Alley-Oop: whether this possession has been asked "Dunk It?" yet.
    var dunkOffered = false
    /// **How the attempt in the air was taken.** Set the moment a shoot button is pressed
    /// and read by the crew, by scoring, and by the cutscene.
    var shotType: ShotType = .layup
    /// The defender just beaten, held while his man picks what it was worth.
    var beatenClamp: ActiveClamp?
    /// Paid to the one attempt taken off a payoff.
    var payoffShotBonus = 0
    /// What the passer said yes to, carried into the pass — see `CardOption`.
    var passTakesBall = false
    var passFlipsCoin = false
    var passAssignsClamps = false
    /// Rhythm Dribble: SHOT owed to the very next action, if that action is a shot.
    var nextShotBonus = 0
    /// Equalizer: the seat whose make, if it goes in, levels every player's points.
    var levelsPointsFor: Seat?
    /// The Future: the discard now open is buying a three up to four.
    var fourPointOffer = false
    /// Move cards played this possession, counted rather than named — Torn Achilles allows one.
    var moveCardsThisPossession = 0

    /// **How many Moves this player's possession holds** — the Move bar, which is both the
    /// Travel line and the dunk's gate. One owner, because those two must never disagree:
    /// a bar that says three while the dunk wants four is a button nobody can explain.
    func moveLimit(for seat: Seat) -> Int {
        var limit = rules.movesPerPossession
        limit -= armedWhistles.reduce(0) { $0 + ($1.card.descriptor.whistle?.lowersMoveLimit ?? 0) }
        if let guarded = self[seat].clamps
            .compactMap({ $0.card.clamp?.movesPerPossession }).min() {
            limit = min(limit, guarded)
        }
        if let hurt = self[seat].injuries
            .compactMap({ $0.injury?.movesPerPossession }).min() {
            limit = min(limit, hurt)
        }
        return max(1, limit)
    }
    /// One Intangible a possession, played by hand like a Varena.
    var playedIntangibleThisPossession = false
    /// Everyone who has had the ball this round — Wide-Open Three asks.
    var possessedThisRound: Set<Seat> = []
    /// Varsitile's swap, once a possession.
    var slotsExchangedThisPossession = false
    /// Carousel Court: which way the hands go round, declared when it was played.
    var carouselClockwise: Bool?
    /// Turnstile Tile: whether this possession is the plus one.
    var turnstileUp = true
    /// Spazzphalt's roll, for the shot being priced.
    var courtShotRoll: Int?
    /// Foot Ball: Moves and Passes played and locked until the possession ends.
    var footLocked: [UUID] = []
    /// Monster Ball: every Intangible it has swallowed, in order.
    var monsterBallIntangibles: [CardDescriptor] = []
    /// And the ones being rebounded for now it has gone, first up first.
    var intangibleBoard: [CardDescriptor] = []
    /// Blight Ball: who is carrying the TOVs.
    var pileCarrier: Seat?
    /// S.O.S: the shot on its way up is a two at double SHOT.
    var sellingOut = false
    /// Tick-Tock Tile: ticks owed by cards played, paid once each card has resolved.
    var clockTicksOwed = 0
    /// Whistles set down and waiting. Resolved in the order they were armed, so a
    /// Whistle that cancels another Whistle has a defined winner.
    var armedWhistles: [ArmedWhistle] = []
    /// Played, but with nobody to land on yet. Attaches to the next ball-holder.
    var pendingClamps: [ActiveClamp] = []
    /// An armed Whistle that let a Clamp resolve and is waiting for it to land, so it can
    /// negate what it does rather than the play that made it.
    var pendingClampVoid: UUID?
    /// Swallowed Whistle. Cleared when the round turns over.
    var whistlesSilenced = false
    /// A possession held mid-arrival while its man is asked whether he is stepping out of
    /// it — see `Rules.beginPossession`. Everything it needs to pick up where it stopped.
    struct HeldPossession: Hashable, Codable {
        let seat: Seat
        let ticks: Bool
        let fromRebound: Bool
        let fromOwnMiss: Bool
        /// Whether the possession's own draw has already been made. It happens before the
        /// question is asked, and the question re-runs the whole opening on the answer —
        /// so without this he draws twice for turning one down.
        let drew: Bool
    }
    var heldPossession: HeldPossession?
    /// Back-and-Forth Game: how many more Breaks get waved away as they land.
    var breaksWaived = 0
    /// Mic'd Up: SHOT carried by whoever is holding the ball. Not part of `shot`, which
    /// is the ball's and travels with it — this one is gone the moment he gives it up.
    var holderShot = 0
    /// Altercation: the man you just shoved is not the man you throw it in to.
    var inboundBarred: Seat?
    /// How many times each Whistle has been called this round, by descriptor id. Cleared
    /// at the top of a round, which is what makes Delay-of-Game's second call a foul.
    var whistleCallsThisRound: [String: Int] = [:]
    /// Set by a Special Move for the shot it is about to take.
    var pendingShotOverride: ShotOverride?
    /// Sixth Man's button, pressed: this shot goes up at what it offered.
    var passiveShotOverride: ShotOverride?
    /// True when this possession began by grabbing a miss. Putback Tip is the only card
    /// that asks, and it is the whole of what makes it a *putback*.
    var possessionFromRebound = false
    /// **And whether it was his own miss he took back.** A different question: a board off
    /// somebody else's brick is still a rebound, and the cards that pay for one say "your
    /// own" on their face — Board-Crasher and Lethal Shooter both.
    var possessionFromOwnRebound = false
    /// The card that delivered the ball, if a pass did. A Clear Out asks it which way the
    /// ball was going — see `CardDescriptor.movesInADirection`.
    var arrivedBy: CardDescriptor?
    var lastPasser: Seat?
    /// Descriptor id of the last card played in the current possession; arms combos.
    var lastPlayThisPossession: String?
    /// Move cards played in the current possession. Uncapped by the rules, but read by
    /// the AI and by cards that restrict further Move plays.
    var movesThisPossession = 0
    /// Whether anything has gone off this possession that nobody chose: a Whistle blowing
    /// or a Game Break turning up. Give-and-Go is the one card that asks — it is a play
    /// off a clean look, and a clean look is one nothing has interrupted.
    var possessionWasInterrupted = false
    var rng: SeededRNG

    subscript(seat: Seat) -> PlayerState {
        get { players[seat.rawValue] }
        set { players[seat.rawValue] = newValue }
    }

    var half: Int { round <= rules.roundsPerHalf ? 1 : 2 }
    /// How many bodies are standing on a player: what every Clamp on them brings, which
    /// the sheet sets per card.
    func defenders(on seat: Seat) -> Int {
        self[seat].clamps.reduce(0) { $0 + ($1.card.clamp?.defenders ?? 1) }
    }

    var isOver: Bool { if case .gameOver = phase { return true }; return false }
    /// The floor the game is played on: whatever Varena is out, or Cardwood.
    var currentCourt: CardDescriptor { courtCard?.descriptor ?? CardLibrary.cardwood }
    /// The Variaball in play. Nil is a Regulation Ball.
    var currentBall: CardDescriptor? { ballCard?.descriptor }
    /// What the floor does. Cardwood does nothing.
    var floorEffect: VarenaEffect { currentCourt.varena ?? VarenaEffect() }
    /// What the ball does. A Regulation Ball does nothing.
    var ballEffect: VariaballEffect { currentBall?.variaball ?? VariaballEffect() }
    /// **The most cards a hand may hold.** The match's, unless the floor is stricter.
    var handLimit: Int { min(rules.handLimit, floorEffect.handLimit ?? rules.handLimit) }

    /// **One player's bag limit**, which Sixth Man widens. The floor and the match can
    /// only ever tighten it; a passive is the one thing that opens it back up, and the
    /// three still wants five however big the bag gets — see `ShotType.requiredHand`.
    func handLimit(for seat: Seat) -> Int {
        max(handLimit,
            self[seat].intangibles.compactMap { $0.intangible?.handLimit }.max() ?? handLimit)
    }
    /// **How many passives a board may hold.** The floor's, the match's — and tighter
    /// still if an official is checking bags. Official Review caps it at one.
    var intangibleSlotLimit: Int {
        let checked = armedWhistles.compactMap { $0.card.descriptor.whistle?.intangibleSlots }
        return min(floorEffect.intangibleSlots ?? rules.intangibleSlots,
                   checked.min() ?? Int.max)
    }

    /// **Whether anything pays a bonus right now.** Delay-of-Game Warning says nothing and
    /// makes no call; he simply stops them being paid while he works.
    var bonusesPaid: Bool {
        !armedWhistles.contains { $0.card.descriptor.whistle?.barsBonuses == true }
    }
    /// The shot clock on this floor.
    var shotClockLength: Int { floorEffect.shotClockStart ?? rules.shotClockStart }
    /// Dim Dome: whether this seat may read SHOT.
    func canReadShot(_ seat: Seat) -> Bool { !floorEffect.hidesShot || ball == seat }
}

/// RNG access goes through these so no call site takes overlapping `inout` access to state.
extension GameState {
    mutating func shuffled(_ cards: [Card]) -> [Card] { cards.shuffled(using: &rng) }
    mutating func pick(from seats: [Seat]) -> Seat { seats.randomElement(using: &rng)! }
    mutating func roll(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &rng) }
}
