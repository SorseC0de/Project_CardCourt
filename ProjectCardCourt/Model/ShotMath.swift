import Foundation

/// One contribution to a shot, kept for the breakdown.
struct ShotStep: Hashable, Codable {
    let label: String
    /// The running total after this step.
    let total: Int
}

/// A shot's chance and how it got there.
struct ShotResolution: Hashable, Codable {
    let base: Int
    let steps: [ShotStep]
    let chance: Int
}

struct ShotModifier: Hashable, Codable {
    let label: String
    let amount: Double
}

/// A `SHOT = x%` card. Sits after the debuffs, so its condition reads the number the
/// player actually ended up with — Slam Dunk asks whether your shot *survived* to 70,
/// not whether it ever touched 70 earlier in the stack.
///
/// It **replaces** the running total rather than adjusting it, which cuts both ways on
/// purpose: Full-Court Heave's 25% is a floor as much as a ceiling, so a player buried
/// under Clamps can still reach for it and get exactly 25. Same idea as Pokémon TCG's
/// "ignore Weakness and Resistance".
struct ShotOverride: Hashable, Codable {
    let label: String
    let amount: Double
    /// nil is unconditional. Slam Dunk sets 70.
    var requiresAtLeast: Int?
}

/// What a shot collects, grouped by **class of operation** rather than by source.
/// A single card can contribute to more than one class.
struct ShotModifiers: Hashable, Codable {
    /// Flat deltas, in the order received.
    var adds: [ShotModifier] = []
    /// Applied after every add. Clutch Gene is the only multiplier in the sheet and
    /// Intangibles are 1-ofs, so two can never be live at once and stacking order is
    /// unreachable by construction.
    var multipliers: [ShotModifier] = []
    /// Clamp debuffs, after the multipliers, so a debuff's magnitude stays predictable
    /// instead of being scaled by the victim's own build.
    var debuffs: [ShotModifier] = []
    /// Any `SHOT = x%` card, not just the 100% ones. Beats every other layer, including
    /// debuffs. The only thing that outranks it is a Whistle cancelling the shot outright,
    /// which happens earlier — at interception, before this runs at all. **Only ever one**:
    /// when several claim it, `GameState.shotModifiers` decides which.
    var override: ShotOverride?
    /// Med Ball: no shot goes past this. The ball's own tier, so an Intangible's or the
    /// floor's override is not held to it.
    var ceiling: ShotOverride?

    var isEmpty: Bool {
        adds.isEmpty && multipliers.isEmpty && debuffs.isEmpty && override == nil
            && ceiling == nil
    }
}

enum ShotMath {

    /// Resolves in a fixed order: adds, multipliers, debuffs, override.
    ///
    /// A card contributes to whichever classes it uses, not to one layer. Slam Dunk's
    /// `SHOT +10%` is an add and its `SHOT = 100%` is an override — the same card in two
    /// places, which is the point of ordering by operation rather than by source.
    ///
    /// The floor and ceiling are applied **once, at the very end**. Clamping between
    /// steps would silently change the answer as soon as a multiplier is involved —
    /// `(40+20)x2-25` is 95 resolved once and 75 resolved step by step.
    static func resolve(base: Int, modifiers: ShotModifiers, rules: MatchRules) -> ShotResolution {
        var running = Double(base)
        var steps: [ShotStep] = []

        func record(_ label: String) {
            steps.append(ShotStep(label: label, total: Int(running.rounded())))
        }

        for add in modifiers.adds {
            running += add.amount
            record(add.label)
        }
        for multiplier in modifiers.multipliers {
            running *= multiplier.amount
            record(multiplier.label)
        }
        for debuff in modifiers.debuffs {
            running += debuff.amount
            record(debuff.label)
        }
        if let override = modifiers.override {
            let survived = Int(running.rounded())
            if override.requiresAtLeast.map({ survived >= $0 }) ?? true {
                running = override.amount
                record(override.label)
            }
        }
        if let ceiling = modifiers.ceiling, running > ceiling.amount {
            running = ceiling.amount
            record(ceiling.label)
        }

        return ShotResolution(base: base, steps: steps,
                              chance: max(rules.shotFloor,
                                          min(rules.shotCeiling, Int(running.rounded()))))
    }
}

extension GameState {
    /// What this seat's shot picks up beyond the ball's own SHOT.
    ///
    /// Each source appends to the class it belongs to; the calculation never changes.
    func shotModifiers(for seat: Seat, ignoringClamps: Bool = false,
                       fromThree: Bool = false) -> ShotModifiers {
        var modifiers = ShotModifiers()
        var passiveOverride: ShotOverride?
        // Injuries: Bone Bruise, on every shot.
        for injury in self[seat].injuries {
            if let bonus = injury.injury?.shotBonus, bonus != 0 {
                modifiers.adds.append(ShotModifier(label: injury.name, amount: Double(bonus)))
            }
        }
        // Adds first, in the order the passives were received.
        for passive in self[seat].intangibles {
            guard let effect = passive.intangible else { continue }
            guard pays(effect, for: seat, fromThree: fromThree) else { continue }
            if effect.shotBonus != 0 {
                modifiers.adds.append(ShotModifier(label: passive.name,
                                                   amount: Double(effect.shotBonus)))
            }
            if effect.shotMultiplier != 0 {
                modifiers.multipliers.append(ShotModifier(label: passive.name,
                                                          amount: effect.shotMultiplier))
            }
            if let over = effect.shotOverride {
                passiveOverride = ShotOverride(label: passive.name, amount: Double(over))
            }
        }
        // The floor's standing numbers: a flat bonus, Turnstile Tile's swing, and Kiddie
        // Court's low rim for a shot finished there.
        let floor = floorEffect
        if floor.shotBonus != 0 {
            modifiers.adds.append(ShotModifier(label: currentCourt.name,
                                               amount: Double(floor.shotBonus)))
        }
        if floor.turnstileSwing != 0 {
            let swing = turnstileUp ? floor.turnstileSwing : -floor.turnstileSwing
            modifiers.adds.append(ShotModifier(label: currentCourt.name, amount: Double(swing)))
        }
        if floor.dunkBonus != 0, dunking != nil {
            modifiers.adds.append(ShotModifier(label: currentCourt.name,
                                               amount: Double(floor.dunkBonus)))
        }
        // The Retiring Official: the look is better while he is working, for everybody.
        for whistle in armedWhistles {
            let paid = whistle.card.descriptor.whistle?.shotWhileWorking ?? 0
            guard paid != 0 else { continue }
            modifiers.adds.append(ShotModifier(label: whistle.card.name, amount: Double(paid)))
        }
        // Hero Ball: it pays the man taking the shot, since nobody can pass it to him.
        if let ball = currentBall, let paid = ball.variaball?.shotWhenShooting, paid != 0 {
            modifiers.adds.append(ShotModifier(label: ball.name, amount: Double(paid)))
        }
        // S.O.S: a three sold out for a two, at double the look.
        if sellingOut {
            modifiers.multipliers.append(ShotModifier(label: CardLibrary.sellOutStadium.name,
                                                      amount: 2))
        }
        let courtOverride = (floor.shotOverride ?? (floor.randomShotOverride ? courtShotRoll : nil))
            .map { ShotOverride(label: currentCourt.name, amount: Double($0)) }
        let ballOverride = currentBall.flatMap { ball -> ShotOverride? in
            if let flat = ball.variaball?.shotOverride {
                return ShotOverride(label: ball.name, amount: Double(flat))
            }
            // Bag'n Ball: the shot is worth the hand holding it.
            if let per = ball.variaball?.shotPerCardInHand, per > 0 {
                return ShotOverride(label: ball.name,
                                    amount: Double(min(100, self[seat].bag.count * per)))
            }
            return nil
        }
        // **One override, and the highest claim to it wins:** an Intangible, then the floor,
        // then the ball, then the card just played.
        // Sixth Man's button, pressed, is the Intangible's claim.
        let intangibleClaim = passiveShotOverride ?? passiveOverride
        modifiers.override = intangibleClaim ?? courtOverride ?? ballOverride ?? pendingShotOverride
        // Med Ball holds everything under it in the hierarchy, and nothing over it.
        if let cap = ballEffect.shotCeiling, intangibleClaim == nil, courtOverride == nil,
           let ball = currentBall {
            modifiers.ceiling = ShotOverride(label: ball.name, amount: Double(cap))
        }

        // Skyhook goes up over everybody: the debuff layer is skipped for this one shot.
        // Nothing is cancelled, though that makes no odds — Clamps come off at the end of
        // the possession anyway, and a shot ends one. Like That refuses every reduction
        // there is.
        let shrugs = self[seat].intangibles.contains {
            $0.intangible?.shotCannotBeReduced == true
        }
        // **Competitive is paid for the man being there**, not for ignoring him: rising
        // over a defender is the whole point of the card, so it reads the Clamps rather
        // than cancelling them — and walks straight into Goaltending's window doing it.
        if !self[seat].clamps.isEmpty {
            let over = self[seat].intangibles.reduce(0) { $0 + ($1.intangible?.shotOverClamp ?? 0) }
            if over != 0 {
                modifiers.adds.append(ShotModifier(label: "Competitive", amount: Double(over)))
            }
        }
        // **A man stepped around is a man who is not there for this shot.** Floater picks
        // one; Bankshot's Heads picks one; both are per-attempt rather than a clear.
        // A defender outside his band is a defender being shot over — see `bitingClamps`.
        let present = bitingClamps(on: seat).filter { !ignoredClamps.contains($0.id) }
        for clamp in (ignoringClamps || shrugs) ? [] : present {
            var debuff = clamp.card.clamp?.shotDebuff ?? 0
            guard debuff != 0 else { continue }
            // Smacktop: every Clamp takes a step more.
            if floorEffect.enhancesClamps, debuff < 0 { debuff -= 10 }
            modifiers.debuffs.append(ShotModifier(label: clamp.card.name, amount: Double(debuff)))
        }
        // Southpaw Shooter, before Like That, so a gain turned into a loss is still refused.
        if self[seat].intangibles.contains(where: { $0.intangible?.reversesShotChanges == true }) {
            modifiers.adds = modifiers.adds.map { ShotModifier(label: $0.label, amount: -$0.amount) }
            modifiers.debuffs = modifiers.debuffs.map { ShotModifier(label: $0.label, amount: -$0.amount) }
        }
        if self[seat].intangibles.contains(where: { $0.intangible?.shotCannotBeReduced == true }) {
            modifiers.adds.removeAll { $0.amount < 0 }
        }
        // **Splash Ball: a Three cannot miss.** The reason the table wants it gone.
        if fromThree, let sure = ballEffect.shotOverrideOnThrees {
            modifiers.override = ShotOverride(label: "Splash Ball", amount: Double(sure))
        }
        modifiers.override = modifiers.override.map { equalized($0, for: seat) }
        return modifiers
    }

    /// Whether a passive's conditions are met right now.
    ///
    /// One place for all of them, because a passive with two conditions — Clutch Gene
    /// wants a thin hand *or* a dying clock — reads as one question rather than as a
    /// chain of guards spread through the stack.
    private func pays(_ effect: IntangibleEffect, for seat: Seat, fromThree: Bool) -> Bool {
        if effect.requiresScoredLastRound && !self[seat].scoredLastRound { return false }
        // **Hot Hand belongs to the ball.** A run is a run with *this* rock; swap it and
        // the streak starts again, which makes changing somebody else's ball a way of
        // cooling them off.
        if effect.requiresScoredWithBall,
           self[seat].scoredWithBall != (ballCard?.id ?? Rules.regulationBallRun) {
            return false
        }
        if effect.requiresThree && !fromThree { return false }
        // **His own board, not just a board.** Both of these say "your own" on the card;
        // they were reading `possessionFromRebound`, which is true off anybody's miss —
        // so Lethal Shooter handed out its hundred per cent for cleaning up after
        // somebody else.
        if effect.requiresOwnRebound && !possessionFromOwnRebound { return false }
        if effect.requiresAfterOwnRebound && !possessionFromOwnRebound { return false }
        // Board-Crasher takes any board. Lethal Shooter is the one that still wants yours.
        if effect.requiresAfterAnyRebound && !possessionFromRebound { return false }
        if effect.requiresReceivedPass && lastPasser == nil { return false }
        if effect.requiresFirstAction && !isShootingFirst { return false }
        if let nth = effect.requiresNthShotOfRound, shotsThisRound + 1 != nth { return false }
        if effect.requiresAnySix, !anySix(for: seat) { return false }
        // Either half is enough. Both nil is no condition at all.
        if effect.requiresHandAtMost != nil || effect.requiresClockAtMost != nil {
            let thin = effect.requiresHandAtMost.map { self[seat].bag.count <= $0 } ?? false
            let late = effect.requiresClockAtMost.map { (shotClock ?? 99) <= $0 } ?? false
            if !thin && !late { return false }
        }
        return true
    }

    /// Whether a six is showing anywhere that matters, for Sixth Man.
    private func anySix(for seat: Seat) -> Bool {
        self[seat].bag.count == 6
            || shotClock == 6
            || shotsThisRound + 1 == 6
            || self[seat].score == 6
    }

    /// The second Shoot button — Sixth Man's while a six is showing, Equalizer's always. With
    /// both on the board, the better shot is the one offered.
    func shotOffer(for seat: Seat) -> ShotOverride? {
        let offers = self[seat].intangibles.compactMap { passive -> ShotOverride? in
            guard let effect = passive.intangible, let offered = effect.offersShotAt,
                  pays(effect, for: seat, fromThree: false) else { return nil }
            return equalized(ShotOverride(label: passive.name, amount: Double(offered)), for: seat)
        }
        return offers.max { $0.amount < $1.amount }
    }

    /// Equalizer: a SHOT = shot goes up at 100%, whatever it named.
    private func equalized(_ override: ShotOverride, for seat: Seat) -> ShotOverride {
        guard self[seat].intangibles.contains(where: { $0.intangible?.equalizesOverrides == true })
        else { return override }
        // Named for Equalizer, so the lit Shoot button shows the card doing it.
        return ShotOverride(label: "Equalizer", amount: 100,
                            requiresAtLeast: override.requiresAtLeast)
    }

    /// Catch & Shoot: nothing played yet this possession, or only the shot itself.
    private var isShootingFirst: Bool {
        guard let last = lastPlayThisPossession else { return true }
        return movesThisPossession <= 1 && CardLibrary.byID[last]?.takesShot == true
    }
}
