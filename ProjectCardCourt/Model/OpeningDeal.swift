import Foundation

// Moved out of View/CourtStage.swift: who is dealt to, and how many each.

/// The opening deal: who gets cards, and how many each.
struct OpeningDeal: Identifiable, Equatable {
    let id: UUID
    /// Dealt in this order, one player at a time.
    let order: [Seat]
    let each: Int
}
