import SwiftUI

/// A slotted card raised to be read.
///
/// Grows out of the slot that was tapped rather than appearing in the middle of the
/// screen. With three Intangibles and up to three Clamps on the board at once, a card
/// arriving from nowhere makes you work out which one you asked for; arriving from its
/// own slot answers that before you can ask.
struct InspectedCardView: View {
    let card: CardDescriptor
    /// The slot's centre, in global coordinates.
    let from: CGPoint
    var onKeyword: ((String) -> Void)?

    @State private var arrived = false

    var body: some View {
        GeometryReader { geo in
            CardFrontView(descriptor: card, displayWidth: 96, expanded: true,
                          onKeyword: onKeyword)
                .scaleEffect(arrived ? 2 : 0.3)
                .opacity(arrived ? 1 : 0)
                .position(arrived
                          ? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                          : from)
                .shadow(color: .black.opacity(0.55), radius: 22, y: 12)
        }
        .allowsHitTesting(false)
        .task {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) { arrived = true }
        }
    }
}

extension View {
    /// Taps this card up out of wherever it is sitting.
    ///
    /// The point handed back is the card's own centre on screen, because
    /// `InspectedCardView` grows out of the place that was tapped — a card arriving from
    /// nowhere makes you work out which one you asked for.
    @ViewBuilder
    func raisable(_ card: CardDescriptor,
                  _ onSelect: ((CardDescriptor, CGPoint) -> Void)?) -> some View {
        if let onSelect {
            overlay {
                GeometryReader { slot in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(card, CGPoint(x: slot.frame(in: .global).midX,
                                                   y: slot.frame(in: .global).midY))
                        }
                }
            }
        } else {
            self
        }
    }
}

/// **What a card strings together**, opened from its COMBO button.
///
/// The card being read sits on its own side of the chevrons and what it pairs with on the
/// other: what it follows to the left, what follows it to the right. A combo with more than
/// one route fans them. A route not done yet is a locked card, and a combo with no route done
/// has no name. Its own dim, so it covers the hand and the card raised out of it.
struct ComboView: View {
    let card: CardDescriptor
    let onDismiss: () -> Void

    @State private var done = DoneCombos.shared
    @State private var tuning = CardTextTuning.shared

    private enum Layout {
        static let cardWidth: CGFloat = 100
        static let fanStep: CGFloat = 14
        static let fanTurn: Double = 6
        static let nameSize: CGFloat = 30
        static let payoffSize: CGFloat = 16
        static let payoffWidth: CGFloat = 300
    }

    private static let locked = CardDescriptor(id: "locked", name: "", type: .variaball,
                                               effect: "", numberInDeck: 0)

    /// The combo this card finishes, if it finishes one.
    private var finishing: Combo? { Combo.all.first { $0.finisher.id == card.id } }

    /// The combos this card opens.
    private var opening: [Combo] {
        Combo.all.filter { combo in combo.openers.contains { $0.id == card.id } }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.66)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
            VStack(spacing: 18) {
                title
                HStack(spacing: 14) {
                    if let finishing {
                        fan(finishing.openers.map { ($0, done.hasDone($0.id, into: card.id)) })
                        DottedChevrons()
                        CardFrontView(descriptor: card, displayWidth: Layout.cardWidth)
                    } else {
                        CardFrontView(descriptor: card, displayWidth: Layout.cardWidth)
                        DottedChevrons()
                        fan(opening.map { ($0.finisher, done.hasDone(card.id, into: $0.finisher.id)) })
                    }
                }
                payoffs
            }
            .padding(.horizontal, 20)
            .allowsHitTesting(false)
        }
    }

    /// Named only once a route has been done.
    private var doneNames: [String] {
        if let finishing {
            return finishing.openers.contains { done.hasDone($0.id, into: card.id) }
                ? [finishing.name] : []
        }
        // One name however many routes it has: four dunks off a Lob are one Alley-Oop.
        return opening.filter { done.hasDone(card.id, into: $0.finisher.id) }.map(\.name)
            .reduce(into: [String]()) { names, name in
                if !names.contains(name) { names.append(name) }
            }
    }

    @ViewBuilder private var title: some View {
        if !doneNames.isEmpty {
            ActionText(doneNames.joined(separator: " / "), size: Layout.nameSize,
                       ink: CardPalette.gold, drop: CardPalette.blue, taper: 0, tracking: 0.02)
        }
    }

    /// The payoff and what it has to follow. Always, for the card that pays — it is that
    /// card's own rule. From the other end, only for combos done, or it gives them away.
    private var payoffLines: [String] {
        if let finishing { return [finishing.finisher.combo].compactMap { $0 } }
        return opening.filter { done.hasDone(card.id, into: $0.finisher.id) }
            .compactMap { combo in combo.finisher.combo.map { "\(combo.finisher.name): \($0)" } }
    }

    private var payoffs: some View {
        VStack(spacing: 6) {
            ForEach(payoffLines, id: \.self) { line in
                CardText(text: line, font: CardFont.name(tuning.weight), size: Layout.payoffSize,
                         ink: .white, highlight: tuning.highlight, face: CardFace(of: card))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: Layout.payoffWidth)
    }

    private func fan(_ entries: [(card: CardDescriptor, isDone: Bool)]) -> some View {
        let middle = Double(entries.count - 1) / 2
        return ZStack {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                let spread = Double(index) - middle
                Group {
                    if entry.isDone {
                        CardFrontView(descriptor: entry.card, displayWidth: Layout.cardWidth)
                    } else {
                        CardFrontView(descriptor: Self.locked, displayWidth: Layout.cardWidth,
                                      isBlank: true)
                    }
                }
                .rotationEffect(.degrees(spread * Layout.fanTurn), anchor: .bottom)
                .offset(x: CGFloat(spread) * Layout.fanStep)
            }
        }
        .frame(width: Layout.cardWidth + Layout.fanStep * CGFloat(max(entries.count - 1, 0)))
    }
}

/// Two chevrons drawn in dots, pointing the way a combo runs.
struct DottedChevrons: View {
    var height: CGFloat = 34

    var body: some View {
        HStack(spacing: height * 0.15) {
            ForEach(0..<2, id: \.self) { _ in
                ChevronShape()
                    .stroke(.white, style: StrokeStyle(lineWidth: height * 0.12, lineCap: .round,
                                                       dash: [0, height * 0.22]))
                    .frame(width: height * 0.45, height: height)
            }
        }
        .shadow(color: CardPalette.blue, radius: 0, x: 2, y: 2)
    }

    private struct ChevronShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            return path
        }
    }
}
