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
    var isStanding: Bool { shotDebuff != 0 || locksRandomCards > 0 || passOnly }

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
}

/// A passive that sits in one of a player's slots for the rest of the match.
struct IntangibleEffect: Hashable, Codable {
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
    /// Board-Crasher: only off your own miss. Catch & Shoot: only off a pass.
    var requiresOwnRebound = false
    var requiresReceivedPass = false
    /// Sniper and Splash Cousin only pay from range.
    var requiresThree = false
    /// `SHOT = x%` rather than a delta, under whatever conditions are also set.
    var shotOverride: Int?
    /// Sixth Man: the nth attempt of the round, counting from one.
    var requiresNthShotOfRound: Int?
    /// Lethal Shooter: the shot straight after taking your own board.
    var requiresAfterOwnRebound = false
    /// Point God draws on every pass; Unselfish only on a good one.
    var drawAfterPass: Int = 0
    /// Ball Pounder: every Dribble is a card richer and a look worse.
    var dribbleBonusDraw: Int = 0
    var dribbleShotPenalty: Int = 0
    /// Like That, Unguardable: nothing may take SHOT down.
    var shotCannotBeReduced = false
    var ignoresClampDebuffs = false
    /// Gravity: every Clamp lands here whoever it was aimed at, and every other player's
    /// attempt is an assist.
    var attractsClamps = false
    var assistOnOthersShot = false
    /// Great Conditioning: an Injury never lands, and the draw is taken again.
    var shrugsOffInjuries = false
    /// Fox-Like First Step: a Move that costs SHOT pays it instead.
    var invertsMoveDebuffs = false
    /// No Bag, Fundamentalist. One blocks Moves, the other Special Moves.
    var blocksMoves = false
    var blocksSpecialMoves = false
    /// Free Agent: no bag of his own. He plays out of whoever is nearest.
    ///
    /// The hand is dumped once the draw chain that turned this up has finished, not the
    /// moment it lands — drawing it second in an opening deal should cost the whole hand,
    /// not one card.
    var playsFromOthers = false
    /// Villainous Reputation: every call costs you, whoever it was against.
    var discardOnAnyWhistle = 0
    /// And it never really leaves — taken off you, it lands on somebody. Possibly you.
    var reattachesOnDiscard = false
    /// Dirty Player: a Clamp of yours lands on a man already hurt and it costs him.
    var clampCostsInjured = 0
    /// Fundamentalist: each Move once a turn, and the plainest cards are never spent.
    var oneOfEachMovePerTurn = false
    var keepsOnPlay: [String] = []
    /// Floor General: **every** target on the floor is named by this player instead —
    /// who a pass finds, which card comes out of a hand, which branch a card takes. Not
    /// the choices a player makes about their own board: giving up one of your own cards
    /// is not a target.
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
    /// Unselfish: paid whenever you do something for somebody else.
    ///
    /// **Deliberately broad.** The card says "whenever you positively affect another
    /// player" and means it — see `Rules.credit`, which is the one place that decides
    /// what counts. Every route that hands somebody the ball, a card, a point, a trip to
    /// the line, or takes something off them goes through it.
    var drawOnHelping: Int = 0
    var shotOnHelping: Int = 0
}

/// A one-off that fires the moment it is drawn.
struct GameBreakEffect: Hashable, Codable {
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
    /// The sheet gives Injuries their own type column, and they wear their own colour.
    var isInjury = false
    /// **How long an Injury sits on you, and whether it ever comes back.**
    ///
    /// An ordinary Injury lasts the round and is shuffled back in at halftime with
    /// everything else. A Devastating one lasts the whole game and is never shuffled back
    /// — one copy exists and once it has been drawn it is gone, unless a card says
    /// otherwise. See `Injury`.
    var injury: Injury?
    /// Bone Bruise: one card off the top of your hand at the start of every turn, after
    /// you have drawn — so the turn always begins with a choice rather than a tax.
    var discardsEachTurn = 0
    /// Torn Achilles: everything in the bag is held down but this many, rolled fresh each
    /// turn. Zero is no lock at all.
    var playableEachTurn: Int?
    /// Free throws for whoever drew it. Nobody fouled them, so nobody hands the ball back.
    var freeThrows = 0
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
struct SpecialMoveEffect: Hashable, Codable {
    var shootsImmediately = false
    /// Three-pointers pay one extra on a make.
    var bonusPointOnMake = 0
    /// `SHOT = x%`. Sits in the override layer, so it beats the debuffs.
    var shotOverride: Int?
    /// Slam Dunk only. Read after the debuffs, against what survived.
    var overrideRequiresAtLeast: Int?
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
    /// Euro Step: flip until tails, paying out per head.
    /// Discard any number first, paying this much SHOT for each (Turnaround Three).
    var discardForShotBonus = 0
    var coinRunShot = 0
    var coinRunDraw = 0
    /// Dagger Three: worth more the later it is taken.
    ///
    /// Paid on top of the card's own `shotDelta`, once for every tick of the Shot Clock
    /// already spent. So a −60% base and +10% a tick is −60% taken at the top of the
    /// clock, level at 04 and +30% at 01 — which is the card's printed text, arithmetic
    /// and all. Measured against `shotClockStart` rather than a fixed pivot, so it is the
    /// *clock* that decides, not a number that happens to suit a ten-tick one.
    var shotPerClockSpent = 0
}

enum CardType: String, Hashable, Codable {
    case pass = "Pass"
    case move = "Move"
    case specialMove = "Special Move"
    case clamp = "Clamp"
    case whistle = "Whistle"
    case gameBreak = "Game Break"
    case intangible = "Intangible"
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
    /// And what else an armed combo is worth. Hand-Off pays a card off a Dribble;
    /// Kick-Out pays one off a Drive.
    var comboDraw = 0
    /// Paid only when the play it followed was **itself** a combo — a Kick-Out off a
    /// Drive that came off a Dribble is a dribble drive, and that is a different play
    /// from a Drive standing on its own.
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
    /// Paid per Clamp shaken off. Spin Move turns being guarded into an advantage.
    var shotPerClamp = 0
    var drawPerClamp = 0
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
    /// Right Back: he takes it and gives it straight back. Both legs pay, so the card is
    /// worth twice its own SHOT and a card to each of them — and whatever the trip cost
    /// him on the way happens in between.
    var returnsImmediately = false
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
    /// Set on Special Moves.
    let special: SpecialMoveEffect?
    /// Flop: a trip to the line for every Clamp standing on you.
    let freeThrowsPerClamp: Int
    /// Shakes off every Clamp on the player — Flop sells it, Pump Fake shrugs it.
    let clearsClamps: Bool
    /// Flop with nobody guarding you: the referee has watched you throw yourself down
    /// on an empty floor.
    let turnoverIfNoClamps: Bool

    init(id: String, name: String, type: CardType, effect: String, numberInDeck: Int,
         passTarget: PassTarget? = nil, shotDelta: Int? = nil, drawCount: Int = 0,
         clockDelta: Int = 0, comboAfter: String? = nil,
         comboAfterDribble: Bool = false, comboBonus: Int = 0,
         comboDraw: Int = 0, comboAssist: Int = 0,
         upgradesToThree: Bool = false, replacesClockTick: Bool = false,
         whistle: WhistleEffect? = nil, clamp: ClampEffect? = nil,
         intangible: IntangibleEffect? = nil, gameBreak: GameBreakEffect? = nil,
         special: SpecialMoveEffect? = nil, isDribble: Bool = false,
         selfDiscard: Int = 0, shotPerClamp: Int = 0, drawPerClamp: Int = 0,
         clamperDiscardsPerClamp: Int = 0,
         freeThrowsPerClamp: Int = 0, clearsClamps: Bool = false,
         turnoverIfNoClamps: Bool = false,
         receiverDiscards: Int = 0, bonusAssistOnScore: Bool = false,
         forcesReceiverShot: Bool = false, forcesImmediateShot: Bool = false,
         returnsImmediately: Bool = false, drawIfFirstAction: Int = 0,
         clearsOut: Bool = false, firstActionOnly: Bool = false,
         stealsAlongPass: Int = 0,
         targetDiscards: Int = 0, optionalDiscardForShot: Int = 0,
         modes: [CardMode] = [], blocksFurtherMoves: Bool = false) {
        self.receiverDiscards = receiverDiscards
        self.bonusAssistOnScore = bonusAssistOnScore
        self.forcesReceiverShot = forcesReceiverShot
        self.forcesImmediateShot = forcesImmediateShot
        self.returnsImmediately = returnsImmediately
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
        self.clamperDiscardsPerClamp = clamperDiscardsPerClamp
        self.id = id; self.name = name; self.type = type; self.effect = effect
        self.numberInDeck = numberInDeck; self.passTarget = passTarget
        self.shotDelta = shotDelta; self.drawCount = drawCount; self.clockDelta = clockDelta
        self.comboAfter = comboAfter; self.comboAfterDribble = comboAfterDribble
        self.comboBonus = comboBonus
        self.comboDraw = comboDraw; self.comboAssist = comboAssist
        self.upgradesToThree = upgradesToThree
        self.replacesClockTick = replacesClockTick
        self.whistle = whistle; self.clamp = clamp
        self.intangible = intangible; self.gameBreak = gameBreak
        self.special = special; self.isDribble = isDribble
        self.freeThrowsPerClamp = freeThrowsPerClamp; self.clearsClamps = clearsClamps
        self.turnoverIfNoClamps = turnoverIfNoClamps
    }

    var isPass: Bool { passTarget != nil }

    /// Every way a card can touch SHOT. Cards that touch none of them show no percentage.
    var shotEffect: Int? {
        // Passes only. On any other type the figure would sit beside a second, unbadged
        // modifier and read as the whole story.
        guard type == .pass else { return nil }
        if let override = special?.shotOverride { return override }
        if baseShotDelta != 0 { return baseShotDelta }
        if let per = special?.discardForShotBonus, per != 0 { return per }
        if let per = special?.coinRunShot, per != 0 { return per }
        // Not Clamps. Their percentage lands on whoever gets the ball next, so putting it
        // on the badge would read as the holder's own number.
        _ = clamp?.shotDebuff
        if let bonus = intangible?.shotBonus, bonus != 0 { return bonus }
        if let shift = gameBreak?.shotThisPossession, shift != 0 { return shift }
        return nil
    }

    /// True when the number is a target rather than a change.
    var setsShot: Bool { special?.shotOverride != nil }

    /// A drawn icon for the types that have one. Whistles are mirrored, matching the
    /// referee. nil falls through to `symbol`.
    /// `scale` because a hand-drawn SVG arrives at whatever size its artboard was, and
    /// they do not agree with each other.
    /// Drawn with a slash through it — the card says "no" to whatever the icon shows.
    var isSlashed: Bool { id == "swallowed-whistle" }

    var artwork: (name: String, mirrored: Bool, scale: CGFloat)? {
        // It is a Game Break, but what it is *about* is Whistles — and with the slash
        // through it the whistle says the whole effect without a word.
        if id == "swallowed-whistle" { return ("WhistleIcon", true, 1.6) }
        // Cards with art of their own. Each carries its own multiplier: the drawings are
        // trimmed to their subject, so one shared number reads at different sizes.
        switch id {
        case "dribble":      return ("DribbleIcon", false, 1)
        case "drive":        return ("DriveIcon", false, 1)
        case "hesi":         return ("HesiIcon", false, 1)
        case "full-court-heave": return ("HeaveIcon", false, 1)
        case "contest":      return ("ContestIcon", false, 1)
        case "all-swissh-selection": return ("PendingDrawIcon", false, 1)
        case "off-night":    return ("OffNightIcon", false, 1)
        case "benched":      return ("BenchIcon", false, 1)
        case "crowd-noise":  return ("CrowdNoiseIcon", false, 1)
        case "putback-tip":  return ("PutbackIcon", false, 1)
        case "slam-dunk":    return ("DunkIcon", false, 1)
        default: break
        }
        switch type {
        case .whistle:    return ("WhistleIcon", true, 1.6)
        case .clamp:      return ("ClampIcon", false, 1.44)
        case .gameBreak:  return ("GameBreakIcon", false, 1)
        default:          return nil
        }
    }

    /// Turning applied to the icon, in degrees clockwise.
    var iconRotation: Double {
        switch id {
        case "shot-creator": return 90
        default: return 0
        }
    }

    /// A second, smaller symbol set off from the main one — the ball leaving the hand on
    /// a Fadeaway, or the ball a Putback tips back up. Sizes and offsets are fractions of
    /// the icon's own side.
    ///
    /// Worn by drawn artwork as well as by symbols, so a card whose icon is an SVG can
    /// still take the game's own ball rather than one baked into the drawing.
    var accentSymbol: (name: String, scale: CGFloat, x: CGFloat, y: CGFloat, turn: Double)? {
        switch id {
        case "fadeaway": return ("basketball.fill", 0.21, 0.40, -0.46, 0)
        // The hand is drawn art and the ball is not, which is the point — the ball a
        // Putback tips is the same ball every other card draws.
        case "putback-tip": return ("basketball.fill", 0.50, 0.24, -0.30, 0)
        // A second pair of prints, so the walk is four steps rather than two.
        case "travel":   return ("shoeprints.fill", 0.82, 0.34, 0.30, 14)
        default:         return nil
        }
    }

    /// Turns the main symbol alone, leaving any accent to its own angle. Distinct from
    /// `iconRotation`, which turns the whole icon.
    var symbolRotation: Double {
        id == "travel" ? -11 : 0
    }

    /// Nudges an icon that turning has thrown off centre.
    var iconYAdjust: CGFloat {
        id == "shot-creator" ? 0.02 : 0
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
        let figure = "(?i)SHOT\\s*[+\\-\u{2212}=]?\\s*\\d+%"
        let bare = "^\\s*\(figure)\\s*$"

        // "More" only makes sense as a second helping. A card with one figure — Contest's
        // "Next player: SHOT -25%" — is stating its whole effect, not adding to it.
        let hasBaseFigure = effect
            .split(whereSeparator: { $0 == "." })
            .contains { $0.trimmingCharacters(in: .whitespaces)
                .range(of: bare, options: .regularExpression) != nil }
        let kept = text
            .split(whereSeparator: { $0 == "." })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { sentence -> String? in
                // A bare figure is the card's own SHOT. On a pass the badge shows it, so
                // it goes; anywhere else the words are the only place it appears, and it
                // stays exactly as written — it is not a bonus, so never "More".
                if sentence.range(of: bare, options: .regularExpression) != nil {
                    return type == .pass ? nil : sentence
                }
                guard hasBaseFigure else { return sentence }
                // Anything else carrying a figure is a separate, conditional modifier —
                // Drive's "Following Dribble" is a second bonus, not a restatement.
                guard sentence.range(of: "for each", options: .caseInsensitive) == nil else {
                    return sentence
                }
                // An `=` figure replaces the number rather than adding to it, so there is
                // no "more" about it — Putback Tip's hundred per cent off the glass is
                // the whole SHOT, not a hundred on top of one.
                guard sentence.range(of: "(?i)SHOT\\s*=",
                                     options: .regularExpression) == nil else {
                    return sentence
                }
                return sentence.replacingOccurrences(
                    of: "(?i)SHOT\\s*([+\\-\u{2212}=]?\\s*\\d+%)",
                    with: "$1 More", options: .regularExpression)
            }

        return kept.joined(separator: ". ")
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ."))
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
        case "shooting-slump":              return "snowflake"
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
        case "fox-like-first-step":         return "hare.fill"
        case "gravity":                     return "globe.desk.fill"
        case "like-that":                   return "hand.thumbsup.fill"
        case "no-bag":                      return "bag.badge.minus"
        case "point-god":                   return "crown.fill"
        case "sixth-man":                   return "6.circle.fill"
        case "sniper":                      return "scope"
        case "splash-cousin":               return "drop.fill"
        case "unguardable":                 return "figure.walk.motion.trianglebadge.exclamationmark"
        case "lethal-shooter":              return "target"
        case "ball-pounder":                return "arrow.down.circle.fill"
        case "unselfish":                   return "heart.circle.fill"
        case "trade-deadline":              return "arrow.trianglehead.2.clockwise.rotate.90"
        case "fresh-ball":                  return "basketball"
        case "wet-spot":                    return "drop.triangle.fill"
        case "floor-cleanup":               return "wind"
        case "official-timeout":            return "cross.circle.fill"
        case "free-agent":                  return "figure.wave"
        case "villainous-reputation":       return "theatermask.and.paintbrush.fill"
        case "dirty-player":                return "hand.raised.fingers.spread.fill"
        case "franchise-player":            return "person.crop.rectangle.badge.plus"
        case "team-doctor":                 return "stethoscope"
        case "wide-open-three":             return "person.3.sequence.fill"
        case "hand-off":                    return "hands.and.sparkles"
        case "outlet-pass":                 return "arrow.up.right.circle.fill"
        case "kick-out":                    return "arrow.turn.up.right"
        case "alley-oop":                   return "arrow.up.forward.circle.fill"
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
        case .intangible:   return "sparkles"
        }
    }
    var isMove: Bool { type == .move }

    /// Always concrete on a dealt card — `buildDeck` bakes the passing bonus in.
    var baseShotDelta: Int { shotDelta ?? 0 }

    /// A copy with the match's passing increment written in, so the card carries its own
    /// number rather than pointing at one.
    func resolved(passShotBonus: Int) -> CardDescriptor {
        guard shotDelta == nil, isPass else { return self }
        var copy = self
        copy.shotDelta = passShotBonus
        return copy
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
