import CoreGraphics

/// **How big each ball in play is against the plain one**, for the pixel ball — the drawings
/// already carry it, framed on the plain ball's side. Only the ones that differ are listed.
///
/// Written by `Tools/icons.py` on every run; measured off the drawings, so edit those.
enum BallSizes {
    static let share: [String: CGFloat] = [
        "hand-ball": 0.75,
    ]
}
