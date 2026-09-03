import Foundation

/// Where a pass sends the ball. `backToPasser` resolves against state, not geometry.
enum PassTarget: String, Hashable, Codable {
    case left, right, across, backToPasser
}

/// What a Clamp does to whoever it lands on. Most Clamps attach to the next ball-holder,
/// which is what makes passing into a Clamp a real decision.
struct ClampEffect: Hashable, Codable {
    /// Bodies this Clamp puts next to its victim. Double-Team is two, Triple-Team three.
    var defenders = 1
    /// Feeds the debuff layer of the SHOT stack if the clamped player shoots.
    var shotDebuff: Int = 0
    /// Discarded at random when the clamped player's possession begins.
    var discardAtStart: Int = 0
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
}

/// A one-off that fires the moment it is drawn.
struct GameBreakEffect: Hashable, Codable {
    /// The drawer discards this many at random.
    var discard = 0
    /// Everyone discards down to this hand size.
    var everyoneDiscardsTo: Int?
    /// The drawer fills their hand up to this size. Every drawing Break works this way,
    /// so there is no "draw exactly N" variant to get them confused with.
    var drawUpTo: Int?
    /// Applied to the ball's SHOT for the rest of the possession.
    var shotThisPossession = 0
    /// Hands the ball to someone else. Not a pass — no SHOT, no assist.
    var givesBallAway = false
    /// No Whistle can fire for the rest of the round.
    var silencesWhistles = false
    /// The sheet gives Injuries their own type column, and they wear their own colour.
    var isInjury = false
    /// Free throws for whoever drew it. Nobody fouled them, so nobody hands the ball back.
    var freeThrows = 0
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
    /// Euro Step: flip until tails, paying out per head.
    /// Discard any number first, paying this much SHOT for each (Turnaround Three).
    var discardForShotBonus = 0
    var coinRunShot = 0
    var coinRunDraw = 0
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
    let comboBonus: Int
    /// Set on Whistles.
    let whistle: WhistleEffect?
    /// Part of the Dribble family, which Double Dribble watches for.
    let isDribble: Bool
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
         clockDelta: Int = 0, comboAfter: String? = nil, comboBonus: Int = 0,
         whistle: WhistleEffect? = nil, clamp: ClampEffect? = nil,
         intangible: IntangibleEffect? = nil, gameBreak: GameBreakEffect? = nil,
         special: SpecialMoveEffect? = nil, isDribble: Bool = false,
         freeThrowsPerClamp: Int = 0, clearsClamps: Bool = false,
         turnoverIfNoClamps: Bool = false) {
        self.id = id; self.name = name; self.type = type; self.effect = effect
        self.numberInDeck = numberInDeck; self.passTarget = passTarget
        self.shotDelta = shotDelta; self.drawCount = drawCount; self.clockDelta = clockDelta
        self.comboAfter = comboAfter; self.comboBonus = comboBonus
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
        case "shot-creator", "drive": return 90
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
