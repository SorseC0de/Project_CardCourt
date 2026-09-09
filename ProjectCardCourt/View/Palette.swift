import Observation
import SwiftUI

/// **Which of the two palettes the game is painted in**, so they can be told apart on the
/// only screen that has been telling the truth.
///
/// The muted set is not a guess at a mood. It is what a screenshot of the game recorded:
/// macOS captured the Display P3 signal the panel was actually emitting and tagged the
/// file sRGB, so the numbers are the same colours written in P3 and then read as though
/// they were not. Measured off `desat.png` — blue came back `#3A79BB` against a shipped
/// `#147CC1`, and every other colour matched the same conversion to within a point.
///
/// Read as sRGB those numbers are a real palette, about a third less chroma across the
/// board. Whether it is the better one is a question for the phone, which is what this
/// exists to answer.
@Observable
@MainActor
final class Palette {
    static let shared = Palette()

    /// **Off ships the palette we have.** Nothing about the toggle survives a launch: it
    /// is an instrument for looking, not a setting.
    var muted = false

    /// One colour, either way. Called by every member of `CardPalette`.
    ///
    /// Static and unisolated so a colour can still be read from anywhere a colour was
    /// read from before — the flag itself is main-actor, and every caller is drawing.
    nonisolated static func pick(_ shipped: String, _ muted: String) -> Color {
        MainActor.assumeIsolated { colour(shared.muted ? muted : shipped) }
    }

    private static func colour(_ hex: String) -> Color {
        let digits = Array(hex)
        func part(_ at: Int) -> Double {
            Double(Int(String(digits[at...(at + 1)]), radix: 16) ?? 0) / 255
        }
        return Color(red: part(0), green: part(2), blue: part(4))
    }
}
