import Foundation
import CoreGraphics

/// **What the court's camera is framing.** The floor and everyone on it zoom; the HUD
/// icons over the court and everything above them do not — see `CourtView`.
///
/// Subjects are named rather than placed, so the court works out where they are standing
/// at the moment it draws — a ball in the air is followed across its flight.
struct CourtCamera: Equatable {
    enum Subject: Equatable {
        case seat(Seat)
        /// Wherever the ball is: in somebody's hands, or crossing between two.
        case ball
        /// A referee by his place in the crew, the first Whistle's man being nought.
        case referee(Int)
    }

    /// Framed together: the camera centres on the middle of them.
    var subjects: [Subject]
    /// One is the whole floor.
    var zoom: CGFloat
    /// How long the camera takes to get there.
    var seconds: Double = 0.5

    /// How long it takes to go back to the whole floor.
    static let release: Double = 0.5
    /// A lesson's slow-motion pass, followed across.
    static let lessonPass: CGFloat = 1.6
}

/// A pass leaving somebody's hands, which the court plays the throw off.
struct PassThrow: Identifiable, Equatable {
    let id = UUID()
    let from: Seat
    let to: Seat
    /// No-Look and Behind-the-Back go out behind him, wherever they are headed.
    let blind: Bool
    let at: Date
}
