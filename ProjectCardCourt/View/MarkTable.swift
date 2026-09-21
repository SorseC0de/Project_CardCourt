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

/// The three faces a number can be set in.
///
/// **One choice for the whole court.** It is the same league, so all four men wear the
/// same numbering — a style per player would read as four different competitions.
enum NumberStyle: String, CaseIterable, Identifiable, Codable {
    case a, b, c

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    var font: String {
        switch self {
        case .a: return "PressStart2P"
        case .b: return "Teeny-Tiny-Pixls"
        case .c: return "Dogica_Pixel"
        }
    }
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

extension MarkTable {
    /// **Placed by hand, one sheet at a time.** Everything not named here falls through to
    /// `MarkTuning.guessed`, which is why a sheet nobody has been over still draws.
    ///
    /// `*` is every frame; a numbered frame beats it. Written out by the gallery's print
    /// button — do not hand-edit, tune and print again.
    static let baked: [String: Spot] = [
        // Player_Catch
        "Player_Catch/*/near": Spot(x: 0, y: 0, shown: false),
        "Player_Catch/0/near": Spot(x: 0, y: -2, shown: true),
        "Player_Catch/1/near": Spot(x: 0, y: -1, shown: true),
        "Player_Catch/2/near": Spot(x: 1, y: 0, shown: true),
        "Player_Catch/3/near": Spot(x: 1, y: -1, shown: true),
        "Player_Catch/4/near": Spot(x: 0, y: -2, shown: true),
        "Player_Catch/5/near": Spot(x: -1, y: -1, shown: true),
        "Player_Catch/0/far": Spot(x: -5, y: -3, shown: true),
        "Player_Catch/1/far": Spot(x: -5, y: -2, shown: true),
        "Player_Catch/2/far": Spot(x: -4, y: -1, shown: true),
        "Player_Catch/3/far": Spot(x: -4, y: -2, shown: true),
        "Player_Catch/4/far": Spot(x: -5, y: -3, shown: true),
        "Player_Catch/5/far": Spot(x: -1, y: 0, shown: false),
        // Player_Dribble
        "Player_Dribble/*/near": Spot(x: 0, y: -1, shown: false),
        "Player_Dribble/*/far": Spot(x: 0, y: 0, shown: false),
        "Player_Dribble/*/number": Spot(x: 0, y: -1, shown: true),
        "Player_Dribble/0/number": Spot(x: 0, y: -2, shown: true),
        "Player_Dribble/1/number": Spot(x: 1, y: -1, shown: true),
        "Player_Dribble/2/number": Spot(x: 1, y: 0, shown: true),
        "Player_Dribble/4/number": Spot(x: -1, y: -2, shown: true),
        "Player_Dribble/5/number": Spot(x: -1, y: -1, shown: true),
        "Player_Dribble/6/number": Spot(x: 0, y: 0, shown: true),
        "Player_Dribble/8/number": Spot(x: 0, y: -2, shown: true),
        "Player_Dribble/9/number": Spot(x: 1, y: -1, shown: true),
        "Player_Dribble/10/number": Spot(x: 1, y: 0, shown: true),
        "Player_Dribble/12/number": Spot(x: -1, y: -2, shown: true),
        "Player_Dribble/13/number": Spot(x: -1, y: -1, shown: true),
        "Player_Dribble/14/number": Spot(x: 0, y: 0, shown: true),
        // Player_Run
        "Player_Run/*/near": Spot(x: 0, y: -1, shown: false),
        "Player_Run/*/far": Spot(x: 0, y: 0, shown: false),
        "Player_Run/*/number": Spot(x: 0, y: -1, shown: true),
        "Player_Run/0/number": Spot(x: 0, y: -2, shown: true),
        "Player_Run/1/number": Spot(x: 1, y: -1, shown: true),
        "Player_Run/2/number": Spot(x: 1, y: 0, shown: true),
        "Player_Run/4/number": Spot(x: -1, y: -2, shown: true),
        "Player_Run/5/number": Spot(x: -1, y: -1, shown: true),
        "Player_Run/6/number": Spot(x: 0, y: 0, shown: true),
        "Player_Run/8/number": Spot(x: 0, y: -2, shown: true),
        "Player_Run/9/number": Spot(x: 1, y: -1, shown: true),
        "Player_Run/10/number": Spot(x: 1, y: 0, shown: true),
        "Player_Run/12/number": Spot(x: -1, y: -2, shown: true),
        "Player_Run/13/number": Spot(x: -1, y: -1, shown: true),
        "Player_Run/14/number": Spot(x: 0, y: 0, shown: true),
        // Player_Run_Look
        "Player_Run_Look/*/near": Spot(x: 0, y: -1, shown: false),
        "Player_Run_Look/11/near": Spot(x: -2, y: -2, shown: true),
        "Player_Run_Look/12/near": Spot(x: -2, y: -3, shown: true),
        "Player_Run_Look/13/near": Spot(x: -2, y: -2, shown: true),
        "Player_Run_Look/14/near": Spot(x: -2, y: -1, shown: true),
        "Player_Run_Look/*/far": Spot(x: 0, y: 0, shown: false),
        "Player_Run_Look/10/far": Spot(x: -4, y: 0, shown: true),
        "Player_Run_Look/11/far": Spot(x: -3, y: -1, shown: true),
        "Player_Run_Look/12/far": Spot(x: -3, y: -2, shown: true),
        "Player_Run_Look/13/far": Spot(x: -3, y: -1, shown: true),
        "Player_Run_Look/14/far": Spot(x: -3, y: 0, shown: true),
        "Player_Run_Look/15/far": Spot(x: -4, y: -1, shown: true),
        "Player_Run_Look/*/number": Spot(x: 0, y: -1, shown: true),
        "Player_Run_Look/0/number": Spot(x: 0, y: -2, shown: true),
        "Player_Run_Look/1/number": Spot(x: 1, y: -1, shown: true),
        "Player_Run_Look/2/number": Spot(x: 1, y: 0, shown: true),
        "Player_Run_Look/4/number": Spot(x: -1, y: -2, shown: true),
        "Player_Run_Look/5/number": Spot(x: -1, y: -1, shown: true),
        "Player_Run_Look/6/number": Spot(x: 0, y: 0, shown: true),
        "Player_Run_Look/8/number": Spot(x: 0, y: -2, shown: true),
        "Player_Run_Look/9/number": Spot(x: 1, y: -1, shown: true),
        "Player_Run_Look/10/number": Spot(x: 1, y: 0, shown: true),
        "Player_Run_Look/12/number": Spot(x: -1, y: -2, shown: true),
        "Player_Run_Look/13/number": Spot(x: -1, y: -1, shown: true),
        "Player_Run_Look/14/number": Spot(x: 0, y: 0, shown: true),
        // Player_Run_Look2
        "Player_Run_Look2/*/near": Spot(x: 0, y: 0, shown: false),
        "Player_Run_Look2/10/near": Spot(x: 4, y: 0, shown: true),
        "Player_Run_Look2/11/near": Spot(x: 3, y: -1, shown: true),
        "Player_Run_Look2/12/near": Spot(x: 3, y: -2, shown: true),
        "Player_Run_Look2/13/near": Spot(x: 3, y: -1, shown: true),
        "Player_Run_Look2/14/near": Spot(x: 3, y: 0, shown: true),
        "Player_Run_Look2/15/near": Spot(x: 4, y: -1, shown: true),
        "Player_Run_Look2/*/far": Spot(x: 0, y: -1, shown: false),
        "Player_Run_Look2/11/far": Spot(x: 2, y: -2, shown: true),
        "Player_Run_Look2/12/far": Spot(x: 2, y: -3, shown: true),
        "Player_Run_Look2/13/far": Spot(x: 2, y: -2, shown: true),
        "Player_Run_Look2/14/far": Spot(x: 2, y: -1, shown: true),
        "Player_Run_Look2/*/number": Spot(x: 0, y: -1, shown: true),
        "Player_Run_Look2/0/number": Spot(x: 0, y: -2, shown: true),
        "Player_Run_Look2/1/number": Spot(x: 1, y: -1, shown: true),
        "Player_Run_Look2/2/number": Spot(x: 1, y: 0, shown: true),
        "Player_Run_Look2/4/number": Spot(x: -1, y: -2, shown: true),
        "Player_Run_Look2/5/number": Spot(x: -1, y: -1, shown: true),
        "Player_Run_Look2/6/number": Spot(x: 0, y: 0, shown: true),
        "Player_Run_Look2/8/number": Spot(x: 0, y: -2, shown: true),
        "Player_Run_Look2/9/number": Spot(x: 1, y: -1, shown: true),
        "Player_Run_Look2/10/number": Spot(x: 1, y: 0, shown: true),
        "Player_Run_Look2/11/number": Spot(x: 0, y: 0, shown: true),
        "Player_Run_Look2/12/number": Spot(x: -1, y: -2, shown: true),
        "Player_Run_Look2/13/number": Spot(x: -1, y: -1, shown: true),
        "Player_Run_Look2/14/number": Spot(x: 0, y: 0, shown: true),
        // Player_Wave
        "Player_Wave/*/near": Spot(x: 0, y: -1, shown: false),
        "Player_Wave/*/far": Spot(x: 0, y: 0, shown: false),
        "Player_Wave/*/number": Spot(x: 2, y: -1, shown: true),
        "Player_Wave/0/number": Spot(x: 0, y: -2, shown: true),
        "Player_Wave/1/number": Spot(x: 1, y: -1, shown: true),
        "Player_Wave/2/number": Spot(x: 1, y: 0, shown: true),
        "Player_Wave/3/number": Spot(x: 0, y: -1, shown: true),
        "Player_Wave/4/number": Spot(x: -1, y: -2, shown: true),
        "Player_Wave/5/number": Spot(x: -1, y: -1, shown: true),
        "Player_Wave/6/number": Spot(x: 0, y: 0, shown: true),
        "Player_Wave/7/number": Spot(x: 0, y: -1, shown: true),
        "Player_Wave/8/number": Spot(x: 0, y: -2, shown: true),
        "Player_Wave/10/number": Spot(x: 1, y: 0, shown: true),
        "Player_Wave/11/number": Spot(x: 2, y: -2, shown: true),
        "Player_Wave/13/number": Spot(x: 2, y: 0, shown: true),
        "Player_Wave/15/number": Spot(x: 2, y: -2, shown: true),
        // Player_Inbounder
        "Player_Inbounder/*/near": Spot(x: 0, y: 0, shown: true),
        "Player_Inbounder/1/near": Spot(x: 1, y: 0, shown: true),
        "Player_Inbounder/3/near": Spot(x: -1, y: 0, shown: true),
        "Player_Inbounder/*/far": Spot(x: 0, y: 0, shown: true),
        "Player_Inbounder/1/far": Spot(x: 1, y: 0, shown: true),
        "Player_Inbounder/3/far": Spot(x: -1, y: 0, shown: true),
        // Player_Inbound_Receiver_Back
        "Player_Inbound_Receiver_Back/*/number": Spot(x: 0, y: 0, shown: true),
        // Player_Shoot
        "Player_Shoot/*/number": Spot(x: 0, y: 1, shown: true),
        "Player_Shoot/0/number": Spot(x: 0, y: 0, shown: true),
        "Player_Shoot/3/number": Spot(x: 0, y: 0, shown: true),
        "Player_Shoot/4/number": Spot(x: 0, y: -1, shown: true),
        "Player_Shoot/5/number": Spot(x: 0, y: -1, shown: true),
        "Player_Shoot/6/number": Spot(x: 0, y: -6, shown: true),
        "Player_Shoot/7/number": Spot(x: 0, y: -8, shown: true),
        "Player_Shoot/8/number": Spot(x: 0, y: -8, shown: true),
        "Player_Shoot/9/number": Spot(x: 0, y: -7, shown: true),
        "Player_Shoot/10/number": Spot(x: 0, y: 0, shown: true),
        // Player_Layup
        "Player_Layup/1/far": Spot(x: -5, y: -2, shown: true),
        "Player_Layup/2/far": Spot(x: -4, y: -3, shown: true),
        "Player_Layup/3/far": Spot(x: -5, y: -5, shown: true),
        "Player_Layup/*/number": Spot(x: 1, y: -1, shown: true),
        "Player_Layup/1/number": Spot(x: 1, y: 0, shown: true),
        "Player_Layup/3/number": Spot(x: 1, y: -3, shown: true),
        // Player_back
        "Player_back/*/number": Spot(x: 0, y: 0, shown: true),
        // Player_right
        "Player_right/*/near": Spot(x: 4, y: 0, shown: true),
        // Player_akumapose
        "Player_akumapose/*/number": Spot(x: 0, y: 0, shown: true),
        // Player_rebound
        "Player_rebound/*/near": Spot(x: 0, y: 2, shown: true),
        "Player_rebound/1/near": Spot(x: 0, y: 3, shown: true),
        "Player_rebound/2/near": Spot(x: 0, y: -3, shown: true),
        "Player_rebound/3/near": Spot(x: 0, y: -4, shown: true),
        "Player_rebound/4/near": Spot(x: 0, y: -5, shown: true),
        "Player_rebound/*/far": Spot(x: 0, y: 2, shown: true),
        "Player_rebound/1/far": Spot(x: 0, y: 3, shown: true),
        "Player_rebound/2/far": Spot(x: 0, y: -3, shown: true),
        "Player_rebound/3/far": Spot(x: 0, y: -4, shown: true),
        "Player_rebound/4/far": Spot(x: 0, y: -5, shown: true),
        // Player_land
        "Player_land/*/near": Spot(x: 0, y: 3, shown: true),
        "Player_land/1/near": Spot(x: 0, y: 2, shown: true),
        "Player_land/2/near": Spot(x: 0, y: 0, shown: true),
        "Player_land/*/far": Spot(x: 0, y: 3, shown: true),
        "Player_land/1/far": Spot(x: 0, y: 2, shown: true),
        "Player_land/2/far": Spot(x: 0, y: 0, shown: true),
        // Player_land_back
        "Player_land_back/*/number": Spot(x: 0, y: 2, shown: true),
        "Player_land_back/1/number": Spot(x: 0, y: 1, shown: true),
        "Player_land_back/2/number": Spot(x: 0, y: 0, shown: true),
        // Player_dunk_prepare
        "Player_dunk_prepare/*/number": Spot(x: 0, y: 2, shown: true),
        "Player_dunk_prepare/0/number": Spot(x: 0, y: 1, shown: true),
        // Player_dunk_1hand
        "Player_dunk_1hand/*/number": Spot(x: 0, y: -1, shown: true),
        "Player_dunk_1hand/3/number": Spot(x: 0, y: 0, shown: true),
        "Player_dunk_1hand/4/number": Spot(x: 0, y: 0, shown: true),
        // Player_dunk_reverse
        "Player_dunk_reverse/0/near": Spot(x: 0, y: 0, shown: false),
        "Player_dunk_reverse/1/near": Spot(x: 0, y: 0, shown: false),
        "Player_dunk_reverse/2/near": Spot(x: 0, y: -2, shown: true),
        "Player_dunk_reverse/3/near": Spot(x: 0, y: -1, shown: true),
        "Player_dunk_reverse/0/far": Spot(x: 0, y: 0, shown: false),
        "Player_dunk_reverse/1/far": Spot(x: 0, y: 0, shown: false),
        "Player_dunk_reverse/2/far": Spot(x: 0, y: -2, shown: true),
        "Player_dunk_reverse/3/far": Spot(x: 0, y: -1, shown: true),
        "Player_dunk_reverse/0/number": Spot(x: 0, y: -1, shown: true),
        "Player_dunk_reverse/2/number": Spot(x: 0, y: -1, shown: false),
        // Player_dunk_whirlwind
        "Player_dunk_whirlwind/*/number": Spot(x: 0, y: -1, shown: true),
        "Player_dunk_whirlwind/7/number": Spot(x: 0, y: 0, shown: true),
        "Player_dunk_whirlwind/8/number": Spot(x: 0, y: 0, shown: true),
    ]
}
