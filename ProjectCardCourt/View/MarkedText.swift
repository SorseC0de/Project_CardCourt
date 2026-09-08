import SwiftUI

/// Effect text with the colour written into it.
///
/// ## The markers
///
/// `@[Rhythm Dribble]` is a **card name**; `#[Discard]` is a **keyword** — a mechanic the
/// rules give a meaning to. Everything between the bracket and its close takes that
/// colour, and the three characters are eaten on the way to the screen.
///
/// Written this way because the alternative is a list somewhere else: the old highlighter
/// matched card names against `CardLibrary.namesReferencedInText` and regexes against
/// phrases, so a card could not be renamed, a keyword could not be added, and no card
/// could ever say a word it did not mean. A marker in the string is the whole rule, right
/// where the string is being written.
enum Marked {
    /// What a marked span is.
    enum Ink: Character, CaseIterable {
        /// Another card, by name.
        case name = "@"
        /// A mechanic the rules name: Discard, Draw, Injury, Clear.
        case keyword = "#"

        /// What this reads as on a given card. **Asked of the card, not of the marker**:
        /// a keyword inked the body's own colour is a keyword nobody can see, and which
        /// colour that is depends entirely on what the card is. See `CardInk`.
        @MainActor
        func colour(on type: CardType) -> Color {
            let ink = CardInk.of(type)
            switch self {
            case .name:    return ink.name
            case .keyword: return ink.keyword
            }
        }

        /// The hard drop under it. A colour needs the one under it as much as itself —
        /// gold on orange and orange on navy are two different signals, not one twice.
        @MainActor
        func shade(on type: CardType) -> Color {
            let ink = CardInk.of(type)
            switch self {
            case .name:    return ink.nameShade
            case .keyword: return ink.keywordShade
            }
        }
    }

    /// One run of text and how it is drawn. Nil is the card's own colour.
    struct Run: Hashable {
        var text: String
        var ink: Ink?
        /// What the keyword is worth, when it is written as one: `#[Draw|2]` is a Draw of
        /// two, `#[Draw|?]` is a Draw of however many. Kept alongside the run's text,
        /// which already reads "Draw 2" — see `Marked.runs(of:)`.
        var value: String?
    }

    /// The keyword badge a card leads with, if it has one, and what is left to say.
    ///
    /// **A card whose whole effect is the badge says it large in the middle**; one with
    /// anything else left says it small at the foot and keeps its words. That is the only
    /// difference between Crowd Noise and Salary Cap Increase.
    static func badge(of text: String) -> (run: Run, rest: String)? {
        let all = runs(of: text)
        guard let index = all.firstIndex(where: { $0.value != nil }) else { return nil }
        var rest = all
        rest.remove(at: index)
        return (all[index], rest.map(\.text).joined()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces))
    }

    /// Splits a written effect into its runs, markers removed.
    static func runs(of text: String) -> [Run] {
        var runs: [Run] = []
        var plain = ""
        var index = text.startIndex

        func flush() {
            guard !plain.isEmpty else { return }
            runs.append(Run(text: plain, ink: nil))
            plain = ""
        }

        while index < text.endIndex {
            let character = text[index]
            let after = text.index(after: index)
            // A marker is the character, a bracket, and something to close it. Anything
            // else that looks like one is simply text — an unclosed bracket prints.
            if let ink = Ink(rawValue: character), after < text.endIndex, text[after] == "[",
               let close = text[after...].firstIndex(of: "]") {
                flush()
                let start = text.index(after: after)
                // `#[Draw|2]`: the word, and what it is worth.
                let inside = String(text[start..<close]).split(separator: "|",
                                                               maxSplits: 1,
                                                               omittingEmptySubsequences: false)
                let word = String(inside[0])
                let value = inside.count > 1 ? String(inside[1]) : nil
                // **The number joins the word.** It used to be printed on the face of a
                // picture standing in for the word; now the word is printed, so its
                // number belongs beside it and everything that measures or wraps the
                // line counts it without being told. A `?` is not a number — the
                // sentence around it already says how many, as in "Up to 5 Draw".
                runs.append(Run(text: value == nil || value == "?" ? word
                                : "\(word) \(value!)",
                                ink: ink, value: value))
                index = text.index(after: close)
                continue
            }
            plain.append(character)
            index = after
        }
        flush()
        return runs
    }

    /// The same text with every marker taken out — for anywhere the colour cannot go: a
    /// log line, a search, a sheet.
    static func plain(_ text: String) -> String {
        runs(of: text).map(\.text).joined()
    }
}
