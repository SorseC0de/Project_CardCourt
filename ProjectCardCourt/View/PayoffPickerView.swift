import SwiftUI

/// **You beat your man.** The defender who has just been sent off, held up with the three
/// things blowing by him is worth.
///
/// The same three every time, so the choice is learnt once and then known for the rest of
/// the game — see `ClampPayoff`. The card is shown rather than named because the printed
/// counter on its face is what was just met, and seeing it there is how a player learns
/// that the condition was the way out all along.
struct PayoffPickerView: View {
    let clamp: CardDescriptor
    /// The one a controller is pointing at. **A stack, not a row** — see `Row.runsDown`.
    var ringed: ClampPayoff?
    var onPick: (ClampPayoff) -> Void

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()

            VStack(spacing: 18) {
                ActionText(runs: [.init("BLOW-BY", ink: CardPalette.gold,
                                        drop: CardPalette.orange)], size: 34)
                CardFrontView(descriptor: clamp, displayWidth: 150, expanded: true)
                    .shadow(color: .black.opacity(0.55), radius: 20, y: 10)
                    // Beaten, and on his way off.
                    .rotationEffect(.degrees(-6))

                VStack(spacing: 10) {
                    ForEach(ClampPayoff.allCases) { payoff in
                        ChunkyButton(title: payoff.label.uppercased(),
                                     fill: CardPalette.blue,
                                     stroke: CardPalette.blue,
                                     shade: CardPalette.darkBlue,
                                     size: 18) { onPick(payoff) }
                            .padRing(pill: ringed == payoff)
                    }
                }
                .padding(.horizontal, 30)
            }
        }
        .transition(.opacity)
    }
}
