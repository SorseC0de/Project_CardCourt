import Observation
import SwiftUI

/// Where one eye sits on one cell of one sheet.
///
/// **Per eye, per frame, per sheet**, because that is how the drawing varies: a head that
/// turns hides one eye and lifts the other, a head that bobs takes both with it, and a
/// sheet drawn from behind has neither. Three named rules covered the easy cases and
/// nothing else; a table covers all of them and says exactly what it is doing.
struct EyeSpot: Codable, Hashable {
    /// Art pixels from the head's own origin, **as seen on screen**: right and down are
    /// positive for both eyes. The far eye is drawn flipped, so its offset is turned
    /// round on the way in — nudging it right moves it right.
    var x: CGFloat = 0
    var y: CGFloat = 0
    /// Whether it is drawn at all. A man in profile has one eye; a man with his back
    /// turned has none.
    var shown = true
}

/// Which of the two.
///
/// The sheet holds one eye and the other is a flipped copy of it, so they are named for
/// what they are rather than left and right — which swaps meaning the moment the whole
/// figure mirrors.
enum Eye: String, CaseIterable, Codable {
    /// The one the sheet is drawn with.
    case near
    /// Its reflection.
    case far

    var title: String { self == .near ? "Near" : "Far" }
}

/// Every eye on every sheet, tuned by hand and dumped as source.
///
/// Lives in `UserDefaults` while it is being worked out, and is meant to end up in
/// `EyeTuning.baked` — press Print in the gallery and paste what comes out. Until then
/// anything untouched falls back to what the code guessed, so a half-finished pass is
/// still a working game.
@Observable
@MainActor
final class EyeTuning {
    static let shared = EyeTuning()

    /// Sheet, frame and eye, flattened — a dictionary of dictionaries is three lookups
    /// and three places for a key to go missing.
    private var tuned: [String: EyeSpot] = [:]

    private static let store = "eyes.tuned"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: Self.store),
              let read = try? JSONDecoder().decode([String: EyeSpot].self, from: data)
        else { return }
        tuned = read
    }

    static func key(_ sheet: Sprite, frame: Int, eye: Eye) -> String {
        "\(sheet.rawValue)/\(frame)/\(eye.rawValue)"
    }

    /// Where this eye goes. Tuned if it has been; otherwise what the sheet's own rule
    /// says, which is where the tuning starts from rather than something it replaces.
    func spot(_ sheet: Sprite, frame: Int, eye: Eye) -> EyeSpot {
        tuned[Self.key(sheet, frame: frame, eye: eye)] ?? Self.guessed(sheet, frame: frame, eye: eye)
    }

    func set(_ spot: EyeSpot, on sheet: Sprite, frame: Int, eye: Eye) {
        tuned[Self.key(sheet, frame: frame, eye: eye)] = spot
        save()
    }

    /// One frame's answer, given to every frame of the sheet. Most sheets want this —
    /// the head does not move on most of them — so it is one press rather than sixteen.
    func spread(from frame: Int, on sheet: Sprite, eye: Eye) {
        let spot = spot(sheet, frame: frame, eye: eye)
        for other in 0..<sheet.frames {
            tuned[Self.key(sheet, frame: other, eye: eye)] = spot
        }
        save()
    }

    /// Back to what the code guessed, for one sheet.
    func forget(_ sheet: Sprite) {
        for frame in 0..<sheet.frames {
            for eye in Eye.allCases { tuned[Self.key(sheet, frame: frame, eye: eye)] = nil }
        }
        save()
    }

    /// Whether this sheet has been touched at all, so the gallery can say what is left.
    func isTuned(_ sheet: Sprite) -> Bool {
        (0..<sheet.frames).contains { frame in
            Eye.allCases.contains { tuned[Self.key(sheet, frame: frame, eye: $0)] != nil }
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tuned) else { return }
        UserDefaults.standard.set(data, forKey: Self.store)
    }

    // MARK: - Out

    /// The whole table as Swift, ready to paste into `baked`.
    ///
    /// Only what differs from the guess is written: a dump that repeats the default for
    /// every frame of every sheet is four hundred lines saying nothing.
    var dump: String {
        var lines: [String] = []
        for sheet in Sprite.allCases {
            var sheetLines: [String] = []
            for frame in 0..<sheet.frames {
                for eye in Eye.allCases {
                    let key = Self.key(sheet, frame: frame, eye: eye)
                    guard let spot = tuned[key],
                          spot != Self.guessed(sheet, frame: frame, eye: eye) else { continue }
                    sheetLines.append(
                        "    \"\(key)\": EyeSpot(x: \(trim(spot.x)), y: \(trim(spot.y)),"
                        + " shown: \(spot.shown)),")
                }
            }
            guard !sheetLines.isEmpty else { continue }
            lines.append("    // \(sheet.rawValue)")
            lines += sheetLines
        }
        guard !lines.isEmpty else { return "// nothing tuned yet" }
        return "static let baked: [String: EyeSpot] = [\n" + lines.joined(separator: "\n") + "\n]"
    }

    private func trim(_ value: CGFloat) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    // MARK: - What the code guessed

    /// The starting point: the three rules the sheets carried before there was a table,
    /// plus whatever the head does on that frame.
    ///
    /// Kept as the fallback rather than deleted, so an untouched sheet draws as it did
    /// and a half-finished pass is still a working game.
    static func guessed(_ sheet: Sprite, frame: Int, eye: Eye) -> EyeSpot {
        let head = sheet.headShift(atFrame: frame)
        switch (sheet.face, eye) {
        case (.whole, _):
            return EyeSpot(x: head.x, y: head.y)
        case (.profile, .near):
            return EyeSpot(x: head.x, y: head.y)
        case (.glancing(let lift), .far):
            return EyeSpot(x: head.x, y: head.y + lift)
        case (.glancing, .near):
            return EyeSpot(x: head.x, y: head.y)
        // Profile's far eye is behind the nose; a sheet with no face has neither.
        default:
            return EyeSpot(x: head.x, y: head.y, shown: false)
        }
    }
}
