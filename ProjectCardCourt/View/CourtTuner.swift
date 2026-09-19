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
    /// When the ball leaves his hand. **Read off the sheet**: the release happens on a
    /// particular cell of the shot's thirteen, so this is that cell's own time and it
    /// follows the rate rather than being retuned by hand. It was 0.90 at eight frames a
    /// second, which is cell seven — and stayed 0.90 when the rate went to ten, which put
    /// the ball in the air a fifth of a second after his hand had finished with it.
    var releaseDelay: Double = ShotTiming.release
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

/// Where the piles stand on the court and how big they read, while that is still being
/// eyeballed. Freeze into `Perspective` and `DeckStackView` once it lands.
///
/// One owner for both renderers. The flat pile and the staged one are drawn by completely
/// unrelated code, and reading the same numbers is the only thing that keeps them in the
/// same place — the 2D pile used to carry a `geo.height * 0.02` nudge the stage never got.
@Observable
final class DeckTuning {
    static let shared = DeckTuning()

    /// Multiplies whatever size the piles would otherwise read at.
    /// Small, so the deck has room to fly about the court without running into anybody.
    var size: CGFloat = 0.555
    /// Mirrored about the centre line: the deck goes one way and the discard the other,
    /// so this spreads the pair apart rather than sliding both sideways.
    var x: CGFloat = 0.030
    var y: CGFloat = 0.02
    /// The tallest the draw pile is ever drawn, in slabs.
    ///
    /// A reading rather than a count: Standard deals from close to four hundred cards, and
    /// drawing them honestly stands a tower on the floor taller than the players around it.
    var slabs: CGFloat = 10
}

/// Where the two lines of the inbound prompt sit, while that is being eyeballed. Freeze
/// into `CourtView.inboundPrompt` once they land.
/// Where a dealt card finishes turning.
///
/// **Only the far end is a dial.** The near end is not a choice — a card comes off the
/// top of a pile at that pile's own lean, which `DeckStage.bowAngle` already says — and
/// the tween is the whole of what happens in between. So there is one number here.
@Observable
@MainActor
final class DealTuning {
    static let shared = DealTuning()
    /// Degrees from lying flat, about the axis it is travelling along. Ninety is standing
    /// straight up; the sign is which way it turns over.
    var endAngle: Double = -90
}

@Observable
final class InboundTextTuning {
    static let shared = InboundTextTuning()

    var topX: CGFloat = 0
    var topY: CGFloat = 270
    var bottomX: CGFloat = 0
    var bottomY: CGFloat = 300

    /// Where the ball sits in the thrower's hands, in art pixels from his frame's top
    /// left — art pixels rather than points, so it stays put at any scale.
    var ballX: CGFloat = 14
    var ballY: CGFloat = 14

    /// How far the thrower stands from the middle of the floor. The other seats do not
    /// move — they line up by depth instead, which is `Perspective.inboundLine`.
    /// North-west of North, rather than straight up from him.
    var throwerX: CGFloat = -120
}

#if DEBUG

/// Debug actions, tucked under the log on the left.
///
/// Two rows when open, and one pill when it is not. Everything that had finished its job
/// is gone rather than hidden: the flat-pile switch that measured what the renderer cost,
/// the pass sliders now frozen in `Theme.Pass`, the slab-corner sliders now taken from the
/// card's own eight per cent, and the shuffle and landing buttons that built the two
/// halves of a deal nobody triggers separately any more.
///
/// What is left is either a thing to poke at during a game, or a knob still being turned.
struct DebugActionsView: View {
    var controller: GameController

    @State private var deck = DeckTuning.shared
    @State private var dunks = DunkTuning.shared
    /// The card's face lives on the printing dial now — see `CardTextStyle`.
    @State private var printing = CardTextTuning.shared
    /// Observed, or the switch's own label never changes and it reads as dead.
    @State private var render = RenderDebug.shared
    /// Who a practice pass goes to. Always from the player, so this is the whole choice.
    @State private var target = 0

    private static let targets: [Seat] = [.east, .north, .west]

    /// Kept across launches — folding it shut on every relaunch was worse than the panel
    /// being open.
    @AppStorage("bench.open") private var isOpen = true
    @AppStorage("bench.cuts") private var showCuts = false
    @AppStorage("bench.deck") private var showDeck = false
    /// The one HUD arrangement that is a setting rather than a measurement.
    @AppStorage(DeckReadout.setting) private var deckReadout = DeckReadout.over

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            action(isOpen ? "bench ▾" : "bench ▸") { isOpen.toggle() }
            if isOpen { rows }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.6)))
        .animation(.easeOut(duration: 0.15), value: isOpen)
    }

    /// The live tools, and a door to each of the two things worth watching on their own.
    private var rows: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                action("draw") { controller.debugDraw() }
                action("dump") { controller.debugDiscardHand() }
                action("→ \(Self.targets[target].playerName)") {
                    target = (target + 1) % Self.targets.count
                }
                action("pass") { controller.debugPass(to: Self.targets[target]) }
                action("arm") { controller.debugArmWhistle() }
                action("blow") { controller.debugBlowWhistle() }
                action("gravity") { controller.debugGravity(to: Self.targets[target]) }
            }
            HStack(spacing: 4) {
                action(showCuts ? "cuts ▾" : "cuts ▸") { showCuts.toggle() }
                action(showDeck ? "deck ▾" : "deck ▸") { showDeck.toggle() }
                action("count: \(deckReadout.rawValue)") {
                    deckReadout = deckReadout.next
                }
                action("unsee") {
                    SeenCards.shared.forgetAll()
                    DoneCombos.shared.forgetAll()
                }
                action("Aa \(printing.weight.label)") {
                    printing.weight = printing.weight.next
                }
                // Not a real screen yet, and it cannot be until the app has a Game Center
                // record to authenticate against.
            }
            if showCuts {
                HStack(spacing: 4) {
                    action("travel") { controller.debugTurnover(.whistle("Travel")) }
                    action("clock") { controller.debugTurnover(.shotClock) }
                    action("loose") { controller.debugTurnover(.whistle("Back Court Violation")) }
                    action("shot") { controller.debugShot() }
                    // **Throws one and moves on to the next.** The button showed
                    // whichever finish the bench was set to and threw that one forever,
                    // so a placement settled here had been settled against a third of
                    // the evidence. Tap three times and you have seen all three.
                    action("dunk \(DunkBench.label(dunks.showing))") {
                        controller.debugDunk(dunks.showing)
                        dunks.showing = Dunk.allCases[
                            (Dunk.allCases.firstIndex(of: dunks.showing)! + 1)
                                % Dunk.allCases.count]
                    }
                    action("name") { controller.debugNameCall() }
                    action("lethal") { controller.debugUnderstood() }
                    action("three") { controller.debugThree() }
                    action("miss") { controller.debugMiss() }
                    action("FTs") { controller.debugFreeThrows() }
                }
                // **Where the finish lands, in art pixels over the ring.** On the phone
                // rather than in the preview canvas: the two are different heights, and
                // this was settled on the one nobody plays.
                slider("dunk y",
                       Binding(get: { Double(dunks.overTheRim) },
                               set: { dunks.overTheRim = CGFloat(($0).rounded()) }),
                       -10...10)
                    .frame(width: 150)
            }
            if showDeck {
                HStack(spacing: 4) {
                    action("deal") { controller.debugDeal() }
                    action("open") { controller.debugOpening() }
                    action(render.courtStage ? "stage ✓" : "stage ✗") {
                        render.courtStage.toggle()
                    }
                    action("reset") {
                        deck.size = 0.555; deck.x = 0.030; deck.y = 0.02; deck.slabs = 10
                    }
                }
                deckSliders
            }
        }
    }

    /// Moves and sizes both piles at once — they are a pair, and the discard drifting away
    /// from the deck is never what is wanted.
    private var deckSliders: some View {
        VStack(alignment: .leading, spacing: 0) {
            slider("size", bind(\.size), 0.3...2.5)
            slider("slabs", bind(\.slabs), 1...20)
            slider("x", bind(\.x), -0.25...0.25)
            slider("y", bind(\.y), -0.25...0.25)
            // The far end of a dealt card's turn. Whole turn either way, so the answer
            // is reachable whichever direction it wants to go.
            slider("deal°", Binding(get: { DealTuning.shared.endAngle },
                                    set: { DealTuning.shared.endAngle = $0 }),
                   -180...180)
        }
        .frame(width: 150)
    }

    private func bind(_ path: ReferenceWritableKeyPath<DeckTuning, CGFloat>) -> Binding<Double> {
        Binding(get: { Double(deck[keyPath: path]) },
                set: { deck[keyPath: path] = CGFloat($0) })
    }

    private func slider(_ label: String, _ value: Binding<Double>,
                        _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: -3) {
            Text("\(label)  \(String(format: "%.3f", value.wrappedValue))")
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


/// Where the shot's beats fall on its own sheet.
enum ShotTiming {
    /// The cell the ball leaves on, of `Sprite.shoot`'s thirteen.
    static let releaseCell: Double = 7
    static var release: Double { releaseCell / Theme.Figure.shootFPS }
}
