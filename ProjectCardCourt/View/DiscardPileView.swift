import SwiftUI

/// The discard pile, sitting beside the deck. Smaller, because it is reference rather
/// than a thing you draw from.
struct DiscardPileView: View {
    let count: Int
    var width: CGFloat = 32

    var body: some View {
        VStack(spacing: 3) {
            Image("CardBack")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: width)
            Text("\(count)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.inkDim)
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
