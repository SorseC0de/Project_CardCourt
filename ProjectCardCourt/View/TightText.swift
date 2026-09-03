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
    /// A line matching this is drawn in its own colour. Applied per line rather than per
    /// run, because `Text` concatenation cannot carry a shadow on part of a string.
    var highlight: String?
    var highlightColour: Color = .primary
    var highlightShadow: Color = .clear
    var highlightShadowOffset: CGFloat = 0
    /// Card names appearing in the text, drawn in their own colour so a reference to
    /// another card reads as one. Matched longest-first, so "Rhythm Dribble" wins over
    /// "Dribble".
    var namedCards: [String] = []
    var nameColour: Color = .primary
    var nameShadow: Color = .clear

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
                let lit = highlight.map {
                    line.range(of: $0, options: .regularExpression) != nil
                } ?? false
                // Runs rather than one Text: a shadow is a view modifier, so a named card
                // can only carry its own by being its own view.
                HStack(spacing: 0) {
                    ForEach(Array(runs(of: line).enumerated()), id: \.offset) { _, run in
                        Text(run.text)
                            .font(.custom(font, size: points))
                            .tracking(tracking)
                            .foregroundStyle(run.isName ? AnyShapeStyle(nameColour)
                                             : lit ? AnyShapeStyle(highlightColour)
                                                   : AnyShapeStyle(.foreground))
                            .shadow(color: run.isName ? nameShadow : (lit ? highlightShadow : .clear),
                                    radius: 0, x: highlightShadowOffset, y: highlightShadowOffset)
                    }
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    /// Sentences break first, then each is balanced across the lines it needs.
    ///
    /// A plain greedy wrap strands the tail — "…if they shoot" leaves "shoot" alone on a
    /// line, and "TOV +1" splits after the word. Balancing spreads the words evenly over
    /// however many lines the sentence actually requires, which keeps those together.
    private func wrapped(at points: CGFloat) -> [String] {
        var result: [String] = []
        for sentence in sentences {
            result += balanced(sentence, at: points)
            if result.count > maxLines { break }
        }
        return result
    }

    private var sentences: [String] {
        text.split(whereSeparator: { $0 == "." })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Splits a line into plain and card-name pieces, keeping the spacing intact.
    private func runs(of line: String) -> [(text: String, isName: Bool)] {
        guard !namedCards.isEmpty else { return [(line, false)] }
        let names = namedCards.sorted { $0.count > $1.count }

        var pieces: [(String, Bool)] = []
        var plain = ""
        var index = line.startIndex

        outer: while index < line.endIndex {
            for name in names {
                if line[index...].hasPrefix(name) {
                    if !plain.isEmpty { pieces.append((plain, false)); plain = "" }
                    pieces.append((name, true))
                    index = line.index(index, offsetBy: name.count)
                    continue outer
                }
            }
            plain.append(line[index])
            index = line.index(after: index)
        }
        if !plain.isEmpty { pieces.append((plain, false)) }
        return pieces
    }

    private func measure(_ string: String, at points: CGFloat) -> CGFloat {
        (string as NSString)
            .size(withAttributes: [.font: uiFont(at: points), .kern: tracking]).width
    }

    /// Splits into the fewest lines that fit, then evens them out.
    private func balanced(_ sentence: String, at points: CGFloat) -> [String] {
        let words = sentence.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }

        var count = 1
        while count < words.count && !fits(words, over: count, at: points) { count += 1 }
        return share(words, over: count, at: points)
    }

    private func fits(_ words: [String], over count: Int, at points: CGFloat) -> Bool {
        share(words, over: count, at: points).allSatisfy { measure($0, at: points) <= width }
    }

    /// Fills each line to roughly its share of the total width, so the last line is never
    /// left holding a single orphan.
    private func share(_ words: [String], over count: Int, at points: CGFloat) -> [String] {
        guard count > 1 else { return [words.joined(separator: " ")] }
        let target = measure(words.joined(separator: " "), at: points) / CGFloat(count)

        var lines: [String] = []
        var current = ""
        for word in words {
            let candidate = current.isEmpty ? word : current + " " + word
            let remaining = count - lines.count
            // Never break just before the tail of a label: "Following Dribble:" is one
            // phrase, and splitting it leaves "Following" stranded on its own line.
            let closesLabel = word.hasSuffix(":")
            if !current.isEmpty, !closesLabel, measure(candidate, at: points) > target,
               remaining > 1, words.count - lines.count > remaining {
                lines.append(current)
                current = word
            } else {
                current = candidate
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}
