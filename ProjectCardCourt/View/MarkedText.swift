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

        var colour: Color {
            switch self {
            case .name:    return CardPalette.gold
            case .keyword: return CardPalette.orange
            }
        }

        /// The hard drop under it. A colour needs the one under it as much as itself —
        /// gold on navy and orange on red are two different signals, not one twice.
        var shade: Color {
            switch self {
            case .name:    return CardPalette.orange
            case .keyword: return CardPalette.red
            }
        }
    }

    /// One run of text and how it is drawn. Nil is the card's own colour.
    struct Run: Hashable {
        var text: String
        var ink: Ink?
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
                runs.append(Run(text: String(text[start..<close]), ink: ink))
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
