import SwiftUI

/// A card's effect, coloured where it names something, **wrapped by SwiftUI**.
///
/// ## Why this replaced the hand wrap
///
/// Colouring a span used to mean the span was its own view — a shadow is a view modifier,
/// so there was no other way to give one its own drop. Views in a row do not wrap, so the
/// lines had to be broken by hand, and a hand wrap is worse than the one the system does
/// for free: it stranded tails, it broke "TOV +1" after the word, and it made the ink and
/// the spacing one decision when they are two.
///
/// **One `Text`, many runs.** An `AttributedString` carries a colour and a face per run
/// and still reads as a single string, so the line breaks are the system's again and
/// colour costs nothing in layout. The technique is Rota's `QuotedText`, without the
/// space it inserts between segments — that would fall inside "SHOT +10%".
///
/// ## What it gives up, and what it gains
///
/// A run cannot carry its own hard drop any more: shadows are views, and there is one
/// view here. That is the trade, and it is the right way round — the drop was worth less
/// than the wrap.
///
/// What it gains is that a run can be **tapped**. A keyword carries a link to its own
/// name, and `onKeyword` is handed whichever one was pressed, so tapping *Draw* on a card
/// can say what a Draw is. See `CardFrontView`, which stops flattening the card while it
/// is raised so the tap can land.
struct CardText: View {
    let text: String
    let font: String
    let size: CGFloat
    /// Line to line, against the face's own leading. Under one is tighter than the font
    /// was drawn to be, which is what a card wants.
    var lineHeight: CGFloat = 1
    var tracking: CGFloat = 0
    var maxLines = 6
    /// How small it may shrink to fit. One is not at all — every card the same size.
    var minScale: CGFloat = 1
    /// What the unmarked words are printed in.
    var ink: Color = CardPalette.navy
    /// Whether the marked spans are inked at all. Off prints the lot in `ink`.
    var highlight = true
    /// What this card is, which is what decides the two marked colours — see `CardInk`.
    var face: CardFace = .pass
    /// Handed the keyword a reader pressed, where pressing is possible.
    var onKeyword: ((String) -> Void)?

    /// The scheme a keyword's link is built on. Its own, so nothing else in the app can
    /// be opened by a card and no card can open anything else.
    static let scheme = "cardkeyword"

    private var uiFont: UIFont {
        UIFont(name: font, size: size) ?? .systemFont(ofSize: size, weight: .bold)
    }

    private func colour(of run: Marked.Run) -> Color {
        if run.ink == .type, let named = CardFace(named: run.word ?? run.text) {
            return CardTextTuning.shared.typeReferenceInk(for: named, on: face)
        }
        return run.ink?.colour(on: face) ?? ink
    }

    /// Brackets: a size down, and slanted by hand, since the face has no italic of its own.
    private enum Aside {
        static let scale: CGFloat = 0.8
        static let slant: CGFloat = 0.2
    }

    private var asideFont: Font {
        let slant = CGAffineTransform(a: 1, b: 0, c: Aside.slant, d: 1, tx: 0, ty: 0)
        let slanted = UIFont(descriptor: uiFont.fontDescriptor.withMatrix(slant),
                             size: size * Aside.scale)
        return Font(slanted as CTFont)
    }

    /// One run as it is set: its face, its colour, and a link if it is a keyword — or the
    /// picture it stands for.
    private func piece(_ run: Marked.Run) -> Text {
        if run.icon == "2X" {
            return Text(Image(uiImage: TwoXMark.image(size: size)))
                .baselineOffset(-size * TwoXMark.baselineDrop)
        }
        var piece = AttributedString(run.text)
        piece.font = run.aside ? asideFont : .custom(font, size: size)
        // **A named type takes the named type's colour**, which is the one thing the
        // run itself has to be asked about — every other ink is a property of the
        // card doing the printing. See `CardTextStyle.typeReference`.
        piece.foregroundColor = highlight ? colour(of: run) : ink
        // **Only a keyword is worth explaining.** A card named inside the text is
        // already a card you can go and read; a mechanic is a rule you may never
        // have been told.
        // **The mechanic, not the run.** "Draw 2" is one marked span and two words,
        // and it is a Draw that has a meaning rather than a Draw 2.
        if highlight, run.ink == .keyword, onKeyword != nil, let word = run.word,
           let link = URL(string: "\(Self.scheme)://"
                         + (word.addingPercentEncoding(
                            withAllowedCharacters: .urlHostAllowed) ?? word)) {
            piece.link = link
        }
        return Text(piece)
    }

    /// **Still one `Text`**, joined run by run, so the wrap stays the system's even with a
    /// picture in the line.
    private var written: Text {
        Marked.runs(of: text).reduce(Text(verbatim: "")) { $0 + piece($1) }
    }

    var body: some View {
        written
            .tracking(tracking)
            // The gap this exists to close. `lineSpacing` cannot go under the font's own
            // leading, so the negative half of the dial is spent here.
            .lineSpacing(uiFont.lineHeight * (lineHeight - 1))
            .multilineTextAlignment(.center)
            .lineLimit(maxLines)
            .minimumScaleFactor(minScale)
            // A link paints itself in the accent colour unless something says otherwise,
            // and the run's own colour is what should win.
            .tint(nil)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == Self.scheme,
                      let word = url.host()?.removingPercentEncoding else {
                    return .discarded
                }
                onKeyword?(word)
                return .handled
            })
    }
}
