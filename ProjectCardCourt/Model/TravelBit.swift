import Foundation

// Hoisted out of View/TravelCutsceneView.swift. Which bit of business a travel plays
// is a fact about the turnover; `TravelCutsceneView` is how it is drawn. An
// unresolved nested type is also what was killing `TurnoverCutscene`'s synthesised
// Equatable — a stored property whose type will not resolve takes the conformance
// down with it.

enum TravelBit: CaseIterable {
    case footprints, roadTrip, flight

    /// How long the whole bit needs, word included.
    ///
    /// One hold for all three left the prints sitting there long after the joke had
    /// landed — the number was set for the plane, which has a circuit to fly.
    var hold: Double {
        switch self {
        case .footprints: return 4.2
        case .roadTrip:   return 5.4
        case .flight:     return 6.2
        }
    }
}

