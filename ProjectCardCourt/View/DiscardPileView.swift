import SwiftUI

/// **Retirement**, sitting beside the deck — where a spent card goes. Smaller, because it is reference rather
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
        // Flat, and owing RealityKit nothing — see `FlatPile`. Thinner slabs than the
        // deck's, so a handful of cards is a handful rather than a shrunken deck.
        FlatPile(layers: layers, slab: 0.035)
            .frame(width: width, height: width * DeckBody.frameHeight)
            // Spent cards. Only the pile is drained of colour — a card pulled back out to
            // be read is drawn by `CardFrontView` and is untouched.
            .grayscale(1)
            .allowsHitTesting(false)
    }

    private enum Spent {
        /// The same lift the draw pile rides at, so the two sit on one floor.
        static let lift: CGFloat = 0.12
        /// How far under that the count sits, as a share of the width. Placed rather than
        /// stacked: the pile is drawn by the 3D stage most of the time, so there is
        /// nothing here for a `VStack` to measure against — which is what displaced it.
        static let countDrop: CGFloat = 0.30
    }

    var body: some View {
        ZStack {
            if showsPile {
                pile.offset(y: -width * Spent.lift)
            }
            Text("\(count)")
                .font(.custom("AvenirNextCondensed-Heavy", size: 24))
                .foregroundStyle(.white)
                .shadow(color: CardPalette.blue, radius: 0, x: 2, y: 2)
                .contentTransition(.numericText())
                .offset(y: width * Spent.countDrop)
        }
        // Nothing at all when nothing has been spent. A greyed-out zero over a bare
        // patch of floor is a thing that looks broken rather than a thing that is empty.
        .opacity(count == 0 ? 0 : 1)
        .animation(.easeOut(duration: 0.25), value: count == 0)
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
            DimLayer(on: true, amount: Theme.dimBrowser)
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 10) {
                HStack {
                    Text("RETIRED · \(cards.count)")
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
                    Text("Nobody has retired yet.")
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


/// **The game's log, opened on request** — the same dimmed pop-up the discard pile uses.
///
/// It lived as a strip across the top of the court, and a scrolling wall of text was
/// winning the fight for the eye. Here it is somewhere you go to look, the way the pile is,
/// and the newest line is at the bottom where the eye lands.
struct LogBrowserView: View {
    let lines: [LogLine]
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 10) {
                HStack {
                    Text("LOG")
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

                LogView(lines: lines, showsBackground: false)
                    .frame(maxHeight: .infinity)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: 360, maxHeight: 520)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.panel))
            .padding(20)
        }
    }
}
