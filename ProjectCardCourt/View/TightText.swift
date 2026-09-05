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
    var glyphBefore: (word: String, symbol: String)?

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

    var body: some View {
        let points = chosenSize
        VStack(spacing: uiFont(at: points).lineHeight * (lineHeight - 1)) {
            ForEach(Array(wrapped(at: points).enumerated()), id: \.offset) { _, line in
                // Runs rather than one Text: a shadow is a view modifier, so a marked
                // span can only carry its own by being its own view.
                HStack(spacing: 0) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, run in
                        (glyph(for: run).map { Text(Image(systemName: $0)) + Text(" ") }
                            ?? Text(verbatim: "")
                            + Text(run.text))
                            .font(.custom(font, size: points))
                            .tracking(tracking)
                            .foregroundStyle(run.ink.map { AnyShapeStyle($0.colour) }
                                             ?? AnyShapeStyle(.foreground))
                            .shadow(color: run.ink?.shade ?? .clear, radius: 0,
                                    x: markShadowOffset, y: markShadowOffset)
                    }
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    /// The symbol this run leads with, if any.
    private func glyph(for run: Marked.Run) -> String? {
        guard run.ink != nil, let glyphBefore,
              run.text.localizedCaseInsensitiveContains(glyphBefore.word) else { return nil }
        return glyphBefore.symbol
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
