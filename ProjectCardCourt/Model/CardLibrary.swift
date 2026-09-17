import Foundation

/// The cards in play. Counts come from the Number in Deck column of
/// Project CardCourt_CardDB.xlsx, and the percentages match its effect text:
/// passes move SHOT less than Move cards do.
enum CardLibrary {

    /// **The spine, and the rule it carries.**
    ///
    /// The two swings are the same number as each other, and **the pass across is half of
    /// one of them** — Hex Hex holds the same ratio between its Turn Asides and its
    /// Deflect Across, and it is what keeps a four-handed table from playing as if the man
    /// opposite were as near as the men beside you.
    ///
    /// **Move one and move the other.** Taking slots back for new cards comes out of the
    /// swings, which is almost certainly how Smirk & Dagger arrived at a number as odd as
    /// twenty-six — and every time the swings move, Skip Pass follows them down to half.
    /// `Tools/tests.swift` holds that ratio so it cannot drift.
    ///
    /// **An odd swing cannot be halved.** At twenty-one the across is ten or eleven and
    /// neither is exactly half, so the test allows the rounding rather than forbidding an
    /// odd count. Ten is the one that is written here: it is the half that rounds down,
    /// and it is what keeps the deck at three hundred.
    static let swingLeft = CardDescriptor(
        id: "swing-left", name: "Swing Left", type: .pass,
        effect: "~[Pass] Left.", numberInDeck: 20, passTarget: .left)

    static let swingRight = CardDescriptor(
        id: "swing-right", name: "Swing Right", type: .pass,
        effect: "~[Pass] Right.", numberInDeck: 20, passTarget: .right)

    static let skipPass = CardDescriptor(
        id: "skip-pass", name: "Skip", type: .pass,
        effect: "~[Pass] Across.", numberInDeck: 10, passTarget: .across)

    static let behindTheBack = CardDescriptor(
        id: "behind-the-back", name: "Behind-the-Back", type: .pass,
        effect: "~[Pass] back to last player. Gains what the pass to you gained",
        numberInDeck: 5, passTarget: .backToPasser, retiresLastCaller: true,
        matchesArrivingPass: true,
        bonus: "#[Retire] the last ~[Ref] who made a call")

    static let dime = CardDescriptor(
        id: "dime", name: "Dime", type: .pass,
        effect: "SHOT +10%. ~[Pass] to target player.", numberInDeck: 5,
        passTarget: .choice, passesToOthersOnly: true,
        shotDelta: 10, bonusAssistOnScore: true,
        bonus: "Extra #[AST] + 1 if new player scores")

    static let lob = CardDescriptor(
        id: "lob", name: "Lob", type: .pass,
        effect: "SHOT +10%. ~[Pass] to target player. They must shoot.",
        numberInDeck: 5,
        passTarget: .choice, shotDelta: 10, forcesReceiverShot: true, mayTakeBall: true,
        bonus: "You may add current Ball to hand while passing.")

    static let nutmeg = CardDescriptor(
        id: "nutmeg", name: "Nutmeg", type: .pass,
        effect: "SHOT +10%. ~[Pass] Left or Right. #[Knock] 1 card to next player.",
        numberInDeck: 5,
        passTarget: .leftOrRight, shotDelta: 10, stealsAlongPass: 1)

    static let noLook = CardDescriptor(
        id: "no-look", name: "No-Look", type: .pass,
        effect: "SHOT +10%. ~[Pass] to random other player.", numberInDeck: 5,
        passTarget: .random, shotDelta: 10, mayFlipForDraw: true,
        bonus: "You may flip a coin while passing.\n• Heads: #[Draw] 2 cards\n"
            + "• Tails: #[Draw] 1 card")

    static let touchPass = CardDescriptor(
        id: "touch-pass", name: "Touch", type: .pass,
        effect: "SHOT +10%. Continue the ball in the direction of travel.\n"
            + "(Cannot be played when the ball arrived Across)",
        numberInDeck: 5,
        passTarget: .continuing, shotDelta: 10, drawIfFirstAction: 2,
        bonus: "If played as your first action: #[Draw] 2 cards")

    static let rightBack = CardDescriptor(
        id: "right-back", name: "Right Back", type: .pass,
        effect: "SHOT +10%. ~[Pass] to target player. They must immediately pass it back. "
            + "(They do not play a ~[Pass] card)",
        numberInDeck: 3,
        passTarget: .choice, passesToOthersOnly: true,
        shotDelta: 10, returnsImmediately: true)

    static let handOff = CardDescriptor(
        id: "hand-off", name: "Hand-Off", type: .pass,
        effect: "SHOT +10%. ~[Pass] left or right. #[Draw] 1 card while passing.",
        numberInDeck: 5,
        passTarget: .leftOrRight, shotDelta: 10, drawCount: 1,
        comboAfterDribble: true, comboBonus: 10, comboDraw: 1,
        combo: "SHOT +10% and #[Draw] 1 extra card")

    static let outletPass = CardDescriptor(
        id: "outlet-pass", name: "Outlet", type: .pass,
        effect: "SHOT +10%. ~[Pass] to target player. #[Shot Clock] +01.",
        numberInDeck: 5,
        passTarget: .choice, shotDelta: 10, clockDelta: 1, replacesClockTick: true,
        clearsTargetClamp: true,
        bonus: "You may #[Clear] target ~[Clamp]")

    static let kickOut = CardDescriptor(
        id: "kick-out", name: "Kick-Out", type: .pass,
        effect: "SHOT +10%. ~[Pass] to target player. They must immediately shoot a #[Three]. "
            + "#[Draw] 2 cards while passing.",
        numberInDeck: 5,
        passTarget: .choice, shotDelta: 10, drawCount: 2, upgradesToThree: true,
        forcesImmediateShot: true, movesClampsToReceiver: true,
        bonus: "You may #[Assign] all your ~[Clamps] to new player while passing.")

    static let bulletPass = CardDescriptor(
        id: "bullet-pass", name: "Bullet", type: .pass,
        effect: "SHOT +10%. ~[Pass] to target player. #[Retire] 1 card from their hand while passing",
        numberInDeck: 5,
        passTarget: .choice, shotDelta: 10, receiverDiscards: 1)

    static let dribble = CardDescriptor(
        id: "dribble", name: "Dribble", type: .move,
        effect: "#[Draw] 2 cards. SHOT -10%", numberInDeck: 10,
        shotDelta: -10, drawCount: 2, isDribble: true)

    static let drive = CardDescriptor(
        id: "drive", name: "Drive", type: .move,
        effect: "#[Draw] 1 card. SHOT +10%", numberInDeck: 10,
        shotDelta: 10, drawCount: 1, comboAfterDribble: true, comboBonus: 10,
        combo: "SHOT +10% extra")

    static let poundDribble = CardDescriptor(
        id: "pound-dribble", name: "Pound Dribble", type: .move,
        effect: "SHOT +10%. #[Draw] 3 cards then #[Retire] 1", numberInDeck: 5,
        shotDelta: 10, drawCount: 3, isDribble: true, selfDiscard: 1)

    static let spinMove = CardDescriptor(
        id: "spin-move", name: "Spin Move", type: .move,
        effect: "#[Draw] 1 card. SHOT +10%", numberInDeck: 5,
        shotDelta: 10, drawCount: 1,
        retiresARef: true, reassignsAClamp: true,
        bonus: "You may #[Retire] target ~[Ref] or #[Reassign] target ~[Clamp] "
            + "(from anyone to anyone, inclusive)")

    /// **Finishes the Ankle Breaker combo** off a Dribble — see `Combo.name`.
    static let crossover = CardDescriptor(
        id: "crossover", name: "Crossover", type: .move,
        effect: "#[Draw] 1 card. SHOT +10%. #[Clear] target ~[Clamp]",
        numberInDeck: 5,
        shotDelta: 10, drawCount: 1, comboAfterDribble: true, comboBonus: 10,
        clearsTargetClamp: true,
        combo: "SHOT +10% extra. You may #[Retire] 1 card from target player's hand")

    static let rhythmDribble = CardDescriptor(
        id: "rhythm-dribble", name: "Rhythm Dribble", type: .move,
        effect: "After a ~[Dribble]: SHOT +10%. #[Draw] 2 cards.", numberInDeck: 5,
        shotDelta: 10, drawCount: 2, isDribble: true, requiresDribbleFirst: true,
        nextShotBonus: 10,
        bonus: "If your next action is a Shot Attempt, it has SHOT +10% extra.")

    /// **Retired as a card** (2026-09-14): it is the combo a Crossover finishes off a
    /// Dribble now. Out of every pool.
    static let ankleBreaker = CardDescriptor(
        id: "ankle-breaker", name: "Ankle Breaker", type: .move,
        effect: "#[Target] player #[Retires] 1. SHOT +20%", numberInDeck: 5,
        shotDelta: 20, targetDiscards: 1)

    static let hesi = CardDescriptor(
        id: "hesi", name: "Hesitation Dribble", type: .move,
        effect: "SHOT +10%. #[Draw] 2 cards. #[Shot Clock] -03.", numberInDeck: 5,
        shotDelta: 10, drawCount: 2, clockDelta: -3, isDribble: true)

    static let pumpFake = CardDescriptor(
        id: "pump-fake", name: "Pump Fake", type: .move,
        effect: "#[Draw] 1 card. SHOT +10%. #[Shot Clock] -01.\n"
            + "Target any number of ~[Clamps] on you: SHOT +15% and #[Shot Clock] -01 "
            + "extra for each",
        numberInDeck: 5,
        shotDelta: 10, drawCount: 1, clockDelta: -1,
        shotPerClampNamed: 15, clockPerClampNamed: -1)

    static let stepback = CardDescriptor(
        id: "stepback", name: "Stepback", type: .move,
        effect: "#[Draw] 1 card. SHOT +10%", numberInDeck: 5,
        shotDelta: 10, drawCount: 1, threeWithFewerCards: 2, optionalDiscardForShot: 10,
        bonus: "You may #[Retire] 1 card for SHOT +10% extra. You may attempt a #[Three] "
            + "with 2 fewer cards immediately after playing this card.")

    /// Closes Moves for the whole possession: none after it, and none before it either.
    static let tripleThreat = CardDescriptor(
        id: "triple-threat", name: "Triple Threat", type: .move,
        effect: "#[Draw] 1 card, then pick 1:\n"
            + "\u{2022} #[Draw] 3 extra cards\n"
            + "\u{2022} ~[Pass] (+0%)\n"
            + "\u{2022} SHOT +30%\n"
            + "(Cannot play other ~[Move] cards this possession.)",
        numberInDeck: 3,
        drawCount: 1,
        modes: [CardMode(label: "Draw 3", draws: 3),
                CardMode(label: "Pass (+0%)", shotDelta: 0, passes: .choice),
                CardMode(label: "SHOT +30%", shotDelta: 30)],
        blocksFurtherMoves: true)

    /// **The only multi-clear in the game.** Clamps are standing assignments now, so
    /// there is nothing in flight to dodge — you wave the floor clear and the ball goes
    /// on without you. Held until three men have piled on, it is a whole possession
    /// bought back.
    static let clearOut = CardDescriptor(
        id: "clear-out", name: "Clear Out", type: .move,
        effect: "First action only: #[Clear] all ~[Clamps] on you and step aside, "
            + "dodging the ball. #[Draw] 1 card.",
        numberInDeck: 5,
        drawCount: 1, drawPerClamp: 1, clearsClamps: true,
        clearsOut: true, firstActionOnly: true,
        bonus: "#[Draw] 1 card for each ~[Clamp] #[Cleared]")

    static let flop = CardDescriptor(
        id: "flop", name: "Flop", type: .move,
        effect: "#[Draw] 1 card. #[Clear] all ~[Clamps]. Take 1 #[FT] for each. "
            + "If no ~[Clamps], #[TOV] +1",
        numberInDeck: 3,
        drawCount: 1, freeThrowsPerClamp: 1, clearsClamps: true,
        compulsoryFirstAction: true,
        turnoverIfNoClamps: true)

    // ── Clamps ────────────────────────────────────────────────────────
    //
    // **A defender is an assignment, not a swipe.** Every standing Clamp prints two
    // things: the band it bites in, if it has one, and what it takes to beat it. Both are
    // read across the table — hand sizes are public, the Shot Clock is on the wall, SHOT
    // is on the HUD — so being squeezed is something a player can see coming and play out
    // of rather than something that simply happens to them.
    //
    // Beating one pays: see `ClampPayoff`. Giving up the ball always sends one off, which
    // is the floor under the whole system — nobody is ever stuck with a defender they
    // have no answer to.

    static let contest = CardDescriptor(
        id: "contest", name: "Contest", type: .clamp,
        effect: "Target player: SHOT -25%\n#[Clear]: SHOT 60% or more", numberInDeck: 8,
        clamp: ClampEffect(clearedBy: .shotAtLeast(60), shotDebuff: -25))

    static let manToMan = CardDescriptor(
        id: "man-to-man", name: "Man-To-Man", type: .clamp,
        effect: "Target player: SHOT -10% each time a card is played\n"
            + "#[Clear]: 3 ~[Move] cards this possession", numberInDeck: 4,
        clamp: ClampEffect(clearedBy: .movesAtLeast(3), shotPerCardPlayed: -10))

    static let closeOut = CardDescriptor(
        id: "close-out", name: "Close-Out", type: .clamp,
        effect: "Target player cannot attempt a @[Three]\n"
            + "#[Clear]: #[Shot Clock] 03 or less", numberInDeck: 4,
        clamp: ClampEffect(clearedBy: .clockAtMost(3), blocksThrees: true))

    static let zone = CardDescriptor(
        id: "zone", name: "Zone", type: .clamp,
        effect: "Target player cannot #[Shoot]. With no playable ~[Pass] cards, "
            + "#[TOV] +1 and the round ends\n#[Clear]: Give up the ball", numberInDeck: 1,
        clamp: ClampEffect(blocksShooting: true, turnoverWithoutAPass: true))

    static let doubleTeam = CardDescriptor(
        id: "double-team", name: "Double-Team", type: .clamp,
        effect: "Target player #[Lock|2]\n#[Clear]: 2 cards or fewer in hand",
        numberInDeck: 3,
        clamp: ClampEffect(clearedBy: .handAtMost(2), defenders: 2, locksRandomCards: 2))

    static let tripleTeam = CardDescriptor(
        id: "triple-team", name: "Triple-Team", type: .clamp,
        effect: "Target player #[Lock|3]\n#[Clear]: 1 card or fewer in hand",
        numberInDeck: 3,
        clamp: ClampEffect(clearedBy: .handAtMost(1), defenders: 3, locksRandomCards: 3))

    static let trap = CardDescriptor(
        id: "trap", name: "Trap", type: .clamp,
        effect: "Target player can only ~[Pass] or #[Shoot]\n#[Clear]: Give up the ball",
        numberInDeck: 3,
        clamp: ClampEffect(defenders: 3, passOnly: true))

    static let fullCourtPress = CardDescriptor(
        id: "full-court-press", name: "Full-Court Press", type: .clamp,
        effect: "Target player #[Retire|2]", numberInDeck: 2,
        clamp: ClampEffect(discardAtStart: 2))

    // ── The pace defenders ────────────────────────────────────────────
    //
    // Hand size is how fast a player is moving, and it is public. A big man punishes a
    // slow one and is beaten by speeding up; a pest punishes a hoarder and is beaten by
    // spending down. Neither hand size is right — which one is right depends on who is
    // standing in front of you, and it changes the moment he does.
    //
    // Outside his band a defender is simply not a problem: a seven-footer does not see
    // the five-two guard, and the shot goes straight over him. He stays out there, and
    // he becomes a problem again the moment the hand moves back.

    static let crushingCenter = CardDescriptor(
        id: "crushing-center", name: "Crushing Center", type: .clamp,
        effect: "Target player with 2 cards or fewer in hand: SHOT -30%\n"
            + "#[Clear]: 4 cards or more in hand", numberInDeck: 6,
        clamp: ClampEffect(clearedBy: .handAtLeast(4), appliesWhen: .handAtMost(2),
                           shotDebuff: -30))

    static let pressingPoint = CardDescriptor(
        id: "pressing-point", name: "Pressing Point", type: .clamp,
        effect: "Target player with 4 cards or more in hand: SHOT -30%\n"
            + "#[Clear]: 2 cards or fewer in hand", numberInDeck: 6,
        clamp: ClampEffect(clearedBy: .handAtMost(2), appliesWhen: .handAtLeast(4),
                           shotDebuff: -30))

    static let lurkingWing = CardDescriptor(
        id: "lurking-wing", name: "Lurking Wing", type: .clamp,
        effect: "Target player at #[Shot Clock] 05 or less: SHOT -25%\n"
            + "#[Clear]: #[Shot Clock] 06 or more", numberInDeck: 4,
        clamp: ClampEffect(clearedBy: .clockAtLeast(6), appliesWhen: .clockAtMost(5),
                           shotDebuff: -25))

    static let helpSideForward = CardDescriptor(
        id: "help-side-forward", name: "Help-Side Forward", type: .clamp,
        effect: "Target player: SHOT -15%\n#[Clear]: 2 ~[Move] cards this possession",
        numberInDeck: 4,
        clamp: ClampEffect(clearedBy: .movesAtLeast(2), shotDebuff: -15))

    // ── The forcers ───────────────────────────────────────────────────
    //
    // The other half of the matrix. A forcer takes away two of the three finishes, and
    // the crew working the game is watching one of them — so a defender and an official
    // between them can walk a player into a call everybody at the table can see coming.
    // That is the whole point of it being face-up: it is a checkmate rather than a trap.

    static let baselineDenial = CardDescriptor(
        id: "baseline-denial", name: "Baseline Denial", type: .clamp,
        effect: "Target player can only shoot a @[Layup]\n#[Clear]: 5 cards in hand",
        numberInDeck: 4,
        clamp: ClampEffect(clearedBy: .handAtLeast(5), forcesShotType: .layup))

    static let paintPacker = CardDescriptor(
        id: "paint-packer", name: "Paint Packer", type: .clamp,
        effect: "Target player can only shoot a @[Three]\n#[Clear]: 2 cards or fewer in hand",
        numberInDeck: 4,
        clamp: ClampEffect(clearedBy: .handAtMost(2), forcesShotType: .three))

    static let rimRunner = CardDescriptor(
        id: "rim-runner", name: "Rim Runner", type: .clamp,
        effect: "Target player can only shoot a @[Dunk]\n#[Clear]: SHOT 40% or less",
        numberInDeck: 4,
        clamp: ClampEffect(clearedBy: .shotAtMost(40), forcesShotType: .dunk))

    // ── Whistles ──────────────────────────────────────────────────────
    // A nil trigger resolves on play; everything else lies in wait. A turnover always
    // costs the ball and re-inbounds without advancing the round.

    static let shotClockViolation = CardDescriptor(
        id: "shot-clock-violation", name: "Shot Clock Violation", type: .whistle,
        effect: "#[Shot Clock] changes: #[TOV] +1. Side-out.", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .shotClockChanged, turnoverOnOffender: true,
                               cancelsCard: false, offenderInbounds: true))

    /// Called on the draw itself, which is the only Whistle that is — see
    /// `WhistleTrigger.cardDrawn`. It ends the possession where it stands and throws away
    /// whatever the draw still had queued.
    static let discontinuedDribble = CardDescriptor(
        id: "discontinued-dribble", name: "Discontinued Dribble", type: .whistle,
        effect: "Cancel a @[Dribble]. #[Retire] 1. #[TOV] +1",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .dribblePlayed, turnoverOnOffender: true,
                               offenderDiscards: 1))

    /// **Tighter officiating.** The speed limit is the match's — see
    /// `MatchRules.movesPerPossession` — and this referee does not bring it, he lowers it.
    static let travel = CardDescriptor(
        id: "travel", name: "Traffic Cop", type: .whistle,
        effect: "On ~[Move]: flip a coin.\nTails: #[TOV] +1",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .movePlayed, turnoverOnOffender: true,
                               coinFlip: true))

    /// **Out of the deck.** It answers a Game Break, and there are none — see `whistles`.
    static let playOn = CardDescriptor(
        id: "play-on", name: "Play-On", type: .whistle,
        effect: "On ~[Game Break]: #[Cancel] and #[Draw] again",
        numberInDeck: 0,
        whistle: WhistleEffect(trigger: .gameBreakDrawn))

    static let extravagantMechanics = CardDescriptor(
        id: "extravagant-mechanics", name: "Extravagant Mechanics", type: .whistle,
        effect: "On ~[Intangible], ~[Variaball] or ~[Special Move] play: #[Cancel] it",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .slotOrSpecialPlayed))

    static let crewChiefReview = CardDescriptor(
        id: "crew-chief-review", name: "Crew Chief Review", type: .whistle,
        effect: "Cancel a pass. The ball comes to you", numberInDeck: 1,
        whistle: WhistleEffect(takesBall: true, trigger: .passPlayed))

    static let doubleDribble = CardDescriptor(
        id: "double-dribble", name: "Double Dribble", type: .whistle,
        effect: "Same ~[Move] card twice running: #[Cancel] it. #[Retire] 1. #[TOV] +1",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .sameMoveTwice, turnoverOnOffender: true,
                               offenderDiscards: 1))

    static let backCourtViolation = CardDescriptor(
        id: "back-court-violation", name: "Back Court Violation", type: .whistle,
        effect: "On ~[Pass]: flip a coin.\nTails: #[TOV] +1",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .passPlayed, turnoverOnOffender: true,
                               coinFlip: true))

    static let inadvertentWhistle = CardDescriptor(
        id: "inadvertent-whistle", name: "Inadvertent Whistle", type: .whistle,
        effect: "Any other ~[Ref] fires: cancel it. Turn player #[Draws] 1",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .whistleFired, offenderDraws: 1))

    static let coachsChallenge = CardDescriptor(
        id: "coachs-challenge", name: "Coach's Challenge", type: .whistle,
        effect: "Cancel Next ~[Ref]. +1 @[Timeout]",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .whistlePlayed, recoversTimeout: true))

    static let officialReview = CardDescriptor(
        id: "official-review", name: "Official Review", type: .whistle,
        effect: "~[Intangible] slots: 1", numberInDeck: 1,
        whistle: WhistleEffect(intangibleSlots: 1))

    static let goaltending = CardDescriptor(
        id: "goaltending", name: "Goaltending", type: .whistle,
        effect: "Shooting over a ~[Clamp]: #[Cancel] it. Take the points. End round",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .shotAttempt, endsRound: true,
                               awardsShotValueToOffender: true,
                               requiresShotOverClamp: true))

    // These three let the Clamp resolve and negate what it does, so that "the clamped
    // player" has somebody to refer to — see WhistleEffect.voidsClampOnLanding.

    static let blockingFoul = CardDescriptor(
        id: "blocking-foul", name: "Blocking Foul", type: .whistle,
        effect: "Next ~[Clamp]: target player +1 #[FT]", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .clampPlayed, freeThrowsToClampVictim: 1,
                               cancelsCard: false))

    static let flagrantFoul = CardDescriptor(
        id: "flagrant-foul", name: "Flagrant Foul", type: .whistle,
        effect: "~[Clamp] that #[Retires] cards: no effect. Clamper #[Retires] 1. "
            + "Target player +1 #[FT] and keeps the ball",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .clampPlayed, offenderDiscards: 1,
                               voidsClampOnLanding: true, freeThrowsToClampVictim: 1,
                               victimKeepsBall: true, requiresClampRetires: true))

    static let flagrantFoulII = CardDescriptor(
        id: "flagrant-foul-ii", name: "Flagrant Foul II", type: .whistle,
        effect: "~[Clamp] on a clamped player: Clamper #[Retires] 2. Target player +1 #[FT]",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .clampPlayed, offenderDiscards: 2,
                               freeThrowsToClampVictim: 1, cancelsCard: false,
                               requiresClampOnClamped: true))

    static let charge = CardDescriptor(
        id: "charge", name: "Charge", type: .whistle,
        effect: "Next @[Dunk]: #[Cancel] it. #[TOV] +1", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .shotAttempt, turnoverOnOffender: true,
                               requiresShotType: .dunk))

    /// The three that was not one. It does not wave the shot off — it says where his foot
    /// was, and the ball still goes in for two.
    static let footOnTheLine = CardDescriptor(
        id: "foot-on-the-line", name: "Foot On The Line", type: .whistle,
        effect: "Next @[Three] scores 2 PTS instead", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .shotAttempt, cancelsCard: false,
                               requiresShotType: .three, downgradesThree: true))

    /// **Palming, not Offensive Foul.** A charge is an offensive foul, so the old name was
    /// the general case of the card standing beside it.
    static let offensiveFoul = CardDescriptor(
        id: "offensive-foul", name: "Palming", type: .whistle,
        effect: "Next @[Layup]: #[Cancel] it. #[TOV] +1", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .shotAttempt, turnoverOnOffender: true,
                               requiresShotType: .layup))

    static let technicalFoul = CardDescriptor(
        id: "technical-foul", name: "Technical Foul", type: .whistle,
        effect: "#[Target] another player: they take 1 #[FT]", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .targetedAnother,
                               freeThrowsToClampVictim: 1, cancelsCard: false))

    static let delayOfGameWarning = CardDescriptor(
        id: "delay-of-game-warning", name: "Delay-of-Game Warning", type: .whistle,
        effect: "No bonuses are paid",
        numberInDeck: 1,
        whistle: WhistleEffect(barsBonuses: true))

    static let timeout = CardDescriptor(
        id: "timeout", name: "Timeout", type: .whistle,
        effect: "Reset #[Shot Clock]. You inbound. All #[Draw] 1", numberInDeck: 1,
        whistle: WhistleEffect(ownerInbounds: true, resetsShotClock: true,
                               everyoneDraws: 1))

    static let clearedToPlay = CardDescriptor(
        id: "cleared-to-play", name: "Cleared to Play", type: .whistle,
        // **Parked**: its trigger is an Injury turning up in a draw and Injuries are
        // parked, so it made nought calls in 252 rounds worked. Back when the knocks are.
        effect: "An ~[Injury] turns up: it never lands", numberInDeck: 0,
        whistle: WhistleEffect(trigger: .injuryDrawn))

    static let clearPathFoul = CardDescriptor(
        id: "clear-path-foul", name: "Clear Path Foul", type: .whistle,
        effect: "~[Clamp] on a player with no cards, or at SHOT 0%: #[Cancel] it. "
            + "Target player +1 #[FT]",
        numberInDeck: 1,
        whistle: WhistleEffect(trigger: .clampPlayed, freeThrowsToClampVictim: 1,
                               requiresDefencelessVictim: true))

    static let roswellReach = CardDescriptor(
        id: "roswell-reach", name: "Roswell Reach", type: .intangible,
        effect: "Every #[Rebound] bid you make counts as one card extra", numberInDeck: 1,
        intangible: IntangibleEffect(reboundBidBonus: 1))

    static let boardCrasher = CardDescriptor(
        id: "board-crasher", name: "Board-Crasher", type: .intangible,
        effect: "SHOT +25% when shooting as your first action after a #[Rebound]",
        numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: 25, requiresFirstAction: true,
                                     requiresAfterAnyRebound: true))

    static let catchAndShoot = CardDescriptor(
        id: "catch-and-shoot", name: "Catch & Shoot Specialist", type: .intangible,
        effect: "SHOT +25% when shooting as your first action after a ~[Pass]",
        numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: 25, requiresReceivedPass: true,
                                     requiresFirstAction: true))

    static let clutchGene = CardDescriptor(
        id: "clutch-gene", name: "Clutch Gene", type: .intangible,
        effect: "SHOT = $[2X] if you have 1 card or fewer in hand, or the #[Shot Clock] is 03 or less",
        numberInDeck: 1,
        intangible: IntangibleEffect(shotMultiplier: 2,
                                     requiresHandAtMost: 1, requiresClockAtMost: 3))

    static let floorGeneral = CardDescriptor(
        id: "floor-general", name: "Floor General", type: .intangible,
        effect: "You name every target on the floor", numberInDeck: 1,
        intangible: IntangibleEffect(aimsEveryTarget: true))

    static let southpawShooter = CardDescriptor(
        id: "southpaw-shooter", name: "Southpaw Shooter", type: .intangible,
        effect: "SHOT gains and losses are reversed", numberInDeck: 1,
        intangible: IntangibleEffect(reversesShotChanges: true))

    static let gravity = CardDescriptor(
        id: "gravity", name: "Gravity", type: .intangible,
        effect: "All ~[Clamps] must target you. Gain +1 #[AST] when any other player scores",
        numberInDeck: 1,
        intangible: IntangibleEffect(attractsClamps: true, assistOnOthersScore: true))

    static let greatConditioning = CardDescriptor(
        id: "great-conditioning", name: "Great Conditioning", type: .intangible,
        // **Parked**: Injuries are out of the pool, so there is nothing for it to shrug.
        effect: "~[Injuries] never land. #[Draw] again for each", numberInDeck: 0,
        intangible: IntangibleEffect(shrugsOffInjuries: true))

    static let likeThat = CardDescriptor(
        id: "like-that", name: "Like That", type: .intangible,
        // **Parked**: it blanks every SHOT cost in the game, including its owner's own.
        effect: "Nothing takes your SHOT down", numberInDeck: 0,
        intangible: IntangibleEffect(shotCannotBeReduced: true))

    static let parkShark = CardDescriptor(
        id: "park-shark", name: "Park Shark", type: .intangible,
        effect: "SHOT +25%. Cannot play ~[Special Moves] or shoot #[Threes]", numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: 25, blocksSpecialMoves: true,
                                     blocksThrees: true))

    static let pointGod = CardDescriptor(
        id: "point-god", name: "Point God", type: .intangible,
        effect: "#[Draw] 1 card while passing", numberInDeck: 1,
        intangible: IntangibleEffect(drawAfterPass: 1))

    static let sixthMan = CardDescriptor(
        id: "sixth-man", name: "Sixth Man", type: .intangible,
        effect: "Your max Bag size is 6", numberInDeck: 1,
        intangible: IntangibleEffect(handLimit: 6))

    static let sniper = CardDescriptor(
        id: "sniper", name: "Sniper", type: .intangible,
        effect: "SHOT +25% when attempting a #[Three]", numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: 25, requiresThree: true))

    static let splashCousin = CardDescriptor(
        id: "splash-cousin", name: "Splash Cousin", type: .intangible,
        effect: "When attempting a #[Three], you may #[Retire] this card: "
            + "replace the current ~[Ball] with @[Splash Ball]", numberInDeck: 1,
        intangible: IntangibleEffect(swapsBallForSplash: true))

    static let competitive = CardDescriptor(
        id: "competitive", name: "Competitive", type: .intangible,
        effect: "Gain SHOT +25% when shooting over a ~[Clamp]", numberInDeck: 1,
        intangible: IntangibleEffect(shotOverClamp: 25))

    static let lethalShooter = CardDescriptor(
        id: "lethal-shooter", name: "Lethal Shooter", type: .intangible,
        effect: "SHOT = 100% when shooting as your first action after a #[Rebound] of your own miss",
        numberInDeck: 1,
        intangible: IntangibleEffect(requiresFirstAction: true, shotOverride: 100,
                                     requiresAfterOwnRebound: true))

    static let ballPounder = CardDescriptor(
        id: "ball-pounder", name: "Ball Pounder", type: .intangible,
        effect: "When playing a ~[Dribble], you may reduce the #[Shot Clock] by 03 to "
            + "#[Draw] 1 extra card and gain SHOT +10%",
        numberInDeck: 1,
        intangible: IntangibleEffect(dribbleClockTradeCost: 3, dribbleClockTradeDraw: 1,
                                     dribbleClockTradeShot: 10))

    static let franchisePlayer = CardDescriptor(
        id: "franchise-player", name: "Franchise Player", type: .intangible,
        effect: "While passing: You may #[Retire] an active ~[Ball], ~[Ref], or ~[Intangible]",
        numberInDeck: 1,
        intangible: IntangibleEffect(retiresInPlayOnPass: true))

    static let dirtyPlayer = CardDescriptor(
        id: "dirty-player", name: "Officially Infamous", type: .intangible,
        effect: "#[Retire] any ~[Ref] that calls a violation on you",
        numberInDeck: 1,
        intangible: IntangibleEffect(retiresCallerAgainstYou: true))

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
        effect: "Cannot play ~[Special Moves]. #[Retire] the active ~[Ball]. "
            + "#[Draw] 1 extra card when playing a ~[Move]",
        numberInDeck: 1,
        intangible: IntangibleEffect(blocksSpecialMoves: true,
                                     retiresBallOnActivation: true, extraDrawPerMove: 1))

    // ── Injuries ──────────────────────────────────────────────────────
    //
    // Their own column on the sheet and their own rules. An ordinary Injury lasts the
    // round and comes back in the halftime shuffle, so there can be several copies and
    // each is kept scarce. A Devastating one lasts the game, exists once, and never
    // returns to the deck.

    // Devastating Injuries (2026-09-15): the game, one of each. Landing one discards every
    // other Injury, and while one is on you a new Injury is discarded.

    static let tornAchilles = CardDescriptor(
        id: "torn-achilles", name: "Torn Achilles", type: .injury,
        effect: "Cannot Play Dunk Cards. Can only play 1 ~[Move] card per possession", numberInDeck: 1,
        injury: InjuryEffect(lasts: .game, blocksDunks: true, movesPerPossession: 1))

    static let tornACL = CardDescriptor(
        id: "torn-acl", name: "Torn ACL", type: .injury,
        effect: "Cannot Play ~[Move] Cards.", numberInDeck: 1,
        injury: InjuryEffect(lasts: .game, blocksMoves: true))

    static let tornMeniscus = CardDescriptor(
        id: "torn-meniscus", name: "Torn Meniscus", type: .injury,
        effect: "Randomly #[Lock] all but 1 Card Each Possession", numberInDeck: 1,
        injury: InjuryEffect(lasts: .game, playableEachTurn: 1))

    static let patellarTendonTear = CardDescriptor(
        id: "patellar-tendon-tear", name: "Patellar Tendon Tear", type: .injury,
        effect: "Cannot #[Draw] Cards except at the start of your possession", numberInDeck: 1,
        injury: InjuryEffect(lasts: .game, drawsOnlyAtPossessionStart: true))

    // Injuries: the round, two of each.

    static let boneBruise = CardDescriptor(
        id: "bone-bruise", name: "Bone Bruise", type: .injury,
        effect: "SHOT -10%", numberInDeck: 2,
        injury: InjuryEffect(lasts: .round, shotBonus: -10))

    static let rolledAnkle = CardDescriptor(
        id: "rolled-ankle", name: "Rolled Ankle", type: .injury,
        effect: "#[Retire] 1 card to play a ~[Move] card", numberInDeck: 2,
        injury: InjuryEffect(lasts: .round, moveDiscardCost: 1))

    static let fracturedCollarbone = CardDescriptor(
        id: "fractured-collarbone", name: "Fractured Collarbone", type: .injury,
        effect: "Cannot attempt #[Three]-point shots", numberInDeck: 2,
        injury: InjuryEffect(lasts: .round, blocksThrees: true))

    static let jammedFinger = CardDescriptor(
        id: "jammed-finger", name: "Jammed Finger", type: .injury,
        effect: "#[Retire] 1 card at random while receiving a ~[Pass]", numberInDeck: 2,
        injury: InjuryEffect(lasts: .round, discardsOnReceivingPass: 1))

    static let sprainedHamstring = CardDescriptor(
        id: "sprained-hamstring", name: "Sprained Hamstring", type: .injury,
        effect: "Your #[Rebound] Bids are worth 1 less", numberInDeck: 2,
        injury: InjuryEffect(lasts: .round, reboundBidPenalty: 1))

    static let hipContusion = CardDescriptor(
        id: "hip-contusion", name: "Hip Contusion", type: .injury,
        effect: "#[Retire] 1 card at random when playing a ~[Pass] card", numberInDeck: 2,
        injury: InjuryEffect(lasts: .round, discardsOnPlayingPass: 1))

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
        effect: "With a referee out: every ~[Injury] comes off and the crew leaves. Otherwise all #[Draw] 1",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(healsAllInjuries: true, requiresReferee: true,
                                   clearsReferees: true, everyoneDrawsInstead: 1))

    static let teamDoctor = CardDescriptor(
        id: "team-doctor", name: "Team Doctor", type: .gameBreak,
        effect: "An ~[Injury] off target player. #[Draw] 2 if it was not you", numberInDeck: 3,
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
        effect: "Every ~[Injury] in the pile and the deck. Take one", numberInDeck: 3,
        gameBreak: GameBreakEffect(offersInjuries: true))

    static let iceWrap = CardDescriptor(
        id: "ice-wrap", name: "Ice Wrap", type: .gameBreak,
        effect: "#[Draw] 1. #[Clear] all ~[Injuries] — or #[Draw] 1 more if there were none",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(draws: 1, healsInjuries: true, drawIfUninjured: 1))

    static let hitTheBike = CardDescriptor(
        id: "hit-the-bike", name: "Hit the Bike", type: .gameBreak,
        effect: "#[Clear] all ~[Injuries]. #[Draw] 1. Hand the ball to another player",
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
        effect: "#[Draw] 1 extra card when #[Drawing] a card(s). "
            + "(Does not apply to cards drawn with this effect)", numberInDeck: 1,
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
        effect: "Gain SHOT +25% if you scored with the active ~[Ball]", numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: 25, requiresScoredWithBall: true))

    static let freethrowMerchant = CardDescriptor(
        id: "freethrow-merchant", name: "Freethrow Merchant", type: .intangible,
        effect: "Take 1 #[FT] when #[Clamped]", numberInDeck: 1,
        intangible: IntangibleEffect(freeThrowWhenClamped: 1))

    static let generationalWhistle = CardDescriptor(
        id: "generational-whistle", name: "Generational Whistle", type: .intangible,
        effect: "After taking a #[FT], take 1 extra. "
            + "(Does not apply to #[FTs] taken due to this card)", numberInDeck: 1,
        intangible: IntangibleEffect(bonusFreeThrows: 1))

    /// **The one official anybody can spend.** He works the game like the rest of the
    /// crew, and any player may cash him in — the whole hand for a certain basket that
    /// drags every score up to theirs. There is exactly one in a game: he is exempt from
    /// the officials' reshuffle and from Retirement's, so once he has been used he is
    /// gone. The button under the triangle reads EQUALIZER.
    static let equalizer = CardDescriptor(
        id: "equalizer", name: "The Equalizer", type: .whistle,
        effect: "A player may #[Retire] this card and their hand: SHOT = 100%. "
            + "All players' PTS become your new total PTS.\n"
            + "(This card does not shuffle back into the deck once #[Retired] "
            + "and cannot be retrieved from Retirement)",
        numberInDeck: 1,
        whistle: WhistleEffect(equalizerShot: 100, levelsPointsOnMake: true,
                               neverReturns: true))

    static let varsitile = CardDescriptor(
        id: "varsitile", name: "Varsitile", type: .intangible,
        effect: "Play any number of ~[Variaballs] per possession. Once per possession, "
            + "you may exchange the ~[Ball] or an ~[Intangible] for one in Retirement",
        numberInDeck: 1,
        intangible: IntangibleEffect(playsSlotsFreely: true, exchangesWithRetirement: true))
    static let brawlHandler = CardDescriptor(
        id: "brawl-handler", name: "Brawl Handler", type: .intangible,
        effect: "You may #[Clear] target ~[Clamp] when you change the ~[Ball]", numberInDeck: 1,
        intangible: IntangibleEffect(clearsTargetClampOnBallChange: true))
    static let baller = CardDescriptor(
        id: "baller", name: "Baller", type: .intangible,
        effect: "#[Draw] 1 card each time the ~[Ball] is changed", numberInDeck: 1,
        intangible: IntangibleEffect(drawsOnBallChange: 1, drawsOnAnyBallChange: true))

    static let intangibles: [CardDescriptor] = [
        shotCreator, hotHand, movesAtOwnPace, freethrowMerchant, generationalWhistle,
        boardCrasher, roswellReach, catchAndShoot, clutchGene, floorGeneral, southpawShooter,
        gravity, greatConditioning, likeThat, parkShark, pointGod,
        sixthMan, sniper, splashCousin, competitive, lethalShooter, ballPounder,
        fundamentalist, dirtyPlayer, franchisePlayer, varsitile, brawlHandler, baller,
    ]

    // ── Varenas ───────────────────────────────────────────────────────

    /// **The basic floor.** On the table from the start, like Fluxx's basic rule card — and in
    /// the deck as well, where playing one takes the court back to basic.
    static let cardwood = CardDescriptor(
        id: "cardwood", name: "Cardwood", type: .varena,
        effect: "Changes the court back to basic", numberInDeck: 6,
        varena: VarenaEffect())

    static let primeParquet = CardDescriptor(
        id: "prime-parquet", name: "Prime Parquet", type: .varena,
        effect: "SHOT +20%", numberInDeck: 3,
        varena: VarenaEffect(shotBonus: 20))
    /// Prime Parquet's opposite, always: whatever one gives, the other takes.
    static let lacktop = CardDescriptor(
        id: "lacktop", name: "Lacktop", type: .varena,
        effect: "SHOT -20%", numberInDeck: 3,
        varena: VarenaEffect(shotBonus: -20))
    static let smacktop = CardDescriptor(
        id: "smacktop", name: "Smacktop", type: .varena,
        effect: "Clear All ~[Whistles]. ~[Whistles] Cannot Be Played. All ~[Clamps] are enhanced",
        numberInDeck: 3,
        varena: VarenaEffect(clearsWhistlesOnArrival: true, barsWhistles: true,
                             enhancesClamps: true))
    static let boarderCourt = CardDescriptor(
        id: "boarder-court", name: "Boarder Court", type: .varena,
        effect: "Off your own miss, your #[Rebound] bid counts as one card more", numberInDeck: 1,
        varena: VarenaEffect(shooterReboundBonus: 1))
    static let dimDome = CardDescriptor(
        id: "dim-dome", name: "Dim Dome", type: .varena,
        effect: "SHOT is hidden from everyone but the ball holder", numberInDeck: 1,
        varena: VarenaEffect(hidesShot: true))
    static let triHardTiling = CardDescriptor(
        id: "tri-hard-tiling", name: "Tri-hard Tiling", type: .varena,
        effect: "Hand limit 3", numberInDeck: 3,
        varena: VarenaEffect(handLimit: 3))
    /// **Out of the deck** (2026-09-15): its referees could lock a game into a loop.
    static let policeum = CardDescriptor(
        id: "policeum", name: "Policeum", type: .varena,
        effect: "Referees do not leave once triggered", numberInDeck: 3,
        varena: VarenaEffect(refereesStay: true))
    static let kiddieCourt = CardDescriptor(
        id: "kiddie-court", name: "Kiddie Court", type: .varena,
        effect: "SHOT +10%. Dunks +10%. Three-point shots cannot be attempted.", numberInDeck: 3,
        varena: VarenaEffect(shotBonus: 10, dunkBonus: 10, barsThrees: true, makesCount: 2))
    static let rechargingResin = CardDescriptor(
        id: "recharging-resin", name: "Recharging Resin", type: .varena,
        effect: "Everyone refills their hand at the start of their possession",
        numberInDeck: 3,
        varena: VarenaEffect(refillsToHand: true))
    static let contactCourt = CardDescriptor(
        id: "contact-court", name: "Contact Court", type: .varena,
        effect: "Being clamped: take 1 #[FT]. The ~[Clamp] still lands", numberInDeck: 3,
        varena: VarenaEffect(freeThrowsWhenClamped: 1))
    static let mvpiquia = CardDescriptor(
        id: "mvpiquia", name: "MVPiquia", type: .varena,
        effect: "The highest scorer refills their hand at the start of their possession",
        numberInDeck: 1,
        varena: VarenaEffect(leaderRefillsToHand: true))
    static let polypaypylene = CardDescriptor(
        id: "polypaypylene", name: "Polypaypylene", type: .varena,
        effect: "Making a shot: #[Draw] 3", numberInDeck: 1,
        varena: VarenaEffect(drawsOnMake: 3))
    static let recoverena = CardDescriptor(
        id: "recoverena", name: "Recoverena", type: .varena,
        effect: "Discard all ~[Injuries]. A new ~[Injury] is discarded, and that player #[Draws] 1",
        numberInDeck: 3,
        varena: VarenaEffect(healsInjuriesOnArrival: true, injuriesBecomeDraws: true))
    static let carouselCourt = CardDescriptor(
        id: "carousel-court", name: "Carousel Court", type: .varena,
        effect: "Declare left or right. Every possession, hands move one seat that way",
        numberInDeck: 1,
        varena: VarenaEffect(rotatesHands: true))
    static let traderousTarmac = CardDescriptor(
        id: "traderous-tarmac", name: "Traderous Tarmac", type: .varena,
        effect: "During your turn, hand off any number of the ~[Clamps] on you to other players",
        numberInDeck: 1,
        varena: VarenaEffect(clampsHandOff: true))
    static let clearcoatCourt = CardDescriptor(
        id: "clearcoat-court", name: "Clearcoat Court", type: .varena,
        effect: "Every possession: clear all referees, ~[Clamps], ~[Injuries] and ~[Intangibles]",
        numberInDeck: 3,
        varena: VarenaEffect(wipesEachPossession: true))
    static let malicePalace = CardDescriptor(
        id: "malice-palace", name: "Malice Palace", type: .varena,
        effect: "At the start of your possession, before your draw: #[Retire] your hand",
        numberInDeck: 1,
        varena: VarenaEffect(discardsHandBeforeDraw: true))
    static let turnstileTile = CardDescriptor(
        id: "turnstile-tile", name: "Turnstile Tile", type: .varena,
        effect: "Upright: SHOT +25%\nReversed: SHOT -25%\n#[Turn] this card at the start of each possession",
        numberInDeck: 3,
        varena: VarenaEffect(turnstileSwing: 25))
    static let roleplayerPolymer = CardDescriptor(
        id: "roleplayer-polymer", name: "Roleplayer Polymer", type: .varena,
        effect: "Every possession, everyone but the turn player #[Draws] 1", numberInDeck: 2,
        varena: VarenaEffect(othersDrawEachPossession: 1))
    static let variaballVinyl = CardDescriptor(
        id: "variaball-vinyl", name: "Variaball Vinyl", type: .varena,
        effect: "The draw for turn goes to a random player each possession", numberInDeck: 1,
        varena: VarenaEffect(turnDrawToRandomPlayer: true))
    static let graviGym = CardDescriptor(
        id: "gravi-gym", name: "Gravi-Gym", type: .varena,
        effect: "SHOT -10%. No dunks", numberInDeck: 3,
        varena: VarenaEffect(shotBonus: -10, barsDunks: true))
    static let vintageVarnish = CardDescriptor(
        id: "vintage-varnish", name: "Vintage Varnish", type: .varena,
        effect: "#[Shot Clock] 14. No threes. No Variaballs. 1 ~[Intangible] per player",
        numberInDeck: 3,
        varena: VarenaEffect(barsThrees: true, shotClockStart: 14, barsVariaballs: true,
                             intangibleSlots: 1))
    static let sellOutStadium = CardDescriptor(
        id: "sell-out-stadium", name: "S.O.S — Sell-Out Stadium", type: .varena,
        effect: "A #[Three] may be attempted as a two at $[2X] SHOT", numberInDeck: 3,
        varena: VarenaEffect(threesAsDoubleTwos: true))
    static let grayvstone = CardDescriptor(
        id: "grayvstone", name: "Grayvstone", type: .varena,
        effect: "Each possession, the ball becomes the last Variaball in the discards",
        numberInDeck: 1,
        varena: VarenaEffect(ballFromDiscard: true))
    static let conCrete = CardDescriptor(
        id: "con-crete", name: "Con-crete", type: .varena,
        effect: "~[Move] cards: SHOT -10%", numberInDeck: 3,
        varena: VarenaEffect(shotPerMovePlayed: -10))
    static let spazzphalt = CardDescriptor(
        id: "spazzphalt", name: "Spazzphalt", type: .varena,
        // Still a fresh roll, 0–100 in steps of 5. The card only says it is unknown.
        effect: "SHOT = ?", numberInDeck: 3,
        varena: VarenaEffect(randomShotOverride: true))
    static let frostbiteFinish = CardDescriptor(
        id: "frostbite-finish", name: "Frostbite Finish", type: .varena,
        effect: "Playing a ~[Move] costs #[Retire] 1 other card", numberInDeck: 2,
        varena: VarenaEffect(moveDiscardCost: 1))
    static let tickTockTile = CardDescriptor(
        id: "tick-tock-tile", name: "Tick-Tock Tile", type: .varena,
        effect: "Playing any card also ticks the #[Shot Clock]", numberInDeck: 3,
        varena: VarenaEffect(cardsTickClock: true))
    /// New in the SHOT audit (2026-09-14). Special Moves count as Moves on it.
    static let theFuture = CardDescriptor(
        id: "the-future", name: "The Future", type: .varena,
        effect: "SHOT +10% and #[Draw] 1 card when playing a ~[Move] card.\n"
            + "SHOT -10% while ~[Passing].",
        numberInDeck: 1,
        varena: VarenaEffect(shotPerMovePlayed: 10, drawsPerMovePlayed: 1, shotPerPass: -10,
                             offersFourPointThree: true),
        bonus: "You may #[Retire] 1 card during a #[Three] attempt to make it worth four pts "
            + "(at SHOT -10%)")

    // ── Variaballs ────────────────────────────────────────────────────

    static let medBall = CardDescriptor(
        id: "med-ball", name: "Med Ball", type: .variaball,
        effect: "SHOT cannot exceed 50%. ~[Move] cards never @[Travel]", numberInDeck: 1,
        variaball: VariaballEffect(shotCeiling: 50, ignoresTravel: true))
    static let dishcountBall = CardDescriptor(
        id: "dishcount-ball", name: "Dishcount Ball", type: .variaball,
        effect: "#[Retire] one fewer for card costs and ~[Clamps]", numberInDeck: 1,
        variaball: VariaballEffect(discountsDiscards: true))
    static let blightBall = CardDescriptor(
        id: "blight-ball", name: "Blight Ball", type: .variaball,
        effect: "~[Injuries] travel with the ball, and new ones join the pile. Discarding the ball takes the pile with it",
        numberInDeck: 1,
        variaball: VariaballEffect(injuriesTravel: true))
    static let benchBall = CardDescriptor(
        id: "bench-ball", name: "Bench Ball", type: .variaball,
        effect: "Receiving it by ~[Pass]: no draw, no turn. You inbound", numberInDeck: 1,
        variaball: VariaballEffect(benchesReceiver: true))
    /// **The ball that gets the officials looking at it** instead of at the floor. The
    /// word *target* is printed so a Floor General can name the one who goes.
    static let dishtractingBall = CardDescriptor(
        id: "dishtracting-ball", name: "Dishtracting Ball", type: .variaball,
        effect: "While passing, you may #[Retire] target ~[Ref] and place a new one",
        numberInDeck: 1,
        variaball: VariaballEffect(retiresARef: true))
    /// **The ball that will not tell you the truth about a miss.** Once more is literal:
    /// one extra attempt, and a missed retake is just a miss.
    static let liarBall = CardDescriptor(
        id: "liar-ball", name: "Liar Ball", type: .variaball,
        effect: "On #[FT] miss: take once more", numberInDeck: 1,
        variaball: VariaballEffect(retakesMissedFreeThrow: true))

    /// **The beaten grey one with the texture worn off** that somebody always brings to an
    /// outdoor run. No grip, so putting it up costs you — which is the toll Dishtracting
    /// Ball used to carry before it went off to distract the officials instead.
    static let baldBall = CardDescriptor(
        id: "bald-ball", name: "Bald Ball", type: .variaball,
        effect: "Shooting: #[Retire] 1 card", numberInDeck: 1,
        variaball: VariaballEffect(shooterDiscards: 1))

    /// **Not in the deck.** Splash Cousin is the only thing that puts it in play, and
    /// when it is Retired it leaves the game rather than the pile — so the scramble it
    /// starts has exactly one ending.
    static let splashBall = CardDescriptor(
        id: "splash-ball", name: "Splash Ball", type: .variaball,
        effect: "SHOT = 100% on #[Three] attempts", numberInDeck: 0,
        variaball: VariaballEffect(shotOverrideOnThrees: 100,
                                   removedFromPlayWhenRetired: true))

    static let handBall = CardDescriptor(
        id: "hand-ball", name: "Hand Ball", type: .variaball,
        effect: "A ~[Pass] swaps hands: yours goes with the ball, theirs comes back",
        numberInDeck: 1,
        variaball: VariaballEffect(swapsHandsOnPass: true))
    static let footBall = CardDescriptor(
        id: "foot-ball", name: "Foot Ball", type: .variaball,
        effect: "~[Moves] and ~[Passes] are not spent. They lock until your possession ends",
        numberInDeck: 1,
        variaball: VariaballEffect(locksInsteadOfSpending: true))
    static let rechargeRock = CardDescriptor(
        id: "recharge-rock", name: "Recharge Rock", type: .variaball,
        effect: "Double your draw for turn", numberInDeck: 1,
        variaball: VariaballEffect(turnDrawMultiplier: 2))
    static let variaball = CardDescriptor(
        id: "variaball", name: "Variaball", type: .variaball,
        effect: "A random Variaball from the discards goes into play. Then discard this",
        numberInDeck: 1,
        variaball: VariaballEffect(rollsFromDiscard: true))
    static let shufflebagBall = CardDescriptor(
        id: "shufflebag-ball", name: "Shufflebag Ball", type: .variaball,
        effect: "Every possession, the turn player shuffles their hand into the deck and #[Draws] the same number, then draws for turn",
        numberInDeck: 1,
        variaball: VariaballEffect(reshufflesHandEachPossession: true))
    static let bagnBall = CardDescriptor(
        id: "bagn-ball", name: "Bag'n Ball", type: .variaball,
        effect: "#[Draw] 1 card when played. SHOT = 10% for each card in your hand",
        numberInDeck: 1,
        variaball: VariaballEffect(shotPerCardInHand: 10, drawsOnArrival: 1))
    static let blazeBall = CardDescriptor(
        id: "blaze-ball", name: "Blaze Ball", type: .variaball,
        effect: "SHOT +10% as this Ball is ~[Passed]", numberInDeck: 1,
        variaball: VariaballEffect(shotPerPass: 10))
    /// Blaze Ball's opposite, worded to match.
    static let snowBall = CardDescriptor(
        id: "snow-ball", name: "Snow Ball", type: .variaball,
        effect: "SHOT -10% as this Ball is ~[Passed]", numberInDeck: 1,
        variaball: VariaballEffect(shotPerPass: -10, overridesPassShot: true))
    static let brickBall = CardDescriptor(
        id: "brick-ball", name: "Brick Ball", type: .variaball,
        effect: "SHOT = 25%", numberInDeck: 1,
        variaball: VariaballEffect(shotOverride: 25))
    static let monsterBall = CardDescriptor(
        id: "monster-ball", name: "Monster Ball", type: .variaball,
        effect: "~[Intangibles] are absorbed into the ball. When it's discarded, players #[Rebound] for them one at a time",
        numberInDeck: 1,
        variaball: VariaballEffect(absorbsIntangibles: true))
    static let brandNewBall = CardDescriptor(
        id: "brand-new-ball", name: "Brand New Ball", type: .variaball,
        effect: "25% chance a shot attempt is a turnover instead", numberInDeck: 1,
        variaball: VariaballEffect(turnoverChance: 25))
    static let makeOrTakeBall = CardDescriptor(
        id: "make-or-take-ball", name: "Make-or-Take Ball", type: .variaball,
        effect: "Take 1 #[FT] after missing a shot attempt.", numberInDeck: 1,
        variaball: VariaballEffect(freeThrowsOnMiss: 1))
    static let heroBall = CardDescriptor(
        id: "hero-ball", name: "Hero Ball", type: .variaball,
        effect: "Cannot play ~[Pass] cards. Made shots grant no #[AST]. SHOT +25% while "
            + "shooting. #[Draw] 1 extra when this Ball is rebounded",
        numberInDeck: 1,
        variaball: VariaballEffect(shotWhenShooting: 25, drawsOnRebound: 1,
                                   barsPasses: true, noAssists: true))

    /// **Alley-Oop**: a Lob, dunked as the first thing done with it. What the combo adds on
    /// top of the Lob and the dunk card.
    static let alleyOopBonus = 10

    static let variaballs: [CardDescriptor] = [
        medBall, dishcountBall, blightBall, benchBall, dishtractingBall, handBall, footBall,
        liarBall, baldBall, splashBall,
        rechargeRock, variaball, shufflebagBall, bagnBall, blazeBall, snowBall, brickBall,
        monsterBall, brandNewBall, makeOrTakeBall, heroBall,
    ]

    static let varenas: [CardDescriptor] = [
        cardwood, primeParquet, lacktop, smacktop, boarderCourt, dimDome, triHardTiling,
        kiddieCourt, rechargingResin, contactCourt, mvpiquia, polypaypylene,
        recoverena, carouselCourt, traderousTarmac, clearcoatCourt, malicePalace,
        turnstileTile, roleplayerPolymer, variaballVinyl, graviGym, vintageVarnish,
        sellOutStadium, grayvstone, conCrete, spazzphalt, frostbiteFinish, tickTockTile,
        theFuture,
    ]

    // ── Game Breaks ───────────────────────────────────────────────────
    // Out of the deck: each retires into a Varena or a Variaball. The descriptors and the
    // rules they lean on stay until each replacement is built.

    static let crowdNoise = CardDescriptor(
        id: "crowd-noise", name: "Crowd Noise", type: .gameBreak,
        effect: "#[Retire|1]", numberInDeck: 3,
        gameBreak: GameBreakEffect(discard: 1))

    static let twoMinuteWarning = CardDescriptor(
        id: "two-minute-warning", name: "2-Minute Warning", type: .gameBreak,
        effect: "All, down to 2 #[Retire|?]", numberInDeck: 3,
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
        effect: "~[Whistles] cannot be called for the rest of the round",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(silencesWhistles: true))

    static let foul = CardDescriptor(
        id: "foul", name: "Foul", type: .gameBreak,
        effect: "Take 1 #[FT]", numberInDeck: 3,
        gameBreak: GameBreakEffect(freeThrows: 1))

    // ── Special Moves ─────────────────────────────────────────────────
    // These take the shot themselves, which ends the possession.

    static let fadeaway = CardDescriptor(
        id: "fadeaway", name: "Fadeaway Three", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT -10%\nIgnore ~[Clamps] and ~[Refs]", numberInDeck: 1,
        shotDelta: -10, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .three,
                                   ignoresClamps: true, ignoresRefs: true))

    static let fromTheHash = CardDescriptor(
        id: "from-the-hash", name: "From the Hash", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT -20%\nYou may #[Retire] target ~[Ref]",
        numberInDeck: 1,
        shotDelta: -20, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .three),
        retiresARef: true)

    static let fromTheLogo = CardDescriptor(
        id: "from-the-logo", name: "From the Logo", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT -30%\nYou may #[Retire] target ~[Ref] and/or ~[Ball]",
        numberInDeck: 1,
        shotDelta: -30, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .three),
        retiresARef: true, mayRetireTheBall: true)

    /// **The third of the generic auto-shots**, with Slam Dunk and Three-Ball: one for
    /// each button, so every finish has a card that simply takes it.
    static let floater = CardDescriptor(
        id: "floater", name: "Floater", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT +30%\nIgnore target ~[Clamp]", numberInDeck: 3,
        shotDelta: 30, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .layup,
                                   ignoresATargetClamp: true))

    static let threeBall = CardDescriptor(
        id: "three-ball", name: "Three-Ball", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT -10%", numberInDeck: 3,
        shotDelta: -10, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .three))

    static let fullCourtHeave = CardDescriptor(
        id: "full-court-heave", name: "Full-Court Heave", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT = 25%\n#[Retire] the ~[Ball]\n"
            + "Ignore ~[Clamps] and ~[Refs]\nYou may #[Retire] target player's ~[Intangible]",
        numberInDeck: 1, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .three,
                                   shotOverride: 25, ignoresClamps: true, ignoresRefs: true),
        retiresTheBall: true, retiresAnIntangible: true)

    static let buzzerBeater = CardDescriptor(
        id: "buzzer-beater", name: "Buzzer Beater", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT = 100%. (Can only be played if the #[Shot Clock] is at 01)",
        numberInDeck: 1, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .three,
                                   shotOverride: 100, onlyAtShotClock: 1))

    static let putbackTip = CardDescriptor(
        id: "putback-tip", name: "Putback Tip", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT +10%", numberInDeck: 1,
        shotDelta: 10, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .layup,
                                   shotOverrideAfterRebound: 100),
        bonus: "If played as your first action after a #[Rebound]: SHOT = 100%")

    static let bankshot = CardDescriptor(
        id: "bankshot", name: "Bankshot", type: .specialMove,
        effect: "#[Draw] 1 card. Flip a coin:\n"
            + "• Heads: SHOT +25% and ignore target ~[Clamp]\n"
            + "• Tails: SHOT -25% and #[Draw] 1 extra card",
        numberInDeck: 1,
        drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .layup,
                                   coinFlipShot: 25,
                                   headsIgnoresAClamp: true, tailsDraw: 1))

    static let daggerThree = CardDescriptor(
        id: "dagger-three", name: "Dagger Three", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT +60%. SHOT -10% x #[Shot Clock]",
        numberInDeck: 1,
        shotDelta: 60, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .three,
                                   shotPerClockTick: -10))

    static let skyhook = CardDescriptor(
        id: "skyhook", name: "Skyhook", type: .specialMove,
        effect: "Choose a card from Retirement. SHOT +25%", numberInDeck: 1,
        shotDelta: 25,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .layup,
                                   ignoresClamps: true),
        takesFromRetirement: 1,
        bonus: "This shot is unaffected by ~[Clamps].")

    static let twoHandJam = CardDescriptor(
        id: "two-hand-jam", name: "2-Hand Jam", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT +25%. If played as the first action after your "
            + "#[Rebound], you may #[Retire] any number of cards: SHOT +10% extra for each",
        numberInDeck: 1,
        shotDelta: 25, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .dunk,
                                   dunkKind: .reverse, dunks: true,
                                   discardForShotBonus: 10, discardBeyondLimitBonus: 10,
                                   discardsOnlyAfterRebound: true),
        combo: "SHOT +10% extra (as your first action)")

    /// **Removed from the game** (2026-09-14). Out of every pool.
    static let giveAndGoDunk = CardDescriptor(
        id: "give-and-go-dunk", name: "Give-and-Go Dunk", type: .specialMove,
        effect: "Clean look only — no ~[Clamps] on you and nothing has gone off this "
              + "possession. SHOT +30%",
        numberInDeck: 1,
        shotDelta: 30,
        special: SpecialMoveEffect(shootsImmediately: true, dunks: true))

    static let tomahawk = CardDescriptor(
        id: "tomahawk", name: "Tomahawk", type: .specialMove,
        effect: "#[Draw] 1 card.\nSHOT 50% or more: SHOT +25%\nSHOT less than 50%: SHOT -25%",
        numberInDeck: 1, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .dunk,
                                   dunkKind: .oneHand,
                                   shotSwing: ShotSwing(at: 50, under: -25, over: 25),
                                   dunks: true),
        combo: "SHOT +10% extra (as your first action)")

    static let slamDunk = CardDescriptor(
        id: "slam-dunk", name: "Slam Dunk", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT +25%", numberInDeck: 3,
        shotDelta: 25, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .dunk,
                                   shotOverride: 100,
                                   overrideRequiresAtLeast: 75, dunks: true),
        combo: "SHOT +10% extra (as your first action)",
        bonus: "SHOT = 100% if final SHOT is 75% or more")

    static let euroStep = CardDescriptor(
        id: "euro-step", name: "Euro Step", type: .specialMove,
        effect: "#[Draw] 1 card. Flip 3 coins: for each Heads, SHOT +15%, #[Draw] 1 card, "
            + "and increment the #[Move] meter",
        numberInDeck: 3, drawCount: 1,
        special: SpecialMoveEffect(coinRunShot: 15, coinRunDraw: 1, coinRunFlips: 3,
                                   coinRunMoves: 1))

    static let wideOpenThree = CardDescriptor(
        id: "wide-open-three", name: "Open Three", type: .specialMove,
        effect: "#[Draw] 1 card.\n"
            + "If 2 or more ~[Passes] have been played this round: SHOT +50%",
        numberInDeck: 1, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .three,
                                   shotOverrideOnceAllHaveHadBall: 100,
                                   shotPerPassesThisRound: 50, passesRequired: 2,
                                   wideOpenName: "Wide-Open Three"))

    static let turnaroundThree = CardDescriptor(
        id: "turnaround-three", name: "Turnaround Three", type: .specialMove,
        effect: "#[Draw] 1 card. SHOT -30%",
        numberInDeck: 1,
        shotDelta: -30, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true, shotType: .three,
                                   offersHandDumpAt: 3,
                                   handDumpRetiresARef: true, handDumpOverrideAt: 5),
        bonus: "If you have 3 or more cards in hand, you may #[Retire] them: "
            + "#[Retire] target ~[Ref]. If #[Retiring] 5 or more, SHOT = 100%")

    static let specialMoves: [CardDescriptor] = [
        fadeaway, fromTheHash, fromTheLogo, threeBall, fullCourtHeave, buzzerBeater, putbackTip,
        euroStep, turnaroundThree, bankshot, daggerThree, skyhook, slamDunk,
        twoHandJam, tomahawk, floater,
        wideOpenThree,
    ]

    static let altercation = CardDescriptor(
        id: "altercation", name: "Altercation", type: .gameBreak,
        effect: "Select another player: you and they each #[Retire] 1 at random. Inbound to anybody else",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(fightsChosenPlayer: true))

    static let hugeAltercation = CardDescriptor(
        id: "huge-altercation", name: "Huge Altercation", type: .gameBreak,
        effect: "All players #[Retire] their hands. With a referee out, all take 1 #[TOV]. Inbound the ball",
        numberInDeck: 1,
        gameBreak: GameBreakEffect(everyoneDiscardsHands: true, turnoversIfReferee: 1,
                                   givesBallAway: true))

    static let homeCourtAdvantage = CardDescriptor(
        id: "home-court-advantage", name: "Home Court Advantage", type: .gameBreak,
        effect: "SHOT + 25%", numberInDeck: 3,
        gameBreak: GameBreakEffect(shotThisPossession: 25))

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
        effect: "#[Retire] the next 3 ~[Game Breaks]. Whoever #[Draws] one #[Draws] again",
        numberInDeck: 3,
        gameBreak: GameBreakEffect(waivesBreaks: 3))

    /// Their own type. A Devastating Injury is the sub-type that lasts the game — see `Injury`.
    static let injuries: [CardDescriptor] = [
        tornAchilles, tornACL, tornMeniscus, patellarTendonTear,
        boneBruise, rolledAnkle, fracturedCollarbone, jammedFinger, sprainedHamstring, hipContusion,
    ]

    static let tileTampering = CardDescriptor(
        id: "tile-tampering", name: "Tile Tampering", type: .whistle,
        effect: "Varena played: cancel it. #[TOV] +1", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .varenaPlayed, turnoverOnOffender: true))
    static let overVaringEvidence = CardDescriptor(
        id: "over-varing-evidence", name: "Over-Varing Evidence", type: .whistle,
        effect: "Variaball played: cancel it. #[TOV] +1", numberInDeck: 1,
        whistle: WhistleEffect(trigger: .variaballPlayed, turnoverOnOffender: true))

    /// **The officials deck.** Its own pile: shuffled at the start of the game like the
    /// main deck, three turned face-up at the top of every round, and never dealt into
    /// anybody's hand. Everyone reads what the crew is watching for and plays under it.
    ///
    /// Nobody owns one, so nothing here pays a setter. The calls that only made sense as
    /// somebody's trap — a Timeout, a Coach's Challenge, a review that hands the caller
    /// the ball — are out of the deck; see `retiredWhistles`.
    static let officialsPool: [CardDescriptor] = [
        travel, shotClockViolation, doubleDribble, backCourtViolation, discontinuedDribble,
        charge, footOnTheLine, offensiveFoul,
        goaltending, blockingFoul, flagrantFoul, flagrantFoulII,
        technicalFoul, clearPathFoul, delayOfGameWarning, officialReview,
        extravagantMechanics, overVaringEvidence, crewChief, rookieOfficial,
        retiringOfficial, equalizer,
    ]

    /// Whistles that needed an owner to mean anything. Kept so a saved match can still
    /// decode them, out of every pool.
    static let retiredWhistles: [CardDescriptor] = [
        timeout, coachsChallenge, crewChiefReview, inadvertentWhistle, tileTampering,
        playOn, clearedToPlay,
    ]

    /// **A call spends the man who made it.** Any official's call, his own included,
    /// retires him and draws a replacement — so the stage churns as it is used, and a rule
    /// somebody has just worked around is swapped for one they have not read yet.
    ///
    /// While he is out, every other referee is back to one call apiece.
    static let crewChief = CardDescriptor(
        id: "crew-chief", name: "Crew Chief", type: .whistle,
        effect: "Any call: #[Retire] that ~[Ref] and place a new one", numberInDeck: 1,
        whistle: WhistleEffect(retiresCaller: true))

    /// **A positive one**, of which the crew wants more. Retiring stops being a loss and
    /// becomes a swap: you give up what you spent and take back something already played.
    static let rookieOfficial = CardDescriptor(
        id: "rookie-official", name: "Rookie Official", type: .whistle,
        effect: "When the first card you play in a possession is non-standing: "
            + "take a card of a different name from Retirement",
        numberInDeck: 1,
        whistle: WhistleEffect(swapsOnRetire: true))

    /// **The one who is on his way out and does not much mind.** The other positive
    /// official: the look is better while he works, a Clamp played in front of him is a
    /// card instead of a defender, and when he finally goes he takes Retirement back into
    /// the deck with him.
    static let retiringOfficial = CardDescriptor(
        id: "retiring-official", name: "Retiring Official", type: .whistle,
        effect: "SHOT +10%\n~[Clamp] played: #[Draw] 1 card instead\n"
            + "When he leaves: Retirement is shuffled into the deck",
        numberInDeck: 1,
        whistle: WhistleEffect(shotWhileWorking: 10, clampsDrawInstead: true,
                               shufflesRetirementOnLeaving: true))

    static let whistles: [CardDescriptor] = [
        shotClockViolation, travel, doubleDribble, backCourtViolation, inadvertentWhistle,
        discontinuedDribble,
        coachsChallenge, officialReview, goaltending, timeout, delayOfGameWarning,
        blockingFoul, flagrantFoul, flagrantFoulII, charge, technicalFoul, clearPathFoul,
        clearedToPlay, extravagantMechanics, crewChiefReview, tileTampering,
        overVaringEvidence,
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
        rightBack, touchPass,
        dribble, drive, rhythmDribble, poundDribble, spinMove, crossover,
        hesi, pumpFake, stepback, tripleThreat, clearOut,
    ]

    /// Classic mode's pool: Pass and Move cards only.
    static let classicPool: [CardDescriptor] = passesAndMoves

    /// Standard adds everything else, as each type gets built.
    /// **The fifth colour.** Nine coverages and seven assignments: the half of the game
    /// that stops the ball, which was a nine-card afterthought before.
    static let clamps: [CardDescriptor] = [
        contest, manToMan, closeOut, zone, fullCourtPress, doubleTeam, tripleTeam, trap,
        crushingCenter, pressingPoint, lurkingWing, helpSideForward,
        baselineDenial, paintPacker, rimRunner,
    ]

    /// The main deck, and it is five types: Pass, Move, Ball, Clamp and Intangible.
    ///
    /// **No Whistles** — the crew is its own pile, dealt face-up at the top of every
    /// round; see `officialsPool`. **No Varenas and no Injuries** — both are parked while
    /// the venue and the knocks are redesigned, so every match is played on plain Cardwood
    /// with nobody hurt. The descriptors stay reachable by id so a saved match still
    /// decodes; see `byID`.
    static let standardPool: [CardDescriptor] = passesAndMoves
        + [flop] + clamps
        + intangibles + specialMoves
        + variaballs

    /// **Every card in the game.**
    ///
    /// This name used to belong to the twenty-eight passes and moves that make up
    /// Classic, and six places read it meaning *all of them*: the gallery showed two of
    /// the seven types and no others existed as far as it knew, a collection could never
    /// record a Whistle you had met, and `Rules` looked cards up by id in it — so a
    /// Special Move, a Clamp or an Intangible simply came back nil. A name that says
    /// `all` has to mean all.
    /// Every card still dealt is in `standardPool` or in the officials deck, and both are
    /// dealt from — so `all` is the two of them together.
    static let all: [CardDescriptor] = standardPool + officialsPool

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
        // The retired ones and the shelved Varenas are in here but in no pool: a saved
        // match still has to be able to decode a card the deck no longer builds.
        for card in all + varenas + injuries + retiredWhistles + [faceDown] {
            found[card.id] = card
        }
        return found
    }()

    /// Names that turn up inside other cards' text, for highlighting them there. Only
    /// multi-letter names, so a stray word is never mistaken for a reference.
    /// Actual card names only. Type words — Whistle, Clamp, Move, Pass, Intangible —
    /// are categories, not cards, and colouring them read as a reference to something
    /// that does not exist.
    static let namesReferencedInText: [String] = [
        "Rhythm Dribble", "Timeout", "Dribble", "Drive", "Travel",
    ]

    static func buildDeck(pool: [CardDescriptor], passShotBonus: Int) -> [Card] {
        pool.flatMap { descriptor in
            let resolved = descriptor.resolved(passShotBonus: passShotBonus)
            return (0..<resolved.numberInDeck).map { _ in Card(resolved) }
        }
    }
}

/// **A card that pays extra for following another.** The finisher carries the rule; the
/// openers are what it can follow — one named card, or every Dribble.
struct Combo: Hashable, Identifiable {
    let finisher: CardDescriptor
    let openers: [CardDescriptor]

    var id: String { finisher.id }

    /// "Dribble-Drive". Every Dribble route shares the one name, because the card says
    /// Dribble rather than naming one.
    var name: String {
        if openers.map(\.id) == [CardLibrary.lob.id] { return "Alley-Oop" }
        if finisher.id == CardLibrary.handOff.id { return "DHO" }
        if finisher.id == CardLibrary.crossover.id { return "Ankle Breaker" }
        let opener = finisher.comboAfterDribble ? "Dribble" : (openers.first?.name ?? "")
        return "\(opener)-\(finisher.name)"
    }

    static func route(_ opener: String, into finisher: String) -> String {
        "\(opener)>\(finisher)"
    }

    static let all: [Combo] = CardLibrary.standardPool.compactMap { card in
        if card.comboAfterDribble {
            return Combo(finisher: card, openers: CardLibrary.standardPool.filter(\.isDribble))
        }
        guard let after = card.comboAfter, let opener = CardLibrary.byID[after] else { return nil }
        return Combo(finisher: card, openers: [opener])
    } + alleyOops

    /// Alley-Oop: a Lob, finished by any card that dunks.
    static let alleyOops: [Combo] = CardLibrary.standardPool
        .filter { $0.special?.dunks == true }
        .map { Combo(finisher: $0, openers: [CardLibrary.lob]) }

    /// Every combo a card is part of, from either end.
    static func involving(_ card: CardDescriptor) -> [Combo] {
        all.filter { $0.finisher.id == card.id || $0.openers.contains { $0.id == card.id } }
    }
}
