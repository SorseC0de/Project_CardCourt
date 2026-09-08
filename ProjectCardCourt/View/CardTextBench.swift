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

/// One of the marks that can stand in the row along the foot of a card.
enum FootMark: String, CaseIterable, Hashable, Codable {
    case ball, draw, discard, lock, shoot, three, dribble

    var label: String { rawValue }

    /// The art each one is drawn from, where it is a drawing. The shoot mark, the three
    /// and the dribble are drawn by hand — see `CardFrontView`.
    static let art: [String: FootMark] = [
        "DrawIcon": .draw, "DiscardIcon": .discard, "LockIcon": .lock,
    ]
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

/// **How a card's effect text is set.** The frozen printing, and the only copy of it.
///
/// A card is the whole of what a player has to read, and this had been settled one card
/// at a time across five views and two enums — which is how seven types ended up printed
/// seven different ways. **One set of numbers for all of them**: the same size, the same
/// spacing, the same face. Only the colours are per type, because only the bodies are.
///
/// See `CardTextBench`, where all of it is on a dial.
enum CardTextStyle {
    /// Against the card's width, so a hand card and a gallery card are one drawing.
    static let size: CGFloat = 0.1
    /// How far in from each edge the column sits.
    static let inset: CGFloat = 0.05
    /// Line to line, against the face's own line height. Under one is tighter than the
    /// font was drawn to be, which is what a card wants.
    static let lineHeight: CGFloat = 0.75
    /// Letter to letter, against the type size.
    static let tracking: CGFloat = -0.05
    /// Where the column's middle sits down the card.
    static let y: CGFloat = 0.75
    /// The cut the words are set in.
    static let weight: CardFont.Weight = .semibold

    /// **How small a card is allowed to shrink to fit, and how many lines it may take.**
    ///
    /// One is no shrinking at all, which is the point: shrinking to fit sets every card
    /// at a different size, and a Clamp's four words beside a Move's dozen then read as
    /// two different faces. One size for all of them, and a card with too much to say
    /// takes another line — or is too wordy, which is a thing worth seeing rather than
    /// hiding.
    static let minScale: CGFloat = 1
    static let maxLines = 6

    /// Whether marked words carry a hard drop under them, and how far it falls against
    /// the card's width.
    static let shadows = false
    static let shadowDrop: CGFloat = 0.02

    /// One of the marks that can stand in the row at the foot of a card.
    ///
    /// Named, so each can carry its own size: they are separate drawings on separate
    /// artboards — a ball is round and fills its box, a whistle is wide and does not —
    /// and one multiplier across the six is a row where three of them look wrong.
    static let footMarks = FootMark.self

    /// **The row of marks along the bottom edge**: what the card is worth, what it makes
    /// you do, whether it shoots. How big against the card's width, how far apart against
    /// their own side, how far off the bottom against the card's height, and how far the
    /// words lift to make room for them.
    static let footSize: CGFloat = 0.25
    static let footGap: CGFloat = 0.18
    static let footBottom: CGFloat = 0.01
    static let footLift: CGFloat = 0.025

    /// **The drop under the marks in the row**, and what colour it falls in. Its own,
    /// not the big icon's: they sit on a different part of the card and one of them is
    /// twice the size of the other.
    static let footDrop: CGFloat = 0.014
    static let footShade: [CardType: CardTextInk] = [
        .pass: .blue, .move: .navy, .specialMove: .navy, .clamp: .navy,
        .whistle: .blue, .gameBreak: .navy, .intangible: .navy,
    ]

    /// **Each mark against the row's own size.** Separate drawings on separate artboards
    /// — see `FootMark`.
    static let footScale: [FootMark: CGFloat] = [
        .ball: 0.8, .draw: 0.8, .discard: 0.7, .lock: 1,
        .shoot: 1, .three: 1, .dribble: 0.95,
    ]

    /// The card's big icon, against `CardLayout.iconSizeFraction`.
    static let iconScale: CGFloat = 0.8

    /// **The hard drop under that icon**, per type — the one colour of the four that is
    /// not about the words.
    static let iconShade: [CardType: CardTextInk] = [
        .pass: .gray, .move: .navy, .specialMove: .navy, .clamp: .navy,
        .whistle: .blue, .gameBreak: .navy, .intangible: .navy,
    ]

    /// Whether the marked spans inside the words are inked.
    ///
    /// **On again.** It was turned off because colouring a span cost the line breaks —
    /// a run had to be its own view to carry a shadow, and views in a row do not wrap.
    /// One `AttributedString` inks every run and still wraps as one string, so the
    /// colour is free. See `CardText`.
    static let highlight = true

    /// **What the body text is printed in, per type.** The one thing that has to differ:
    /// navy on a near-black Intangible is lettering nobody can find.
    static let text: [CardType: CardTextInk] = [
        .pass: .white, .move: .navy, .specialMove: .navy, .clamp: .navy,
        .whistle: .black, .gameBreak: .white, .intangible: .white,
    ]

    /// **And what a named mechanic inside it is printed in.** Orange on an orange body is
    /// the card saying its own mechanic in its own colour, which is the same as not
    /// saying it.
    static let keyword: [CardType: CardTextInk] = [
        .pass: .gold, .move: .blue, .specialMove: .orange, .clamp: .orange,
        .whistle: .orange, .gameBreak: .orange, .intangible: .orange,
    ]

    /// **The inner ring**, per type. It is drawn in the same navy most bodies are printed
    /// in, so the one body that *is* that navy has to turn it over.
    static let ring: [CardType: CardTextInk] = [
        .pass: .gray, .move: .navy, .specialMove: .navy, .clamp: .navy,
        .whistle: .navy, .gameBreak: .navy, .intangible: .gold,
    ]

    /// **The drop under the name plate**, per type. The plate itself is gold whatever the
    /// body is; what falls behind it is the question, and blue behind gold on a dark body
    /// reads as nothing at all.
    static let plate: [CardType: CardTextInk] = [
        .pass: .gold, .move: .blue, .specialMove: .blue, .clamp: .blue,
        .whistle: .blue, .gameBreak: .gold, .intangible: .gold,
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
    var weight = CardTextStyle.weight

    var shadows = CardTextStyle.shadows
    var shadowDrop = CardTextStyle.shadowDrop

    var footSize = CardTextStyle.footSize
    var footGap = CardTextStyle.footGap
    var footScale = CardTextStyle.footScale
    var footDrop = CardTextStyle.footDrop
    var footShade = CardTextStyle.footShade
    var minScale = CardTextStyle.minScale
    var maxLines = CardTextStyle.maxLines

    func footShadeInk(for type: CardType) -> Color { (footShade[type] ?? .navy).colour }
    var iconScale = CardTextStyle.iconScale
    var iconShade = CardTextStyle.iconShade
    var highlight = CardTextStyle.highlight

    func scale(of mark: FootMark) -> CGFloat { footScale[mark] ?? 1 }
    func iconShadeInk(for type: CardType) -> Color { (iconShade[type] ?? .navy).colour }
    var footBottom = CardTextStyle.footBottom
    var footLift = CardTextStyle.footLift

    /// The only half that is per type.
    var text = CardTextStyle.text
    var keyword = CardTextStyle.keyword
    var ring = CardTextStyle.ring
    var plate = CardTextStyle.plate

    func ink(for type: CardType) -> Color { (text[type] ?? .navy).colour }
    func keywordInk(for type: CardType) -> Color { (keyword[type] ?? .orange).colour }
    func ringInk(for type: CardType) -> Color { (ring[type] ?? .navy).colour }
    func plateInk(for type: CardType) -> Color { (plate[type] ?? .blue).colour }

    func reset() {
        size = CardTextStyle.size; inset = CardTextStyle.inset
        lineHeight = CardTextStyle.lineHeight; tracking = CardTextStyle.tracking
        y = CardTextStyle.y; weight = CardTextStyle.weight
        shadows = CardTextStyle.shadows; shadowDrop = CardTextStyle.shadowDrop
        footSize = CardTextStyle.footSize; footGap = CardTextStyle.footGap
        footBottom = CardTextStyle.footBottom
        footLift = CardTextStyle.footLift
        text = CardTextStyle.text; keyword = CardTextStyle.keyword
        ring = CardTextStyle.ring; plate = CardTextStyle.plate
        footScale = CardTextStyle.footScale; iconScale = CardTextStyle.iconScale
        iconShade = CardTextStyle.iconShade; highlight = CardTextStyle.highlight
        footDrop = CardTextStyle.footDrop; footShade = CardTextStyle.footShade
        minScale = CardTextStyle.minScale; maxLines = CardTextStyle.maxLines
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
        static let weight: CardFont.Weight = .\(weight)
        static let minScale: CGFloat = \(n(minScale))
        static let maxLines = \(maxLines)
        static let shadows = \(shadows)
        static let shadowDrop: CGFloat = \(n(shadowDrop))
        static let footSize: CGFloat = \(n(footSize))
        static let footGap: CGFloat = \(n(footGap))
        static let footBottom: CGFloat = \(n(footBottom))
        static let footLift: CGFloat = \(n(footLift))
        static let text: [CardType: CardTextInk] = [\(table(text))]
        static let keyword: [CardType: CardTextInk] = [\(table(keyword))]
        static let ring: [CardType: CardTextInk] = [\(table(ring))]
        static let plate: [CardType: CardTextInk] = [\(table(plate))]
        static let iconShade: [CardType: CardTextInk] = [\(table(iconShade))]
        static let footDrop: CGFloat = \(n(footDrop))
        static let footShade: [CardType: CardTextInk] = [\(table(footShade))]
        static let iconScale: CGFloat = \(n(iconScale))
        static let highlight = \(highlight)
        static let footScale: [FootMark: CGFloat] = [\(
            FootMark.allCases.map { ".\($0.rawValue): \(n(scale(of: $0)))" }
                .joined(separator: ", "))]
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
                    // The console as well as the clipboard: a device is not always
                    // plugged into the machine the source lives on.
                    DevLog.say(.bench, "CardTextStyle\n" + tune.source)
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
                        // **One set for all seven.** Only the colours below are per
                        // type — see `CardTextStyle`.
                        heading("the words")
                        dial("size", $tune.size, 0.04...0.16)
                        dial("padding", $tune.inset, 0...0.2)
                        dial("line gap", $tune.lineHeight, 0.5...1.6)
                        dial("letter gap", $tune.tracking, -0.15...0.15)
                        dial("y", $tune.y, 0.4...1)
                        row("face", tune.weight.label) {
                            HStack(spacing: 3) {
                                ForEach(CardFont.Weight.allCases, id: \.self) { cut in
                                    chip(cut.label, on: tune.weight == cut) {
                                        tune.weight = cut
                                    }
                                }
                            }
                        }
                        // **One is no shrinking.** Shrinking to fit sets every card at a
                        // different size, which is what had Clamp and Move reading as
                        // two different faces.
                        dial("min scale", $tune.minScale, 0.4...1)
                        row("lines", "\(tune.maxLines)") {
                            HStack(spacing: 3) {
                                ForEach(3...8, id: \.self) { count in
                                    chip("\(count)", on: tune.maxLines == count) {
                                        tune.maxLines = count
                                    }
                                }
                            }
                        }
                        heading("the drop")
                        // **On.** Inking a span costs nothing now it is one string — see
                        // `CardText`. Free now that one AttributedString inks every run.
                        row("highlight", tune.highlight ? "on" : "off") {
                            HStack(spacing: 3) {
                                chip("on", on: tune.highlight) { tune.highlight = true }
                                chip("off", on: !tune.highlight) { tune.highlight = false }
                            }
                        }
                        row("shadows", tune.shadows ? "on" : "off") {
                            HStack(spacing: 3) {
                                chip("on", on: tune.shadows) { tune.shadows = true }
                                chip("off", on: !tune.shadows) { tune.shadows = false }
                            }
                        }
                        dial("depth", $tune.shadowDrop, 0...0.05)
                        heading("the big icon")
                        dial("size", $tune.iconScale, 0.3...2)
                        heading("\(type.shortLabel): under the icon")
                        inks(tune.iconShade[type] ?? .navy) { tune.iconShade[type] = $0 }
                        heading("the marks at the foot")
                        dial("row size", $tune.footSize, 0.05...0.6)
                        dial("gap", $tune.footGap, 0...1)
                        dial("off bottom", $tune.footBottom, 0...0.2)
                        dial("words lift", $tune.footLift, 0...0.3)
                        dial("drop", $tune.footDrop, 0...0.05)
                        heading("\(type.shortLabel): under the marks")
                        inks(tune.footShade[type] ?? .navy) { tune.footShade[type] = $0 }
                        heading("each mark")
                        // **Each one against the row.** They are separate drawings on
                        // separate artboards — see `FootMark`.
                        ForEach(FootMark.allCases, id: \.self) { mark in
                            dial(mark.label,
                                 Binding(get: { tune.scale(of: mark) },
                                         set: { tune.footScale[mark] = $0 }),
                                 0.2...2.5)
                        }
                        heading("\(type.shortLabel): the ink")
                        inks(tune.text[type] ?? .navy) { tune.text[type] = $0 }
                        heading("\(type.shortLabel): the mechanics")
                        inks(tune.keyword[type] ?? .orange) { tune.keyword[type] = $0 }
                        heading("\(type.shortLabel): the inner ring")
                        inks(tune.ring[type] ?? .navy) { tune.ring[type] = $0 }
                        heading("\(type.shortLabel): under the name")
                        inks(tune.plate[type] ?? .blue) { tune.plate[type] = $0 }
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
