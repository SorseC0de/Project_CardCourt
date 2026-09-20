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
        // **The whole footprint is the tap**, not just the count — the pile itself is
        // usually drawn by the 3D stage, which leaves nothing here to hit but the number.
        .frame(width: width, height: width * DeckBody.frameHeight)
        .contentShape(Rectangle())
        // Nothing at all when nothing has been spent. A greyed-out zero over a bare
        // patch of floor is a thing that looks broken rather than a thing that is empty.
        .opacity(count == 0 ? 0 : 1)
        .animation(.easeOut(duration: 0.25), value: count == 0)
    }
}

/// Everything in the pile, grouped so twenty Swing Lefts read as one card with a count.
/// **One card in the pile, and how many of it are in there.**
struct DiscardEntry: Hashable {
    let card: CardDescriptor
    let count: Int

    static func == (a: DiscardEntry, b: DiscardEntry) -> Bool {
        a.card.id == b.card.id && a.count == b.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(card.id)
        hasher.combine(count)
    }
}

/// **Everything that has been spent, laid out to be read.**
///
/// The pile used to open as a grid of cards too small to read, which meant the only way
/// to find out what was in there was to already know. It is the iMAPicker now: the cards
/// fan out from whatever was tapped into a column you scroll, and tapping one stands it
/// up full size beside the list rather than choosing it — nothing here is a question.
struct DiscardBrowserView: View {
    let cards: [Card]
    /// Where the press came from, so the column fans out of it.
    var from: CGRect = .zero
    var onDismiss: () -> Void

    private enum Browse {
        static let row: CGFloat = 40
        static let raised: CGFloat = 150
        static let name: CGFloat = 13
        static let count: CGFloat = 11
    }

    private var grouped: [DiscardEntry] {
        Dictionary(grouping: cards, by: \.descriptor.id)
            .values
            .compactMap { group in group.first.map { DiscardEntry(card: $0.descriptor,
                                                                  count: group.count) } }
            .sorted { ($0.card.type.rawValue, $0.card.name)
                    < ($1.card.type.rawValue, $1.card.name) }
    }

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
                .onTapGesture(perform: onDismiss)

            if grouped.isEmpty {
                Text("Nobody has retired yet.")
                    .font(.system(size: 12)).foregroundStyle(Theme.inkDim)
            } else {
                iMAPickerList(items: grouped, sourceFrame: from) { entry, open in
                    line(entry, open: open)
                } detail: { entry in
                    CardFrontView(descriptor: entry.card, displayWidth: Browse.raised,
                                  expanded: true)
                        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                } onDismiss: {
                    onDismiss()
                }
            }

            VStack {
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
                .padding(.top, 16)
                Spacer()
            }
        }
    }

    /// One row: the card small, what it is called, and how many of it went in.
    private func line(_ entry: DiscardEntry, open: Bool) -> some View {
        HStack(spacing: 8) {
            CardFrontView(descriptor: entry.card, displayWidth: Browse.row)
            VStack(alignment: .leading, spacing: 1) {
                SmallCapsText(text: entry.card.name, font: Chrome.display,
                              size: Browse.name, tracking: Browse.name * 0.02)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if entry.count > 1 {
                    Text("×\(entry.count)")
                        .font(.system(size: Browse.count, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.inkDim)
                }
            }
            Spacer(minLength: 0)
        }
        .shadow(color: CardPalette.black, radius: 0, x: 2, y: 2)
        // The one being read stands a little out of the column.
        .scaleEffect(open ? 1.06 : 1, anchor: .leading)
        .opacity(open ? 1 : 0.75)
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
                Text("LOG")
                    .font(.system(size: 12, weight: .black)).tracking(1.6)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)

                LogView(lines: lines, showsBackground: false)
                    .frame(maxHeight: .infinity)

                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.inkDim)
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: 360, maxHeight: 520)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.panel))
            .padding(20)
        }
    }
}
