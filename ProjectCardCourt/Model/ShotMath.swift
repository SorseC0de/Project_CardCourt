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
/// purpose: Full-Court Heave's 10% is a floor as much as a ceiling, so a player buried
/// under Clamps can still reach for it and get exactly 10. Same idea as Pokémon TCG's
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
    /// which happens earlier — at interception, before this runs at all.
    var override: ShotOverride?

    var isEmpty: Bool {
        adds.isEmpty && multipliers.isEmpty && debuffs.isEmpty && override == nil
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
                modifiers.override = ShotOverride(label: passive.name, amount: Double(over))
            }
        }
        // A card's own `SHOT =` beats a passive's, being the thing just played.
        if let pending = pendingShotOverride { modifiers.override = pending }

        // Skyhook goes up over everybody: the debuff layer is skipped for this one shot.
        // Nothing is cancelled, though that makes no odds — Clamps come off at the end of
        // the possession anyway, and a shot ends one. Unguardable does the same thing for
        // a whole game, and Like That refuses every reduction there is.
        let shrugs = self[seat].intangibles.contains {
            $0.intangible?.ignoresClampDebuffs == true || $0.intangible?.shotCannotBeReduced == true
        }
        for clamp in (ignoringClamps || shrugs) ? [] : self[seat].clamps {
            let debuff = clamp.card.clamp?.shotDebuff ?? 0
            guard debuff != 0 else { continue }
            modifiers.debuffs.append(ShotModifier(label: clamp.card.name, amount: Double(debuff)))
        }
        if self[seat].intangibles.contains(where: { $0.intangible?.shotCannotBeReduced == true }) {
            modifiers.adds.removeAll { $0.amount < 0 }
        }
        return modifiers
    }

    /// Whether a passive's conditions are met right now.
    ///
    /// One place for all of them, because a passive with two conditions — Clutch Gene
    /// wants a thin hand *or* a dying clock — reads as one question rather than as a
    /// chain of guards spread through the stack.
    private func pays(_ effect: IntangibleEffect, for seat: Seat, fromThree: Bool) -> Bool {
        if effect.requiresScoredLastRound && !self[seat].scoredLastRound { return false }
        if effect.requiresThree && !fromThree { return false }
        if effect.requiresOwnRebound && !possessionFromRebound { return false }
        if effect.requiresAfterOwnRebound && !possessionFromRebound { return false }
        if effect.requiresReceivedPass && lastPasser == nil { return false }
        if let nth = effect.requiresNthShotOfRound, shotsThisRound + 1 != nth { return false }
        // Either half is enough. Both nil is no condition at all.
        if effect.requiresHandAtMost != nil || effect.requiresClockAtMost != nil {
            let thin = effect.requiresHandAtMost.map { self[seat].bag.count <= $0 } ?? false
            let late = effect.requiresClockAtMost.map { (shotClock ?? 99) <= $0 } ?? false
            if !thin && !late { return false }
        }
        return true
    }
}
