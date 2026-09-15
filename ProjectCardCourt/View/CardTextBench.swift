import Observation
import SwiftUI

extension CardFace {
    /// How the case is spelled in Swift, for printing a table back into source. The raw
    /// value happens to match, and is kept separate so a renamed case cannot quietly
    /// change what the dump prints.
    var caseName: String {
        switch self {
        case .pass: return "pass"
        case .move: return "move"
        case .specialMove: return "specialMove"
        case .clamp: return "clamp"
        case .whistle: return "whistle"
        case .gameBreak: return "gameBreak"
        case .intangible: return "intangible"
        case .varena: return "varena"
        case .variaball: return "variaball"
        case .injury: return "injury"
        case .devastatingInjury: return "devastatingInjury"
        }
    }

    /// Short enough for a chip on the bench.
    var shortLabel: String {
        switch self {
        case .specialMove: return "special"
        case .gameBreak: return "break"
        case .devastatingInjury: return "deva"
        default: return caseName
        }
    }
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
    case navy, white, black, gold, orange, blue, red, lightBlue, gray,
         tangerine, tan, brown, cloud, darkBlue, azure, cobalt, teal, darkRed, maroon, plum, blood,
         magenta, green, purple, steel

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
        case .tangerine: return CardPalette.tangerine
        case .tan:       return CardPalette.tan
        case .brown:     return CardPalette.brown
        case .cloud:     return CardPalette.cloud
        case .darkBlue:  return CardPalette.darkBlue
        case .azure:     return CardPalette.azure
        case .teal:      return CardPalette.teal
        case .cobalt:    return CardPalette.cobalt
        case .plum:     return CardPalette.plum
        case .blood: return CardPalette.blood
        case .darkRed:   return CardPalette.darkRed
        case .maroon:  return CardPalette.maroon
        case .magenta: return CardPalette.magenta
        case .green:   return CardPalette.green
        case .purple:  return CardPalette.purple
        case .steel:   return CardPalette.steel
        }
    }

    /// What the bench shows on a chip.
    var label: String {
        switch self {
        case .lightBlue: return "lt blue"
        case .darkBlue:  return "dk blue"
        case .darkRed:   return "dk red"
        default:         return rawValue
        }
    }
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
    static let size: CGFloat = 0.075
    /// How far in from each edge the column sits.
    static let inset: CGFloat = 0.12
    /// Line to line, against the face's own line height. Under one is tighter than the
    /// font was drawn to be, which is what a card wants.
    static let lineHeight: CGFloat = 0.75
    /// Letter to letter, against the type size.
    static let tracking: CGFloat = 0
    /// Where the column's middle sits down the card.
    static let y: CGFloat = 0.75
    /// The cut the words are set in.
    static let weight: CardFont.Weight = .geoform

    /// **A wash over the court, behind the words.**
    ///
    /// The body is a saturated colour with a court printed over it, and heavy type on top
    /// of that is type competing with a picture. Black at a third takes the contrast out
    /// from behind the letters and leaves the drawing everywhere else.
    ///
    /// **The same box the court overlay is drawn in**, corner aside — see
    /// `CardLayout.textOverlay*`, which both of them are laid out by.
    static let panel = true
    /// Its corner, against the card's width.
    static let panelCorner: CGFloat = 0.05
    /// How black it is.
    static let panelDark: CGFloat = 0.25

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
    static let footShade: [CardFace: CardTextInk] = [
        .pass: .blue, .move: .navy, .specialMove: .navy, .clamp: .navy,
        .whistle: .blue, .gameBreak: .navy, .intangible: .navy,
        .injury: .navy, .devastatingInjury: .navy,
        .varena: .navy, .variaball: .navy,
    ]

    /// **Each mark against the row's own size.** Separate drawings on separate artboards
    /// — see `FootMark`.
    static let footScale: [FootMark: CGFloat] = [
        .ball: 0.8, .draw: 0.8, .discard: 0.7, .lock: 1,
        .shoot: 1, .three: 1, .dribble: 0.95,
    ]

    /// The card's big icon, against `CardLayout.iconSizeFraction`.
    static let iconScale: CGFloat = 2
    /// **How far the drop under it falls**, against the card's width. Nothing, now that
    /// the icons are full-colour drawings on their own circle: a hard shadow under a
    /// drawing that already has a ground is a second edge nobody asked for.
    static let iconDrop: CGFloat = 0

    /// **Which side of the icon's plate the name banner is drawn on.** On, and the banner
    /// is over the circle and cuts its top off; off, and the circle covers the banner.
    ///
    /// The icon's **subject** goes over the banner either way — that is what the split is
    /// for. This is only about the circle behind it.
    static let plateOverIcon = true

    /// **Where the top of that icon's circle sits**, down the card. The name plate ends at 0.186,
    /// so anything smaller than that runs up behind it — which is the intent: the icon is
    /// cut off by the plate rather than parked under it.
    static let iconTop: CGFloat = 0.15

    /// **The hard drop under that icon**, per type — the one colour of the four that is
    /// not about the words.
    static let iconShade: [CardFace: CardTextInk] = [
        .pass: .gray, .move: .navy, .specialMove: .navy, .clamp: .black,
        .whistle: .blue, .gameBreak: .navy, .intangible: .navy,
        .injury: .navy, .devastatingInjury: .navy,
        .varena: .navy, .variaball: .navy,
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
    static let text: [CardFace: CardTextInk] = [
        .pass: .white, .move: .white, .specialMove: .white, .clamp: .white,
        .whistle: .black, .gameBreak: .white, .intangible: .white,
        .injury: .white, .devastatingInjury: .white,
        .varena: .white, .variaball: .white,
    ]

    /// **And what a named mechanic inside it is printed in.** One colour on every body:
    /// a mechanic is the same mechanic wherever it is written, and a reader looking for
    /// what a card *does* should not have to learn a colour per type to find it.
    static let keyword: [CardFace: CardTextInk] = [
        .pass: .tangerine, .move: .tangerine, .specialMove: .tangerine,
        .clamp: .tangerine, .whistle: .tangerine, .gameBreak: .tangerine,
        .intangible: .tangerine, .injury: .tangerine, .devastatingInjury: .tangerine,
        .varena: .tangerine, .variaball: .tangerine,
    ]

    /// **How thick that ring is drawn**, per type, against `CardLayout.strokeFraction`.
    ///
    /// One width for all seven was one width on paper and not on screen. An Intangible's
    /// ring is the only **light** line on a **dark** body — every other type is navy on a
    /// mid or light one — and a light line on a dark ground reads fatter than the same
    /// line the other way round. The number is the same; the eye is not.
    static let ringWidth: [CardFace: CGFloat] = [
        .pass: 1, .move: 1, .specialMove: 1, .clamp: 1,
        .whistle: 1, .gameBreak: 1, .intangible: 0.75,
        .injury: 1, .devastatingInjury: 1,
        .varena: 1, .variaball: 1,
    ]

    /// **What the card is printed on**, per type. The frozen bodies to begin with — this
    /// is here so a body can be tried against a ring and a keyword without a rebuild.
    static let body: [CardFace: CardTextInk] = [
        .pass: .blue, .move: .purple, .specialMove: .gold, .clamp: .red,
        .whistle: .cloud, .gameBreak: .purple, .intangible: .black,
        .injury: .blood, .devastatingInjury: .maroon,
        .varena: .plum, .variaball: .orange,
    ]

    /// **The card's name, per face, in two inks.**
    ///
    /// The wordmark's trick: the fill changes colour at a line four fifths of the way up
    /// the capitals, so the word reads as lettering drawn in two inks rather than as type
    /// with a gradient on it. See `LinearGradient.hardSplit`.
    ///
    /// **There is no one-colour switch.** A name in one ink is the same ink top and
    /// bottom, which is a gradient of a colour against itself — one rule instead of two.
    static let nameTop: [CardFace: CardTextInk] = [
        .pass: .darkBlue, .move: .darkBlue, .specialMove: .blue, .clamp: .cloud,
        .whistle: .maroon, .gameBreak: .azure, .intangible: .cobalt,
        .injury: .tan, .devastatingInjury: .magenta,
        .varena: .azure, .variaball: .purple,
    ]
    static let nameBottom: [CardFace: CardTextInk] = [
        .pass: .navy, .move: .navy, .specialMove: .darkBlue, .clamp: .lightBlue,
        .whistle: .black, .gameBreak: .navy, .intangible: .black,
        .injury: .blood, .devastatingInjury: .red,
        .varena: .navy, .variaball: .azure,
    ]

    /// **What another card's name is printed in**, where a card's words name one. One
    /// colour on every body, for the same reason the keywords are.
    static let nameReference: [CardFace: CardTextInk] = [
        .pass: .lightBlue, .move: .lightBlue, .specialMove: .lightBlue,
        .clamp: .lightBlue, .whistle: .lightBlue, .gameBreak: .lightBlue,
        .intangible: .lightBlue, .injury: .lightBlue, .devastatingInjury: .lightBlue,
        .varena: .lightBlue, .variaball: .lightBlue,
    ]

    /// **What a named type is printed in — keyed by the type being named**, not by the
    /// card doing the naming. That is the whole point: a Whistle saying "no Special
    /// Moves" prints those two words in the Special Move's own colour, so the sentence
    /// says which family it means without spelling it twice.
    ///
    /// Seeded from each face's body and lightened where a body is too dark to read as
    /// lettering — a Pass's blue and an Intangible's black both go up a step.
    static let typeReference: [CardFace: CardTextInk] = [
        .pass: .lightBlue, .move: .orange, .specialMove: .gold, .clamp: .darkRed,
        .whistle: .cloud, .gameBreak: .purple, .intangible: .gray,
        .injury: .teal, .devastatingInjury: .darkRed,
        .varena: .purple, .variaball: .orange,
    ]

    /// **The inner ring**, per type. It is drawn in the same navy most bodies are printed
    /// in, so the one body that *is* that navy has to turn it over.
    static let ring: [CardFace: CardTextInk] = [
        .pass: .gold, .move: .lightBlue, .specialMove: .blue, .clamp: .azure,
        .whistle: .black, .gameBreak: .navy, .intangible: .green,
        .injury: .plum, .devastatingInjury: .red,
        .varena: .purple, .variaball: .tangerine,
    ]

    /// **The name banner itself**, per face. White on all of them to begin with, which is
    /// what the drawing was filled with before it could be asked.
    static let plateFill: [CardFace: CardTextInk] = [
        .pass: .white, .move: .white, .specialMove: .lightBlue, .clamp: .darkRed,
        .whistle: .tan, .gameBreak: .gold, .intangible: .gold,
        .injury: .black, .devastatingInjury: .black,
        .varena: .gold, .variaball: .tan,
    ]

    /// **The drop under the name banner**, per type. The plate itself is white whatever the
    /// body is; what falls behind it is the question, and blue behind it on a dark body
    /// reads as nothing at all.
    static let plateDrop: [CardFace: CardTextInk] = [
        .pass: .lightBlue, .move: .tan, .specialMove: .blue, .clamp: .maroon,
        .whistle: .blood, .gameBreak: .orange, .intangible: .orange,
        .injury: .cobalt, .devastatingInjury: .cobalt,
        .varena: .orange, .variaball: .brown,
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

    func footShadeInk(for face: CardFace) -> Color { (footShade[face] ?? .navy).colour }
    var iconScale = CardTextStyle.iconScale
    var iconTop = CardTextStyle.iconTop
    var iconDrop = CardTextStyle.iconDrop
    var panel = CardTextStyle.panel
    var panelCorner = CardTextStyle.panelCorner
    var panelDark = CardTextStyle.panelDark
    var plateOverIcon = CardTextStyle.plateOverIcon
    var iconShade = CardTextStyle.iconShade
    var highlight = CardTextStyle.highlight

    func scale(of mark: FootMark) -> CGFloat { footScale[mark] ?? 1 }
    func iconShadeInk(for face: CardFace) -> Color { (iconShade[face] ?? .navy).colour }
    var footBottom = CardTextStyle.footBottom
    var footLift = CardTextStyle.footLift

    /// The only half that is per type.
    var text = CardTextStyle.text
    var keyword = CardTextStyle.keyword
    var nameReference = CardTextStyle.nameReference
    var typeReference = CardTextStyle.typeReference
    var ring = CardTextStyle.ring
    var body = CardTextStyle.body
    var nameTop = CardTextStyle.nameTop
    var nameBottom = CardTextStyle.nameBottom
    var ringWidth = CardTextStyle.ringWidth
    var plateDrop = CardTextStyle.plateDrop
    var plateFill = CardTextStyle.plateFill

    func ink(for face: CardFace) -> Color { (text[face] ?? .navy).colour }
    func keywordInk(for face: CardFace) -> Color { (keyword[face] ?? .orange).colour }
    func nameReferenceInk(for face: CardFace) -> Color {
        (nameReference[face] ?? .lightBlue).colour
    }
    /// **Asked of the type being named**, not of the card naming it.
    func typeReferenceInk(for named: CardFace) -> Color {
        (typeReference[named] ?? .cloud).colour
    }
    func ringInk(for face: CardFace) -> Color { (ring[face] ?? .navy).colour }
    func ringWeight(for face: CardFace) -> CGFloat { ringWidth[face] ?? 1 }
    func bodyInk(for face: CardFace) -> Color { (body[face] ?? .blue).colour }
    func nameTopInk(for face: CardFace) -> Color { (nameTop[face] ?? .navy).colour }
    func nameBottomInk(for face: CardFace) -> Color { (nameBottom[face] ?? .navy).colour }
    /// What falls behind the banner.
    func plateDropInk(for face: CardFace) -> Color { (plateDrop[face] ?? .blue).colour }
    /// And the banner itself.
    func plateFillInk(for face: CardFace) -> Color { (plateFill[face] ?? .white).colour }

    func reset() {
        size = CardTextStyle.size; inset = CardTextStyle.inset
        lineHeight = CardTextStyle.lineHeight; tracking = CardTextStyle.tracking
        y = CardTextStyle.y; weight = CardTextStyle.weight
        shadows = CardTextStyle.shadows; shadowDrop = CardTextStyle.shadowDrop
        footSize = CardTextStyle.footSize; footGap = CardTextStyle.footGap
        footBottom = CardTextStyle.footBottom
        footLift = CardTextStyle.footLift
        text = CardTextStyle.text; keyword = CardTextStyle.keyword
        ring = CardTextStyle.ring; plateDrop = CardTextStyle.plateDrop
        plateFill = CardTextStyle.plateFill
        body = CardTextStyle.body
        nameTop = CardTextStyle.nameTop; nameBottom = CardTextStyle.nameBottom
        ringWidth = CardTextStyle.ringWidth
        footScale = CardTextStyle.footScale; iconScale = CardTextStyle.iconScale
        iconTop = CardTextStyle.iconTop; plateOverIcon = CardTextStyle.plateOverIcon
        iconDrop = CardTextStyle.iconDrop
        panel = CardTextStyle.panel; panelCorner = CardTextStyle.panelCorner
        panelDark = CardTextStyle.panelDark
        iconShade = CardTextStyle.iconShade; highlight = CardTextStyle.highlight
        footDrop = CardTextStyle.footDrop; footShade = CardTextStyle.footShade
        minScale = CardTextStyle.minScale; maxLines = CardTextStyle.maxLines
    }

    /// The dials as `CardTextStyle`, ready to paste over it.
    var source: String {
        func n(_ value: CGFloat) -> String { String(format: "%g", value) }
        func table(_ inks: [CardFace: CardTextInk]) -> String {
            CardFace.allCases.map { ".\($0.caseName): .\((inks[$0] ?? .navy).rawValue)" }
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
        static let text: [CardFace: CardTextInk] = [\(table(text))]
        static let keyword: [CardFace: CardTextInk] = [\(table(keyword))]
        static let nameReference: [CardFace: CardTextInk] = [\(table(nameReference))]
        static let typeReference: [CardFace: CardTextInk] = [\(table(typeReference))]
        static let ring: [CardFace: CardTextInk] = [\(table(ring))]
        static let body: [CardFace: CardTextInk] = [\(table(body))]
        static let nameTop: [CardFace: CardTextInk] = [\(table(nameTop))]
        static let nameBottom: [CardFace: CardTextInk] = [\(table(nameBottom))]
        static let ringWidth: [CardFace: CGFloat] = [\(
            CardFace.allCases.map { ".\($0.caseName): \(n(ringWeight(for: $0)))" }
                .joined(separator: ", "))]
        static let plateDrop: [CardFace: CardTextInk] = [\(table(plateDrop))]
        static let iconShade: [CardFace: CardTextInk] = [\(table(iconShade))]
        static let footDrop: CGFloat = \(n(footDrop))
        static let footShade: [CardFace: CardTextInk] = [\(table(footShade))]
        static let iconScale: CGFloat = \(n(iconScale))
        static let iconDrop: CGFloat = \(n(iconDrop))
        static let iconTop: CGFloat = \(n(iconTop))
        static let panel = \(panel)
        static let panelCorner: CGFloat = \(n(panelCorner))
        static let panelDark: CGFloat = \(n(panelDark))
        static let plateOverIcon = \(plateOverIcon)
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
    @State private var face: CardFace = .move
    @State private var raised = false
    /// Which card is being held up. **Tap any other one to promote it** — the rows under
    /// the presented card run behind the dials, and the wordiest card of a type is not
    /// always the one worth looking at.
    @State private var presenting: String?
    @State private var open = true

    /// The wordiest card of each type — the one that has to fit. A dial settled on a
    /// three-word card is a dial that has not been tested.
    private var cards: [CardDescriptor] {
        let ofType = CardLibrary.all.filter { CardFace(of: $0) == face }
        return ofType
            .sorted { $0.printedEffect.count > $1.printedEffect.count }
            .prefix(3)
            .map { $0 }
    }

    /// The card being held up: whichever was last tapped, and the wordiest of the type
    /// until one is.
    private var presented: CardDescriptor? {
        cards.first { $0.id == presenting } ?? cards.first
    }

    var body: some View {
        ZStack {
            CardPalette.navy.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 8)
                // **Presented** — the size a card is held up at when it is played, which
                // is where most of a game's reading happens. One card, because at this
                // size a row of them is a row of nothing.
                if let card = presented {
                    CardFrontView(descriptor: card, displayWidth: 210, expanded: raised)
                }
                // Raised, where the wording is longest and the reading actually happens.
                HStack(alignment: .top, spacing: 14) {
                    ForEach(cards, id: \.id) { card in
                        CardFrontView(descriptor: card, displayWidth: 108,
                                      expanded: raised)
                            .onTapGesture { presenting = card.id }
                    }
                }
                // And in the hand, which is the size a player sees ninety times a game.
                HStack(alignment: .top, spacing: 8) {
                    ForEach(cards, id: \.id) { card in
                        CardFrontView(descriptor: card, displayWidth: 76)
                            .onTapGesture { presenting = card.id }
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
                        // **Nine, not seven.** Injuries are Game Breaks by the rules and
                        // their own thing on paper — see `CardFace`.
                        row("type", "") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52),
                                                         spacing: 3)], spacing: 3) {
                                ForEach(CardFace.allCases, id: \.self) { kind in
                                    chip(kind.shortLabel, on: face == kind) { face = kind }
                                }
                            }
                        }
                        // **One set for all nine.** Only the colours below are per
                        // face — see `CardTextStyle`.
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
                        heading("the wash over the court")
                        row("wash", tune.panel ? "on" : "off") {
                            HStack(spacing: 3) {
                                chip("on", on: tune.panel) { tune.panel = true }
                                chip("off", on: !tune.panel) { tune.panel = false }
                            }
                        }
                        dial("corner", $tune.panelCorner, 0...0.2)
                        dial("black", $tune.panelDark, 0...1)
                        heading("the big icon")
                        dial("size", $tune.iconScale, 0.3...4)
                        dial("top", $tune.iconTop, 0...0.4)
                        dial("drop", $tune.iconDrop, 0...0.05)
                        row("name plate", tune.plateOverIcon ? "over" : "under") {
                            HStack(spacing: 3) {
                                chip("over", on: tune.plateOverIcon) {
                                    tune.plateOverIcon = true
                                }
                                chip("under", on: !tune.plateOverIcon) {
                                    tune.plateOverIcon = false
                                }
                            }
                        }
                        heading("\(face.shortLabel): under the icon")
                        inks(tune.iconShade[face] ?? .navy) { tune.iconShade[face] = $0 }
                        heading("the marks at the foot")
                        dial("row size", $tune.footSize, 0.05...0.6)
                        dial("gap", $tune.footGap, 0...1)
                        dial("off bottom", $tune.footBottom, 0...0.2)
                        dial("words lift", $tune.footLift, 0...0.3)
                        dial("drop", $tune.footDrop, 0...0.05)
                        heading("\(face.shortLabel): under the marks")
                        inks(tune.footShade[face] ?? .navy) { tune.footShade[face] = $0 }
                        heading("each mark")
                        // **Each one against the row.** They are separate drawings on
                        // separate artboards — see `FootMark`.
                        ForEach(FootMark.allCases, id: \.self) { mark in
                            dial(mark.label,
                                 Binding(get: { tune.scale(of: mark) },
                                         set: { tune.footScale[mark] = $0 }),
                                 0.2...2.5)
                        }
                        heading("\(face.shortLabel): the ink")
                        inks(tune.text[face] ?? .navy) { tune.text[face] = $0 }
                        heading("\(face.shortLabel): the mechanics")
                        inks(tune.keyword[face] ?? .orange) { tune.keyword[face] = $0 }
                        heading("\(face.shortLabel): the body")
                        inks(tune.body[face] ?? .blue) { tune.body[face] = $0 }
                        heading("\(face.shortLabel): the name, top then bottom")
                        inks(tune.nameTop[face] ?? .navy) { tune.nameTop[face] = $0 }
                        inks(tune.nameBottom[face] ?? .navy) { tune.nameBottom[face] = $0 }
                        heading("\(face.shortLabel): the name banner")
                        inks(tune.plateFill[face] ?? .white) { tune.plateFill[face] = $0 }
                        heading("a card named in the words")
                        inks(tune.nameReference[face] ?? .lightBlue) {
                            tune.nameReference[face] = $0
                        }
                        heading("\(face.shortLabel) named in another card's words")
                        inks(tune.typeReference[face] ?? .cloud) { tune.typeReference[face] = $0 }
                        heading("\(face.shortLabel): the inner ring")
                        inks(tune.ring[face] ?? .navy) { tune.ring[face] = $0 }
                        dial("thickness", Binding(
                            get: { tune.ringWidth[face] ?? 1 },
                            set: { tune.ringWidth[face] = $0 }), 0.3...1.6)
                        heading("\(face.shortLabel): under the name")
                        inks(tune.plateDrop[face] ?? .blue) { tune.plateDrop[face] = $0 }
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
    /// **Swatches, not names.** Twenty-five colours spelled out took three lines and read
    /// as a paragraph; the same twenty-five as squares fit on one and are picked by eye,
    /// which is how a colour is picked anyway.
    private func inks(_ chosen: CardTextInk,
                      _ pick: @escaping (CardTextInk) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 17), spacing: 3)], spacing: 3) {
            ForEach(CardTextInk.allCases, id: \.self) { ink in
                Button { pick(ink) } label: {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ink.colour)
                        .frame(height: 17)
                        .overlay(RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(CardPalette.lightBlue,
                                          lineWidth: ink == chosen ? 3 : 0))
                }
                .buttonStyle(.plain)
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
