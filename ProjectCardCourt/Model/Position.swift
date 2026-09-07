import Foundation

/// Where a man plays.
///
/// **In the model, not in the kit.** It began as one more thing you pick about your own
/// hooper, and it stayed that way until the rim mattered: what a player throws down
/// instead of shooting turns on his position, and the rules cannot see `HooperKit`.
enum Position: String, CaseIterable, Identifiable, Codable, Hashable {
    case pointGuard = "PG"
    case shootingGuard = "SG"
    case smallForward = "SF"
    case powerForward = "PF"
    case centre = "C"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pointGuard:     return "Point Guard"
        case .shootingGuard:  return "Shooting Guard"
        case .smallForward:   return "Small Forward"
        case .powerForward:   return "Power Forward"
        case .centre:         return "Centre"
        }
}
    }
