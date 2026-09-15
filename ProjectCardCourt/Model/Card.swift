import Foundation

/// Where a pass sends the ball. `backToPasser` resolves against state, not geometry.
/// One branch of a card that offers a choice. Triple Threat is the only one so far.
struct CardMode: Hashable, Codable, Identifiable {
    var id: String { label }
    let label: String
    var draws = 0
    var shotDelta = 0
    var passes: PassTarget?
}

enum PassTarget: String, Hashable, Codable {
    case left, right, across, backToPasser
    /// The passer picks. Asked for rather than worked out — see `Phase.awaitingPassTarget`.
    case choice
    /// Nobody picks. No-Look does not know where it is going either.
    case random
    /// One of two, and still a choice.
    case leftOrRight
}

/// What a Clamp does to whoever it lands on. Most Clamps attach to the next ball-holder,
/// which is what makes passing into a Clamp a real decision.
struct ClampEffect: Hashable, Codable {
    /// True when the Clamp goes on standing there. A Clamp that debuffs SHOT is a
    /// defender in your way for the whole possession; one that only takes cards has done
    /// its work the moment it arrives and leaves again.
    var isStanding: Bool {
        shotDebuff != 0 || locksRandomCards > 0 || passOnly || shotPerCardPlayed != 0
            || blocksThrees || blocksShooting || turnoverWithoutAPass
    }

    /// Bodies this Clamp puts next to its victim. Double-Team is two, Triple-Team three.
    var defenders = 1
    /// Feeds the debuff layer of the SHOT stack if the clamped player shoots.
    var shotDebuff: Int = 0
    /// Discarded at random when the clamped player's possession begins.
    var discardAtStart: Int = 0
    /// Cards in the clamped player's hand they cannot play this possession, picked at
    /// random when the Clamp lands and then fixed — see `ActiveClamp.locked`. Re-rolling
    /// them each time the hand is drawn would make the lock unreadable.
    var locksRandomCards: Int = 0
    /// Nothing but Pass cards. Shooting is a free action rather than a card, so it stays.
    var passOnly = false
    /// Man-To-Man: SHOT, every time the clamped player plays a card.
    var shotPerCardPlayed = 0
    /// Close-Out: no three-point attempts.
    var blocksThrees = false
    /// Zone: no shots at all.
    var blocksShooting = false
    /// Zone: left without a playable Pass at any point, the player turns it over and the
    /// round ends.
    var turnoverWithoutAPass = false
}

/// A passive that sits in one of a player's slots for the rest of the match.
struct IntangibleEffect: Hashable, Codable {
    /// Moves At Own Pace: he cannot be called for Traveling or for a shot-clock
    /// violation. **He may play at nought** — the clock runs out and nothing happens.
    ///
    /// The violation is not forgiven, only held: `Rules.clockCatchesUp(_:)` calls it the
    /// moment the card leaves him, so a man sitting on 00 loses the ball as soon as the
    /// passive does.
    var ignoresViolations = false
    /// Feeds the adds layer of the SHOT stack.
    var shotBonus: Int = 0
    /// Hot Hand only pays if you scored in the previous round.
    var requiresScoredLastRound = false
    /// Extra cards pulled alongside every draw (Shot Creator).
    var bonusDraw: Int = 0
    /// Generational Whistle: every trip to the line is one attempt longer. Paid once per
    /// trip, not once per attempt.
    var bonusFreeThrows: Int = 0
    /// Freethrow Merchant: being Clamped is itself a foul, and the defenders never
    /// arrive — the trip to the line replaces what the Clamp was going to do.
    var freeThrowPerClamp: Int = 0
    /// SHOT multiplied rather than added to. Clutch Gene, under its own conditions.
    var shotMultiplier: Double = 0
    /// Clutch Gene fires on either: a hand this thin, or a clock this low.
    var requiresHandAtMost: Int?
    var requiresClockAtMost: Int?
    /// Roswell Reach: every bid he actually makes is worth one more card than he put
    /// in. Nought stays nought — a man who did not go up for it is not on the board.
    var reboundBidBonus = 0
    /// Board-Crasher: only off your own miss. Catch & Shoot: only off a pass.
    var requiresOwnRebound = false
    var requiresReceivedPass = false
    /// Catch & Shoot: only when the shot is the first thing you do with the pass.
    var requiresFirstAction = false
    /// Sniper and Splash Cousin only pay from range.
    var requiresThree = false
    /// `SHOT = x%` rather than a delta, under whatever conditions are also set.
    var shotOverride: Int?
    /// Sixth Man: the nth attempt of the round, counting from one.
    var requiresNthShotOfRound: Int?
    /// **Sixth Man: any six will do.** Six cards in hand, six on the Shot Clock, the
    /// sixth shot of the round, or a score of six. One of them is enough — the card is
    /// about the number rather than about any one way of reaching it.
    var requiresAnySix = false
    /// Sixth Man: a second Shoot button at this SHOT, taken only when the player wants it.
    var offersShotAt: Int?
    /// Lethal Shooter: the shot straight after taking your own board.
    var requiresAfterOwnRebound = false
    /// Point God draws on every pass.
    var drawAfterPass: Int = 0
    /// Ball Pounder: every Dribble is a card richer and a look worse.
    var dribbleBonusDraw: Int = 0
    var dribbleShotPenalty: Int = 0
    var dribbleClockDelta: Int = 0
    /// Like That, Competitive: nothing may take SHOT down. A Variaball still can under Like
    /// That — the ball is what changed, not the player.
    var shotCannotBeReduced = false
    var ignoresClampDebuffs = false
    /// Equalizer: any SHOT = shot goes up at 100%.
    var equalizesOverrides = false
    /// Gravity: every Clamp lands here whoever it was aimed at, and every other player's
    /// attempt is an assist.
    var attractsClamps = false
    var assistOnOthersShot = false
    /// Great Conditioning: an Injury never lands, and the draw is taken again. Landing also
    /// clears the ones already carried.
    var shrugsOffInjuries = false
    /// Southpaw Shooter: every SHOT gain is a loss and every loss a gain.
    var reversesShotChanges = false
    /// Park Shark blocks both; Fundamentalist only the Special Moves.
    var blocksMoves = false
    var blocksSpecialMoves = false
    /// Park Shark: no threes.
    var blocksThrees = false
    /// Free Agent: no bag of his own. He plays out of whoever is nearest.
    ///
    /// The hand is dumped once the draw chain that turned this up has finished, not the
    /// moment it lands — drawing it second in an opening deal should cost the whole hand,
    /// not one card.
    var playsFromOthers = false
    /// Dirty Player: every Whistle that fires costs you a card, whoever it was against.
    var discardOnAnyWhistle = 0
    /// Dirty Player: each of your Clamps on an Injured player costs them a card.
    var clampCostsInjured = 0
    /// Fundamentalist: each Move once a turn, and the plainest cards are never spent.
    var oneOfEachMovePerTurn = false
    var keepsOnPlay: [String] = []
    /// Fundamentalist: the ball goes back to Regulation when it lands.
    var discardsBallOnActivation = false
    /// Varsitile: no limit on Varenas and Variaballs a possession, and once a possession the
    /// floor, the ball or both can be swapped for ones in the discard.
    var playsSlotsFreely = false
    /// Brawl Handler: changing the ball takes your own Clamps off.
    var clearsClampsOnBallChange = false
    /// Baller: changing the ball draws you this many.
    var drawsOnBallChange = 0
    /// Floor General: **every** target on the floor is named by this player instead —
    /// who a pass finds, and which card comes out of a hand you cannot see. **Not the
    /// choices a player makes about their own card**: which branch of a multi-effect card
    /// to take, or whether to feed a shot an extra discard, are not targets — they are
    /// the play itself, and naming a target is not playing somebody's card for them.
    var aimsEveryTarget = false
    /// Franchise Player: a pass costs the man receiving it something. One of his
    /// passives, or one card out of a hand you cannot see.
    var passCostsTarget = false
    /// Comes off at the end of the round rather than sitting in a slot for the game.
    ///
    /// **Only the purely negative ones**, generally. An Intangible lasts the game unless
    /// something clears it; the exception is a passive that does nothing but hurt, which
    /// is a bad hand for a round rather than a permanent handicap. Floor General and
    /// Point God both read as round-long from their wording and neither was meant to.
    var lastsRound = false
    /// Equalizer: the offered shot discards the card that offered it.
    var spentOnOffer = false
    /// Equalizer: if that shot goes in, every player's points become the shooter's.
    var levelsPointsOnMake = false
}

/// A one-off that fires the moment it is drawn.
struct GameBreakEffect: Hashable, Codable {
    /// Off the Backboard: the next shot this player misses comes straight back to them.
    /// No bid, no scramble — see `Rules.resolveShot`. Carried until it is spent.
    var reboundsNextMiss = false
    /// Everybody, not only whoever turned it up.
    var everyoneDraws = 0
    /// Role Player: everybody *else*. The man who turned it up gets nothing.
    var othersDraw = 0
    /// Back-and-Forth Game: this many Breaks after it are waved away as they land, and
    /// the player who drew each one draws again instead.
    var waivesBreaks = 0
    /// The drawer, plainly. **One batch**, so anything that pays per draw pays once for
    /// the lot rather than once a card — see `Rules.drawBatch`.
    var draws = 0
    /// Ice Wrap and Hit the Bike: every Injury comes off, whatever it was going to last.
    var healsInjuries = false
    /// Ice Wrap: what it is worth when there was nothing to heal.
    var drawIfUninjured = 0
    /// All-Swissh Selection: owed, and paid on the next make rather than now.
    var drawsOnNextMake = 0
    /// Rock Fight: nobody shoots from a look this good or better, for the round.
    var blocksShotAtOrAbove: Int?
    /// Trade Deadline: every bag moves one seat, and the ball goes with it. The player
    /// who turned it up says which way.
    var rotatesHands = false
    /// Traded Mid-Game: the man who turned it up and one other, picked at random, trade
    /// hands where they stand. **Hands, not seats** — moving a man round the diamond
    /// moves the ball, the clamps standing on him and everybody's view of the court, and
    /// a trade is about the squad rather than about where he is standing.
    var swapsHandsAtRandom = false
    /// Fresh Ball: the next possession opens without its draw. A bad thing — a fresh ball
    /// is a ball nobody has broken in.
    var skipsNextDraw = false
    /// Floor Cleanup: every hand goes back into the deck and comes out again, the same
    /// size it went in.
    var everyoneRedraws = false
    /// Official Timeout: every Injury on every player, gone — but only if there is a
    /// referee on the floor to call it. With none, it is a card for everybody instead.
    var healsAllInjuries = false
    var requiresReferee = false
    var clearsReferees = false
    /// What it does instead, when its condition is not met.
    var everyoneDrawsInstead = 0
    /// Team Doctor: an Injury off a player of your choosing, and cards for looking after
    /// somebody other than yourself.
    var healsChosenInjury = false
    var drawsForHealingAnother = 0
    /// Wet Spot: every Injury in the pile and the deck is laid out, the deck's face down,
    /// and one of them is yours.
    var offersInjuries = false
    /// Altercation: you and the man you pick shove each other, and each lose a card at
    /// random. The ball goes back in to anybody but him.
    var fightsChosenPlayer = false
    /// Huge Altercation: every hand on the floor.
    var everyoneDiscardsHands = false
    /// And what it costs everybody when a referee was standing there to see it.
    var turnoversIfReferee = 0

    /// The drawer discards this many at random.
    var discard = 0
    /// Everyone discards down to this hand size.
    var everyoneDiscardsTo: Int?
    /// The drawer fills their hand up to this size. Every drawing Break works this way,
    /// so there is no "draw exactly N" variant to get them confused with.
    var drawUpTo: Int?
    /// Applied to the ball's SHOT for the rest of the possession.
    var shotThisPossession = 0
    /// Mic'd Up: SHOT the man holding the ball carries himself. It belongs to him and not
    /// to the ball, so a pass leaves it behind, and his own attempt spends it.
    var shotForHolder = 0
    /// In The Zone: a card for every 10% the ball is already worth, and never fewer than one.
    var drawsPerTenPercentShot = false
    /// Hands the ball to someone else. Not a pass — no SHOT, no assist.
    var givesBallAway = false
    /// No Whistle can fire for the rest of the round.
    var silencesWhistles = false
    /// Free throws for whoever drew it. Nobody fouled them, so nobody hands the ball back.
    var freeThrows = 0
}

/// **What an Injury does to the man carrying it.** Its own card type rather than a Game
/// Break, and a Devastating Injury is its sub-type — the one that lasts the game.
struct InjuryEffect: Hashable, Codable {
    /// **How long it sits on you, and whether it ever comes back.** An ordinary Injury lasts
    /// the round and is shuffled back in at halftime with everything else. A Devastating one
    /// lasts the whole game and is never shuffled back. See `Injury`.
    var lasts: Injury
    /// Bone Bruise: one card off the top of your hand at the start of every turn, after
    /// you have drawn — so the turn always begins with a choice rather than a tax.
    var discardsEachTurn = 0
    /// Torn Achilles: everything in the bag is held down but this many, rolled fresh each
    /// turn. Zero is no lock at all.
    var playableEachTurn: Int?
}

/// What a Varena changes while it is the floor — one field per mechanic, like
/// `GameBreakEffect`. Cardwood, the default floor, sets none.
struct VarenaEffect: Hashable, Codable {
    /// `SHOT = x%` on every shot. Only an Intangible's override outranks it.
    var shotOverride: Int?
    /// Spazzphalt: SHOT is a fresh roll, 0–100 in steps of 5, on every shot.
    var randomShotOverride = false
    /// On every shot. Prime Parquet, Lacktop, Kiddie Court, Gravi-Gym.
    var shotBonus = 0
    /// Kiddie Court: a dunk is worth this much more.
    var dunkBonus = 0
    /// Every Move card played moves SHOT this much: Con-crete takes, The Future gives.
    var shotPerMovePlayed = 0
    /// Turnstile Tile: plus this one possession, minus it the next.
    var turnstileSwing = 0
    /// Smacktop: the referees go when it lands, none can be played, and Clamps hit harder.
    var clearsWhistlesOnArrival = false
    var barsWhistles = false
    var enhancesClamps = false
    /// Policeum: a referee who calls one stays until the floor changes.
    var refereesStay = false
    /// Boarder Court: the shooter's own bid counts this many more.
    var shooterReboundBonus = 0
    /// Dim Dome: nobody but the ball holder reads SHOT.
    var hidesShot = false
    /// Tri-hard Tiling: hands are cut to this, and a draw into a full hand is discarded.
    var handLimit: Int?
    /// Kiddie Court and Vintage Varnish: no threes, and nothing that makes one.
    var barsThrees = false
    /// Kiddie Court: every basket is worth this.
    var makesCount: Int?
    /// Gravi-Gym: no card that dunks.
    var barsDunks = false
    /// Recharging Resin: everyone refills to this at the start of their possession.
    var refillsTo: Int?
    /// MVPiquia: only the highest scorer does.
    var leaderRefillsTo: Int?
    /// Contact Court: landed on by a Clamp, you shoot this many free throws.
    var freeThrowsWhenClamped = 0
    /// Polypaypylene: a make draws this many.
    var drawsOnMake = 0
    /// Recoverena: every Injury goes when it lands, and a new one is a card instead.
    var healsInjuriesOnArrival = false
    var injuriesBecomeDraws = false
    /// Carousel Court: every possession, the hands move one seat the declared way.
    var rotatesHands = false
    /// Traderous Tarmac: the Clamps on you are yours to hand out.
    var clampsHandOff = false
    /// Clearcoat Court: referees, Clamps, Injuries and Intangibles off, every possession.
    var wipesEachPossession = false
    /// Malice Palace: the hand goes before the draw.
    var discardsHandBeforeDraw = false
    /// Roleplayer Polymer: everyone but the player with the ball draws this many.
    var othersDrawEachPossession = 0
    /// Variaball Vinyl: the draw for turn goes to a random player.
    var turnDrawToRandomPlayer = false
    /// Vintage Varnish: its own shot clock, no balls, one Intangible each.
    var shotClockStart: Int?
    var barsVariaballs = false
    var intangibleSlots: Int?
    /// S.O.S — Sell-Out Stadium: a three may go up as a two at double SHOT.
    var threesAsDoubleTwos = false
    /// Grayvstone: every possession, the ball is the last one discarded.
    var ballFromDiscard = false
    /// Frostbite Finish: a Move costs this many other cards.
    var moveDiscardCost = 0
    /// Tick-Tock Tile: every card played takes a tick off the clock.
    var cardsTickClock = false
    /// The Future: a card for every Move played, SHOT off every pass, and a three that can
    /// be bought up to four.
    var drawsPerMovePlayed = 0
    var shotPerPass = 0
    var offersFourPointThree = false
}

/// What a Variaball changes while it is the ball.
struct VariaballEffect: Hashable, Codable {
    /// `SHOT = x%` on every shot — Brick Ball's flat 25. Outranked by an Intangible's and
    /// the floor's; outranks a played card's.
    var shotOverride: Int?
    /// Bag'n Ball: SHOT is this much for every card in the shooter's hand.
    var shotPerCardInHand = 0
    /// Med Ball: SHOT never goes past this.
    var shotCeiling: Int?
    /// Blaze Ball and Snow Ball It: every pass, on its own, whatever else the pass does.
    var shotPerPass = 0
    /// Dishcount Ball: one fewer for card costs and Clamps.
    var discountsDiscards = false
    /// Blight Ball: Injuries go wherever the ball goes.
    var injuriesTravel = false
    /// Bench Ball: caught off a pass, you go straight to the inbound.
    var benchesReceiver = false
    /// Dishtracting Ball: taking the ball costs a card, after the draw.
    var receiverDiscards = 0
    /// Hand Ball: a pass swaps hands.
    var swapsHandsOnPass = false
    /// Foot Ball: Moves and Passes lock instead of being spent.
    var locksInsteadOfSpending = false
    /// Recharge Rock: the draw for turn, this many times over.
    var turnDrawMultiplier = 1
    /// Shufflebag Ball: the hand goes into the deck and comes back out, every possession.
    var reshufflesHandEachPossession = false
    /// Bag'n Ball: its player draws this many when it arrives.
    var drawsOnArrival = 0
    /// Monster Ball: every Intangible goes into the ball.
    var absorbsIntangibles = false
    /// Brand New Ball: the chance, in per cent, that a shot is a turnover instead.
    var turnoverChance = 0
    /// Variaball: never sits in the slot. It puts a discarded ball there instead.
    var rollsFromDiscard = false
}

/// How long an Injury stays on the man who drew it.
enum Injury: String, Hashable, Codable {
    /// Off at the end of the round, and back in the deck at halftime.
    case round
    /// On for the rest of the game, and never shuffled back in.
    case game
}

/// A Special Move: the redesign of the old Shot cards. Most of them take the shot
/// themselves, which ends the possession — so a player wants everything else played first.
/// A card whose worth turns on what the SHOT already is.
struct ShotSwing: Hashable, Codable {
    /// The mark it is read against.
    var at: Int
    /// What it does below that mark, and what it does at or above it.
    var under: Int
    var over: Int

    func delta(on shot: Int) -> Int { shot < at ? under : over }
}

struct SpecialMoveEffect: Hashable, Codable {
    var shootsImmediately = false
    /// Three-pointers pay one extra on a make.
    var bonusPointOnMake = 0
    /// `SHOT = x%`. Sits in the override layer, so it beats the debuffs.
    var shotOverride: Int?
    /// Slam Dunk only. Read after the debuffs, against what survived.
    var overrideRequiresAtLeast: Int?
    /// Which finish this card calls for. Nil lets the man's own position decide, which
    /// is what a plain possession does — see `Dunk.ordinary`.
    var dunkKind: Dunk?
    /// Wide-Open Three: only as your first action, with no Clamps or Injuries on you and no
    /// Whistles out on the floor.
    var needsWideOpenLook = false
    /// **A swing rather than a delta.** Tomahawk pays either way and the SHOT it is played
    /// on decides which: under the mark it costs, at or over it pays.
    var shotSwing: ShotSwing?
    /// Straight off your own board, and only as the first thing you do with it.
    var bonusOffOwnRebound = 0
    /// The attempt is finished at the rim, whoever is taking it. Any of the three, since
    /// the card asked for a dunk rather than for the one this man usually throws down.
    var dunks = false
    /// Buzzer Beater is unplayable unless the clock reads exactly this.
    var onlyAtShotClock: Int?
    /// `SHOT = x%`, but only off the glass. Putback Tip is a tip-in: from anywhere else
    /// it is an ordinary ten per cent, and straight after a board it cannot miss.
    var shotOverrideAfterRebound: Int?
    /// Wide-Open Three: name any number of the others. Each is worth this much SHOT, and
    /// each takes an assist if it goes in — the first card that pays an opponent.
    var shotPerNamed = 0
    /// Lob: the man it lands on has to put it up first.
    /// Bankshot: one flip, paying this much either way.
    var coinFlipShot = 0
    /// Skyhook goes up over everything. The debuff layer is skipped for this shot.
    var ignoresClamps = false
    /// 2-Hand Jam: discard first, paying this much SHOT for each — up to the limit, and past
    /// it at the beyond price when the card's bonus is on.
    var discardForShotBonus = 0
    var discardForShotLimit: Int?
    var discardBeyondLimitBonus = 0
    /// Euro Step: flips exactly this many coins, paying out per head. All of them Heads is
    /// a Travel instead.
    var coinRunShot = 0
    var coinRunDraw = 0
    var coinRunFlips = 0
    /// Dagger Three: worth more the later it is taken. Paid on top of the card's own
    /// `shotDelta`, once for every tick still on the Shot Clock — so +60% and −10% a tick
    /// is +50% at 01 and −40% at 10, read straight off the clock.
    var shotPerClockTick = 0
    /// Turnaround Three: a hand at least this big may all be discarded, for SHOT = 100%.
    var offersHandDumpAt: Int?
}

enum CardType: String, Hashable, Codable, CaseIterable {
    case pass = "Pass"
    case move = "Move"
    case specialMove = "Special Move"
    case clamp = "Clamp"
    case whistle = "Whistle"
    case gameBreak = "Game Break"
    case intangible = "Intangible"
    /// Drawn and carried. A Devastating Injury is its sub-type, the one that lasts the game.
    case injury = "Injury"
    /// The floor. One is always out — Cardwood until somebody plays over it.
    case varena = "Varena"
    /// The ball. None out is a Regulation Ball.
    case variaball = "Variaball"
}

/// One row of the card sheet. `numberInDeck` mirrors the Number in Deck column.
struct CardDescriptor: Hashable, Identifiable, Codable {
    let id: String
    let name: String
    let type: CardType
    let effect: String
    let numberInDeck: Int

    /// nil for cards that do not move the ball.
    let passTarget: PassTarget?
    /// **Whether the man throwing it may name himself.**
    ///
    /// He may, on nearly all of them: people throw the ball off the glass and take it
    /// back, and the sheet only says *another* player where the card means it. Dime is
    /// one — an assist to yourself is not an assist — and Right Back is the other, where
    /// the return leg is the same man twice and the ball never leaves his hands.
    ///
    /// Passing to yourself is Traveling unless something says otherwise; see
    /// `Rules.completePass` and `IntangibleEffect.ignoresViolations`.
    var passesToOthersOnly = false
    /// Resolved into a concrete value by `CardLibrary.buildDeck`, so a dealt card
    /// never depends on a rule that could move under it.
    var shotDelta: Int?
    let drawCount: Int
    let clockDelta: Int
    /// Descriptor id that must be the immediately preceding play to arm `comboBonus`.
    let comboAfter: String?
    /// Or any Dribble at all, rather than one named card. Drive follows *a* dribble —
    /// naming the base one meant Rhythm Dribble, which is equally a dribble, did not
    /// arm it.
    var comboAfterDribble = false
    let comboBonus: Int
    /// And what else an armed combo is worth. Hand-Off pays a card off a Dribble.
    var comboDraw = 0
    /// Paid only when the play it followed was **itself** a combo.
    var comboAssist = 0
    /// The next basket this possession is worth one more. A kick-out is a three because
    /// of where it puts the man, not because of what he does with it.
    var upgradesToThree = false
    /// The Shot Clock is moved by this card **instead of** by the possession. Outlet Pass
    /// runs the other way: it hands a tick back rather than costing one.
    var replacesClockTick = false
    /// Set on Whistles.
    let whistle: WhistleEffect?
    /// Part of the Dribble family, which Double Dribble watches for.
    let isDribble: Bool
    /// Discarded at random from your own hand after the card resolves. Pound Dribble
    /// draws two and gives one back.
    var selfDiscard = 0
    /// Paid per Clamp cleared. Spin Move turns being guarded into an advantage.
    var shotPerClamp = 0
    var drawPerClamp = 0
    /// Pump Fake: the Shot Clock, per Clamp cleared.
    var clockPerClamp = 0
    /// And what it costs whoever sent them.
    var clamperDiscardsPerClamp = 0
    /// Bullet Pass: the man it lands on gives one up for the privilege.
    var receiverDiscards = 0
    /// Dime: an extra assist if the man you found scores off it.
    var bonusAssistOnScore = false
    /// Lob: he has to put it up as his first action.
    var forcesReceiverShot = false
    /// Alley-Oop: he does not get to choose at all. It goes up the moment he has drawn.
    var forcesImmediateShot = false
    /// Kick-Out: the passer **may** Assign every Clamp on him to the receiver.
    var movesClampsToReceiver = false
    /// Lob: the passer may take the current Ball out of play and into his hand.
    var mayTakeBall = false
    /// No-Look: the passer may flip a coin; Heads draws a card.
    var mayFlipForDraw = false
    /// Outlet Pass: the passer may Reset the Shot Clock as his next possession opens.
    var offersClockReset = false
    /// Rhythm Dribble: this much SHOT on the very next action, if that action is a shot.
    var nextShotBonus = 0
    /// Right Back: he takes it and gives it straight back. Both legs pay, so the card is
    /// worth twice its own SHOT and a card to each of them — and whatever the trip cost
    /// him on the way happens in between.
    var returnsImmediately = false
    /// **Worth whatever the pass that found you was worth.**
    ///
    /// Behind-the-Back alone. Every other pass names its number and takes the match's
    /// increment if it does not; this one is priced off the ball rather than off the
    /// card — a good feed sent straight back is a good feed twice, and a swing sent back
    /// is only a swing. Its number is nil for that reason, so `resolved(passShotBonus:)`
    /// has to leave it alone.
    var matchesArrivingPass = false
    /// Touch Pass: worth more when it never stops in your hands.
    var drawIfFirstAction = 0
    /// Clear Out: you are not where the pass expected you to be. A pass thrown by
    /// direction carries on past you; a pass that named you is thrown away.
    var clearsOut = false
    /// You get out of the way before the play starts, or not at all.
    var firstActionOnly = false
    /// Nutmeg: a card travels the way the pass did, from the receiver to the next along.
    var stealsAlongPass = 0
    /// Ankle Breaker: a player of your choosing gives one up.
    var targetDiscards = 0
    /// Stepback: an optional card for an optional extra look.
    var optionalDiscardForShot = 0
    /// Triple Threat: one of several things, chosen when it is played.
    var modes: [CardMode] = []
    /// And what it costs — no more Moves this possession.
    var blocksFurtherMoves = false
    /// Set on Clamps.
    let clamp: ClampEffect?
    /// Set on Intangibles.
    let intangible: IntangibleEffect?
    /// Set on Game Breaks.
    let gameBreak: GameBreakEffect?
    /// Set on Injuries.
    let injury: InjuryEffect?
    /// Set on Varenas.
    let varena: VarenaEffect?
    /// Set on Variaballs.
    let variaball: VariaballEffect?
    /// Set on Special Moves.
    let special: SpecialMoveEffect?
    /// Flop: a trip to the line for every Clamp standing on you.
    let freeThrowsPerClamp: Int
    /// Clears every Clamp on the player — Flop sells it, Pump Fake shrugs it.
    let clearsClamps: Bool
    /// Flop with nobody guarding you: the referee has watched you throw yourself down
    /// on an empty floor.
    let turnoverIfNoClamps: Bool
    /// What following another card pays and what it has to follow. Behind the COMBO button
    /// rather than printed, since the face has no room for it.
    let combo: String?
    /// The card's conditional half, behind the BONUS button. See `bonusLines`.
    let bonus: String?

    init(id: String, name: String, type: CardType, effect: String, numberInDeck: Int,
         passTarget: PassTarget? = nil, passesToOthersOnly: Bool = false,
         shotDelta: Int? = nil, drawCount: Int = 0,
         clockDelta: Int = 0, comboAfter: String? = nil,
         comboAfterDribble: Bool = false, comboBonus: Int = 0,
         comboDraw: Int = 0, comboAssist: Int = 0,
         upgradesToThree: Bool = false, replacesClockTick: Bool = false,
         whistle: WhistleEffect? = nil, clamp: ClampEffect? = nil,
         intangible: IntangibleEffect? = nil, gameBreak: GameBreakEffect? = nil,
         injury: InjuryEffect? = nil,
         varena: VarenaEffect? = nil, variaball: VariaballEffect? = nil,
         special: SpecialMoveEffect? = nil, isDribble: Bool = false,
         selfDiscard: Int = 0, shotPerClamp: Int = 0, drawPerClamp: Int = 0,
         clockPerClamp: Int = 0, clamperDiscardsPerClamp: Int = 0,
         freeThrowsPerClamp: Int = 0, clearsClamps: Bool = false,
         turnoverIfNoClamps: Bool = false,
         receiverDiscards: Int = 0, bonusAssistOnScore: Bool = false,
         forcesReceiverShot: Bool = false, forcesImmediateShot: Bool = false,
         movesClampsToReceiver: Bool = false,
         mayTakeBall: Bool = false, mayFlipForDraw: Bool = false,
         offersClockReset: Bool = false, nextShotBonus: Int = 0,
         returnsImmediately: Bool = false, matchesArrivingPass: Bool = false,
         drawIfFirstAction: Int = 0,
         clearsOut: Bool = false, firstActionOnly: Bool = false,
         stealsAlongPass: Int = 0,
         targetDiscards: Int = 0, optionalDiscardForShot: Int = 0,
         modes: [CardMode] = [], blocksFurtherMoves: Bool = false,
         combo: String? = nil, bonus: String? = nil) {
        self.receiverDiscards = receiverDiscards
        self.bonusAssistOnScore = bonusAssistOnScore
        self.forcesReceiverShot = forcesReceiverShot
        self.forcesImmediateShot = forcesImmediateShot
        self.movesClampsToReceiver = movesClampsToReceiver
        self.mayTakeBall = mayTakeBall
        self.mayFlipForDraw = mayFlipForDraw
        self.offersClockReset = offersClockReset
        self.nextShotBonus = nextShotBonus
        self.returnsImmediately = returnsImmediately
        self.matchesArrivingPass = matchesArrivingPass
        self.drawIfFirstAction = drawIfFirstAction
        self.clearsOut = clearsOut
        self.firstActionOnly = firstActionOnly
        self.stealsAlongPass = stealsAlongPass
        self.targetDiscards = targetDiscards
        self.optionalDiscardForShot = optionalDiscardForShot
        self.modes = modes
        self.blocksFurtherMoves = blocksFurtherMoves
        self.selfDiscard = selfDiscard; self.shotPerClamp = shotPerClamp
        self.drawPerClamp = drawPerClamp
        self.clockPerClamp = clockPerClamp
        self.clamperDiscardsPerClamp = clamperDiscardsPerClamp
        self.id = id; self.name = name; self.type = type; self.effect = effect
        self.numberInDeck = numberInDeck; self.passTarget = passTarget
        self.passesToOthersOnly = passesToOthersOnly
        self.shotDelta = shotDelta; self.drawCount = drawCount; self.clockDelta = clockDelta
        self.comboAfter = comboAfter; self.comboAfterDribble = comboAfterDribble
        self.comboBonus = comboBonus
        self.comboDraw = comboDraw; self.comboAssist = comboAssist
        self.upgradesToThree = upgradesToThree
        self.replacesClockTick = replacesClockTick
        self.whistle = whistle; self.clamp = clamp
        self.intangible = intangible; self.gameBreak = gameBreak
        self.injury = injury
        self.varena = varena; self.variaball = variaball
        self.special = special; self.isDribble = isDribble
        self.freeThrowsPerClamp = freeThrowsPerClamp; self.clearsClamps = clearsClamps
        self.turnoverIfNoClamps = turnoverIfNoClamps
        self.combo = combo; self.bonus = bonus
    }

    var isPass: Bool { passTarget != nil }

    /// **What this card does to SHOT**, for the ball at the foot of it. Nil on a card
    /// that does not touch SHOT at all, which is most of them.
    ///
    /// Five types carry it: Passes, Moves and Special Moves, whose number lands on the man
    /// holding the ball; Game Breaks, whose lands on the possession; and Clamps, whose
    /// lands on **whoever gets the ball next** rather than on the holder. That last one
    /// is why a Clamp's percentage is printed in gold rather than white — see
    /// `CardFrontView.percentage`. Intangibles are left out: theirs is a standing bonus
    /// rather than something the card does when it is played.
    var shotEffect: Int? {
        switch type {
        case .pass, .move, .specialMove:
            if let override = special?.shotOverride { return override }
            if baseShotDelta != 0 { return baseShotDelta }
            if let per = special?.discardForShotBonus, per != 0 { return per }
            if let per = special?.coinRunShot, per != 0 { return per }
            return nil
        case .clamp:
            if let debuff = clamp?.shotDebuff, debuff != 0 { return debuff }
            return nil
        case .gameBreak:
            if let shift = gameBreak?.shotThisPossession, shift != 0 { return shift }
            return nil
        case .whistle, .intangible, .injury, .varena, .variaball:
            return nil
        }
    }

    /// True when the number is a target rather than a change.
    var setsShot: Bool { special?.shotOverride != nil }

    /// Drawn with a slash through it — the card says "no" to whatever the icon shows.
    ///
    /// **Off while the icons are per type.** A slash belongs on a picture of the thing
    /// being denied; over a Game Break's own mark it says nothing.
    var isSlashed: Bool { false }

    /// **The card's picture, which is its type's rather than its own.**
    ///
    /// Nine full-colour drawings, one per type, each built on the same circle in the same
    /// place — see `_Design/type-icons.md`. That is what retired the per-card multiplier
    /// this used to carry: every icon is drawn at one size now, and the size is a dial.
    ///
    /// Injuries are Game Breaks but read as their own thing, and the two of them differ
    /// by how long they last, so they get a drawing each.
    var artwork: (name: String, mirrored: Bool, scale: CGFloat)? {
        (name: Self.typeIcon(for: type, lasting: injury?.lasts),
         mirrored: false, scale: 1)
    }

    /// **The half of the drawing that goes in front of the name plate**: the ball on a
    /// Pass, the ankle on a Move, the star and the ball on a Special Move. The same
    /// artboard as the back layer, so the two line up by being drawn at the same size in
    /// the same place rather than by carrying offsets of their own.
    ///
    /// A name only. **Whether the drawing exists is the view's question** — the model is
    /// built headless and knows nothing about an asset catalog. See `CardFrontView`.
    var artworkFront: String {
        Self.typeIcon(for: type, lasting: injury?.lasts) + "Front"
    }

    static func typeIcon(for type: CardType, lasting: Injury?) -> String {
        switch type {
        case .pass:        return "TypePass"
        case .move:        return "TypeMove"
        case .specialMove: return "TypeSpecialMove"
        case .clamp:       return "TypeClamp"
        case .whistle:     return "TypeWhistle"
        case .intangible:  return "TypeIntangible"
        // Cardwood's court, for every Varena until each has its own.
        case .varena:      return "ISO_Court"
        case .variaball:   return "TypeVariaball"
        case .gameBreak:   return "TypeGameBreak"
        case .injury:      return lasting == .game ? "TypeDevaInjury" : "TypeInjury"
        }
    }

    /// Cards that say it with the same mark more than once. Each entry is one copy's
    /// size as a share of the icon's own, drawn left to right — so a Triple-Team is a
    /// defender at full size with a smaller one either side of him, and a Double-Team is
    /// two of equal size. Nil for every card that wears its mark once.
    /// **Off while the icons are per type.** Two of the same type icon side by side says
    /// the type twice, not that two men are on you.
    var iconRepeat: [CGFloat]? { nil }

    /// Turning applied to the icon, in degrees clockwise.
    /// **Off while the icons are per type.** It turned a symbol that had no upright.
    var iconRotation: Double { 0 }

    /// A second, smaller symbol set off from the main one — the ball leaving the hand on
    /// a Fadeaway, or the ball a Putback tips back up. Sizes and offsets are fractions of
    /// the icon's own side.
    ///
    /// Worn by drawn artwork as well as by symbols, so a card whose icon is an SVG can
    /// still take the game's own ball rather than one baked into the drawing.
    ///
    /// **Off while the icons are per type.** These were placed against a particular
    /// drawing; over a type's own mark they land on whatever happens to be there.
    var accentSymbol: (name: String, scale: CGFloat, x: CGFloat, y: CGFloat, turn: Double)? {
        nil
    }

    /// Turns the main symbol alone, leaving any accent to its own angle. Distinct from
    /// `iconRotation`, which turns the whole icon.
    var symbolRotation: Double {
        id == "travel" ? -11 : 0
    }

    /// Nudges an icon that turning has thrown off centre.
    var iconYAdjust: CGFloat { 0 }

    /// Whether the card sends the ball **a way** rather than **at somebody**.
    ///
    /// Left, right and straight over are all directions: the ball is thrown that way and
    /// whoever is standing there catches it. A pass of choice is aimed — it names a man,
    /// and the direction is only wherever he happens to be sitting.
    ///
    /// The line matters twice over. A Clear Out can only carry on a ball that was going
    /// somewhere, and stepping out of one thrown *at* you is a pass to nobody and a
    /// turnover for whoever threw it. And Floor General names every target on the floor —
    /// which is a card about aiming, and has no business renaming a Skip Pass.
    ///
    /// **Across is a direction with nobody past it.** Straight over from the man opposite
    /// ends at you; there is no further seat for a Clear Out to send it on to. So it is
    /// still a turnover — for want of anywhere to go, not for having been aimed.
    var movesInADirection: Bool {
        switch passTarget {
        case .left, .right, .leftOrRight, .across: return true
        default:                                   return false
        }
    }

    /// Cards that put the shot up say so with a mark rather than the words.
    var takesShot: Bool { special?.shootsImmediately == true }

    /// Detail the face has no room for. Shown only when a card is raised for reading, so
    /// the printed text can stay as short as it needs to be.
    var detailNote: String? {
        switch id {
        case "coachs-challenge":  return "(from Discards)"
        case "behind-the-back":   return "(TOV +1 if nobody passed to you)"
        case "swallowed-whistle": return "(Whistles cannot activate)"
        default:                  return nil
        }
    }

    /// What a raised card says: the printed text plus whatever would not fit on it.
    var detailedEffect: String {
        guard let note = detailNote else { return printedEffect }
        return printedEffect + " " + note
    }

    /// Threes say so with the hand rather than the words.
    var isThree: Bool { (special?.bonusPointOnMake ?? 0) > 0 }

    /// **What the BONUS bubble says**: the card's conditional half. That it shoots is the
    /// shoot mark's to say, not a line of text.
    var bonusLines: [String] { bonus.map { [$0] } ?? [] }

    /// The effect text with everything the card already says in pictures taken out —
    /// "Shoot the ball" is the shoot mark, and any SHOT figure is the ball badge.
    ///
    /// A SHOT clause is only dropped when it stands alone. Turnaround Three's
    /// "SHOT +10% for each" is doing real work, so it survives.
    var printedEffect: String {
        var text = effect
        if takesShot {
            text = text
                .replacingOccurrences(of: "Shoot the ball.", with: "")
                .replacingOccurrences(of: "Shoot the ball", with: "")
        }
        if isThree {
            text = text.replacingOccurrences(
                of: "(?i)\\+\\s*1\\s*(?:PT|Point)\\s*on\\s*make", with: "",
                options: .regularExpression)
        }
        // **A sentence that is only the card's own SHOT goes: the badge says it.** Every
        // other word is printed exactly as the card was written — see
        // `_Design/card-text-style.md`. Split by line and then by sentence, so a bullet or
        // a bracketed aside stays whole.
        let bare = "(?i)^SHOT\\s*[+\\-\u{2212}=]?\\s*\\d+%\\.?$"
        let badged = shotEffect != nil
        return text.components(separatedBy: "\n")
            .compactMap { line -> String? in
                let kept = line.components(separatedBy: ". ")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .filter { !badged || $0.range(of: bare, options: .regularExpression) == nil }
                return kept.isEmpty ? nil : kept.joined(separator: ". ")
            }
            .joined(separator: "\n")
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
    }

    /// SF Symbol standing in for the effect, so a glance reads before the text does.
    var symbol: String {
        switch id {
        case "dribble", "rhythm-dribble":   return "arrow.triangle.2.circlepath"
        case "drive":                       return "chevron.up.dotted.2"
        case "timeout":                     return "pause.circle.fill"
        case "crowd-noise":                 return "speaker.wave.3.fill"
        case "two-minute-warning":          return "timer"
        case "designed-play", "mvp-vote":   return "square.stack.3d.up.fill"
        case "benched":                     return "arrow.left.arrow.right.circle.fill"
        case "off-night":                   return "cloud.rain.fill"
        case "swallowed-whistle":           return "speaker.slash.fill"
        // Not all of these are built yet — the sheet has them, the library does not. The
        // mapping is written now so a card arrives wearing the right mark rather than the
        // type's default the first time it is dealt.
        case "great-conditioning":          return "figure.strengthtraining.traditional"
        case "triple-threat":               return "move.3d"
        case "shot-creator":                return "plus.rectangle.on.rectangle"
        case "hot-hand":                    return "flame.fill"
        case "euro-step":                   return "shuffle"
        case "buzzer-beater":               return "alarm.fill"
        case "from-the-hash":               return "number"
        case "from-the-logo":               return "circle.dashed"
        case "full-court-heave":            return "sportscourt"
        case "fadeaway":                    return "figure.fall"
        case "putback-tip":                 return "arrow.up.to.line"
        case "turnaround-three":            return "arrow.trianglehead.2.clockwise"
        case "goaltending":                 return "hand.raised.slash.fill"
        case "shot-clock-violation":        return "clock.badge.exclamationmark.fill"
        case "travel":                      return "shoeprints.fill"
        case "double-dribble":              return "arrow.triangle.2.circlepath.circle.fill"
        case "back-court-violation":        return "arrow.uturn.backward"
        case "inadvertent-whistle":         return "questionmark.circle.fill"
        case "coachs-challenge":            return "flag.2.crossed.fill"
        case "official-review":             return "magnifyingglass"
        case "flop":                        return "theatermasks.fill"
        case "freethrow-merchant":          return "cart.fill"
        case "generational-whistle":        return "star.circle.fill"
        case "contest":                     return "hand.raised.fill"
        case "full-court-press":            return "person.3.fill"
        // ── The passes: each one says how it finds its man. ──
        case "dime":                        return "hand.point.up.left.fill"
        case "lob":                         return "arrow.up.forward"
        case "nutmeg":                      return "arrow.triangle.branch"
        case "no-look":                     return "eye.slash.fill"
        case "bullet-pass":                 return "bolt.horizontal.fill"
        // ── The moves. ──
        case "ankle-breaker":               return "bandage.fill"
        case "hesi":                        return "pause.fill"
        case "pump-fake":                   return "arrow.up.and.down.circle.fill"
        case "stepback":                    return "arrow.backward.to.line"
        // ── Whistles, Breaks and Injuries. ──
        case "cleared-to-play":             return "checkmark.seal.fill"
        case "clear-path-foul":             return "figure.run.circle.fill"
        case "technical-foul":              return "exclamationmark.triangle.fill"
        case "blocking-foul":               return "hand.raised.slash"
        case "flagrant-foul":               return "exclamationmark.octagon.fill"
        case "flagrant-foul-ii":            return "exclamationmark.octagon"
        case "charge":                      return "figure.fall.circle.fill"
        case "delay-of-game-warning":       return "hourglass"
        case "rock-fight":                  return "mountain.2.fill"
        case "ice-wrap":                    return "snowflake.circle.fill"
        case "hit-the-bike":                return "figure.outdoor.cycle"
        case "all-star-selection":          return "star.fill"
        case "salary-cap-increase":         return "dollarsign.circle.fill"
        case "foul":                        return "hand.raised.brakesignal"
        case "bone-bruise":                 return "figure.walk.motion"
        case "torn-achilles":               return "cross.case.fill"
        // ── Intangibles. ──
        case "board-crasher":               return "arrow.up.circle.fill"
        case "catch-and-shoot":             return "hands.and.sparkles.fill"
        case "clutch-gene":                 return "bolt.heart.fill"
        case "floor-general":               return "megaphone.fill"
        case "southpaw-shooter":            return "hand.point.left.fill"
        case "gravity":                     return "globe.desk.fill"
        case "like-that":                   return "hand.thumbsup.fill"
        case "park-shark":                  return "fish.fill"
        case "point-god":                   return "crown.fill"
        case "sixth-man":                   return "6.circle.fill"
        case "sniper":                      return "scope"
        case "splash-cousin":               return "drop.fill"
        case "competitive":                 return "figure.walk.motion.trianglebadge.exclamationmark"
        case "lethal-shooter":              return "target"
        case "ball-pounder":                return "arrow.down.circle.fill"
        case "equalizer":                   return "equal.circle.fill"
        case "trade-deadline":              return "arrow.trianglehead.2.clockwise.rotate.90"
        case "fresh-ball":                  return "basketball"
        case "wet-spot":                    return "drop.triangle.fill"
        case "floor-cleanup":               return "wind"
        case "official-timeout":            return "cross.circle.fill"
        case "free-agent":                  return "figure.wave"
        case "dirty-player":                return "hand.raised.fingers.spread.fill"
        case "franchise-player":            return "person.crop.rectangle.badge.plus"
        case "team-doctor":                 return "stethoscope"
        case "wide-open-three":             return "person.3.sequence.fill"
        case "hand-off":                    return "hands.and.sparkles"
        case "outlet-pass":                 return "arrow.up.right.circle.fill"
        case "kick-out":                    return "arrow.turn.up.right"
        case "right-back":                  return "arrow.left.arrow.right"
        case "touch-pass":                  return "hand.tap.fill"
        case "clear-out":                   return "arrow.left.and.right.righttriangle.left.righttriangle.right.fill"
        case "fundamentalist":              return "book.closed.fill"

        default: break
        }
        switch type {
        case .pass:         return "arrow.forward"
        case .move:         return "figure.bowling"
        case .specialMove:  return "basketball.fill"
        case .clamp:        return "hand.raised.fill"
        case .whistle:      return "flag.fill"
        case .gameBreak:    return "bolt.fill"
        case .injury:       return "bandage.fill"
        case .intangible:   return "sparkles"
        case .varena:       return "sportscourt.fill"
        case .variaball:    return "basketball"
        }
    }
    /// A Special Move is a Move card wherever a card says Move.
    var isMove: Bool { type == .move || type == .specialMove }

    /// Always concrete on a dealt card — `buildDeck` bakes the passing bonus in, except
    /// on a card that is worth whatever found it. See `matchesArrivingPass`.
    var baseShotDelta: Int { shotDelta ?? 0 }

    /// A copy with the match's passing increment written in, so the card carries its own
    /// number rather than pointing at one.
    func resolved(passShotBonus: Int) -> CardDescriptor {
        guard shotDelta == nil, isPass, !matchesArrivingPass else { return self }
        var copy = self
        copy.shotDelta = passShotBonus
        return copy
    }

    // MARK: - On the wire

    /// **By name, plus whatever the match baked into it.**
    ///
    /// A descriptor is a library entry and every device holds the library, so what has to
    /// cross is *which* entry — not a copy of one. A `GameState` carries one per card in
    /// the deck, and written out in full an opening board came to **237 KB**. GameKit
    /// refuses a reliable send over about 87 KB, so `match.send` threw, `broadcast`
    /// swallowed it with `try?`, and no board ever reached a guest. The small messages
    /// went through, which is why the table always seated and nothing else ever happened.
    ///
    /// `shotDelta` travels because it is the one field a dealt card does not share with
    /// its library entry: `buildDeck` calls `resolved(passShotBonus:)` to bake the match's
    /// passing increment in, and that is the only mutation there is. Sent only when it
    /// differs, so an ordinary card is four words on the wire.
    private enum Wire: String, CodingKey { case card, shot }

    init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: Wire.self)
        let named = try box.decode(String.self, forKey: .card)
        guard var found = CardLibrary.byID[named] else {
            throw DecodingError.dataCorruptedError(
                forKey: .card, in: box,
                debugDescription: "no card in the library called \(named)")
        }
        if let baked = try box.decodeIfPresent(Int.self, forKey: .shot) {
            found.shotDelta = baked
        }
        self = found
    }

    func encode(to encoder: any Encoder) throws {
        var box = encoder.container(keyedBy: Wire.self)
        try box.encode(id, forKey: .card)
        if shotDelta != CardLibrary.byID[id]?.shotDelta {
            try box.encode(shotDelta, forKey: .shot)
        }
    }
}

/// A dealt instance. Two copies of Swing Left are different cards in a bag.
struct Card: Hashable, Identifiable, Codable {
    let id: UUID
    let descriptor: CardDescriptor

    init(_ descriptor: CardDescriptor, id: UUID = UUID()) {
        self.id = id
        self.descriptor = descriptor
    }

    var name: String { descriptor.name }
    var isPass: Bool { descriptor.isPass }
}
