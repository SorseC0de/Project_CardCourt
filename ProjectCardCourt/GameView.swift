import SwiftUI

struct GameView: View {
    /// **Owned by `RootView`, not by the screen.** A controller deals a game the moment
    /// it exists, so one made here would be a game dealt by looking at the court — and
    /// quitting has to unload the session, which a screen cannot do to itself.
    var controller: GameController
    /// Ends the session and goes back to the front screen.
    var onQuit: () -> Void = {}
    /// The same again, dealt fresh.
    var onRunItBack: () -> Void = {}
    @State private var paused = false
    @State private var logStyle: LogStyle = .overlay
    @State private var detail: Card?
    /// A slotted passive or an active debuff, held up to be read.
    /// A slotted card held up, and the slot it came from.
    @State private var inspecting: (card: CardDescriptor, from: CGPoint)?
    @State private var browsingDiscard = false
    /// What the player has tapped open on the floor. See `Inspection`.
    @State private var onFloor: Inspection?

    /// The log keeps this height whether it sits in its own band or floats over the court.
    private let logHeight: CGFloat = 74
    /// The log's bottom edge in the screen's own space, which is what the name plate
    /// hangs from. Nought until the first layout, which is one frame before anything
    /// can be played.
    @State private var logBottom: CGFloat = 0
    /// Where the results card starts in `Winner.poses`. Rolled once per game, so the
    /// same win does not always end on the same picture.
    @State private var winnerPose = Int.random(in: 0..<Winner.poses.count)
    /// Where each player's PTS cell is, read off the board rather than guessed at.
    @State private var pointsCells: [Seat: CGPoint] = [:]

    var body: some View {
        // **Five layers rather than two dozen.**
        //
        // A `ZStack` of twenty-six children is one generic type twenty-six deep, and
        // every arm of it is a conditional wrapping a whole screen. Building the view
        // walks that type, and it was over the line: on a large enough device the walk
        // ran out of stack inside whichever branch happened to sit deepest, which is
        // why the crash named a property of the controller rather than anything to do
        // with the screen being opened.
        //
        // **Banded by `zIndex`, not by how the code happened to be ordered.** What sits
        // over what is decided by those numbers, so the groups only hold together while
        // no two of them overlap: the floor is everything to 9.5, the sheets 10 to 11,
        // the questions 12, the set pieces 13 to 20, and what is called over the top 40
        // and above. Each is erased where it joins, which is what keeps the depth from
        // adding back up.
        ZStack {
            ground.zIndex(0)
            floorSheets.zIndex(1)
            prompts.zIndex(2)
            scenes.zIndex(3)
            calls.zIndex(4)
            if paused { pauseMenu.zIndex(5) }
        }
        // What the log's foot and the name plate are both measured in.
        .coordinateSpace(name: Chrome.screen)
        #if DEBUG
        // Under the round count, where it is out of the name plate's line — that runs
        // across the top of the court now, which is where the bench used to sit.
        .overlay(alignment: .topLeading) {
            DebugActionsView(controller: controller)
                .padding(.leading, 14)
                .padding(.top, 22)
                .zIndex(20)
        }
        #endif
        .animation(.easeInOut(duration: 0.2), value: controller.cutscene)
        .animation(.easeInOut(duration: 0.2), value: controller.turnover)
        .animation(.easeInOut(duration: 0.2), value: controller.reveal)
        .onChange(of: controller.gate) { detail = nil }
        // **Anything that takes the screen holds the game.** A sheet already did; a card
        // raised out of a slot and the discard browser did not, and the floor carried on
        // playing behind them. Not the hand's own card detail — that one is a card you
        // are about to play, and freezing the game would refuse the play.
        .onChange(of: holdsTheFloor) { _, holding in
            holding ? controller.pause() : controller.resume()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: inspecting?.card)
        .background(keyboardCommands)
        .task {
            DevLog.say(.input, "GameView appeared")
            controller.begin()
        }
    }

    /// The floor and everything standing on it: the court, the panels either side of the
    /// hand, the wash over the lot, and whatever card is being held up. The wash sits at
    /// nine and the two bands lift over it to nine and a half, so all three have to be in
    /// one stack for that to mean anything.
    ///
    /// Erased where it joins the body — z 0 to 9.5. See `body`.
    private var ground: AnyView {
        AnyView(ZStack {
                Theme.panel.ignoresSafeArea()

                // The court runs to the bottom of the screen; the bag sits straight on it.
                // Only the court art runs under the home indicator. Everything you touch
                // stays inside the safe area.
                VStack(spacing: 0) {
                    statusBar
                    ScoreboardView(state: controller.shown, withheld: controller.withheldPoints)
                        .onPreferenceChange(PointsCells.self) { pointsCells = $0 }
                    logStrip
                        // **Where the name plate hangs from.** Measured rather than added up:
                        // the plate sits under the log, and the log's own top depends on the
                        // scoreboard, whose height depends on how many players there are.
                        // Summing `statusBar + logHeight` left the whole board out of the
                        // total, which is why every number tried for it landed short.
                        .background {
                            GeometryReader { geo in
                                Color.clear.onGeometryChange(for: CGFloat.self) { _ in
                                    geo.frame(in: .named(Chrome.screen)).maxY
                                } action: { logBottom = $0 }
                            }
                        }
                    stage
                }
                .ignoresSafeArea(edges: .bottom)
                // Lifted over the wash while the floor is what is being asked for, the way
                // the hand's own band is when the question is about cards.
                .zIndex(floorIsTheQuestion ? 9.5 : 0)

                // Anywhere off the raised card puts it back down. Only present while one is
                // up, so it never swallows a tap on the court.
                if detail != nil || inspecting != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { detail = nil; inspecting = nil }
                }

                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 0) {
                        // Takes the band the log used to sit in, just above the hand.
                        HStack(alignment: .bottom) {
                            // **Out of the way while the game is asking for something.** Each
                            // leaves by its own side, and far enough that every slot has gone
                            // rather than half of one — a plate cut off at the screen's edge
                            // is a thing you are still looking at.
                            IntangibleSlotsView(held: controller.shownIntangibles(of: GameRules.localSeat),
                                                dormant: controller.dormantIntangibles,
                                                slots: controller.shown.rules.intangibleSlots,
                                                onSelect: { inspecting = (card: $0, from: $1) })
                                .offset(x: standingAside ? -Panels.aside : 0)
                            Spacer()
                            DebuffSlotsView(cards: controller.human.clamps.map(\.card),
                                            onSelect: { inspecting = (card: $0, from: $1) })
                                .offset(x: standingAside ? Panels.aside : 0)
                        }
                        .padding(.bottom, 4)
                        // Down a little: the flanks stand right above them.
                        .offset(y: Panels.drop)
                        .animation(.easeInOut(duration: 0.28), value: standingAside)
                        ActionBarView(controller: controller, detail: $detail,
                                      onInspectReferees: { open(.referees) })
                    }
                    // Out of the way rather than washed over. Two translucent sheets meeting
                    // multiply, and the seam where the hand's met the court's was a black
                    // band across the screen — so the cards step down instead, which also
                    // keeps them off the prompt.
                    .offset(y: isChoosingInbound ? CourtView.Court.handDrop : 0)
                    .animation(.easeOut(duration: 0.3), value: isChoosingInbound)
                }
                // Above the dim while the hand is the question, under it the rest of the time.
                .zIndex(handIsTheQuestion ? 9.5 : 0)

                // One dim for the whole screen, always in the hierarchy and turned up when
                // something takes the screen over. Never inserted, so it can only ever fade.
                //
                // **The hand is what is being asked for**, so when the question is about cards
                // the band it lives in is lifted over this rather than washed out with the
                // floor — see the `zIndex` on it above.
                DimLayer(on: dim > 0, amount: dim, seconds: 0.22)
                    .zIndex(9)

                if let inspecting {
                    InspectedCardView(card: inspecting.card, from: inspecting.from)
                        .id(inspecting.card.id)
                        .zIndex(9)
                }
                if let played = controller.playedCard {
                    PlayedCardView(played: played, width: 210)
                        // Down, out of the name plate's line. The plate is the caption and
                        // the card is what it is captioning; they were sharing a band.
                        .offset(y: Chrome.playedCardDrop)
                        .transition(.opacity)
                        .zIndex(7)

                    // **Over the card, not under it.** On the status bar's own line — the
                    // same one the SHOT badge takes, counted off the bar's height rather
                    // than hung inside the court, so it can be drawn above everything.
                    VStack {
                        GeometryReader { geo in
                            NameCallView(call: NameCall(seat: played.seat),
                                         reach: geo.size.width,
                                         isLeaving: controller.playedCardLeaving)
                        }
                        .frame(height: NameCallStyle.size(reaching: 393).height)
                        // Under the log rather than beside the scoreboard: the log is the
                        // other thing that talks, and the two were talking over each other.
                        // The overlay style floats the log over the court and still occupies
                        // that band, so only a log turned off gives the space back.
                        .padding(.top, logBottom + Chrome.underLog)
                        Spacer()
                    }
                    .id(played.id)
                    .allowsHitTesting(false)
                    .zIndex(8)
                }
        })
    }

    /// Opened over the floor: a shot, a player raised for reading, the discard pile.
    ///
    /// Erased where it joins the body — z 10 to 11. See `body`.
    private var floorSheets: AnyView {
        AnyView(ZStack {
                if let scene = controller.cutscene {
                    ShotCutsceneView(scene: scene)
                        .transition(.opacity)
                        .zIndex(10)
                }
                if let onFloor {
                    Group {
                        switch onFloor {
                        case .player(let seat):
                            PlayerInspectView(state: controller.shown, seat: seat,
                                              onDismiss: closeFloor)
                        case .referees:
                            RefereeInspectView(state: controller.shown, onDismiss: closeFloor)
                        }
                    }
                    .id(onFloor.id)
                    // Over the cards, under a call: the game speaking still outranks a thing
                    // the player opened for themselves.
                    .zIndex(11)
                }
                if case .awaitingCounter(let card) = controller.gate {
                    // Two cards can be offered here and they do two different things, so the
                    // question is asked in the card's own words rather than Clear Out's.
                    CardChoiceView(title: "\(card.name)?",
                                   note: card.clearsOut
                                       ? "Step aside and the ball carries on"
                                       : "Break the clamps before they land",
                                   offered: [card],
                                   tint: CardPalette.orange,
                                   taking: "Play it!",
                                   declining: "No thanks",
                                   onDecline: { controller.choose(counter: false) },
                                   onPick: { _ in controller.choose(counter: true) })
                        .zIndex(11)
                }
                if browsingDiscard {
                    DiscardBrowserView(cards: controller.shown.discard,
                                       onDismiss: { browsingDiscard = false })
                        .transition(.opacity)
                        .zIndex(11)
                }
        })
    }

    /// Every question the game stops to ask, and the card it turns face up to ask it.
    ///
    /// Erased where it joins the body — z 12. See `body`.
    private var prompts: AnyView {
        AnyView(ZStack {
                if case .awaitingNaming(_, let named) = controller.gate {
                    // The floor takes the names; this only says when there are no more.
                    VStack {
                        Spacer()
                        ChunkyButton(title: named.isEmpty ? "Take it alone"
                                                          : "Shoot (+\(named.count * 10)%)",
                                     fill: CardPalette.gold, stroke: CardPalette.gold,
                                     shade: CardPalette.orange, size: 20) {
                            controller.choose(naming: nil)
                        }
                        .frame(width: 240)
                        .padding(.bottom, 130)
                    }
                    .zIndex(12)
                }
                if case .awaitingToll(let victim) = controller.gate {
                    // His board is face up and his hand is not, so both are on the table and
                    // only one of them can be read.
                    CardChoiceView(title: "\(victim.playerName) Pays",
                                   note: "A passive, or a card",
                                   offered: controller.shown[victim].intangibles,
                                   backs: controller.shown[victim].bag.count,
                                   declining: "Leave it",
                                   onDecline: { controller.choose(toll: nil) }) {
                        controller.choose(toll: $0)
                    }
                    .zIndex(12)
                }
                if case .awaitingIntangibleDrop(let offered) = controller.gate {
                    // The one that just arrived is in the row, so "just discard it" is a
                    // pick rather than a second button.
                    CardChoiceView(title: "Too Many", note: "One has to go", offered: offered,
                                   tint: CardPalette.gold) { pick in
                        if case .named(let id) = pick { controller.choose(dropping: id) }
                    }
                        .zIndex(12)
                }
                if case .awaitingInjuryPick(let card) = controller.gate {
                    CardChoiceView(title: card.name, note: "Take one",
                                   offered: controller.shown.injuriesOffered,
                                   hidden: controller.shown.injuriesHidden) { pick in
                        if case .named(let id) = pick { controller.choose(injury: id) }
                    }
                    .zIndex(12)
                }
                if case .awaitingCardFrom(let card, let victim) = controller.gate {
                    HandPickerView(card: card, victim: victim,
                                   hand: controller.shown[victim].bag.count) { index in
                        let hand = controller.shown[victim].bag
                        guard hand.indices.contains(index) else { return }
                        controller.choose(card: hand[index].id)
                    }
                    .zIndex(12)
                }
                if case .awaitingMode(let card) = controller.gate {
                    ModePickerView(card: card) { controller.choose(mode: $0) }
                        .zIndex(12)
                }
                if let scene = controller.reveal {
                    RevealCutsceneView(scene: scene) { controller.dismissReveal() }
                        // Keyed to the card, so two reveals in a row are two views rather than
                        // one view whose contents changed. Without it SwiftUI reuses the first
                        // and simply morphs the artwork, which reads as one card mutating
                        // instead of a second card arriving.
                        .id(scene.id)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.6).combined(with: .opacity),
                            removal: .scale(scale: 0.85).combined(with: .opacity)))
                        .zIndex(12)
                }
        })
    }

    /// The set pieces: a three, a whistle, a turnover, the line, and the final card.
    ///
    /// Erased where it joins the body — z 13 to 20. See `body`.
    private var scenes: AnyView {
        AnyView(ZStack {
                if let seat = controller.celebratingThree {
                    ThreeCelebrationView(
                        seat: seat,
                        // Roughly that player's PTS cell: the board sits under the status bar,
                        // rows are even, and PTS is the first stat column.
                        // The cell itself, as laid out. Nought until the board's first
                        // pass, which is long before anybody has scored.
                        scoreTarget: pointsCells[seat]
                            ?? CGPoint(x: 78, y: 96 + 24 * CGFloat(scoreRow(of: seat))),
                        onScoreLands: { controller.threeScoreLanded() },
                        onFinished: { controller.threeCelebrationFinished() })
                        .zIndex(13)
                }
                if let scene = controller.whistleReveal {
                    WhistleRevealView(scene: scene) { controller.dismissWhistleReveal() }
                        .transition(.opacity)
                        .zIndex(14)
                }
                if let scene = controller.turnover {
                    TurnoverCutsceneView(scene: scene)
                        .transition(.opacity)
                        .zIndex(15)
                }
                // The player's own trip is a gate; an opponent's plays itself. Both use the
                // same scene, so a free throw looks the same from either seat.
                if case .awaitingFreeThrow(let trip) = controller.gate {
                    FreeThrowView(trip: trip, auto: nil,
                                  onResult: { controller.shootFreeThrow(made: $0) })
                        .id(trip.attempted)
                        .transition(.opacity)
                        .zIndex(16)
                } else if let shot = controller.aiFreeThrow {
                    FreeThrowView(trip: shot.trip, auto: shot.made)
                        .id(shot.id)
                        .transition(.opacity)
                        .zIndex(16)
                }
                if case .gameOver = controller.gate {
                    finalCard.zIndex(20)
                }
        })
    }

    /// Said over the top of everything — the board, the phase call, the frame readout.
    ///
    /// Erased where it joins the body — z 40 and up. See `body`.
    private var calls: AnyView {
        AnyView(ZStack {
                if let score = controller.scoreCall {
                    ScoreCallView(call: score)
                        .transition(.opacity)
                        .zIndex(41)
                }
                if let call = controller.actionCall {
                    ActionCallView(call: call, clamps: controller.clampCall) {
                        controller.actionCallFinished()
                    }
                        .transition(.opacity)
                        // Over everything, cards included. It is the game speaking.
                        .zIndex(40)
                }
                #if DEBUG
                VStack {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            FrameRateView()
                            // Only while there is a match to be wrong about.
                            if controller.match != nil {
                                NetReadout(controller: controller)
                            }
                        }
                        .padding(.trailing, 8)
                    }
                    Spacer()
                }
                .zIndex(99)
                #endif

        })
    }
    /// The rebound plays as its own cutscene in the court's place.
    /// Hardware-keyboard shortcuts, for testing on the simulator and on iPad.
    ///
    /// Zero-sized buttons rather than `onKeyPress`, which needs the view to take focus —
    /// and focus here would fight the hand's drag gesture for input. A `keyboardShortcut`
    /// only needs the button to be in the hierarchy.
    ///
    /// - **R** starts a fresh game.
    /// - **H** dumps your hand and deals another (debug builds only).
    /// - **D** draws a single card (debug builds only).
    private var keyboardCommands: some View {
        ZStack {
            Button("New game") { onRunItBack() }
            .keyboardShortcut("r", modifiers: [])

            #if DEBUG
            Button("Reshuffle hand") { controller.debugReshuffleHand() }
                .keyboardShortcut("h", modifiers: [])
            Button("Draw") { controller.debugDraw() }
                .keyboardShortcut("d", modifiers: [])
            #endif
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }


    /// The court is asking the player to pick somebody to throw to.
    private var isChoosingInbound: Bool {
        if case .awaitingInbound = controller.gate { return true }
        return false
    }

    /// How dark the screen should be, whichever thing has taken it.
    /// Whatever card is being read right now, from the hand or from a slot. Two ways in,
    /// one answer — a Clamp raised out of the fan and one raised out of its slot are the
    /// same card being looked at.
    private var beingRead: CardDescriptor? { detail?.descriptor ?? inspecting?.card }

    /// Everything that takes the screen away from the floor — see the `onChange` that
    /// holds the game while any of it is up.
    private var holdsTheFloor: Bool {
        onFloor != nil || inspecting != nil || browsingDiscard
    }

    /// Opens a floor sheet, where that is allowed. The hold is the `onChange`'s job.
    private func open(_ inspection: Inspection) {
        guard controller.canInspect else { return }
        onFloor = inspection
    }

    private func closeFloor() { onFloor = nil }

    private enum Panels {
        /// How far a slot panel goes to be gone. Wider than the panel itself, so the last
        /// slot clears the screen rather than sitting on its edge.
        static let aside: CGFloat = 320
        /// And how far down they sit, out from under the flanks' feet.
        static let drop: CGFloat = 8
    }

    /// Whether the floor's own readings should get out of the way: something is being
    /// asked for out of the hand, and the hand is what the eye needs.
    /// The panels either side of the hand get out of the way for any question — they are
    /// never the answer to one.
    private var standingAside: Bool {
        switch controller.gate {
        case .awaitingDiscard, .awaitingInjuryDiscard, .awaitingBid,
             .awaitingTarget, .awaitingNaming, .awaitingInbound:
            return true
        default: return false
        }
    }

    /// **Which band the question is about**, and so which one is lifted over the wash
    /// rather than washed out with everything else. The cards in front of you when the
    /// game wants a card; the floor when it wants a player off it.
    private var handIsTheQuestion: Bool {
        switch controller.gate {
        case .awaitingDiscard, .awaitingInjuryDiscard, .awaitingBid: return true
        default: return false
        }
    }

    private var floorIsTheQuestion: Bool {
        switch controller.gate {
        case .awaitingTarget, .awaitingNaming: return true
        default: return false
        }
    }

    private var dim: Double {
        if browsingDiscard { return Theme.dimBrowser }
        // Your own hand being asked for cards is the same question somebody else's hand
        // gets a dimmed floor for.
        switch controller.gate {
        case .awaitingDiscard, .awaitingInjuryDiscard: return Theme.dimBrowser
        // Picking a player off the floor is the same kind of question, and it was the one
        // asked with the screen left exactly as it was — nothing to say the game had
        // stopped and was waiting on you.
        case .awaitingTarget, .awaitingNaming: return Theme.dimBrowser
        default: break
        }
        // The sheets carry their own, so the screen's stays out of it — two scrims over
        // one another multiply into black.
        if onFloor != nil { return 0 }
        if controller.whistleReveal != nil { return Theme.dimWhistle }
        if controller.reveal != nil { return Theme.dimReveal }
        return 0
    }

    private var stage: some View {
        Group {
            if case .awaitingBid(let shooter) = controller.gate {
                ReboundCutsceneView(shooter: shooter, revealedBids: controller.revealedBids,
                                    state: controller.shown, shot: controller.shownShot,
                                    deck: controller.shownDeck, chance: controller.lastChance)
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                court
            }
        }
        .animation(.easeInOut(duration: 0.25), value: controller.gate)
    }

    /// A practice pass overrides both ends of the flight; otherwise the rules say.
    private var passerOnCourt: Seat? {
        #if DEBUG
        if let practice = controller.practicePass { return practice.from }
        #endif
        return controller.shown.lastPasser
    }

    private var receiverOnCourt: Seat? {
        #if DEBUG
        return controller.practicePass?.to
        #else
        return nil
        #endif
    }

    /// In every style but .panel the court claims the log's real estate.
    ///
    /// **Type-erased, and it has to be.** `CourtView` is a stack of a dozen layers, and
    /// every modifier hung on it wraps that whole type in another generic — the court
    /// with its frame, its overlay, its sheet came out as a type deep enough that
    /// instantiating it recursed off the end of the stack. `EXC_BAD_ACCESS` in
    /// `court.getter`, attached; a crash on the first frame, not.
    private var court: AnyView {
        AnyView(CourtView(state: controller.shown,
                  gate: controller.gate,
                  revealedBids: controller.revealedBids,
                  rebound: controller.reboundLeap,
                  settledAt: controller.ballSettledAt,
                  shownBall: controller.shownBall,
                  inbounding: controller.inbounding,
                  throwing: controller.throwing,
                  passer: passerOnCourt,
                  receiver: receiverOnCourt,
                  flight: controller.flight,
                  deckRoutine: controller.deckRoutine,
                  deal: controller.stageDeal,
                  swipe: controller.clampSwipe,
                  opening: controller.opening,
                  flightDuration: controller.flightDuration,
                  onOpenDiscard: { browsingDiscard = true },
                  onSelect: { seat in
                      // The same tap answers both — which is the point of asking for a
                      // player the way the game already asks for one.
                      if case .awaitingTarget = controller.gate {
                          controller.choose(target: seat)
                      } else if case .awaitingNaming = controller.gate {
                          controller.choose(naming: seat)
                      } else {
                          controller.inbound(to: seat)
                      }
                  },
                  undelivered: controller.undelivered,
                  bound: controller.boundSeats,
                  spend: controller.spend,
                  // Nothing on the floor moves while something else has the screen.
                  frozen: dim > 0 || onFloor != nil || beingRead != nil,
                  showingClamps: beingRead?.clamp != nil,
                  onInspectPlayer: { open(.player($0)) },
                  onInspectReferees: { open(.referees) })
            // No inset: the floor and the streaks run to the screen edges, and
            // `CourtGeometry` lays the diamond out across the whole width.
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                StatusHUDView(state: controller.shown, shot: controller.shownShot,
                              deck: controller.shownDeck,
                              onInspectReferees: { open(.referees) })
                    .padding(.trailing, 18)
                    .padding(.top, 6)
            }

            )
    }

    /// Sits under the scoreboard. Overlay drops the solid panel for a scrim so the top
    /// of the court still reads through it.
    @ViewBuilder private var logStrip: some View {
        switch logStyle {
        case .panel:
            LogView(lines: controller.log).frame(height: logHeight)
        case .overlay:
            ZStack {
                Rectangle().fill(Color.black.opacity(0.35))
                LogView(lines: controller.log, showsBackground: false)
            }
            .frame(height: logHeight)
            // Faded at both ends. A mask does not block touches, so this still scrolls.
            .mask(LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.2),
                    .init(color: .black, location: 0.85),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top, endPoint: .bottom))
        case .hidden:
            EmptyView()
        }
    }

    /// Where that seat sits on the scoreboard, which orders by score.
    private func scoreRow(of seat: Seat) -> Int {
        let ranked = controller.shown.players
            .sorted { ($0.score, $0.points) > ($1.score, $1.points) }
        return ranked.firstIndex { $0.seat == seat } ?? 0
    }

    private var statusBar: some View {
        HStack {
            Text("ROUND \(controller.shown.round)/\(controller.shown.rules.roundsPerGame)")
                .font(.system(size: 11, weight: .heavy)).tracking(1)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            shotClock

            HStack(spacing: 8) {
                Text("HALF \(controller.shown.half)")
                    .font(.system(size: 11, weight: .bold)).tracking(1)
                    .foregroundStyle(Theme.inkDim)
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { logStyle = logStyle.next }
                } label: {
                    Image(systemName: logStyle.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkDim)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(logStyle.label)
                pauseButton
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .background(Theme.panel)
    }

    /// **The only way out of a game.** Louder than the two readings beside it, because it
    /// is the one thing on the bar that does something rather than saying something.
    private var pauseButton: some View {
        Button {
            controller.pause()
            withAnimation(.easeOut(duration: 0.2)) { paused = true }
        } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 27, height: 27)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(CardPalette.blue))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(.white, lineWidth: 1.5))
                .shadow(color: CardPalette.gold, radius: 0, x: 2, y: 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pause")
    }

    /// Stopped, and what can be done about it.
    ///
    /// **Quitting unloads the game**, rather than walking away from one still running
    /// behind the front screen — see `RootView`. In a match it cannot stop the table, so
    /// the freeze is silently nothing there and the only real choice is to leave.
    private var pauseMenu: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { resume() }
            VStack(spacing: 18) {
                ScreenTitle(text: "Paused", drop: CardPalette.blue)
                if !controller.canPause {
                    Text("The table carries on without you.")
                        .font(.custom(Chrome.display, size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
                VStack(spacing: 12) {
                    ChunkyButton(title: "Resume", fill: CardPalette.blue) { resume() }
                    ChunkyButton(title: "Quit Game", fill: CardPalette.red) {
                        paused = false
                        onQuit()
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
    }

    private func resume() {
        controller.resume()
        withAnimation(.easeOut(duration: 0.2)) { paused = false }
    }

    /// The last number the clock actually showed.
    ///
    /// It reads `--` only before the first inbound of a round. Everything else that
    /// clears it — a Whistle stopping play, a round turning over mid-scene — is an event,
    /// and blanking the clock for the length of one says the clock is gone when it is
    /// only waiting.
    @State private var lastClock: Int?

    private var shotClock: some View {
        let clock = controller.shown.shotClock ?? lastClock
        return VStack(spacing: 3) {
            SevenSegmentClock(value: clock)
            Text("SHOT CLOCK")
                .font(.system(size: 7, weight: .bold)).tracking(1.3)
                .foregroundStyle(Theme.inkDim)
        }
        .animation(.easeOut(duration: 0.25), value: clock)
        .onChange(of: controller.shown.shotClock) { _, now in
            if let now { lastClock = now }
        }
        // A new round starts the clock over, so the memory goes with it.
        .onChange(of: controller.shown.round) { _, _ in lastClock = nil }
    }

    private var finalCard: some View {
        let winners = Rules.winners(of: controller.shown)
        return ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(spacing: 22) {
                    ForEach(Array(winners.enumerated()), id: \.element) { place, seat in
                        // Facing the room with the ball, not jogging upcourt — the game
                        // is over and there is nowhere left to run. One pose each where
                        // more than one of them won, so a tie is not the same man twice.
                        HooperPortrait(pose: Winner.pose(at: place, from: winnerPose),
                                       // Only the player has chosen a face; the rest
                                       // wear the one on their sheet.
                                       kit: seat.isLocal ? HooperKit.shared : nil,
                                       seat: seat)
                            .scaleEffect(2.1, anchor: .bottom)
                            .frame(width: Theme.Figure.headDiameter * 2.1,
                                   height: Theme.Figure.height * 2.1, alignment: .bottom)
                    }
                }

                Text(verdict(for: winners))
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(winners.count == 1 ? Theme.color(for: winners[0]) : Theme.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .padding(.horizontal, 20)

                ScoreboardView(state: controller.shown, highlighted: Set(winners),
                               totalLabel: "SCORE")
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 26)
                    .padding(.top, 4)

                Button { onRunItBack() } label: {
                    Text("RUN IT BACK")
                        .font(.system(size: 14, weight: .black)).tracking(1.2)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 30).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.ball))
                }
                .padding(.top, 4)
            }
        }
    }

    /// "You Win!" but "Raheem Wins!", and a shared line when nobody separated.
    private func verdict(for winners: [Seat]) -> String {
        guard let first = winners.first else { return "FINAL" }
        guard winners.count == 1 else {
            return winners.map(\.playerName).joined(separator: " & ") + " Tie!"
        }
        return "\(first.playerName) \(first.verb("Wins", "Win"))!"
    }
}

// Two, because the canvas in this file is where the game gets tested and the front
// screen is behind `@main` — a GameView preview is the game by definition, and will never
// show what the app actually opens on. Pick this one to start where the player starts.
#Preview("App") { RootView() }

#Preview("Name call") { NameCallBench() }

#Preview("Column warp") { ColumnWarpBench() }

#Preview("Straight to the table") { GameView(controller: GameController()) }
