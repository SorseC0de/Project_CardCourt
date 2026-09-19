import SwiftUI

/// Lettering that starts big on the left and falls away to the right.
///
/// The Persona 5 trick: the line is not one size with a slant applied, it is a *ramp* —
/// the first letter is the loudest thing on screen and every letter after it gives a
/// little back. Read left to right that is a voice trailing off, which is why it reads as
/// spoken rather than printed.
///
/// Built a character at a time rather than as one `Text`, because concatenated text can
/// carry per-run colour but not per-run *shadow* — and a word picked out in gold with its
/// own orange drop, inside a white line with a navy one, is the whole reason this exists.
/// Characters sit on a shared baseline, so the tops fall away and the feet stay put.
struct ActionText: View {
    /// A stretch of the line with its own colours. One is the common case.
    struct Run {
        var text: String
        var ink: Color = .white
        var drop: Color = CardPalette.navy

        init(_ text: String, ink: Color = .white, drop: Color = CardPalette.navy) {
            self.text = text
            self.ink = ink
            self.drop = drop
        }
    }

    var runs: [Run]
    var font = Chrome.display
    /// The first character's size. Everything else is a share of it.
    var size: CGFloat
    /// What the last character comes out at, as a share of the first.
    var taper: CGFloat = 0.55
    /// Both as shares of each character's own size, so they taper with it.
    var tracking: CGFloat = 0.02
    var dropShare: CGFloat = 0.10
    /// An outline behind every letter, each at a radius of its own size. Nil for the
    /// ordinary case, which is most of them.
    var outline: (ink: Color, share: CGFloat)?
    /// Characters to leave out **without leaving out their space**. The letter is still
    /// laid out, still tapers the ones after it, and still reports its frame — it simply
    /// is not drawn. For a wordmark whose first letter is a picture, which has to sit
    /// exactly where the letter would have.
    var blanked: Set<Int> = []

    /// **Whether to publish where each character landed.**
    ///
    /// Off unless somebody is listening, and exactly one thing ever is — the wordmark,
    /// which puts a ball on the dot of the i. It was on for every `ActionText` in the
    /// game: a `GeometryReader` and a preference write **per character**, on every layout
    /// pass, for every phase call, plate title and mode card on screen. That is what
    /// "Bound preference LetterFrames tried to update multiple times per frame" was, and
    /// it is a real cost rather than a warning about one.
    var reports = false

    /// The coordinate space letter frames are reported in. Declare it on whatever
    /// contains the text and read `LetterFrames`.
    static let space = "action-text"

    init(_ text: String, font: String = Chrome.display, size: CGFloat,
         ink: Color = .white, drop: Color = CardPalette.navy,
         taper: CGFloat = 0.55, tracking: CGFloat = 0.02, dropShare: CGFloat = 0.10,
         outline: (ink: Color, share: CGFloat)? = nil,
         blanked: Set<Int> = []) {
        self.runs = [Run(text, ink: ink, drop: drop)]
        self.font = font
        self.size = size
        self.taper = taper
        self.tracking = tracking
        self.dropShare = dropShare
        self.outline = outline
        self.blanked = blanked
    }

    init(runs: [Run], font: String = Chrome.display, size: CGFloat,
         taper: CGFloat = 0.55, tracking: CGFloat = 0.02, dropShare: CGFloat = 0.10) {
        self.runs = runs
        self.font = font
        self.size = size
        self.taper = taper
        self.tracking = tracking
        self.dropShare = dropShare
    }

    var body: some View {
        let letters = runs.flatMap { run in run.text.map { (character: $0, run: run) } }
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ForEach(letters.indices, id: \.self) { index in
                let along = letters.count > 1
                    ? CGFloat(index) / CGFloat(letters.count - 1) : 0
                let point = size * (1 - (1 - taper) * along)
                let out = blanked.contains(index)
                Text(String(letters[index].character))
                    .font(.custom(font, size: point))
                    .foregroundStyle(out ? .clear : letters[index].run.ink)
                    // Behind the letter, and sized to it — a background changes no layout
                    // and moves no baseline, which is the only reason the outline can be
                    // drawn per character at all.
                    .background {
                        if !out { ring(letters[index].character, point: point) }
                    }
                    .shadow(color: out ? .clear : letters[index].run.drop, radius: 0,
                            x: point * dropShare, y: point * dropShare)
                    .padding(.trailing, point * tracking)
                    .background { reporter(index) }
            }
        }
        .fixedSize()
    }

    /// One letter drawn all the way round itself.
    ///
    /// **The radius is a share of that letter's own size, not the run's.** A fixed radius
    /// outlines the big letters and floods the small ones, which on a tapered word means
    /// the last few close up into a blob.
    @ViewBuilder private func ring(_ character: Character, point: CGFloat) -> some View {
        if let outline {
            let radius = point * outline.share
            let points = Ring.points(radius: radius)
            ZStack {
                ForEach(0..<points, id: \.self) { step in
                    let turn = Double(step) / Double(points) * 2 * .pi
                    Text(String(character))
                        .font(.custom(font, size: point))
                        .foregroundStyle(outline.ink)
                        .offset(x: radius * cos(turn), y: radius * sin(turn))
                }
            }
            .fixedSize()
        }
    }

    /// Publishes where a character landed, for anything that has to sit on one — see
    /// `SwishWordmark`, which puts a ball on the dot of the i. Nothing at all unless it
    /// was asked for; see `reports`.
    @ViewBuilder private func reporter(_ index: Int) -> some View {
        if reports {
            GeometryReader { box in
                Color.clear.preference(
                    key: LetterFrames.self,
                    value: [index: box.frame(in: .named(ActionText.space))])
            }
        }
    }
}

/// How many copies it takes to draw a stroke by ringing a shape with itself.
enum Ring {
    /// Enough that the polygon the copies trace stays within `tolerance` of the circle
    /// they are standing in for.
    ///
    /// **A fixed count is wrong at both ends.** Twenty is extravagant on a hairline and
    /// twelve is visibly faceted on a heavy edge — the first cost a bench its frame rate
    /// and the second put jitter on every curve in the wordmark. This spends copies where
    /// the radius actually needs them, and none at all on a radius of nothing.
    static func points(radius: CGFloat, tolerance: CGFloat = 0.15) -> Int {
        guard radius > 0 else { return 0 }
        guard radius > tolerance else { return 4 }
        let step = acos(max(-1, min(1, 1 - tolerance / radius)))
        guard step > 0 else { return 48 }
        return min(48, max(6, Int((.pi / step).rounded(.up))))
    }
}

/// Where each character of an `ActionText` ended up. Read by whatever declared the space.
struct LetterFrames: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

#if DEBUG
#Preview("Action text") {
    VStack(alignment: .leading, spacing: 26) {
        ActionText("Select a Player", size: 54)
        ActionText(runs: [.init("to "),
                           .init("Inbound", ink: CardPalette.gold, drop: CardPalette.orange),
                           .init(" to!")],
                    size: 30)
        ActionText("Crashing the Glass", size: 40, ink: CardPalette.gold,
                    drop: CardPalette.orange, taper: 0.35)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Chrome.ground)
}
#endif
