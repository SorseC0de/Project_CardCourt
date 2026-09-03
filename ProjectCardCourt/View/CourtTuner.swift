import SwiftUI

/// Court positions still being eyeballed.
///
/// Observable on purpose while it is being tuned, which means the court rebuilds as a
/// slider moves. Freeze these into `Perspective` the way `CardLayout` was once they land.
/// The shot scene's timing and the ball's path, while they are being matched to the
/// sprite by eye. Freeze these into the view once they land.
@Observable
final class ShotTuning {
    static let shared = ShotTuning()

    /// Scales every duration in the scene at once.
    var tempo: Double = 1

    /// Before the ball leaves the shooter's hands.
    var releaseDelay: Double = 0.90
    /// How long it is in the air.
    var flightSeconds: Double = 0.75

    // Where the ball starts and where the rim is, as shares of the scene.
    var startX: CGFloat = 0.66
    var startY: CGFloat = 0.55
    var rimX: CGFloat = 0.5
    var rimY: CGFloat = 0.17
    /// How far the arc bows, as a share of the width and height.
    var archX: CGFloat = 0.18
    var archHeight: CGFloat = 0.50

    /// Shrinks as it travels away from the camera.
    var ballScale: CGFloat = 15
    var ballEndScale: CGFloat = 6
    /// The hoop's width, shared by both halves of the rim so they line up.
    /// When the word lands, measured from the release. Independent of the flight,
    /// so it can arrive while the ball is still in the air.
    var wordDelay: Double = 0.60
    /// The percentage the debug shot and miss buttons pretend to. Live SHOT is usually
    /// low mid-test, which pins every miss to BRRRICK and puts bank out of reach.
    var debugChance: Double = 55
    var rimWidth: CGFloat = 138
    /// The near half alone, for lining it up over the ball's path.
    var rimNearY: CGFloat = 0.01
}

/// Where a pass lands in a player's hands, and how long it stays there.
///
/// The position is in shares of a figure's own height rather than points, so a value
/// dialled in on one seat lands in the same place on every other — whatever their scale
/// or where they stand.
@Observable
final class BallTuning {
    static let shared = BallTuning()

    /// Out from the middle of the player's feet. Negative sits it on their far side.
    var handX: CGFloat = -0.14
    /// Up from them.
    var handY: CGFloat = 0.18

    /// How long the ball takes to cross.
    var flightSeconds: Double = 0.26
    /// How long it stays in the receiver's hands before the sprite's own ball takes over.
    var holdSeconds: Double = 0.08

    /// The catch's own frame rate. Slower than the run cycle it used to borrow — a catch
    /// is a beat, not a loop. Read in two places, so it cannot desync from its own hold.
    var catchFPS: Double = 10
}

/// The deck's slab corners, while it is being worked out whether RealityKit is honouring
/// them at all. Freeze back into `DeckBody.Slab` once they land.
@Observable
final class DeckTuning {
    static let shared = DeckTuning()

    /// The corners of the card's face.
    var major: Float = 0.0050
    /// The slabs' own size against the card printed over them. 1 is the card's exact
    /// proportions, which is where this now sits — the 1.05 it needed was the top card
    /// being sized against the wrong shape, since fixed in `DeckBody`.
    var widthScale: Float = 1
    var depthScale: Float = 1
}

@Observable
final class CourtTuning {
    static let shared = CourtTuning()

    /// The card's effect text.
    /// A multiple of the font's own leading. Below 1 closes the lines up, which
    /// `Text.lineSpacing` cannot do — it clamps at zero.
    var cardTextLineHeight: CGFloat = 0.75
    var cardTextY: CGFloat = 0.75
}

#if DEBUG

/// Debug actions, tucked under the log on the left. The sliders that lived here have
/// served their purpose — their values are frozen in `CardLayout`.
struct DebugActionsView: View {
    var controller: GameController
    @State private var ball = BallTuning.shared
    /// Who a practice pass goes to. Always from the player, so this is the whole choice.
    @State private var target = 0

    private static let targets: [Seat] = [.east, .north, .west]
    @State private var showShotTuner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                action("draw") { controller.debugDraw() }
                action("dump") { controller.debugDiscardHand() }
                action("FTs") { controller.debugFreeThrows() }
                action("unsee") { SeenCards.shared.forgetAll() }
                action("→ \(Self.targets[target].playerName)") {
                    target = (target + 1) % Self.targets.count
                }
                action("pass") { controller.debugPass(to: Self.targets[target]) }
            }
            HStack(spacing: 4) {
                action("travel") { controller.debugTurnover(.whistle("Travel")) }
                action("clock") { controller.debugTurnover(.shotClock) }
                action("loose") { controller.debugTurnover(.whistle("Back Court Violation")) }
                action("shot") { controller.debugShot() }
                action("miss") { controller.debugMiss() }
                action(showShotTuner ? "hide" : "ball") { showShotTuner.toggle() }
            }
            HStack(spacing: 4) {
                action(RenderDebug.shared.flatPiles ? "3D off" : "3D on") {
                    RenderDebug.shared.flatPiles.toggle()
                }
                action(RenderDebug.shared.courtStage ? "stage on" : "stage off") {
                    RenderDebug.shared.courtStage.toggle()
                }
                action("deal") { controller.debugDeal() }
                action("open") { controller.debugOpening() }
                action("shuffle") { controller.debugDeck(.shuffle) }
                action("land") { controller.debugDeck(.landing) }
                action("arm") { controller.debugArmWhistle() }
                action("blow") { controller.debugBlowWhistle() }
            }
            if showShotTuner { ballSliders }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.6)))
    }

    private var ballSliders: some View {
        VStack(alignment: .leading, spacing: 0) {
            slider("hand X", bind(\.handX), -0.3...0.3)
            slider("hand Y", bind(\.handY), -0.3...0.3)
            slider("flight", bind(\.flightSeconds), 0.1...1.5)
            slider("hold", bind(\.holdSeconds), 0...1.5)
            slider("catch fps", bind(\.catchFPS), 2...20)
        }
        .frame(width: 150)
    }

    private func bind(_ path: ReferenceWritableKeyPath<BallTuning, Double>) -> Binding<Double> {
        Binding(get: { ball[keyPath: path] }, set: { ball[keyPath: path] = $0 })
    }

    private func bind(_ path: ReferenceWritableKeyPath<BallTuning, CGFloat>) -> Binding<Double> {
        Binding(get: { Double(ball[keyPath: path]) },
                set: { ball[keyPath: path] = CGFloat($0) })
    }

    private func slider(_ label: String, _ value: Binding<Double>,
                        _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: -3) {
            Text("\(label)  \(String(format: "%.2f", value.wrappedValue))")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Slider(value: value, in: range).tint(PixelPalette.gold).scaleEffect(0.75)
        }
    }

    private func action(_ label: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(PixelPalette.gold))
        }
        .buttonStyle(.plain)
    }
}

#endif
