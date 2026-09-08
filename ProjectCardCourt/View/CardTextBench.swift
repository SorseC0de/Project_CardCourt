import Observation
import SwiftUI

extension CardType {
    /// How the case is spelled in Swift, for printing a table back into source. The raw
    /// value is what the sheet calls it — "Special Move" — which is not a case name.
    var caseName: String {
        switch self {
        case .pass: return "pass"
        case .move: return "move"
        case .specialMove: return "specialMove"
        case .clamp: return "clamp"
        case .whistle: return "whistle"
        case .gameBreak: return "gameBreak"
        case .intangible: return "intangible"
        }
    }
    /// Short enough for a chip on the bench.
    var shortLabel: String { self == .specialMove ? "special" : rawValue.lowercased() }
}

/// A colour a card's printing can be set in, by name.
///
/// **Named rather than raw**, because these numbers get pasted back into `CardTextStyle`
/// and a hex triple in a source file says nothing about what it is. The list is the
/// palette; a card is never printed in anything else.
enum CardTextInk: String, CaseIterable, Hashable, Codable {
    case navy, white, black, gold, orange, blue, red, lightBlue, gray

    var colour: Color {
        switch self {
        case .navy:      return CardPalette.navy
        case .white:     return .white
        case .black:     return CardPalette.black
        case .gold:      return CardPalette.gold
        case .orange:    return CardPalette.orange
        case .blue:      return CardPalette.blue
        case .red:       return CardPalette.red
        case .lightBlue: return CardPalette.lightBlue
        case .gray:      return CardPalette.gray
        }
    }

    /// What the bench shows on a chip.
    var label: String { self == .lightBlue ? "lt blue" : rawValue }
}

/// **How a card's effect text is set.** The frozen numbers, and the only copy of them.
///
/// A card is the whole of what a player has to read, and the printing had been settled
/// one card at a time in five different views. Everything the words do — how big, how far
/// apart, what colour on which body, whether they carry a drop, where the mark under them
/// sits — is a dial here and nowhere else. See `CardTextBench`.
enum CardTextStyle {
    // MARK: The words

    /// Against the card's width, so a hand card and a gallery card are one drawing.
    static let size: CGFloat = 56 / CardMetrics.shape.width
    /// How far in from each edge the column sits.
    static let inset: CGFloat = 0.05
    /// Line to line, against the face's own line height. Under one is tighter than the
    /// font was drawn to be, which is what a card wants.
    static let lineHeight: CGFloat = 0.75
    /// Letter to letter, against the type size.
    static let tracking: CGFloat = -0.05
    /// Where the column's middle sits down the card.
    static let y: CGFloat = 0.75

    // MARK: The drop

    /// Whether marked words carry a hard drop under them at all.
    static let shadows = true
    /// How far it falls, against the card's width. South-east, as everything else in the
    /// game does.
    static let shadowDrop: CGFloat = 0.014

    // MARK: The pictures in the line

    /// The little mark that leads a keyword, against the type size.
    static let glyphShare: CGFloat = 0.85
    /// And how far it rides above the line, against the type size — a picture sitting on
    /// the baseline reads as a letter rather than as a mark beside the writing.
    static let glyphLift: CGFloat = 0

    // MARK: The mark at the foot

    /// The shoot and dribble marks along the bottom edge, against the card's width.
    static let footSize: CGFloat = 0.30 * 0.75
    /// How far off the bottom edge, against the card's height.
    static let footBottom: CGFloat = 0.04
    /// How far the words lift to make room when there is one.
    static let footLift: CGFloat = 0.09

    // MARK: Per type

    /// **What the body text is printed in, per type.** It has to be per type because the
    /// bodies are: navy on a near-black Intangible is lettering nobody can find.
    static let text: [CardType: CardTextInk] = [
        .pass: .navy, .move: .navy, .specialMove: .navy, .clamp: .navy,
        .whistle: .black, .gameBreak: .white, .intangible: .white,
    ]

    /// **What a named mechanic is printed in, per type.** Orange keywords on an orange
    /// body are the card saying its own mechanic in its own colour, which is the same as
    /// not saying it.
    static let keyword: [CardType: CardTextInk] = [
        .pass: .orange, .move: .blue, .specialMove: .orange, .clamp: .orange,
        .whistle: .orange, .gameBreak: .orange, .intangible: .orange,
    ]
}

/// Every number in a card's printing, on a dial.
@Observable
@MainActor
final class CardTextTuning {
    static let shared = CardTextTuning()

    var size = CardTextStyle.size
    var inset = CardTextStyle.inset
    var lineHeight = CardTextStyle.lineHeight
    var tracking = CardTextStyle.tracking
    var y = CardTextStyle.y

    var shadows = CardTextStyle.shadows
    var shadowDrop = CardTextStyle.shadowDrop

    var glyphShare = CardTextStyle.glyphShare
    var glyphLift = CardTextStyle.glyphLift

    var footSize = CardTextStyle.footSize
    var footBottom = CardTextStyle.footBottom
    var footLift = CardTextStyle.footLift

    var text = CardTextStyle.text
    var keyword = CardTextStyle.keyword

    func ink(for type: CardType) -> Color {
        (text[type] ?? .navy).colour
    }
    func keywordInk(for type: CardType) -> Color {
        (keyword[type] ?? .orange).colour
    }

    func reset() {
        size = CardTextStyle.size; inset = CardTextStyle.inset
        lineHeight = CardTextStyle.lineHeight; tracking = CardTextStyle.tracking
        y = CardTextStyle.y
        shadows = CardTextStyle.shadows; shadowDrop = CardTextStyle.shadowDrop
        glyphShare = CardTextStyle.glyphShare; glyphLift = CardTextStyle.glyphLift
        footSize = CardTextStyle.footSize; footBottom = CardTextStyle.footBottom
        footLift = CardTextStyle.footLift
        text = CardTextStyle.text; keyword = CardTextStyle.keyword
    }

    /// The dials as `CardTextStyle`, ready to paste over it.
    var source: String {
        func n(_ value: CGFloat) -> String { String(format: "%g", value) }
        func table(_ inks: [CardType: CardTextInk]) -> String {
            CardType.allCases.map { ".\($0.caseName): .\((inks[$0] ?? .navy).rawValue)" }
                .joined(separator: ", ")
        }
        return """
        static let size: CGFloat = \(n(size))
        static let inset: CGFloat = \(n(inset))
        static let lineHeight: CGFloat = \(n(lineHeight))
        static let tracking: CGFloat = \(n(tracking))
        static let y: CGFloat = \(n(y))
        static let shadows = \(shadows)
        static let shadowDrop: CGFloat = \(n(shadowDrop))
        static let glyphShare: CGFloat = \(n(glyphShare))
        static let glyphLift: CGFloat = \(n(glyphLift))
        static let footSize: CGFloat = \(n(footSize))
        static let footBottom: CGFloat = \(n(footBottom))
        static let footLift: CGFloat = \(n(footLift))
        static let text: [CardType: CardTextInk] = [\(table(text))]
        static let keyword: [CardType: CardTextInk] = [\(table(keyword))]
        """
    }
}

#if DEBUG
/// **The cards, and every number their words are set by.**
///
/// One of each type at a time, at the two sizes that matter — the hand, where a card is
/// glanced at, and raised, where it is actually read. A dial that reads at one size and
/// not the other has not been settled, and settling them one card at a time in five
/// different views is how the printing got into the state it was in.
struct CardTextBench: View {
    var onDismiss: () -> Void = {}

    @State private var tune = CardTextTuning.shared
    @State private var cardFont = CardFont.shared
    @State private var type: CardType = .move
    @State private var raised = false
    @State private var open = true

    /// The wordiest card of each type — the one that has to fit. A dial settled on a
    /// three-word card is a dial that has not been tested.
    private var cards: [CardDescriptor] {
        let ofType = CardLibrary.all.filter { $0.type == type }
        return ofType
            .sorted { $0.printedEffect.count > $1.printedEffect.count }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        ZStack {
            CardPalette.navy.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 8)
                // Raised, where the wording is longest and the reading actually happens.
                HStack(alignment: .top, spacing: 14) {
                    ForEach(cards, id: \.id) { card in
                        CardFrontView(descriptor: card, displayWidth: 108,
                                      expanded: raised)
                    }
                }
                // And in the hand, which is the size a player sees ninety times a game.
                HStack(alignment: .top, spacing: 8) {
                    ForEach(cards, id: \.id) { card in
                        CardFrontView(descriptor: card, displayWidth: 76)
                    }
                }
                Spacer(minLength: 8)
            }
            .padding(.top, 30)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack { Spacer(); panel }
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button("print") {
                    UIPasteboard.general.string = tune.source
                    print(tune.source)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CardPalette.gold)
                Button("reset") { tune.reset() }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(CardPalette.red)
                Button("done", action: onDismiss)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                chip(raised ? "raised" : "in hand", on: true) { raised.toggle() }
                chip("font: \(cardFont.weight.label)", on: true) {
                    cardFont.weight = cardFont.weight.next
                }
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
                    Image(systemName: open ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)

            if open {
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        heading("which card")
                        row("type", "") {
                            HStack(spacing: 3) {
                                ForEach(CardType.allCases, id: \.self) { kind in
                                    chip(kind.shortLabel, on: type == kind) { type = kind }
                                }
                            }
                        }
                        heading("the words")
                        dial("size", $tune.size, 0.04...0.16)
                        dial("padding", $tune.inset, 0...0.2)
                        dial("line gap", $tune.lineHeight, 0.5...1.6)
                        dial("letter gap", $tune.tracking, -0.15...0.15)
                        dial("y", $tune.y, 0.4...1)
                        heading("the drop")
                        row("shadows", tune.shadows ? "on" : "off") {
                            HStack(spacing: 3) {
                                chip("on", on: tune.shadows) { tune.shadows = true }
                                chip("off", on: !tune.shadows) { tune.shadows = false }
                            }
                        }
                        dial("depth", $tune.shadowDrop, 0...0.05)
                        heading("pictures in the line")
                        dial("size", $tune.glyphShare, 0.3...2)
                        dial("lift", $tune.glyphLift, -0.4...0.4)
                        heading("the mark at the foot")
                        dial("size", $tune.footSize, 0.05...0.6)
                        dial("off bottom", $tune.footBottom, 0...0.2)
                        dial("words lift", $tune.footLift, 0...0.3)
                        // Per type, because the bodies are — see `CardTextStyle.text`.
                        heading("\(type.shortLabel): the words")
                        inks(tune.text[type] ?? .navy) { tune.text[type] = $0 }
                        heading("\(type.shortLabel): the mechanics")
                        inks(tune.keyword[type] ?? .orange) { tune.keyword[type] = $0 }
                    }
                    .padding(.horizontal, 10).padding(.bottom, 8)
                }
                .frame(height: 250)
            }
        }
        .background(.black.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    /// The palette, as chips. Each one wearing its own colour, so the choice is made by
    /// looking rather than by reading a word.
    private func inks(_ chosen: CardTextInk,
                      _ pick: @escaping (CardTextInk) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(CardTextInk.allCases, id: \.self) { ink in
                Button { pick(ink) } label: {
                    Text(ink.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ink == .white || ink == .gold ? .black : .white)
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 3).fill(ink.colour))
                        .overlay(RoundedRectangle(cornerRadius: 3)
                            .stroke(CardPalette.lightBlue,
                                    lineWidth: ink == chosen ? 2.5 : 0))
                }
            }
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .black)).tracking(1)
            .foregroundStyle(CardPalette.gold)
            .padding(.top, 4)
    }

    private func chip(_ label: String, on: Bool, _ run: @escaping () -> Void) -> some View {
        Button(label, action: run)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3)
                .fill(on ? CardPalette.blue : .white.opacity(0.12)))
            .foregroundStyle(.white)
    }

    private func dial(_ name: String, _ value: Binding<CGFloat>,
                      _ range: ClosedRange<CGFloat>) -> some View {
        row(name, String(format: "%.3f", value.wrappedValue)) {
            Slider(value: value, in: range)
        }
    }

    private func row(_ name: String, _ reading: String,
                     @ViewBuilder _ control: () -> some View) -> some View {
        HStack(spacing: 6) {
            Text(name).font(.system(size: 10, weight: .semibold))
                .frame(width: 66, alignment: .leading)
            control()
            Text(reading).font(.system(size: 9, design: .monospaced))
                .frame(width: 44, alignment: .trailing)
        }
        .foregroundStyle(.white)
    }
}

#Preview("Card text bench") { CardTextBench() }
#endif
