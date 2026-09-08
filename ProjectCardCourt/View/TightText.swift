import SwiftUI
import UIKit

/// Wrapped text whose lines can sit closer together than the font's own leading.
///
/// `Text.lineSpacing()` clamps at zero — it will open lines up but never close them past
/// the natural leading, so a negative value does nothing. This wraps the string itself and
/// stacks the lines with negative spacing, which has no such floor.
///
/// Deliberately not a `UIViewRepresentable`: the cards are flattened with `drawingGroup`,
/// and a UIKit view cannot be rasterised into one.
struct TightText: View {
    let text: String
    let font: String
    let size: CGFloat
    let width: CGFloat
    /// Below 1 pulls the lines together; 1 is the font's own leading.
    var lineHeight: CGFloat = 1
    var tracking: CGFloat = 0
    var maxLines = 4
    /// Tried largest first; the first that fits within `maxLines` wins. Short effects end
    /// up large, long ones settle back to the base size.
    var scaleSteps: [CGFloat] = [1.25, 1.15, 1.05, 1]
    /// The hard drop under a marked run, as points. See `Marked`, which decides what is
    /// marked and in what colour — this only says how far the shadow falls.
    var markShadowOffset: CGFloat = 0
    /// Keywords the game draws rather than spells: `["Draw": "DrawIcon"]`.
    ///
    /// On a card in the hand the picture stands in for the word — the number beside it is
    /// the whole message. Raised to be read, the word comes back and the picture leads it.
    var glyphs: [String: String] = [:]
    /// How tall a drawn keyword is against the line it sits on.
    var glyphShare: CGFloat = CardLayout.keywordGlyphShare
    /// How far the picture rides above the line, against the type size. One sitting on
    /// the baseline reads as a letter rather than as a mark beside the writing.
    var glyphLift: CGFloat = 0
    /// Which card this is printed on, so a marked run can be inked for it. See `CardInk`.
    var type: CardType = .pass
    /// What the unmarked words are printed in.
    ///
    /// **Passed, not inherited.** These runs asked for `ShapeStyle.foreground`, which
    /// resolves to the environment's default rather than to the `foregroundStyle` set
    /// around this view — so every card's body text came out the primary colour. It
    /// showed up only on the two dark bodies, where the ink is the one thing that has to
    /// change: an Intangible's white text was printing black on near-black.
    var ink: Color = CardPalette.navy

    /// **Whether the marked spans are inked at all.**
    ///
    /// Colouring them costs the wrap: a run is its own view because a shadow is a view
    /// modifier, so the lines have to be broken by hand and stacked — and a hand wrap is
    /// worse than the one SwiftUI does for free. Off, the whole effect is one `Text` that
    /// wraps and shrinks the way any other string does, with the markers eaten on the way
    /// in. The colour is worth having and this is not the way to get it; the code stays
    /// so it can be tried again from a better direction.
    var highlight = false

    /// The size actually used, after the fit search.
    private var chosenSize: CGFloat {
        for step in scaleSteps where wrapped(at: size * step).count <= maxLines {
            return size * step
        }
        return size
    }

    private var uiFont: UIFont { uiFont(at: chosenSize) }

    private func uiFont(at points: CGFloat) -> UIFont {
        UIFont(name: font, size: points) ?? .systemFont(ofSize: points, weight: .bold)
    }

    /// The whole effect as one string, markers gone.
    private var plain: String {
        Marked.runs(of: text).map(\.text).joined()
    }

    var body: some View {
        if highlight { inked } else { straight }
    }

    /// One `Text`, wrapped and shrunk by SwiftUI. **Nothing is measured here**: the line
    /// breaks are the system's, which is the whole point of it.
    private var straight: some View {
        Text(plain)
            .font(.custom(font, size: size))
            .tracking(tracking)
            // The gap this view exists to close. `lineSpacing` cannot go under the
            // font's own leading, so the negative half of the dial is spent here.
            .lineSpacing(uiFont(at: size).lineHeight * (lineHeight - 1))
            .foregroundStyle(ink)
            .multilineTextAlignment(.center)
            .lineLimit(maxLines)
            .minimumScaleFactor(0.55)
            .frame(width: width)
    }

    private var inked: some View {
        let points = chosenSize
        return VStack(spacing: uiFont(at: points).lineHeight * (lineHeight - 1)) {
            ForEach(Array(wrapped(at: points).enumerated()), id: \.offset) { _, line in
                // Runs rather than one Text: a shadow is a view modifier, so a marked
                // span can only carry its own by being its own view.
                HStack(spacing: 0) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, run in
                        let drawn = glyph(for: run)
                        // **The picture is its own view, not one put inside a `Text`.**
                        // A `Text(Image:)` draws at the image's own size, and these are
                        // vectors five hundred points across — one of them came out
                        // bigger than the card it was printed on.
                        HStack(spacing: 0) {
                            if let drawn {
                                Image(drawn)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: points * glyphShare)
                                    .offset(y: -points * glyphLift)
                                Text(" ").font(.custom(font, size: points))
                            }
                            // **The word always prints.** A picture instead of it was
                            // the experiment: a card that says nothing in words is a card
                            // you have to have been told about. The picture leads it and
                            // is drawn under the cap height — a mark beside the writing.
                            Text(run.text)
                                .font(.custom(font, size: points))
                                .tracking(tracking)
                        }
                        .foregroundStyle(run.ink?.colour(on: type) ?? ink)
                        .shadow(color: run.ink?.shade(on: type) ?? .clear, radius: 0,
                                x: markShadowOffset, y: markShadowOffset)
                    }
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    /// The picture this run leads with, if it is a keyword the game draws.
    ///
    /// Matched on the run's first word, since the run is the marked span and the marker is
    /// around the keyword itself — anything after it inside the same span is the sentence
    /// carrying on and keeps its words.
    private func glyph(for run: Marked.Run) -> String? {
        guard run.ink == .keyword else { return nil }
        let word = run.text.prefix(while: { $0 != " " })
        return glyphs[String(word)]
    }

    /// Sentences break first, then each is balanced across the lines it needs.
    ///
    /// A plain greedy wrap strands the tail — "…if they shoot" leaves "shoot" alone on a
    /// line, and "TOV +1" splits after the word. Balancing spreads the words evenly over
    /// however many lines the sentence actually requires, which keeps those together.
    ///
    /// Every step of this carries the ink with the word. Colour cannot be found again once
    /// the string has been cut into lines: `@[Rhythm Dribble]` is one marked span and two
    /// words, and either of them may end up on either line.
    private func wrapped(at points: CGFloat) -> [[Marked.Run]] {
        var result: [[Marked.Run]] = []
        for sentence in sentences {
            result += balanced(sentence, at: points)
            if result.count > maxLines { break }
        }
        return result
    }

    /// One word, and what colour it is.
    private struct Word {
        var text: String
        var ink: Marked.Ink?
    }

    /// The text as sentences of words, markers already resolved.
    private var sentences: [[Word]] {
        var all: [[Word]] = []
        var current: [Word] = []
        for run in Marked.runs(of: text) {
            for piece in run.text.split(separator: " ", omittingEmptySubsequences: true) {
                // A full stop ends a sentence and is not printed, the way it never was.
                let parts = piece.split(separator: ".", omittingEmptySubsequences: false)
                for (index, part) in parts.enumerated() {
                    if !part.isEmpty { current.append(Word(text: String(part), ink: run.ink)) }
                    if index < parts.count - 1, !current.isEmpty {
                        all.append(current)
                        current = []
                    }
                }
            }
        }
        if !current.isEmpty { all.append(current) }
        return all
    }

    private func measure(_ words: [Word], at points: CGFloat) -> CGFloat {
        (words.map(\.text).joined(separator: " ") as NSString)
            .size(withAttributes: [.font: uiFont(at: points), .kern: tracking]).width
    }

    /// Splits into the fewest lines that fit, then evens them out.
    private func balanced(_ sentence: [Word], at points: CGFloat) -> [[Marked.Run]] {
        guard !sentence.isEmpty else { return [] }
        var count = 1
        while count < sentence.count && !fits(sentence, over: count, at: points) { count += 1 }
        return share(sentence, over: count, at: points).map(runs(of:))
    }

    private func fits(_ words: [Word], over count: Int, at points: CGFloat) -> Bool {
        share(words, over: count, at: points).allSatisfy { measure($0, at: points) <= width }
    }

    /// Fills each line to roughly its share of the total width, so the last line is never
    /// left holding a single orphan.
    private func share(_ words: [Word], over count: Int, at points: CGFloat) -> [[Word]] {
        guard count > 1 else { return [words] }
        let target = measure(words, at: points) / CGFloat(count)

        var lines: [[Word]] = []
        var current: [Word] = []
        for word in words {
            let candidate = current + [word]
            let remaining = count - lines.count
            // Never break just before the tail of a label: "Following Dribble:" is one
            // phrase, and splitting it leaves "Following" stranded on its own line.
            let closesLabel = word.text.hasSuffix(":")
            if !current.isEmpty, !closesLabel, measure(candidate, at: points) > target,
               remaining > 1, words.count - lines.count > remaining {
                lines.append(current)
                current = [word]
            } else {
                current = candidate
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    /// A line's words as runs: neighbours of the same colour join, and the space between
    /// two words rides on the first of them so a run never starts with one.
    private func runs(of line: [Word]) -> [Marked.Run] {
        var runs: [Marked.Run] = []
        for (index, word) in line.enumerated() {
            let text = word.text + (index < line.count - 1 ? " " : "")
            if var last = runs.last, last.ink == word.ink {
                last.text += text
                runs[runs.count - 1] = last
            } else {
                runs.append(Marked.Run(text: text, ink: word.ink))
            }
        }
        return runs
    }
}
