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
    @State private var cardText = false
    /// Bumped to re-key the payouts, so they land again.
    @State private var replays = 0
    /// The two passes the crystal bone is being tried in. The second may be "off", which
    /// is how a single pass is compared against a pair.
    @State private var first = 0
    @State private var second = 1

    /// What the crystal bone is drawn with right now.
    private var crystalPasses: [BlendMode] {
        [Self.blends[first].mode, Self.blends[second].mode].compactMap { $0 }
    }

    /// The ones worth trying for glass. Normal first, so the difference is obvious.
    private static let blends: [(name: String, mode: BlendMode?)] = [
        ("softLight", .softLight), ("screen", .screen), ("off", nil),
        ("normal", .normal), ("plusLighter", .plusLighter), ("overlay", .overlay),
        ("hardLight", .hardLight), ("luminosity", .luminosity),
        ("colorDodge", .colorDodge), ("plusDarker", .plusDarker),
    ]

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

                // **The currency, as it is handed over.** Four ramps off one
                // drawing, shown the way the end of a match shows them — see `BoneAward`.
                // Tap to watch one land again.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Swishbones").font(.system(size: 15, weight: .heavy))
                    ForEach(Bone.allCases) { bone in
                        HStack(spacing: 12) {
                            BoneAward(bone: bone, amount: 12, side: 44,
                                      blends: bone == .crystal ? crystalPasses : nil)
                                .id("\(bone.rawValue)-\(replays)-\(first)-\(second)")
                            Spacer(minLength: 0)
                            Text(bone.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(CardPalette.gray)
                        }
                    }
                    // **Which blend makes glass is a thing to look at, not to reason
                    // about.** Cycles the crystal one through the candidates.
                    HStack(spacing: 10) {
                        Button("play again") { replays += 1 }
                        Button("1: \(Self.blends[first].name)") {
                            first = (first + 1) % Self.blends.count
                        }
                        Button("2: \(Self.blends[second].name)") {
                            second = (second + 1) % Self.blends.count
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(CardPalette.gold)
                }

                // **On the device, not in the canvas.** A preview is a different screen
                // at a different size, and settling the printing there is how the words
                // ended up set for a machine nobody plays on.
                ChunkyButton(title: "Card text", fill: CardPalette.orange,
                             stroke: CardPalette.gold, shade: CardPalette.red,
                             size: 16) { cardText = true }
                Text("Every number the words are set by, over the wordiest card of each "
                     + "type, at both the sizes a card is read at.")
                    .font(.system(size: 11))
                    .foregroundStyle(CardPalette.gray)

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
        .fullScreenCover(isPresented: $cardText) {
            CardTextBench(onDismiss: { cardText = false })
        }
    }
}
#endif
