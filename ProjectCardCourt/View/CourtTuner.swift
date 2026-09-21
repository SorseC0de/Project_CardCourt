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

/// **How far out each row of referees stands**, while it is being eyeballed. Freeze into
/// `Perspective` once it lands.
@Observable
final class RefereeTuning {
    static let shared = RefereeTuning()

    /// The far pair, up the wings: a share of the floor's half-width at their depth.
    var farSpread: CGFloat = 0.75
    /// How far up the floor they stand, as floor depth — above North, who is at 0.11.
    var farDepth: CGFloat = 0.07
    /// How big they are drawn against what their depth alone would make them.
    var farScale: CGFloat = 0.85
    /// The near pair beside South: how far in from the screen's edge, in points. Nought
    /// is as far out as they go with the whole of them still on screen; below it they go
    /// part way off it.
    var nearInset: CGFloat = -75
    /// How far nearer the camera than South they stand, as floor depth.
    var nearStep: CGFloat = 0.15
    /// How big they are drawn against what their depth alone would make them.
    var nearScale: CGFloat = 1
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

/// **The fan of cards in your own hand**, while its three readings are being eyeballed:
/// how far it sits down over the ball, how far apart the cards stand, and how big they
/// are drawn. Freeze into `FannedBagView.Hand` and `ActionBarView.Act` once they land.
@Observable
@MainActor
final class HandTuning {
    static let shared = HandTuning()

    /// How far the hand comes down over the rows under it, in points. Bigger sinks it
    /// further onto the ball.
    var lift: CGFloat = 75
    /// What is left showing of the card underneath, as a share of a card's width.
    var spacing: CGFloat = 0.75
    /// Multiplies the card's drawn width, and the room the fan stands in with it.
    var scale: CGFloat = 1
}

/// **The ball standing out of its own card**, under the blocks: how big it is drawn
/// against that card, and where it sits on it. Freeze into `GameView` once it lands.
@Observable
@MainActor
final class BallOverlayTuning {
    static let shared = BallOverlayTuning()

    /// A share of the card's own width.
    var scale: CGFloat = 0.5
    /// Where it sits on the card, in points from its middle. It rides high on the card,
    /// clear of the words.
    var x: CGFloat = 0
    var y: CGFloat = -15
}

/// **The four things on screen while a board is up**, each on its own scale and line:
/// the words, the button that answers them, the hand they are answered out of, and the
/// row of men going up for it. Freeze into their own views once they land.
@Observable
@MainActor
final class ReboundSceneTuning {
    static let shared = ReboundSceneTuning()

    /// "Crashing the Glass" and the line under it.
    var titleScale: CGFloat = 1
    var titleY: CGFloat = -72
    /// The button the bid is placed with.
    var buttonScale: CGFloat = 1
    var buttonY: CGFloat = 110
    /// The cards it is placed out of.
    var handScale: CGFloat = 1
    var handY: CGFloat = 140
    /// Heads, names and Bag counts.
    var bidsScale: CGFloat = 0.7
    /// Measured from under the ball now, not from the middle of the screen.
    var bidsY: CGFloat = 0
    /// The ball itself — or Monster Ball's prize, which stands where it does.
    var ballScale: CGFloat = 1
    var ballY: CGFloat = -1.5
}

/// **The wedges over the ball** — the Moves left, and the three finishes they become —
/// while their size and their seams are being eyeballed. Freeze into `ShootDomeView.Dome`
/// once they land.
@Observable
@MainActor
final class MoveArcTuning {
    static let shared = MoveArcTuning()

    /// Multiplies a wedge as a whole: both how thick the band is and how far round the
    /// ball's shoulder the three of them run.
    var scale: CGFloat = 0.9
    /// The seam between two wedges, in degrees.
    var spacing: Double = 3
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
    @AppStorage("bench.refs") private var showRefs = false
    @State private var refs = RefereeTuning.shared
    @AppStorage("bench.hand") private var showHand = false
    @AppStorage("bench.pass") private var showPass = false
    @AppStorage("bench.board") private var showBoard = false
    /// What a board's four things are set at — see `ReboundSceneTuning`.
    @State private var board = ReboundSceneTuning.shared
    @State private var moveHUD = MoveHUDTuning.shared
    /// The three beats a pass is paced by — see `PassTuning`.
    @State private var pass = PassTuning.shared
    /// The hand's own three readings, and the wedges standing over the ball beside it.
    @State private var hand = HandTuning.shared
    @State private var arc = MoveArcTuning.shared
    /// The ball standing out of its card, under the blocks.
    @State private var overlay = BallOverlayTuning.shared
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
                action(showRefs ? "refs ▾" : "refs ▸") { showRefs.toggle() }
                action(showHand ? "hand ▾" : "hand ▸") { showHand.toggle() }
                action(showPass ? "pass ▾" : "pass ▸") { showPass.toggle() }
                action(showBoard ? "board ▾" : "board ▸") { showBoard.toggle() }
                // **Both meters are kept.** The arcs were the meter before the drawing
                // was; this says which is up, so the two can be looked at side by side.
                action(moveHUD.drawn ? "moves: drawn" : "moves: arcs") {
                    moveHUD.drawn.toggle()
                }
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
            // **The 2X mark's line**, up here rather than behind a door: it is set in
            // card text, which is on screen whatever else is.
            slider("2X y", Binding(get: { Double(printing.markDrop) },
                                   set: { printing.markDrop = CGFloat($0) }),
                   -0.6...0.9)
                .frame(width: 150)
            if showCuts {
                HStack(spacing: 4) {
                    action("travel") { controller.debugTurnover(.whistle("Travel")) }
                    action("clock") { controller.debugTurnover(.shotClock) }
                    action("loose") { controller.debugTurnover(.whistle("Back Court Violation")) }
                    action("shot") { controller.debugShot() }
                    action("layup") { controller.debugLayup() }
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
            if showRefs {
                HStack(spacing: 4) {
                    action("reset") {
                        refs.farSpread = 0.75; refs.farDepth = 0.07; refs.farScale = 0.85
                        refs.nearInset = -75; refs.nearStep = 0.15; refs.nearScale = 1
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    slider("far spread",
                           Binding(get: { Double(refs.farSpread) },
                                   set: { refs.farSpread = CGFloat($0) }),
                           0...1.2)
                    slider("far y",
                           Binding(get: { Double(refs.farDepth) },
                                   set: { refs.farDepth = CGFloat($0) }),
                           0...0.3)
                    slider("far size",
                           Binding(get: { Double(refs.farScale) },
                                   set: { refs.farScale = CGFloat($0) }),
                           0.5...1.6)
                    slider("near inset",
                           Binding(get: { Double(refs.nearInset) },
                                   set: { refs.nearInset = CGFloat($0) }),
                           -200...200)
                    slider("near y",
                           Binding(get: { Double(refs.nearStep) },
                                   set: { refs.nearStep = CGFloat($0) }),
                           0...0.4)
                    slider("near size",
                           Binding(get: { Double(refs.nearScale) },
                                   set: { refs.nearScale = CGFloat($0) }),
                           0.5...1.6)
                }
                .frame(width: 150)
            }
            if showHand {
                HStack(spacing: 4) {
                    action("reset") {
                        hand.lift = 75; hand.spacing = 0.75; hand.scale = 1
                        arc.scale = 0.9; arc.spacing = 3
                        overlay.scale = 0.5; overlay.x = 0; overlay.y = -15
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    slider("hand y",
                           Binding(get: { Double(hand.lift) },
                                   set: { hand.lift = CGFloat($0) }),
                           -40...140)
                    slider("hand spacing",
                           Binding(get: { Double(hand.spacing) },
                                   set: { hand.spacing = CGFloat($0) }),
                           0.2...1.2)
                    slider("hand size",
                           Binding(get: { Double(hand.scale) },
                                   set: { hand.scale = CGFloat($0) }),
                           0.5...1.8)
                    slider("wedge size",
                           Binding(get: { Double(arc.scale) },
                                   set: { arc.scale = CGFloat($0) }),
                           0.4...1.8)
                    slider("wedge seam",
                           Binding(get: { arc.spacing }, set: { arc.spacing = $0 }),
                           0...20)
                    slider("ball size",
                           Binding(get: { Double(overlay.scale) },
                                   set: { overlay.scale = CGFloat($0) }),
                           0.1...1.5)
                    slider("ball x",
                           Binding(get: { Double(overlay.x) },
                                   set: { overlay.x = CGFloat($0) }),
                           -60...60)
                    slider("ball y",
                           Binding(get: { Double(overlay.y) },
                                   set: { overlay.y = CGFloat($0) }),
                           -60...60)
                }
                .frame(width: 150)
            }
            if showBoard {
                VStack(alignment: .leading, spacing: 0) {
                    slider("moves size", Binding(get: { Double(moveHUD.scale) },
                                                 set: { moveHUD.scale = CGFloat($0) }),
                           0.4...1.8)
                    slider("moves x", Binding(get: { Double(moveHUD.x) },
                                              set: { moveHUD.x = CGFloat($0) }), -80...80)
                    slider("moves y", Binding(get: { Double(moveHUD.y) },
                                              set: { moveHUD.y = CGFloat($0) }), -90...90)
                }
                .frame(width: 150)
            }
            if showBoard {
                HStack(spacing: 4) {
                    action("reset") {
                        board.titleScale = 1; board.titleY = -72
                        board.ballScale = 1; board.ballY = -1.5
                        board.buttonScale = 1; board.buttonY = 110
                        board.handScale = 1; board.handY = 140
                        board.bidsScale = 0.7; board.bidsY = 0
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    slider("title size", size(\.titleScale), 0.3...2.5)
                    slider("title y", place(\.titleY), -260...260)
                    slider("ball size", size(\.ballScale), 0.3...2.5)
                    slider("ball y", place(\.ballY), -260...260)
                    slider("bids size", size(\.bidsScale), 0.3...2.5)
                    slider("bids y", place(\.bidsY), -260...260)
                    slider("button size", size(\.buttonScale), 0.3...2.5)
                    slider("button y", place(\.buttonY), -260...260)
                    slider("hand size", size(\.handScale), 0.3...2.5)
                    slider("hand y", place(\.handY), -260...260)
                }
                .frame(width: 150)
            }
            if showPass {
                HStack(spacing: 4) {
                    action("pass") { controller.debugPass(to: Self.targets[target]) }
                    action("reset") {
                        pass.flight = 0.333; pass.throwRate = 15; pass.catchRate = 20
                        pass.inbound = 0.5
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    slider("flight", Binding(get: { pass.flight },
                                             set: { pass.flight = $0 }), 0.05...1.2)
                    slider("throw fps", Binding(get: { pass.throwRate },
                                                set: { pass.throwRate = $0 }), 4...40)
                    slider("catch fps", Binding(get: { pass.catchRate },
                                                set: { pass.catchRate = $0 }), 4...40)
                    slider("inbound", Binding(get: { pass.inbound },
                                              set: { pass.inbound = $0 }), 0.1...2)
                }
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

    /// The board's dials, which are all the same two shapes.
    private func size(_ path: ReferenceWritableKeyPath<ReboundSceneTuning, CGFloat>)
    -> Binding<Double> {
        Binding(get: { Double(board[keyPath: path]) },
                set: { board[keyPath: path] = CGFloat($0) })
    }

    private func place(_ path: ReferenceWritableKeyPath<ReboundSceneTuning, CGFloat>)
    -> Binding<Double> { size(path) }

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
