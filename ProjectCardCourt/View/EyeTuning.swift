import Observation
import SwiftUI

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

    /// Where this eye goes.
    ///
    /// Three answers in order: what was placed on this exact cell, what was placed on the
    /// whole sheet, and — failing both — what the code guessed. The middle one is what
    /// most sheets need, since a head that does not move wants one answer for sixteen
    /// frames.
    func spot(_ sheet: Sprite, frame: Int, eye: Eye) -> EyeSpot {
        EyeTable.spot(sheet.rawValue, frame: frame, eye: eye, in: tuned)
            ?? Self.guessed(sheet, frame: frame, eye: eye)
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

    /// How many of this sheet's cells have been placed, out of how many there are.
    func progress(_ sheet: Sprite) -> (done: Int, all: Int) {
        let all = sheet.frames * Eye.allCases.count
        let done = (0..<sheet.frames).reduce(0) { running, frame in
            running + Eye.allCases.count { tuned[Self.key(sheet, frame: frame, eye: $0)] != nil }
        }
        return (done, all)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tuned) else { return }
        UserDefaults.standard.set(data, forKey: Self.store)
        // **Also to the log, every time.** The table lives in `UserDefaults`, and a
        // rebuild from Xcode reinstalls the app and takes the container with it. A pass
        // nobody has printed yet is a pass one build away from being done twice.
        DevLog.say(.input, "eyes: \(tuned.count) placed")
    }

    // MARK: - Out

    /// The whole table as Swift, ready to paste in.
    var dump: String {
        EyeTable.source(from: tuned,
                        sheets: Sprite.allCases.map { (name: $0.rawValue, frames: $0.frames) })
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
