#if DEBUG
import SwiftUI

/// The handful of switches that have to be reachable **before** a match starts.
///
/// The bench lives on the floor, which is no use for anything that stops you getting to
/// the floor: the 3D stage is a full RealityKit renderer, and a device that hangs bringing
/// one up hangs before there is a bench to poke at. These are the ones you would want on
/// the way in.
struct FrontBenchView: View {
    var onDismiss: () -> Void

    @State private var render = RenderDebug.shared
    @State private var deck = DeckTuning.shared
    @State private var sprites = false

    var body: some View {
        ZStack {
            CardPalette.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(text: "Bench", size: 30, drop: CardPalette.blue)

                Toggle(isOn: $render.courtStage) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("3D deck stage").font(.system(size: 15, weight: .heavy))
                        Text("Off draws the piles flat. Turn it off if the game hangs on "
                             + "the way in — that is RealityKit starting up.")
                            .font(.system(size: 11))
                            .foregroundStyle(CardPalette.gray)
                    }
                }
                .tint(CardPalette.gold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Deck height  \(Int(deck.slabs)) slabs")
                        .font(.system(size: 15, weight: .heavy))
                    Slider(value: $deck.slabs, in: 1...20, step: 1).tint(CardPalette.gold)
                }

                ChunkyButton(title: "Sprite gallery", fill: CardPalette.navy,
                             stroke: CardPalette.gold, shade: CardPalette.blue,
                             size: 16) { sprites = true }
                Text("Every sheet a player is drawn from, with the face composed on it "
                     + "the way the game composes it — for checking where the eyes land.")
                    .font(.system(size: 11))
                    .foregroundStyle(CardPalette.gray)

                Spacer()
                ChunkyButton(title: "Done", fill: CardPalette.blue,
                             stroke: CardPalette.gold, shade: CardPalette.navy,
                             size: 18, run: onDismiss)
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .fullScreenCover(isPresented: $sprites) {
            SpriteGallery(onDismiss: { sprites = false })
        }
    }
}
#endif
