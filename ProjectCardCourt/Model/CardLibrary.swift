import Foundation

/// The cards in play. Counts come from the Number in Deck column of
/// Project CardCourt_CardDB.xlsx, and the percentages match its effect text:
/// passes move SHOT less than Move cards do.
enum CardLibrary {

    static let swingLeft = CardDescriptor(
        id: "swing-left", name: "Swing Left", type: .pass,
        effect: "#[Pass] Left. SHOT +5%", numberInDeck: 30, passTarget: .left)

    static let swingRight = CardDescriptor(
        id: "swing-right", name: "Swing Right", type: .pass,
        effect: "#[Pass] Right. SHOT +5%", numberInDeck: 30, passTarget: .right)

    static let skipPass = CardDescriptor(
        id: "skip-pass", name: "Skip Pass", type: .pass,
        effect: "#[Pass] Across. SHOT +5%", numberInDeck: 20, passTarget: .across)

    static let behindTheBack = CardDescriptor(
        id: "behind-the-back", name: "Behind-the-Back", type: .pass,
        effect: "#[Pass] back to last player. Gains what the pass to you gained",
        numberInDeck: 5, passTarget: .backToPasser, matchesArrivingPass: true)

    static let dime = CardDescriptor(
        id: "dime", name: "Dime", type: .pass,
        effect: "#[Pass] to target player. SHOT +10%", numberInDeck: 5,
        passTarget: .choice, passesToOthersOnly: true,
        shotDelta: 10, bonusAssistOnScore: true)

    static let lob = CardDescriptor(
        id: "lob", name: "Lob", type: .pass,
        effect: "SHOT +10%. #[Pass] to target player. They must shoot.",
        numberInDeck: 6,
        passTarget: .choice, shotDelta: 10, forcesReceiverShot: true)

    static let nutmeg = CardDescriptor(
        id: "nutmeg", name: "Nutmeg", type: .pass,
        effect: "#[Pass] Left or Right. Knock 1 card to next player. SHOT +10%",
        numberInDeck: 6,
        passTarget: .leftOrRight, shotDelta: 10, stealsAlongPass: 1)

    static let noLook = CardDescriptor(
        id: "no-look", name: "No-Look", type: .pass,
        effect: "#[Pass] to random other player. SHOT +10%", numberInDeck: 10,
        passTarget: .random, shotDelta: 10)

    static let touchPass = CardDescriptor(
        id: "touch-pass", name: "Touch Pass", type: .pass,
        effect: "#[Pass] to target player. SHOT +10%. #[Draw] 2 if it never stopped",
        numberInDeck: 5,
        passTarget: .choice, shotDelta: 10, drawIfFirstAction: 2)

    static let rightBack = CardDescriptor(
        id: "right-back", name: "Right Back", type: .pass,
        effect: "#[Pass] to target player to pass right back. SHOT +10%.",
        numberInDeck: 7,
        passTarget: .choice, passesToOthersOnly: true,
        shotDelta: 10, returnsImmediately: true)

    static let alleyOop = CardDescriptor(
        id: "alley-oop", name: "Alley-Oop", type: .pass,
        effect: "#[Pass] to target player. SHOT +20%. They must shoot.",
        numberInDeck: 5,
        passTarget: .choice, shotDelta: 20, forcesImmediateShot: true)

    static let handOff = CardDescriptor(
        id: "hand-off", name: "Hand-Off", type: .pass,
        effect: "#[Pass] Left or Right. SHOT +10%. #[Draw] 1",
        numberInDeck: 7,
        passTarget: .leftOrRight, shotDelta: 10, drawCount: 1,
        comboAfterDribble: true, comboBonus: 5, comboDraw: 1)

    static let outletPass = CardDescriptor(
        id: "outlet-pass", name: "Outlet Pass", type: .pass,
        effect: "#[Pass] to target player. SHOT +10%. #[Shot Clock] +01",
        numberInDeck: 3,
        passTarget: .choice, shotDelta: 10, clockDelta: 1, replacesClockTick: true)

    static let kickOut = CardDescriptor(
        id: "kick-out", name: "Kick-Out", type: .pass,
        effect: "#[Pass] to target player. SHOT +10%. The shot becomes a three",
        numberInDeck: 3,
        passTarget: .choice, shotDelta: 10, comboAfter: "drive",
        comboDraw: 1, comboAssist: 1, upgradesToThree: true)

    static let bulletPass = CardDescriptor(
        id: "bullet-pass", name: "Bullet Pass", type: .pass,
        effect: "#[Pass] to target player. SHOT +10%. They #[Discard] 1 at random",
        numberInDeck: 10,
        passTarget: .choice, shotDelta: 10, receiverDiscards: 1)

    static let dribble = CardDescriptor(
        id: "dribble", name: "Dribble", type: .move,
        effect: "#[Draw] 1. SHOT -10%", numberInDeck: 16,
        shotDelta: -10, drawCount: 1, isDribble: true)

    static let drive = CardDescriptor(
        id: "drive", name: "Drive", type: .move,
        effect: "SHOT +10%. Following a @[Dribble]: SHOT +10%", numberInDeck: 10,
        shotDelta: 10, comboAfterDribble: true, comboBonus: 10)

    static let poundDribble = CardDescriptor(
        id: "pound-dribble", name: "Pound Dribble", type: .move,
        effect: "#[Draw] 2 then #[Discard] 1. SHOT +10%. #[Shot Clock] -1", numberInDeck: 5,
        shotDelta: 10, drawCount: 2, clockDelta: -1, isDribble: true, selfDiscard: 1)

    static let spinMove = CardDescriptor(
        id: "spin-move", name: "Spin Move", type: .move,
        effect: "SHOT +10%. #[Clear] all #[Clamps]: SHOT +10% for each", numberInDeck: 10,
        shotDelta: 10, isDribble: true, shotPerClamp: 10, clearsClamps: true)

    static let crossover = CardDescriptor(
        id: "crossover", name: "Crossover", type: .move,
        effect: "#[Draw] 1. SHOT +10%. #[Clear] all #[Clamps]: #[Draw] 1 and Clamper #[Discards] 1 for each",
        numberInDeck: 5,
        shotDelta: 10, drawCount: 1, isDribble: true,
        drawPerClamp: 1, clamperDiscardsPerClamp: 1, clearsClamps: true)

    static let rhythmDribble = CardDescriptor(
        id: "rhythm-dribble", name: "Rhythm Dribble", type: .move,
        effect: "#[Draw] 1. SHOT +10%. #[Shot Clock] -01", numberInDeck: 5,
        shotDelta: 10, drawCount: 1, clockDelta: -1, isDribble: true)

    /// The sheet's row is cut off after "If no Clamps on you," — so the card does what
    /// the written half says and nothing more. It greys out on an empty floor.
    static let ankleBreaker = CardDescriptor(
        id: "ankle-breaker", name: "Ankle Breaker", type: .move,
        effect: "#[Target] player #[Discards] 1. SHOT +10%", numberInDeck: 10,
        shotDelta: 10, targetDiscards: 1)

    static let hesi = CardDescriptor(
        id: "hesi", name: "Hesi", type: .move,
        effect: "SHOT +10%. #[Shot Clock] -01", numberInDeck: 10,
        shotDelta: 10, clockDelta: -1, isDribble: true)

    static let pumpFake = CardDescriptor(
        id: "pump-fake", name: "Pump Fake", type: .move,
        effect: "SHOT +10%. #[Clear] all #[Clamps]", numberInDeck: 12,
        shotDelta: 10, clearsClamps: true)

    static let stepback = CardDescriptor(
        id: "stepback", name: "Stepback", type: .move,
        effect: "SHOT +10%. You may #[Discard] 1 for additional SHOT +10%", numberInDeck: 12,
        shotDelta: 10, optionalDiscardForShot: 10)

    static let tripleThreat = CardDescriptor(
        id: "triple-threat", name: "Triple Threat", type: .move,
        effect: "Choose: #[Draw] 1 / #[Pass] (+5%) / SHOT +10%.\nCan use no further #[Moves] this possession",
        numberInDeck: 15,
        modes: [CardMode(label: "Draw 1", draws: 1),
                CardMode(label: "Pass (+5%)", shotDelta: 5, passes: .choice),
                CardMode(label: "SHOT +10%", shotDelta: 10)],
        blocksFurtherMoves: true)

    static let clearOut = CardDescriptor(
        id: "clear-out", name: "Clear Out", type: .move,
        effect: "First action only: Step aside, dodging the ball and all #[Clamps].",
        numberInDeck: 8,
        clearsOut: true, firstActionOnly: true)

    static let flop = CardDescriptor(
        id: "flop", name: "Flop", type: .move,
        effect: "#[Clear] all #[Clamps]. Take 1 #[FT] for each. If no #[Clamps], #[TOV] +1",
        numberInDeck: 5,
        freeThrowsPerClamp: 1, clearsClamps: true, turnoverIfNoClamps: true)

    static let contest = CardDescriptor(
        id: "contest", name: "Contest", type: .clamp,
        effect: "Next player: SHOT -25%", numberInDeck: 10,
        clamp: ClampEffect(shotDebuff: -25))

    static let doubleTeam = CardDescriptor(
        id: "double-team", name: "Double-Team", type: .clamp,
        effect: "Next player #[Lock|2]", numberInDeck: 4,
        clamp: ClampEffect(defenders: 2, locksRandomCards: 2))

    static let tripleTeam = CardDescriptor(
        id: "triple-team", name: "Triple-Team", type: .clamp,
        effect: "Next player #[Lock|3]", numberInDeck: 2,
        clamp: ClampEffect(defenders: 3, locksRandomCards: 3))

    static let trap = CardDescriptor(
        id: "trap", name: "Trap", type: .clamp,
        effect: "Next player can only #[Pass] or Shoot", numberInDeck: 5,
        clamp: ClampEffect(defenders: 3, passOnly: true))

    static let fullCourtPress = CardDescriptor(
        id: "full-court-press", name: "Full-Court Press", type: .clamp,
        effect: "Next player #[Discard|2]", numberInDeck: 3,
        clamp: ClampEffect(discardAtStart: 2))

    // ── Whistles ──────────────────────────────────────────────────────
    // A nil trigger resolves on play; everything else lies in wait. A turnover always
    // costs the ball and re-inbounds without advancing the round.

    static let shotClockViolation = CardDescriptor(
        id: "shot-clock-violation", name: "Shot Clock Violation", type: .whistle,
        effect: "#[Shot Clock] changes: #[TOV] +1. Side-out.", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .shotClockLowered, turnoverOnOffender: true,
                               cancelsCard: false, offenderInbounds: true))

    /// Called on the draw itself, which is the only Whistle that is — see
    /// `WhistleTrigger.cardDrawn`. It ends the possession where it stands and throws away
    /// whatever the draw still had queued.
    static let discontinuedDribble = CardDescriptor(
        id: "discontinued-dribble", name: "Discontinued Dribble", type: .whistle,
        effect: "Player #[Draws] a card: Possession ends. Side-out.",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .cardDrawn, cancelsCard: false,
                               offenderInbounds: true, endsPossession: true))

    static let travel = CardDescriptor(
        id: "travel", name: "Travel", type: .whistle,
        effect: "Cancel Next #[Move]. #[TOV] +1. Side-out.", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .movePlayed, turnoverOnOffender: true))

    static let playOn = CardDescriptor(
        id: "play-on", name: "Play-On", type: .whistle,
        effect: "On #[Game Break]: #[Cancel] and #[Draw] again",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .gameBreakDrawn))

    static let crewChiefReview = CardDescriptor(
        id: "crew-chief-review", name: "Crew Chief Review", type: .whistle,
        effect: "Cancel a pass. The ball comes to you", numberInDeck: 1,
        whistle: WhistleEffect(takesBall: true, trigger: .passPlayed))

    static let doubleDribble = CardDescriptor(
        id: "double-dribble", name: "Double Dribble", type: .whistle,
        effect: "Cancel a @[Dribble]. #[Discard] 1. #[TOV] +1", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .dribblePlayed, turnoverOnOffender: true,
                               offenderDiscards: 1))

    static let backCourtViolation = CardDescriptor(
        id: "back-court-violation", name: "Back Court Violation", type: .whistle,
        effect: "Cancel Next #[Pass]. #[TOV] +1. Side-out.",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .passPlayed, turnoverOnOffender: true,
                               setterChoosesInbound: true))

    static let inadvertentWhistle = CardDescriptor(
        id: "inadvertent-whistle", name: "Inadvertent Whistle", type: .whistle,
        effect: "Any other #[Whistle] fires: cancel it. Turn player #[Draws] 1",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .whistleFired, offenderDraws: 1))

    static let coachsChallenge = CardDescriptor(
        id: "coachs-challenge", name: "Coach's Challenge", type: .whistle,
        effect: "Cancel Next #[Whistle]. +1 @[Timeout]",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .whistlePlayed, recoversTimeout: true))

    static let officialReview = CardDescriptor(
        id: "official-review", name: "Official Review", type: .whistle,
        effect: "Next #[Intangible]: #[Discard] all theirs", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .intangiblePlayed, stripsIntangibles: true))

    static let goaltending = CardDescriptor(
        id: "goaltending", name: "Goaltending", type: .whistle,
        effect: "Cancel Next #[Clamp]. +2 PTS. End round",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .clampPlayed, endsRound: true, pointsToVictim: 2))

    // These three let the Clamp resolve and negate what it does, so that "the clamped
    // player" has somebody to refer to — see WhistleEffect.voidsClampOnLanding.

    static let blockingFoul = CardDescriptor(
        id: "blocking-foul", name: "Blocking Foul", type: .whistle,
        effect: "Next #[Clamp]: no effect. Clamped player +1 #[FT]", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .clampPlayed, voidsClampOnLanding: true,
                               freeThrowsToClampVictim: 1))

    static let flagrantFoul = CardDescriptor(
        id: "flagrant-foul", name: "Flagrant Foul", type: .whistle,
        effect: "Next #[Clamp]: no effect. Clamper #[Discards] 1. Clamped player +1 #[FT] and keeps the ball",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .clampPlayed, offenderDiscards: 1,
                               voidsClampOnLanding: true, freeThrowsToClampVictim: 1,
                               victimKeepsBall: true))

    static let flagrantFoulII = CardDescriptor(
        id: "flagrant-foul-ii", name: "Flagrant Foul II", type: .whistle,
        effect: "Next #[Clamp]: no effect. Clamper #[Discards] their bag. Clamped player +1 #[FT] and keeps the ball",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .clampPlayed, offenderDiscardsBag: true,
                               voidsClampOnLanding: true, freeThrowsToClampVictim: 1,
                               victimKeepsBall: true))

    static let charge = CardDescriptor(
        id: "charge", name: "Charge", type: .whistle,
        effect: "Cancel Next Shot. Shooter inbounds", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .shotAttempt, offenderInbounds: true))

    static let technicalFoul = CardDescriptor(
        id: "technical-foul", name: "Technical Foul", type: .whistle,
        effect: "Cancel Next Non-#[Whistle]. Take 1 #[FT]", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .anyNonWhistlePlayed, freeThrowsToVictim: 1))

    static let delayOfGameWarning = CardDescriptor(
        id: "delay-of-game-warning", name: "Delay-of-Game Warning", type: .whistle,
        effect: "Cancel Next Shot-Clock card. 2nd call this round: Take 1 #[FT]",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .shotClockLowered, freeThrowsOnRepeatCall: 1,
                               keepsClockCost: true, staysArmed: true))

    static let timeout = CardDescriptor(
        id: "timeout", name: "Timeout", type: .whistle,
        effect: "Reset #[Shot Clock]. You inbound. All #[Draw] 1", numberInDeck: 1,
        whistle: WhistleEffect(ownerInbounds: true, resetsShotClock: true,
                               everyoneDraws: 1))

    static let clearedToPlay = CardDescriptor(
        id: "cleared-to-play", name: "Cleared to Play", type: .whistle,
        effect: "An #[Injury] turns up: it never lands", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .injuryDrawn))

    static let clearPathFoul = CardDescriptor(
        id: "clear-path-foul", name: "Clear Path Foul", type: .whistle,
        effect: "Shooting under a SHOT #[Clamp]: #[Clear] them, take the points and 1 #[FT]",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .shotAttempt, cancelsCard: false,
                               endsRound: true, freeThrowsToOffender: 1,
                               clearsShotDebuffClamps: true,
                               awardsShotValueToOffender: true,
                               requiresShotDebuffClamp: true))

    static let roswellReach = CardDescriptor(
        id: "roswell-reach", name: "Roswell Reach", type: .intangible,
        effect: "Every #[Rebound] bid you make counts as one card more", numberInDeck: 1,
        intangible: IntangibleEffect(reboundBidBonus: 1))

    static let boardCrasher = CardDescriptor(
        id: "board-crasher", name: "Board-Crasher", type: .intangible,
        effect: "SHOT +10% off your own board", numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: 10, requiresOwnRebound: true))

    static let catchAndShoot = CardDescriptor(
        id: "catch-and-shoot", name: "Catch & Shoot Specialist", type: .intangible,
        effect: "SHOT +10% more on every pass you receive", numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: 10, requiresReceivedPass: true))

    static let clutchGene = CardDescriptor(
        id: "clutch-gene", name: "Clutch Gene", type: .intangible,
        effect: "SHOT x2 at 1 card or fewer, or #[Shot Clock] 3 or under", numberInDeck: 1,
        intangible: IntangibleEffect(shotMultiplier: 2,
                                     requiresHandAtMost: 1, requiresClockAtMost: 3))

    static let floorGeneral = CardDescriptor(
        id: "floor-general", name: "Floor General", type: .intangible,
        effect: "You name every target on the floor", numberInDeck: 1,
        intangible: IntangibleEffect(aimsEveryTarget: true))

    static let foxLikeFirstStep = CardDescriptor(
        id: "fox-like-first-step", name: "Fox-Like First Step", type: .intangible,
        effect: "#[Moves] that cost SHOT pay it instead", numberInDeck: 1,
        intangible: IntangibleEffect(invertsMoveDebuffs: true))

    static let gravity = CardDescriptor(
        id: "gravity", name: "Gravity", type: .intangible,
        effect: "Every #[Clamp] lands on you. #[AST] +1 on anyone else's attempt",
        numberInDeck: 1,
        intangible: IntangibleEffect(attractsClamps: true, assistOnOthersShot: true))

    static let greatConditioning = CardDescriptor(
        id: "great-conditioning", name: "Great Conditioning", type: .intangible,
        effect: "#[Injuries] never land. #[Draw] again for each", numberInDeck: 1,
        intangible: IntangibleEffect(shrugsOffInjuries: true))

    static let likeThat = CardDescriptor(
        id: "like-that", name: "Like That", type: .intangible,
        effect: "Nothing takes your SHOT down", numberInDeck: 1,
        intangible: IntangibleEffect(shotCannotBeReduced: true))

    static let noBag = CardDescriptor(
        id: "no-bag", name: "No Bag", type: .intangible,
        effect: "No #[Move] cards this round", numberInDeck: 1,
        intangible: IntangibleEffect(blocksMoves: true, lastsRound: true))

    static let pointGod = CardDescriptor(
        id: "point-god", name: "Point God", type: .intangible,
        effect: "#[Draw] 1 after each of your passes", numberInDeck: 1,
        intangible: IntangibleEffect(drawAfterPass: 1))

    static let shootingSlump = CardDescriptor(
        id: "shooting-slump", name: "Shooting Slump", type: .intangible,
        effect: "SHOT -20% this round", numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: -20, lastsRound: true))

    static let sixthMan = CardDescriptor(
        id: "sixth-man", name: "Sixth Man", type: .intangible,
        effect: "SHOT = 100% on the 6th shot of the round", numberInDeck: 1,
        intangible: IntangibleEffect(shotOverride: 100, requiresNthShotOfRound: 6))

    static let sniper = CardDescriptor(
        id: "sniper", name: "Sniper", type: .intangible,
        effect: "SHOT +10% from three", numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: 10, requiresThree: true))

    static let splashCousin = CardDescriptor(
        id: "splash-cousin", name: "Splash Cousin", type: .intangible,
        effect: "From three: SHOT = 100%", numberInDeck: 1,
        intangible: IntangibleEffect(requiresThree: true, shotOverride: 100))

    static let competitive = CardDescriptor(
        id: "competitive", name: "Competitive", type: .intangible,
        effect: "#[Clamps] do nothing to your SHOT", numberInDeck: 1,
        intangible: IntangibleEffect(ignoresClampDebuffs: true))

    static let lethalShooter = CardDescriptor(
        id: "lethal-shooter", name: "Lethal Shooter", type: .intangible,
        effect: "SHOT = 100% on the shot after your own board", numberInDeck: 1,
        intangible: IntangibleEffect(shotOverride: 100, requiresAfterOwnRebound: true))

    static let ballPounder = CardDescriptor(
        id: "ball-pounder", name: "Ball Pounder", type: .intangible,
        effect: "Every @[Dribble] #[Draws] 1 more and costs 10% more", numberInDeck: 1,
        intangible: IntangibleEffect(dribbleBonusDraw: 1, dribbleShotPenalty: -10))

    static let franchisePlayer = CardDescriptor(
        id: "franchise-player", name: "Franchise Player", type: .intangible,
        effect: "Your passes cost the man receiving one: a passive of his, or a card",
        numberInDeck: 1,
        intangible: IntangibleEffect(passCostsTarget: true))

    static let villainousReputation = CardDescriptor(
        id: "villainous-reputation", name: "Villainous Reputation", type: .intangible,
        effect: "Every #[Whistle] that fires costs you a card. Taken off you, it finds somebody",
        numberInDeck: 1,
        intangible: IntangibleEffect(discardOnAnyWhistle: 1, reattachesOnDiscard: true))

    static let dirtyPlayer = CardDescriptor(
        id: "dirty-player", name: "Dirty Player", type: .intangible,
        effect: "Your #[Clamps] cost an injured man a card", numberInDeck: 1,
        intangible: IntangibleEffect(clampCostsInjured: 1))

    /// **Out of the deck**, and kept only because everything it needs still works.
    ///
    /// Its whole play is "choose a hand and play a card out of it", and the button that
    /// asks the first half throws the answer away — so it has been an unplayable card
    /// sitting in the pool. It comes back when the borrow is wired to `Move.borrow`,
    /// which is what the rules have always expected. See `Rules.borrow`.
    static let freeAgent = CardDescriptor(
        id: "free-agent", name: "Free Agent", type: .intangible,
        effect: "No bag. Play a card at random out of a player of your choosing",
        numberInDeck: 1,
        intangible: IntangibleEffect(playsFromOthers: true))

    static let fundamentalist = CardDescriptor(
        id: "fundamentalist", name: "Fundamentalist", type: .intangible,
        effect: "No #[Special Moves]. Each #[Move] once a turn. Swings, @[Skip Pass] and @[Dribble] are never spent",
        numberInDeck: 1,
        intangible: IntangibleEffect(blocksSpecialMoves: true, oneOfEachMovePerTurn: true,
                                     keepsOnPlay: ["swing-left", "swing-right",
                                                   "skip-pass", "dribble"]))

    static let unselfish = CardDescriptor(
        id: "unselfish", name: "Unselfish", type: .intangible,
        effect: "#[Draw] 1 and SHOT +5% next time, whenever you positively affect another player",
        numberInDeck: 1,
        intangible: IntangibleEffect(drawOnHelping: 1, shotOnHelping: 5))

    // ── Injuries ──────────────────────────────────────────────────────
    //
    // Their own column on the sheet and their own rules. An ordinary Injury lasts the
    // round and comes back in the halftime shuffle, so there can be several copies and
    // each is kept scarce. A Devastating one lasts the game, exists once, and never
    // returns to the deck.

    static let boneBruise = CardDescriptor(
        id: "bone-bruise", name: "Bone Bruise", type: .gameBreak,
        effect: "#[Discard] 1 each turn, after drawing", numberInDeck: 3,
        gameBreak: GameBreakEffect(isInjury: true, injury: .round, discardsEachTurn: 1))

    static let tornAchilles = CardDescriptor(
        id: "torn-achilles", name: "Torn Achilles", type: .gameBreak,
        effect: "Every turn: all but 1 random card is held", numberInDeck: 1,
        gameBreak: GameBreakEffect(isInjury: true, injury: .game, playableEachTurn: 1))

    static let tradedMidGame = CardDescriptor(
        id: "traded-mid-game", name: "Traded Mid-Game", type: .gameBreak,
        effect: "Trade hands with another player, at random", numberInDeck: 1,
        gameBreak: GameBreakEffect(swapsHandsAtRandom: true))

    static let rockFight = CardDescriptor(
        id: "rock-fight", name: "Rock Fight", type: .gameBreak,
        effect: "Nobody shoots above 50%. Rest of the round", numberInDeck: 3,
        // Fifty is allowed; the block starts one over it — see `blocksShotAtOrAbove`,
        // which is a floor rather than a limit.
        gameBreak: GameBreakEffect(blocksShotAtOrAbove: 51))

    static let offTheBackboard = CardDescriptor(
        id: "off-the-backboard", name: "Off the Backboard", type: .gameBreak,
        effect: "Your next miss rebounds itself", numberInDeck: 3,
        gameBreak: GameBreakEffect(reboundsNextMiss: true))

    static let floorCleanup = CardDescriptor(
        id: "floor-cleanup", name: "Floor Cleanup", type: .gameBreak,
        effect: "Every hand is shuffled back in. Everyone #[Draws] what they had",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(everyoneRedraws: true))

    static let officialTimeout = CardDescriptor(
        id: "official-timeout", name: "Official Timeout", type: .gameBreak,
        effect: "With a referee out: every #[Injury] comes off and the crew leaves. Otherwise all #[Draw] 1",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(healsAllInjuries: true, requiresReferee: true,
                                   clearsReferees: true, everyoneDrawsInstead: 1))

    static let teamDoctor = CardDescriptor(
        id: "team-doctor", name: "Team Doctor", type: .gameBreak,
        effect: "An #[Injury] off target player. #[Draw] 2 if it was not you", numberInDeck: 3,
        gameBreak: GameBreakEffect(healsChosenInjury: true, drawsForHealingAnother: 2))

    static let tradeDeadline = CardDescriptor(
        id: "trade-deadline", name: "Trade Deadline", type: .gameBreak,
        effect: "Left or right: every bag moves one seat, and the ball with it",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(rotatesHands: true))

    static let freshBall = CardDescriptor(
        id: "fresh-ball", name: "Fresh Ball", type: .gameBreak,
        effect: "The next possession opens without its #[Draw]", numberInDeck: 3,
        gameBreak: GameBreakEffect(skipsNextDraw: true))

    static let wetSpot = CardDescriptor(
        id: "wet-spot", name: "Wet Spot", type: .gameBreak,
        effect: "Every #[Injury] in the pile and the deck. Take one", numberInDeck: 3,
        gameBreak: GameBreakEffect(offersInjuries: true))

    static let iceWrap = CardDescriptor(
        id: "ice-wrap", name: "Ice Wrap", type: .gameBreak,
        effect: "#[Draw] 1. #[Clear] all #[Injuries] — or #[Draw] 1 more if there were none",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(draws: 1, healsInjuries: true, drawIfUninjured: 1))

    static let hitTheBike = CardDescriptor(
        id: "hit-the-bike", name: "Hit the Bike", type: .gameBreak,
        effect: "#[Clear] all #[Injuries]. #[Draw] 1. Hand the ball to another player",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(draws: 1, healsInjuries: true, givesBallAway: true))

    static let allStarSelection = CardDescriptor(
        id: "all-star-selection", name: "All Star Selection", type: .gameBreak,
        effect: "#[Draw|2]", numberInDeck: 3,
        gameBreak: GameBreakEffect(draws: 2))

    static let allSwisshSelection = CardDescriptor(
        id: "all-swissh-selection", name: "All-Swissh Selection", type: .gameBreak,
        effect: "#[Draw] 3 after your next make", numberInDeck: 3,
        gameBreak: GameBreakEffect(drawsOnNextMake: 3))

    // ── Intangibles ───────────────────────────────────────────────────

    static let shotCreator = CardDescriptor(
        id: "shot-creator", name: "Shot Creator", type: .intangible,
        effect: "On #[Draw]: #[Draw] +1", numberInDeck: 1,
        intangible: IntangibleEffect(bonusDraw: 1))

    /// He plays at nought. The violation is held rather than forgiven — see
    /// `Rules.clockCatchesUp(_:)`, which calls it the moment this leaves him.
    static let movesAtOwnPace = CardDescriptor(
        id: "moves-at-own-pace", name: "Moves At Own Pace", type: .intangible,
        effect: "Cannot be called for Traveling or #[Shot Clock] violations",
        numberInDeck: 1,
        intangible: IntangibleEffect(ignoresViolations: true))

    static let hotHand = CardDescriptor(
        id: "hot-hand", name: "Hot Hand", type: .intangible,
        effect: "SHOT +20% if you scored last round", numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: 20, requiresScoredLastRound: true))

    static let freethrowMerchant = CardDescriptor(
        id: "freethrow-merchant", name: "Freethrow Merchant", type: .intangible,
        effect: "Any #[Clamp] on you becomes \"Take 1 FT\"", numberInDeck: 1,
        intangible: IntangibleEffect(freeThrowPerClamp: 1))

    static let generationalWhistle = CardDescriptor(
        id: "generational-whistle", name: "Generational Whistle", type: .intangible,
        effect: "Take 1 additional #[FT]", numberInDeck: 1,
        intangible: IntangibleEffect(bonusFreeThrows: 1))

    static let intangibles: [CardDescriptor] = [
        shotCreator, hotHand, movesAtOwnPace, freethrowMerchant, generationalWhistle, unselfish,
        boardCrasher, roswellReach, catchAndShoot, clutchGene, floorGeneral, foxLikeFirstStep,
        gravity, greatConditioning, likeThat, noBag, pointGod, shootingSlump,
        sixthMan, sniper, splashCousin, competitive, lethalShooter, ballPounder,
        fundamentalist, villainousReputation, dirtyPlayer, franchisePlayer,
    ]

    // ── Game Breaks ───────────────────────────────────────────────────

    static let crowdNoise = CardDescriptor(
        id: "crowd-noise", name: "Crowd Noise", type: .gameBreak,
        effect: "#[Discard|1]", numberInDeck: 3,
        gameBreak: GameBreakEffect(discard: 1))

    static let twoMinuteWarning = CardDescriptor(
        id: "two-minute-warning", name: "2-Minute Warning", type: .gameBreak,
        effect: "All, down to 2 #[Discard|?]", numberInDeck: 3,
        gameBreak: GameBreakEffect(everyoneDiscardsTo: 2))

    static let designedPlay = CardDescriptor(
        id: "designed-play", name: "Designed Play", type: .gameBreak,
        effect: "Up to 5 #[Draw|?]", numberInDeck: 3,
        gameBreak: GameBreakEffect(drawUpTo: 5))

    static let mvpVote = CardDescriptor(
        id: "mvp-vote", name: "MVP Vote", type: .gameBreak,
        effect: "Up to 7 #[Draw|?]", numberInDeck: 1,
        gameBreak: GameBreakEffect(drawUpTo: 7))

    static let offNight = CardDescriptor(
        id: "off-night", name: "Off Night", type: .gameBreak,
        effect: "SHOT -20% this possession", numberInDeck: 3,
        gameBreak: GameBreakEffect(shotThisPossession: -20))

    static let benched = CardDescriptor(
        id: "benched", name: "Benched", type: .gameBreak,
        effect: "Give up the ball. You choose who to", numberInDeck: 3,
        gameBreak: GameBreakEffect(givesBallAway: true))

    static let salaryCapIncrease = CardDescriptor(
        id: "salary-cap-increase", name: "Salary Cap Increase", type: .gameBreak,
        effect: "All Players #[Draw|2]", numberInDeck: 3,
        gameBreak: GameBreakEffect(everyoneDraws: 2))

    static let swallowedWhistle = CardDescriptor(
        id: "swallowed-whistle", name: "Swallowed Whistle", type: .gameBreak,
        effect: "#[Whistles] cannot be called for the rest of the round",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(silencesWhistles: true))

    static let foul = CardDescriptor(
        id: "foul", name: "Foul", type: .gameBreak,
        effect: "Take 1 #[FT]", numberInDeck: 3,
        gameBreak: GameBreakEffect(freeThrows: 1))

    // ── Special Moves ─────────────────────────────────────────────────
    // These take the shot themselves, which ends the possession.

    static let fadeaway = CardDescriptor(
        id: "fadeaway", name: "Fadeaway", type: .specialMove,
        effect: "SHOT -10%. #[Draw] 1. Shoot the ball", numberInDeck: 10,
        shotDelta: -10, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true))

    static let fromTheHash = CardDescriptor(
        id: "from-the-hash", name: "From the Hash", type: .specialMove,
        effect: "SHOT -20%. Shoot the ball. +1 PT on make", numberInDeck: 3,
        shotDelta: -20,
        special: SpecialMoveEffect(shootsImmediately: true, bonusPointOnMake: 1))

    static let fromTheLogo = CardDescriptor(
        id: "from-the-logo", name: "From the Logo", type: .specialMove,
        effect: "SHOT -30%. Shoot the ball. +1 PT on make", numberInDeck: 3,
        shotDelta: -30,
        special: SpecialMoveEffect(shootsImmediately: true, bonusPointOnMake: 1))

    static let fullCourtHeave = CardDescriptor(
        id: "full-court-heave", name: "Full-Court Heave", type: .specialMove,
        effect: "SHOT = 10%. Shoot the ball. +1 PT on make", numberInDeck: 3,
        special: SpecialMoveEffect(shootsImmediately: true, bonusPointOnMake: 1, shotOverride: 10))

    static let buzzerBeater = CardDescriptor(
        id: "buzzer-beater", name: "Buzzer Beater", type: .specialMove,
        effect: "SHOT = 100%. Shoot the ball. Only at #[Shot Clock] 1", numberInDeck: 4,
        special: SpecialMoveEffect(shootsImmediately: true, shotOverride: 100, onlyAtShotClock: 1))

    static let putbackTip = CardDescriptor(
        id: "putback-tip", name: "Putback Tip", type: .specialMove,
        effect: "SHOT +10%. Shoot the ball. After a rebound: SHOT = 100%", numberInDeck: 3,
        shotDelta: 10,
        special: SpecialMoveEffect(shootsImmediately: true, shotOverrideAfterRebound: 100))

    static let bankshot = CardDescriptor(
        id: "bankshot", name: "Bankshot", type: .specialMove,
        effect: "Flip a coin. Heads SHOT +10%, tails SHOT -10%. Shoot the ball",
        numberInDeck: 4,
        special: SpecialMoveEffect(shootsImmediately: true, coinFlipShot: 10))

    static let daggerThree = CardDescriptor(
        id: "dagger-three", name: "Dagger Three", type: .specialMove,
        effect: "SHOT -60%. +10% per tick spent. Shoot the ball. +1 PT on make",
        numberInDeck: 4,
        shotDelta: -60,
        special: SpecialMoveEffect(shootsImmediately: true, bonusPointOnMake: 1,
                                   shotPerClockSpent: 10))

    static let skyhook = CardDescriptor(
        id: "skyhook", name: "Skyhook", type: .specialMove,
        effect: "SHOT +10%. Shoot the ball over every #[Clamp]", numberInDeck: 4,
        shotDelta: 10,
        special: SpecialMoveEffect(shootsImmediately: true, ignoresClamps: true))

    static let twoHandJam = CardDescriptor(
        id: "two-hand-jam", name: "2-Hand Jam", type: .specialMove,
        effect: "SHOT +10%. Shoot the ball. Another +10% straight off your own board",
        numberInDeck: 10,
        shotDelta: 10,
        special: SpecialMoveEffect(shootsImmediately: true, dunkKind: .reverse,
                                   bonusOffOwnRebound: 10, dunks: true))

    static let giveAndGoDunk = CardDescriptor(
        id: "give-and-go-dunk", name: "Give-and-Go Dunk", type: .specialMove,
        effect: "Clean look only — no #[Clamps] on you and nothing has gone off this "
              + "possession. SHOT +30%. Shoot the ball",
        numberInDeck: 5,
        shotDelta: 30,
        special: SpecialMoveEffect(shootsImmediately: true, needsCleanLook: true,
                                   dunks: true))

    static let tomahawk = CardDescriptor(
        id: "tomahawk", name: "Tomahawk", type: .specialMove,
        effect: "SHOT +15% at 50% or better, −15% under it. Shoot the ball",
        numberInDeck: 5,
        special: SpecialMoveEffect(shootsImmediately: true,
                                   dunkKind: .oneHand,
                                   shotSwing: ShotSwing(at: 50, under: -15, over: 15),
                                   dunks: true))

    static let slamDunk = CardDescriptor(
        id: "slam-dunk", name: "Slam Dunk", type: .specialMove,
        effect: "SHOT +10%. SHOT = 100% if it reaches 70%. Shoot the ball", numberInDeck: 4,
        shotDelta: 10,
        special: SpecialMoveEffect(shootsImmediately: true, shotOverride: 100,
                                   overrideRequiresAtLeast: 70, dunks: true))

    static let euroStep = CardDescriptor(
        id: "euro-step", name: "Euro Step", type: .specialMove,
        effect: "Flip until Tails. Each Heads: SHOT +5% and #[Draw] 1",
        numberInDeck: 5,
        special: SpecialMoveEffect(coinRunShot: 5, coinRunDraw: 1))

    static let wideOpenThree = CardDescriptor(
        id: "wide-open-three", name: "Wide-Open Three", type: .specialMove,
        effect: "Name any others. SHOT +10% each. On a make they each take #[AST] +1",
        numberInDeck: 2,
        special: SpecialMoveEffect(shootsImmediately: true, bonusPointOnMake: 1,
                                   shotPerNamed: 10))

    static let turnaroundThree = CardDescriptor(
        id: "turnaround-three", name: "Turnaround Three", type: .specialMove,
        effect: "#[Discard] any number. SHOT +10% for each. Shoot the ball. +1 PT on make",
        numberInDeck: 1,
        special: SpecialMoveEffect(shootsImmediately: true, bonusPointOnMake: 1,
                                   discardForShotBonus: 10))

    static let specialMoves: [CardDescriptor] = [
        fadeaway, fromTheHash, fromTheLogo, fullCourtHeave, buzzerBeater, putbackTip,
        euroStep, turnaroundThree, bankshot, daggerThree, skyhook, slamDunk,
        twoHandJam, giveAndGoDunk, tomahawk,
        wideOpenThree,
    ]

    static let altercation = CardDescriptor(
        id: "altercation", name: "Altercation", type: .gameBreak,
        effect: "Select another player: you and they each #[Discard] 1 at random. Inbound to anybody else",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(fightsChosenPlayer: true))

    static let hugeAltercation = CardDescriptor(
        id: "huge-altercation", name: "Huge Altercation", type: .gameBreak,
        effect: "All players #[Discard] their hands. With a referee out, all take 1 #[TOV]. Inbound the ball",
        numberInDeck: 1,
        gameBreak: GameBreakEffect(everyoneDiscardsHands: true, turnoversIfReferee: 1,
                                   givesBallAway: true))

    static let homeCourtAdvantage = CardDescriptor(
        id: "home-court-advantage", name: "Home Court Advantage", type: .gameBreak,
        effect: "SHOT + 10%", numberInDeck: 3,
        gameBreak: GameBreakEffect(shotThisPossession: 10))

    static let awayGame = CardDescriptor(
        id: "away-game", name: "Away Game", type: .gameBreak,
        effect: "SHOT - 10%", numberInDeck: 3,
        gameBreak: GameBreakEffect(shotThisPossession: -10))

    static let micdUp = CardDescriptor(
        id: "micd-up", name: "Mic'd Up", type: .gameBreak,
        effect: "SHOT + 10% until passed or shot",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(shotForHolder: 10))

    static let inTheZone = CardDescriptor(
        id: "in-the-zone", name: "In The Zone", type: .gameBreak,
        effect: "#[Draw] 1 card for each 10% SHOT on the ball, rounded down. Minimum 1",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(drawsPerTenPercentShot: true))

    static let rolePlayer = CardDescriptor(
        id: "role-player", name: "Role Player", type: .gameBreak,
        effect: "All Others #[Draw|1]", numberInDeck: 3,
        gameBreak: GameBreakEffect(othersDraw: 1))

    static let backAndForthGame = CardDescriptor(
        id: "back-and-forth-game", name: "Back-and-Forth Game", type: .gameBreak,
        effect: "#[Discard] the next 3 #[Game Breaks]. Whoever #[Draws] one #[Draws] again",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(waivesBreaks: 3))

    static let gameBreaks: [CardDescriptor] = [
        crowdNoise, twoMinuteWarning, designedPlay, mvpVote, offNight, benched,
        swallowedWhistle, foul, salaryCapIncrease,
        iceWrap, hitTheBike, allStarSelection, allSwisshSelection, rockFight,
        tradedMidGame,
        tradeDeadline, freshBall, wetSpot, floorCleanup, officialTimeout, teamDoctor,
        offTheBackboard,
        altercation, hugeAltercation, homeCourtAdvantage, awayGame, micdUp, inTheZone,
        rolePlayer, backAndForthGame,
    ] + injuries

    /// Their own list, because they are their own column on the sheet and their own rules
    /// — see `Injury`.
    static let injuries: [CardDescriptor] = [boneBruise, tornAchilles]

    static let whistles: [CardDescriptor] = [
        shotClockViolation, travel, doubleDribble, backCourtViolation, inadvertentWhistle,
        discontinuedDribble,
        coachsChallenge, officialReview, goaltending, timeout, delayOfGameWarning,
        blockingFoul, flagrantFoul, flagrantFoulII, charge, technicalFoul, clearPathFoul,
        clearedToPlay, playOn, crewChiefReview,
    ]

    /// A card somebody else is holding, or one still in the deck.
    ///
    /// Never built into a deck — `numberInDeck: 0` keeps it out of `all` and out of any
    /// pool. It exists so a redacted hand is still a hand of cards with the right count in
    /// it, rather than an empty one with a number beside it.
    static let faceDown = CardDescriptor(
        id: "face-down", name: "", type: .gameBreak,
        effect: "", numberInDeck: 0)

    /// Every descriptor there is, by its id — **including `faceDown`**, which is not in
    /// `all` because it is not a card anybody plays.
    ///
    /// The wire needs this. A `Card` used to cross as its whole descriptor: its name, its
    /// type, its effect structs, every time. Both devices already hold this library, so
    /// what has to travel is *which* card it is, not what that card does.
    /// The passes and the moves — **not every card**, whatever the old name said.
    static let passesAndMoves: [CardDescriptor] = [
        swingLeft, swingRight, skipPass, behindTheBack,
        dime, lob, nutmeg, noLook, bulletPass, handOff, outletPass, kickOut,
        alleyOop, rightBack, touchPass,
        dribble, drive, rhythmDribble, poundDribble, spinMove, crossover,
        ankleBreaker, hesi, pumpFake, stepback, tripleThreat, clearOut,
    ]

    /// Classic mode's pool: Pass and Move cards only.
    static let classicPool: [CardDescriptor] = passesAndMoves

    /// Standard adds everything else, as each type gets built.
    static let standardPool: [CardDescriptor] = passesAndMoves
        + [contest, fullCourtPress, doubleTeam, tripleTeam, trap, flop]
        + whistles + intangibles + gameBreaks + specialMoves

    /// **Every card in the game.**
    ///
    /// This name used to belong to the twenty-eight passes and moves that make up
    /// Classic, and six places read it meaning *all of them*: the gallery showed two of
    /// the seven types and no others existed as far as it knew, a collection could never
    /// record a Whistle you had met, and `Rules` looked cards up by id in it — so a
    /// Special Move, a Clamp or an Intangible simply came back nil. A name that says
    /// `all` has to mean all.
    /// The two injuries are already in `gameBreaks` — `injuries` is a *view* of them for
    /// the rules, not a separate set — so this is `standardPool` alone.
    static let all: [CardDescriptor] = standardPool

    /// **Every descriptor there is, by its id.** The wire needs this: a card crosses as
    /// which library entry it is rather than as a copy of one, and the other device looks
    /// it up here — see `Card.encode(to:)`.
    ///
    /// Off `standardPool`, not `all`. `all` is the Classic pool — passes and moves, 28 of
    /// the 128 cards in the game — and building this from it left every Whistle,
    /// Intangible, Game Break, Injury, Clamp and Special Move unable to decode. The
    /// injuries are in neither pool, since nobody is dealt one.
    static let byID: [String: CardDescriptor] = {
        var found: [String: CardDescriptor] = [:]
        for card in all + [faceDown] { found[card.id] = card }
        return found
    }()

    /// Names that turn up inside other cards' text, for highlighting them there. Only
    /// multi-letter names, so a stray word is never mistaken for a reference.
    /// Actual card names only. Type words — Whistle, Clamp, Move, Pass, Intangible —
    /// are categories, not cards, and colouring them read as a reference to something
    /// that does not exist.
    static let namesReferencedInText: [String] = [
        "Rhythm Dribble", "Timeout", "Dribble", "Drive",
    ]

    static func buildDeck(pool: [CardDescriptor], passShotBonus: Int) -> [Card] {
        pool.flatMap { descriptor in
            let resolved = descriptor.resolved(passShotBonus: passShotBonus)
            return (0..<resolved.numberInDeck).map { _ in Card(resolved) }
        }
    }
}
