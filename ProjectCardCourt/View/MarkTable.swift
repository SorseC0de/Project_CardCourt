import CoreGraphics
import Foundation

/// Where one eye sits on one cell of one sheet.
///
/// **Per eye, per frame, per sheet**, because that is how the drawing varies: a head that
/// turns hides one eye and lifts the other, a head that bobs takes both with it, and a
/// sheet drawn from behind has neither. Three named rules covered the easy cases and
/// nothing else; a table covers all of them and says exactly what it is doing.
struct Spot: Codable, Hashable {
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
enum Mark: String, CaseIterable, Codable {
    /// The eye the sheet is drawn with.
    case near
    /// Its reflection.
    case far
    /// The number on his back, set in a pixel face — see `PixelFont`. Placed the same
    /// way and for the same reason: a shirt moves with the man wearing it, so where the
    /// number sits is a fact about the frame, not about the shirt.
    case number

    /// The two that make a face. The number is placed alongside them and drawn its own
    /// way, so anything composing a face asks for these rather than for all of them.
    static let eyes: [Mark] = [.near, .far]

    var title: String {
        switch self {
        case .near:   return "Near"
        case .far:    return "Far"
        case .number: return "Number"
        }
    }

    /// The other one, for a sheet drawn facing the other way: the eye nearer the camera
    /// on one is the far one on its mirror. A number has no opposite — it is one thing.
    var other: Mark { self == .near ? .far : (self == .far ? .near : .number) }
}

/// How the table is written down and read back.
///
/// **No screen in here on purpose.** The lookup and the formatter are pure functions of a
/// dictionary, so `Tools/marks` compiles this very file and round-trips it: place cells,
/// dump them as source, parse the source back, and check every cell reads identical.
/// A tuning pass is an evening's work and nobody should do it twice.
enum MarkTable {
    /// The lookup on its own, over a plain dictionary, so it can be tested without a
    /// screen — and so the reader and the writer cannot disagree about what `*` means.
    static func spot(_ sheet: String, frame: Int, eye: Mark,
                     in table: [String: Spot]) -> Spot? {
        table["\(sheet)/\(frame)/\(eye.rawValue)"]
            ?? table["\(sheet)/\(Self.everyFrame)/\(eye.rawValue)"]
    }

    /// The frame that means all of them.
    static let everyFrame = "*"

    /// **The formatter, as a function of its inputs alone.** No sprites, no screen, no
    /// stored state — so it can be run and its output read before anybody spends an
    /// evening tuning against it. See `Tools/marks`.
    ///
    /// A sheet whose every cell holds the same answer is written once against `*`, which
    /// is what most of them are; the rest are written a cell at a time. When every cell
    /// of a sheet has been placed, the commonest answer takes the `*` and only the
    /// exceptions are spelled out — safe precisely because there is nothing left to fall
    /// back to.
    static func source(from table: [String: Spot],
                       sheets: [(name: String, frames: Int)]) -> String {
        var lines: [String] = []
        for sheet in sheets {
            var sheetLines: [String] = []
            for eye in Mark.allCases {
                let placed = (0..<sheet.frames).map {
                    table["\(sheet.name)/\($0)/\(eye.rawValue)"]
                }
                let known = placed.compactMap { $0 }
                guard !known.isEmpty else { continue }
                // Nothing missing, so a fallback cannot show through a `*`.
                if known.count == sheet.frames {
                    let common = known.reduce(into: [Spot: Int]()) { $0[$1, default: 0] += 1 }
                        .max { $0.value < $1.value }!.key
                    sheetLines.append(line(sheet.name, everyFrame, eye, common))
                    for (frame, spot) in known.enumerated() where spot != common {
                        sheetLines.append(line(sheet.name, String(frame), eye, spot))
                    }
                } else {
                    for (frame, spot) in placed.enumerated() {
                        guard let spot else { continue }
                        sheetLines.append(line(sheet.name, String(frame), eye, spot))
                    }
                }
            }
            guard !sheetLines.isEmpty else { continue }
            lines.append("    // \(sheet.name)")
            lines += sheetLines
        }
        guard !lines.isEmpty else {
            return "// Nothing placed yet — nudge an eye and press print again."
        }
        return "static let baked: [String: Spot] = [\n"
            + lines.joined(separator: "\n") + "\n]"
    }

    private static func line(_ sheet: String, _ frame: String, _ eye: Mark,
                             _ spot: Spot) -> String {
        "    \"\(sheet)/\(frame)/\(eye.rawValue)\": "
            + "Spot(x: \(trim(spot.x)), y: \(trim(spot.y)), shown: \(spot.shown)),"
    }

    private static func trim(_ value: CGFloat) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

}
