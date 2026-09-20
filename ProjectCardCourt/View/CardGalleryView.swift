import SwiftUI

/// Every card in the game, by type.
///
/// A reference sheet rather than a feature: what is drawn, what is worded, and what is
/// still wearing a stand-in symbol, all in one place. It reads `CardLibrary.all`, so a
/// card added to the library turns up here without being added anywhere else.
struct CardGalleryView: View {
    var onDismiss: () -> Void = {}

    @State private var type: CardType = .pass
    @State private var raised: CardDescriptor?
    /// The two a raised card can open — see `CardFrontView`'s COMBO and BONUS.
    @State private var comboOf: CardDescriptor?
    @State private var bonusOf: (card: CardDescriptor, at: CGPoint)?

    private enum Sheet {
        static let card: CGFloat = 96
        static let gap: CGFloat = 12
    }

    /// Every type that has cards, in the order the sheet lists them.
    private var types: [CardType] {
        [.pass, .move, .specialMove, .clamp, .whistle, .gameBreak, .injury, .intangible,
         .varena, .variaball]
            .filter { kind in CardLibrary.all.contains { $0.type == kind } }
    }

    private var showing: [CardDescriptor] {
        CardLibrary.all.filter { $0.type == type }.sorted { $0.name < $1.name }
    }

    var body: some View {
        ZStack {
            Chrome.ground.ignoresSafeArea()

            VStack(spacing: 14) {
                header
                tabs
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: Sheet.card),
                                                 spacing: Sheet.gap)],
                              spacing: Sheet.gap) {
                        ForEach(showing) { card in
                            CardFrontView(descriptor: card, displayWidth: Sheet.card,
                                          expanded: true)
                                .onTapGesture { raised = card }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .padding(.top, 14)

            if let raised {
                DimLayer(on: true, amount: Theme.dimBrowser)
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { self.raised = nil }
                CardFrontView(descriptor: raised, displayWidth: 240, expanded: true,
                              onCombo: { comboOf = raised },
                              onBonus: { bonusOf = (card: raised, at: $0) })
                    .shadow(color: .black.opacity(0.55), radius: 22, y: 12)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            // **What the two buttons on a raised card open**, the same pair the floor
            // opens: the combos this card finishes, and the lines its bonus prints.
            if let comboOf {
                ComboView(card: comboOf) { self.comboOf = nil }
                    .transition(.opacity)
                    .zIndex(9)
            }
            if let bonusOf {
                BonusBubble(lines: bonusOf.card.bonusLines, anchor: bonusOf.at) {
                    self.bonusOf = nil
                }
                .zIndex(9)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: raised)
    }

    private var header: some View {
        HStack {
            ScreenTitle(text: "Card Gallery", size: 28, drop: CardPalette.blue)
            Spacer()
            Text("\(CardLibrary.all.count) cards")
                .font(.custom(Chrome.display, size: 15))
                .foregroundStyle(CardPalette.gray)
            Button(action: onDismiss) {
                Chip(fill: CardPalette.red, stroke: CardPalette.gold,
                     shade: CardPalette.orange, side: 34) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    /// One tab per type, wearing that type's own colour so the row doubles as a legend.
    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(types, id: \.self) { kind in
                    let on = kind == type
                    SmallCapsText(text: kind.rawValue, font: Chrome.display, size: 14,
                                  tracking: 1)
                        .foregroundStyle(on ? .white : CardPalette.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(on ? Theme.color(for: kind)
                                                      : CardPalette.black))
                        .overlay(Capsule().strokeBorder(on ? CardPalette.gold : .clear,
                                                        lineWidth: 3))
                        .onTapGesture { type = kind }
                }
            }
            .padding(.horizontal, 16)
        }
        .animation(.easeOut(duration: 0.2), value: type)
    }
}

#if DEBUG
#Preview("Card gallery") { CardGalleryView() }
#endif
