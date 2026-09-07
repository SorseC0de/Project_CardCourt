import Observation
import SwiftUI

/// Every eye on every sheet, tuned by hand and dumped as source.
///
/// Lives in `UserDefaults` while it is being worked out, and is meant to end up in
/// `MarkTuning.baked` — press Print in the gallery and paste what comes out. Until then
/// anything untouched falls back to what the code guessed, so a half-finished pass is
/// still a working game.
@Observable
@MainActor
final class MarkTuning {
    static let shared = MarkTuning()

    /// Sheet, frame and eye, flattened — a dictionary of dictionaries is three lookups
    /// and three places for a key to go missing.
    private var tuned: [String: Spot] = [:]

    private static let store = "eyes.tuned"
    private static let faceStore = "marks.numberFont"
    private static let sizeStore = "marks.numberSize"

    /// Which pixel face the numbers are set in, and how tall a digit is in art pixels.
    ///
    /// One choice for the whole game rather than per sheet: it is the same shirt on the
    /// same man, and a number that changed face between frames would be two shirts.
    var numberFont: String = NumberStyle.a.font { didSet { saveNumberStyle() } }
    var numberSize: CGFloat = 3 { didSet { saveNumberStyle() } }

    /// Which of the three the player picked. Named rather than described, because a
    /// pixel face at three points is not something a name can tell you about — you look
    /// at the three and choose one.
    var numberStyle: NumberStyle {
        get { NumberStyle.allCases.first { $0.font == numberFont } ?? .a }
        set { numberFont = newValue.font }
    }

    /// What is shown while placing. Four numbers rather than a hundred: a single digit, a
    /// pair of the same, a mixed pair and the widest there is — anything that fits those
    /// fits the rest.
    static let sampleNumbers = ["0", "00", "11", "47", "99"]

    private func saveNumberStyle() {
        UserDefaults.standard.set(numberFont, forKey: Self.faceStore)
        UserDefaults.standard.set(Double(numberSize), forKey: Self.sizeStore)
    }

    private init() {
        // Before anything can be drawn in the chosen face — see `PixelFont.register`.
        PixelFont.register()
        let store = UserDefaults.standard
        if let face = store.string(forKey: Self.faceStore) { numberFont = face }
        if let size = store.object(forKey: Self.sizeStore) as? Double {
            numberSize = CGFloat(size)
        }
        guard let data = UserDefaults.standard.data(forKey: Self.store),
              let read = try? JSONDecoder().decode([String: Spot].self, from: data)
        else { return }
        tuned = read
    }

    static func key(_ sheet: Sprite, frame: Int, eye: Mark) -> String {
        "\(sheet.rawValue)/\(frame)/\(eye.rawValue)"
    }

    /// Where this eye goes.
    ///
    /// Three answers in order: what was placed on this exact cell, what was placed on the
    /// whole sheet, and — failing both — what the code guessed. The middle one is what
    /// most sheets need, since a head that does not move wants one answer for sixteen
    /// frames.
    func spot(_ sheet: Sprite, frame: Int, eye: Mark) -> Spot {
        // Three layers, narrowest first: what is being tuned right now, what was tuned
        // and baked in, and — for a sheet nobody has been over — what the code guessed.
        MarkTable.spot(sheet.rawValue, frame: frame, eye: eye, in: tuned)
            ?? MarkTable.spot(sheet.rawValue, frame: frame, eye: eye, in: MarkTable.baked)
            ?? Self.guessed(sheet, frame: frame, eye: eye)
    }

    func set(_ spot: Spot, on sheet: Sprite, frame: Int, eye: Mark) {
        tuned[Self.key(sheet, frame: frame, eye: eye)] = spot
        save()
    }

    /// One frame's answer, given to every frame of the sheet. Most sheets want this —
    /// the head does not move on most of them — so it is one press rather than sixteen.
    func spread(from frame: Int, on sheet: Sprite, eye: Mark) {
        let spot = spot(sheet, frame: frame, eye: eye)
        for other in 0..<sheet.frames {
            tuned[Self.key(sheet, frame: other, eye: eye)] = spot
        }
        save()
    }

    /// One sheet's whole placement, given to another.
    ///
    /// **Some sheets are the same drawing twice.** A glance over one shoulder and the
    /// same glance over the other are one pass of work, not two — and so is a wave that
    /// holds the same head. Mirrored swaps the eyes and turns the offsets round: what was
    /// nearer the camera is the far one now, and a nudge to the right is a nudge to the
    /// left.
    func copy(from source: Sprite, to target: Sprite, mirrored: Bool) {
        guard source != target else { return }
        for frame in 0..<min(source.frames, target.frames) {
            for eye in Mark.allCases {
                var taken = spot(source, frame: frame, eye: mirrored ? eye.other : eye)
                if mirrored { taken.x = -taken.x }
                tuned[Self.key(target, frame: frame, eye: eye)] = taken
            }
        }
        save()
    }

    /// Back to what the code guessed, for one sheet.
    func forget(_ sheet: Sprite) {
        for frame in 0..<sheet.frames {
            for eye in Mark.allCases { tuned[Self.key(sheet, frame: frame, eye: eye)] = nil }
        }
        save()
    }

    /// Whether this sheet has been touched at all, so the gallery can say what is left.
    func isTuned(_ sheet: Sprite) -> Bool {
        (0..<sheet.frames).contains { frame in
            Mark.allCases.contains { tuned[Self.key(sheet, frame: frame, eye: $0)] != nil }
        }
    }

    /// How many of this sheet's cells have been placed, out of how many there are.
    func progress(_ sheet: Sprite) -> (done: Int, all: Int) {
        let all = sheet.frames * Mark.allCases.count
        let done = (0..<sheet.frames).reduce(0) { running, frame in
            running + Mark.allCases.count { tuned[Self.key(sheet, frame: frame, eye: $0)] != nil }
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
        MarkTable.source(from: tuned,
                        sheets: Sprite.allCases.map { (name: $0.rawValue, frames: $0.frames) })
    }

    // MARK: - What the code guessed

    /// The starting point: the three rules the sheets carried before there was a table,
    /// plus whatever the head does on that frame.
    ///
    /// Kept as the fallback rather than deleted, so an untouched sheet draws as it did
    /// and a half-finished pass is still a working game.
    static func guessed(_ sheet: Sprite, frame: Int, eye: Mark) -> Spot {
        let head = sheet.headShift(atFrame: frame)
        // **A number is never guessed.** There is no rule that says where one sits on a
        // shirt, so an unplaced one is not drawn — which also means a sheet with no
        // number needs nothing said about it.
        guard eye != .number else { return Spot(shown: false) }
        switch (sheet.face, eye) {
        case (.whole, _):
            return Spot(x: head.x, y: head.y)
        case (.profile, .near):
            return Spot(x: head.x, y: head.y)
        case (.glancing(let lift), .far):
            return Spot(x: head.x, y: head.y + lift)
        case (.glancing, .near):
            return Spot(x: head.x, y: head.y)
        // Profile's far eye is behind the nose; a sheet with no face has neither.
        default:
            return Spot(x: head.x, y: head.y, shown: false)
        }
    }
}
