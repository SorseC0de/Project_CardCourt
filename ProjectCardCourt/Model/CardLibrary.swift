import Foundation

/// The cards in play. Counts come from the Number in Deck column of
/// Project CardCourt_CardDB.xlsx, and the percentages match its effect text:
/// passes move SHOT less than Move cards do.
enum CardLibrary {

    static let swingLeft = CardDescriptor(
        id: "swing-left", name: "Swing Left", type: .pass,
        effect: "Pass Left. SHOT +5%", numberInDeck: 31, passTarget: .left)

    static let swingRight = CardDescriptor(
        id: "swing-right", name: "Swing Right", type: .pass,
        effect: "Pass Right. SHOT +5%", numberInDeck: 31, passTarget: .right)

    static let skipPass = CardDescriptor(
        id: "skip-pass", name: "Skip Pass", type: .pass,
        effect: "Pass Across. SHOT +5%", numberInDeck: 20, passTarget: .across)

    static let behindTheBack = CardDescriptor(
        id: "behind-the-back", name: "Behind-the-Back", type: .pass,
        effect: "Pass back to last player. SHOT +5%",
        numberInDeck: 5, passTarget: .backToPasser)

    static let dribble = CardDescriptor(
        id: "dribble", name: "Dribble", type: .move,
        effect: "Draw 1. SHOT -10%", numberInDeck: 15,
        shotDelta: -10, drawCount: 1, isDribble: true)

    static let drive = CardDescriptor(
        id: "drive", name: "Drive", type: .move,
        effect: "SHOT +10%. Following Dribble: SHOT +10%", numberInDeck: 7,
        shotDelta: 10, comboAfter: "dribble", comboBonus: 10)

    static let rhythmDribble = CardDescriptor(
        id: "rhythm-dribble", name: "Rhythm Dribble", type: .move,
        effect: "Draw 1. SHOT +10%. Shot Clock -1", numberInDeck: 5,
        shotDelta: 10, drawCount: 1, clockDelta: -1, isDribble: true)

    static let contest = CardDescriptor(
        id: "contest", name: "Contest", type: .clamp,
        effect: "Next player: SHOT -25%", numberInDeck: 10,
        clamp: ClampEffect(shotDebuff: -25))

    static let fullCourtPress = CardDescriptor(
        id: "full-court-press", name: "Full-Court Press", type: .clamp,
        effect: "Next player discard 2", numberInDeck: 5,
        clamp: ClampEffect(discardAtStart: 2))

    // ── Whistles ──────────────────────────────────────────────────────
    // A nil trigger resolves on play; everything else lies in wait. A turnover always
    // costs the ball and re-inbounds without advancing the round.

    static let shotClockViolation = CardDescriptor(
        id: "shot-clock-violation", name: "Shot Clock Violation", type: .whistle,
        effect: "Cancel Next Shot. TOV +1", numberInDeck: 5,
        whistle: WhistleEffect(trigger: .shotAttempt, turnoverOnOffender: true))

    static let travel = CardDescriptor(
        id: "travel", name: "Travel", type: .whistle,
        effect: "Cancel Next Move. TOV +1", numberInDeck: 5,
        whistle: WhistleEffect(trigger: .movePlayed, turnoverOnOffender: true))

    static let doubleDribble = CardDescriptor(
        id: "double-dribble", name: "Double Dribble", type: .whistle,
        effect: "Cancel Next Dribble. Discard 1. TOV +1", numberInDeck: 5,
        whistle: WhistleEffect(trigger: .dribblePlayed, turnoverOnOffender: true,
                               offenderDiscards: 1))

    static let backCourtViolation = CardDescriptor(
        id: "back-court-violation", name: "Back Court Violation", type: .whistle,
        effect: "Cancel Next Pass. TOV +1. You choose who inbounds",
        numberInDeck: 5,
        whistle: WhistleEffect(trigger: .passPlayed, turnoverOnOffender: true,
                               setterChoosesInbound: true))

    static let inadvertentWhistle = CardDescriptor(
        id: "inadvertent-whistle", name: "Inadvertent Whistle", type: .whistle,
        effect: "Cancel Next Non-Whistle. Player draws 1",
        numberInDeck: 5,
        whistle: WhistleEffect(trigger: .anyNonWhistlePlayed, offenderDraws: 1))

    static let coachsChallenge = CardDescriptor(
        id: "coachs-challenge", name: "Coach's Challenge", type: .whistle,
        effect: "Cancel Next Whistle. +1 Timeout",
        numberInDeck: 5,
        whistle: WhistleEffect(trigger: .whistlePlayed, recoversTimeout: true))

    static let officialReview = CardDescriptor(
        id: "official-review", name: "Official Review", type: .whistle,
        effect: "Next Intangible: discard all theirs", numberInDeck: 5,
        whistle: WhistleEffect(trigger: .intangiblePlayed, stripsIntangibles: true))

    static let goaltending = CardDescriptor(
        id: "goaltending", name: "Goaltending", type: .whistle,
        effect: "Cancel Next Clamp. +2 PTS. End round",
        numberInDeck: 3,
        whistle: WhistleEffect(trigger: .clampPlayed, endsRound: true, pointsToVictim: 2))

    static let timeout = CardDescriptor(
        id: "timeout", name: "Timeout", type: .whistle,
        effect: "Reset Shot Clock. All draw 1", numberInDeck: 5,
        whistle: WhistleEffect(resetsShotClock: true, everyoneDraws: 1))

    // ── Intangibles ───────────────────────────────────────────────────

    static let shotCreator = CardDescriptor(
        id: "shot-creator", name: "Shot Creator", type: .intangible,
        effect: "On Draw: Draw +1", numberInDeck: 1,
        intangible: IntangibleEffect(bonusDraw: 1))

    static let hotHand = CardDescriptor(
        id: "hot-hand", name: "Hot Hand", type: .intangible,
        effect: "SHOT +20% if you scored last round", numberInDeck: 1,
        intangible: IntangibleEffect(shotBonus: 20, requiresScoredLastRound: true))

    static let intangibles: [CardDescriptor] = [shotCreator, hotHand]

    // ── Game Breaks ───────────────────────────────────────────────────

    static let crowdNoise = CardDescriptor(
        id: "crowd-noise", name: "Crowd Noise", type: .gameBreak,
        effect: "Discard 1", numberInDeck: 14,
        gameBreak: GameBreakEffect(discard: 1))

    static let twoMinuteWarning = CardDescriptor(
        id: "two-minute-warning", name: "2-Minute Warning", type: .gameBreak,
        effect: "All discard down to 2", numberInDeck: 2,
        gameBreak: GameBreakEffect(everyoneDiscardsTo: 2))

    static let designedPlay = CardDescriptor(
        id: "designed-play", name: "Designed Play", type: .gameBreak,
        effect: "Draw up to 5", numberInDeck: 10,
        gameBreak: GameBreakEffect(drawUpTo: 5))

    static let mvpVote = CardDescriptor(
        id: "mvp-vote", name: "MVP Vote", type: .gameBreak,
        effect: "Draw up to 7", numberInDeck: 5,
        gameBreak: GameBreakEffect(drawUpTo: 7))

    static let offNight = CardDescriptor(
        id: "off-night", name: "Off Night", type: .gameBreak,
        effect: "SHOT -20% this possession", numberInDeck: 3,
        gameBreak: GameBreakEffect(shotThisPossession: -20))

    static let benched = CardDescriptor(
        id: "benched", name: "Benched", type: .gameBreak,
        effect: "Give ball to random player", numberInDeck: 5,
        gameBreak: GameBreakEffect(givesBallAway: true))

    static let swallowedWhistle = CardDescriptor(
        id: "swallowed-whistle", name: "Swallowed Whistle", type: .gameBreak,
        effect: "This round:",
        numberInDeck: 5,
        gameBreak: GameBreakEffect(silencesWhistles: true))

    // ── Special Moves ─────────────────────────────────────────────────
    // These take the shot themselves, which ends the possession.

    static let fadeaway = CardDescriptor(
        id: "fadeaway", name: "Fadeaway", type: .specialMove,
        effect: "SHOT -10%. Draw 1. Shoot the ball", numberInDeck: 10,
        shotDelta: -10, drawCount: 1,
        special: SpecialMoveEffect(shootsImmediately: true))

    static let fromTheHash = CardDescriptor(
        id: "from-the-hash", name: "From the Hash", type: .specialMove,
        effect: "SHOT -30%. Shoot the ball. +1 PT on make", numberInDeck: 3,
        shotDelta: -30,
        special: SpecialMoveEffect(shootsImmediately: true, bonusPointOnMake: 1))

    static let fromTheLogo = CardDescriptor(
        id: "from-the-logo", name: "From the Logo", type: .specialMove,
        effect: "SHOT -50%. Shoot the ball. +1 PT on make", numberInDeck: 3,
        shotDelta: -50,
        special: SpecialMoveEffect(shootsImmediately: true, bonusPointOnMake: 1))

    static let fullCourtHeave = CardDescriptor(
        id: "full-court-heave", name: "Full-Court Heave", type: .specialMove,
        effect: "SHOT = 10%. Shoot the ball. +1 PT on make", numberInDeck: 3,
        special: SpecialMoveEffect(shootsImmediately: true, bonusPointOnMake: 1, shotOverride: 10))

    static let buzzerBeater = CardDescriptor(
        id: "buzzer-beater", name: "Buzzer Beater", type: .specialMove,
        effect: "SHOT = 100%. Shoot the ball. Only at Shot Clock 1", numberInDeck: 4,
        special: SpecialMoveEffect(shootsImmediately: true, shotOverride: 100, onlyAtShotClock: 1))

    static let putbackTip = CardDescriptor(
        id: "putback-tip", name: "Putback Tip", type: .specialMove,
        effect: "SHOT +10%. Shoot the ball.", numberInDeck: 3,
        shotDelta: 10,
        special: SpecialMoveEffect(shootsImmediately: true))

    static let euroStep = CardDescriptor(
        id: "euro-step", name: "Euro Step", type: .specialMove,
        effect: "Flip until Tails. Each Heads: SHOT +5% and Draw 1",
        numberInDeck: 5,
        special: SpecialMoveEffect(coinRunShot: 5, coinRunDraw: 1))

    static let turnaroundThree = CardDescriptor(
        id: "turnaround-three", name: "Turnaround Three", type: .specialMove,
        effect: "Discard any number. SHOT +10% for each. Shoot the ball. +1 PT on make",
        numberInDeck: 1,
        special: SpecialMoveEffect(shootsImmediately: true, bonusPointOnMake: 1,
                                   discardForShotBonus: 10))

    static let specialMoves: [CardDescriptor] = [
        fadeaway, fromTheHash, fromTheLogo, fullCourtHeave, buzzerBeater, putbackTip,
        euroStep, turnaroundThree,
    ]

    static let gameBreaks: [CardDescriptor] = [
        crowdNoise, twoMinuteWarning, designedPlay, mvpVote, offNight, benched, swallowedWhistle,
    ]

    static let whistles: [CardDescriptor] = [
        shotClockViolation, travel, doubleDribble, backCourtViolation, inadvertentWhistle,
        coachsChallenge, officialReview, goaltending, timeout,
    ]

    static let all: [CardDescriptor] = [
        swingLeft, swingRight, skipPass, behindTheBack, dribble, drive, rhythmDribble,
    ]

    /// Classic mode's pool: Pass and Move cards only.
    static let classicPool: [CardDescriptor] = all

    /// Standard adds everything else, as each type gets built.
    static let standardPool: [CardDescriptor] = all + [contest, fullCourtPress] + whistles + intangibles + gameBreaks + specialMoves

    /// Names that turn up inside other cards' text, for highlighting them there. Only
    /// multi-letter names, so a stray word is never mistaken for a reference.
    static let namesReferencedInText: [String] = [
        "Timeout", "Rhythm Dribble", "Dribble", "Drive", "Intangible", "Intangibles",
        "Whistle", "Non-Whistle", "Clamp", "Clamps", "Move", "Pass",
    ]

    static func buildDeck(pool: [CardDescriptor], passShotBonus: Int) -> [Card] {
        pool.flatMap { descriptor in
            let resolved = descriptor.resolved(passShotBonus: passShotBonus)
            return (0..<resolved.numberInDeck).map { _ in Card(resolved) }
        }
    }
}
