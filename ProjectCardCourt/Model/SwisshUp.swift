import Foundation

/// The Zone: a player reaching a gear nobody can follow, for about three possessions.
///
/// Named for the shot, not the buff — a Swissh-Up is what a player pops when the game is
/// getting away from them. One at a time, popped at will on their own turn, and it burns
/// whether or not they do anything with it.
///
/// **Three possessions, and the one it is popped on is the first.** A player who pops one
/// and shoots has spent a third of it on that shot. The only exception is `empoweredPace`,
/// which pays out at the top of a possession and so has nothing to give on the turn it is
/// popped — its clock starts on the next one.
///
/// Two of them are not buffs at all but single acts: `sixthSense` and `downloaded` happen
/// once and are gone, so they carry no clock.
enum SwisshUp: String, CaseIterable, Codable, Hashable, Identifiable {
    case lockedIn, deadEye, quarterKing, unconscious, vastVision
    case empoweredPace, unguardable, sixthSense, downloaded

    var id: String { rawValue }

    var name: String {
        switch self {
        case .lockedIn:      return "Locked-In"
        case .deadEye:       return "Dead-Eye"
        case .quarterKing:   return "Quarter King"
        case .unconscious:   return "Unconscious"
        case .vastVision:    return "Vast Vision"
        case .empoweredPace: return "Empowered Pace"
        case .unguardable:   return "Unguardable"
        case .sixthSense:    return "Sixth Sense"
        case .downloaded:    return "Downloaded"
        }
    }

    /// What it says on the tin, in the sheet's own voice.
    var effect: String {
        switch self {
        case .lockedIn:      return "SHOT + 10%"
        case .deadEye:       return "Three-point attempts + 20%"
        case .quarterKing:   return "SHOT = 25% on your attempts"
        case .unconscious:   return "SHOT + 20% shooting first after taking a pass"
        case .vastVision:    return "Every pass you play is a pass of choice"
        case .empoweredPace: return "Draw 1 additional card for turn"
        case .unguardable:   return "Clamps have no effect on you"
        case .sixthSense:    return "Draw up to a hand of 6"
        case .downloaded:    return "Replace your hand from the top of the discard pile"
        }
    }

    // ── What it does, read rather than switched on ──────────────────────────
    //
    // Every one of these is a number or a flag the rules can ask for, so the shot maths
    // and the draw both stay one place that reads a buff rather than nine places that
    // know about Swissh-Ups.

    /// Added to every attempt.
    var shotBonus: Int { self == .lockedIn ? 10 : 0 }
    /// Added to attempts from behind the arc, on top of anything else.
    var threeBonus: Int { self == .deadEye ? 20 : 0 }
    /// What the attempt is worth instead, whatever the board reads.
    var shotOverride: Int? { self == .quarterKing ? 25 : nil }
    /// Added to an attempt taken as the first action after a pass arrived.
    var shotAfterCatch: Int { self == .unconscious ? 20 : 0 }
    /// Every pass names its man, whatever the card says.
    var aimsEveryPass: Bool { self == .vastVision }
    /// On top of the one every possession opens with.
    var bonusDrawPerTurn: Int { self == .empoweredPace ? 1 : 0 }
    /// Clamps do nothing at all — not the SHOT, not the locks, not the pass-only.
    var ignoresClamps: Bool { self == .unguardable }
    /// Filled up to this the moment it is popped.
    var drawsUpTo: Int? { self == .sixthSense ? 6 : nil }
    /// The hand goes back and the same number comes off the discard pile — Game Breaks and
    /// Whistles passed over, since neither is a card anybody may hold and play.
    var takesFromDiscard: Bool { self == .downloaded }

    /// How many possessions it lasts. Zero is a single act rather than a state.
    var possessions: Int { drawsUpTo == nil && !takesFromDiscard ? 3 : 0 }

    /// Whether its clock starts on the next possession rather than this one. Only the one
    /// that pays at the top of a turn, which has already happened by the time it is popped.
    var startsNextPossession: Bool { self == .empoweredPace }
}

/// One popped, and what is left of it.
struct ActiveSwisshUp: Hashable, Codable {
    let kind: SwisshUp
    /// Possessions still to come, this one included. Nil while it waits for the next one
    /// to start — see `SwisshUp.startsNextPossession`.
    var left: Int
    var waiting: Bool = false
}
