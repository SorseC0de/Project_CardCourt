import SwiftUI

/// The discard pile, sitting beside the deck. Smaller, because it is reference rather
/// than a thing you draw from.
struct DiscardPileView: View {
    let count: Int
    var width: CGFloat = 32

    /// False when a court-wide stage is drawing the pile instead.
    var showsPile = true


    private enum Pile {
        /// The same rule the deck grows by, so the two piles are the same object at
        /// different heights.
        static let cardsPerLayer = 10
    }

    /// From nothing upward — an empty discard is an empty floor, not a thin stack.
    private var layers: Int {
        max(0, min(DeckBody.maxLayers, count / Pile.cardsPerLayer))
    }

    /// The same renderer as the deck, which is the only way the two are guaranteed to
    /// sit at the same angle.
    ///
    /// Drawing this with `rotation3DEffect` and matching the deck by eye does not work:
    /// SwiftUI's `perspective` and a RealityKit camera are different projections, so no
    /// tilt makes them agree — and even a matched top card would have its stacked edges
    /// recede differently. Sharing the camera removes the question.
    private var pile: some View {
        DeckBody(layers: layers)
            .frame(width: width, height: width * DeckBody.frameHeight)
            // Spent cards. Only the pile is drained of colour — a card pulled back out to
            // be read is drawn by `CardFrontView` and is untouched.
            .grayscale(1)
            .allowsHitTesting(false)
    }

    var body: some View {
        VStack(spacing: showsPile ? -width * DeckBody.labelGap : 4) {
            if showsPile { pile }
            Text("\(count)")
                .font(.custom("AvenirNextCondensed-Heavy", size: 18))
                .foregroundStyle(CardPalette.gray)
                .shadow(color: CardPalette.blue, radius: 0, x: 2, y: 2)
                .contentTransition(.numericText())
        }
        .opacity(count == 0 ? 0.35 : 1)
    }
}

/// Everything in the pile, grouped so twenty Swing Lefts read as one card with a count.
struct DiscardBrowserView: View {
    let cards: [Card]
    var onDismiss: () -> Void

    private var grouped: [(descriptor: CardDescriptor, count: Int)] {
        Dictionary(grouping: cards, by: \.descriptor.id)
            .values
            .compactMap { group in group.first.map { ($0.descriptor, group.count) } }
            .sorted { ($0.descriptor.type.rawValue, $0.descriptor.name)
                    < ($1.descriptor.type.rawValue, $1.descriptor.name) }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 10) {
                HStack {
                    Text("DISCARD · \(cards.count)")
                        .font(.system(size: 12, weight: .black)).tracking(1.6)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.inkDim)
                    }
                }
                .padding(.horizontal, 18)

                if grouped.isEmpty {
                    Spacer()
                    Text("Nothing discarded yet.")
                        .font(.system(size: 12)).foregroundStyle(Theme.inkDim)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)],
                                  spacing: 12) {
                            ForEach(grouped, id: \.descriptor.id) { entry in
                                CardFrontView(descriptor: entry.descriptor, displayWidth: 84)
                                    .overlay(alignment: .topTrailing) {
                                        if entry.count > 1 {
                                            Text("×\(entry.count)")
                                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 5).padding(.vertical, 2)
                                                .background(Capsule().fill(CardPalette.navy))
                                                .offset(x: 4, y: -4)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    }
                }
            }
            .padding(.top, 16)
        }
    }
}
