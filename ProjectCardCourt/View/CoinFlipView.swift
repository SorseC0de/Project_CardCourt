import SwiftUI

/// A coin thrown where it can be seen.
///
/// **It decides something.** No-Look draws on Heads, Bankshot swings SHOT either way — and
/// all of it was over inside a frame, so the only sign a coin had been thrown at all was a
/// line in the log.
struct CoinFlip: Identifiable, Equatable {
    let id = UUID()
    let seat: Seat
    let card: CardDescriptor
    /// How many came up Heads, out of how many were thrown.
    let heads: Int
    let flips: Int

    /// How long it is in the air, and how long the whole thing is on screen.
    static let spin: Double = 0.85
    static let seconds: Double = 1.5

    /// A run of them says the count; a single one says the side.
    var word: String {
        guard flips == 1 else { return "\(heads) of \(flips) Heads" }
        return heads == 1 ? "Heads" : "Tails"
    }

    var isHeads: Bool { heads * 2 >= flips }
}

struct CoinFlipView: View {
    let flip: CoinFlip

    @State private var turns: Double = 0
    @State private var landed = false
    @State private var lift: CGFloat = 0

    private enum Coin {
        static let sideWidth: CGFloat = 92
        /// How far it rises out of the throw, and the drop under it.
        static let rise: CGFloat = 54
        static let drop: CGFloat = 2
        /// Half turns in the air. Enough to read as a flip rather than a wobble.
        static let halfTurns: Double = 6
        static let textSize: CGFloat = 30
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                coin
                    .offset(y: -lift)
                if landed {
                    ActionText(flip.word.uppercased(), size: Coin.textSize,
                               ink: CardPalette.gold,
                               drop: flip.isHeads ? CardPalette.blue : CardPalette.red)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
                SmallCapsText(text: flip.card.name, font: Chrome.display, size: 16)
                    .foregroundStyle(.white)
                    .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
            }
        }
        .allowsHitTesting(false)
        .task { await throwIt() }
    }

    /// Gold, with the game's own ball on its face — it is the coin this game tosses.
    private var coin: some View {
        ZStack {
            let coinImage = flip.isHeads ? "BallVector" : "TypeClampFront"
            let imgPadding = flip.isHeads ? Coin.sideWidth * 0.25 : 0
            let strokeColor = landed ? (flip.isHeads ? CardPalette.blue : CardPalette.red) : CardPalette.purple
            let dropColor = landed ? (flip.isHeads ? CardPalette.darkBlue : CardPalette.darkRed) : CardPalette.plum
            Circle()
                .fill(landed ? CardPalette.brown : CardPalette.blood)
                .overlay(Circle().fill(landed ? CardPalette.gold : CardPalette.blood).frame(width: Coin.sideWidth * 0.75, height: Coin.sideWidth * 0.75))
                .overlay(Circle().strokeBorder(strokeColor, lineWidth: 5))
                .shadow(color: dropColor, radius: 0, x: Coin.drop, y: Coin.drop)
                
            if landed {
                Image(coinImage)
                    .resizable()
                    .scaledToFit()
                    .padding(imgPadding)
            }
        }
        .frame(width: Coin.sideWidth, height: Coin.sideWidth)
        // Turned about its own edge, so it reads as a coin rather than a spinning disc.
        .rotation3DEffect(.degrees(turns), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
    }

    private func throwIt() async {
        withAnimation(.easeOut(duration: CoinFlip.spin * 0.45)) { lift = Coin.rise }
        withAnimation(.easeInOut(duration: CoinFlip.spin)) {
            turns = 180 * Coin.halfTurns
        }
        try? await Task.sleep(for: .seconds(CoinFlip.spin * 0.45))
        withAnimation(.easeIn(duration: CoinFlip.spin * 0.55)) { lift = 0 }
        try? await Task.sleep(for: .seconds(CoinFlip.spin * 0.55))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { landed = true }
    }
}

#if DEBUG
#Preview("Coin flip") {
    ZStack {
        Theme.panel.ignoresSafeArea()
        CoinFlipView(flip: CoinFlip(seat: .south, card: CardLibrary.noLook, heads: 1, flips: 4))
    }
}
#endif
