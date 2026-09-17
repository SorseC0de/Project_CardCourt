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
    /// A How To Play lesson being taken on this table, when there is one.
    var tutorial: TutorialDirector? = nil
    /// The pad, if one is plugged in, and where it is pointing. **Both are nothing until
    /// a controller is connected** — see `Pad.isAttached`, which is what keeps a ring off
    /// the screen of somebody playing on glass.
    @State private var pad = Pad.shared
    @State private var cursor = Cursor()

    @State private var paused = false
    /// Which of the two flank plates is in front — see `debuffPlates`.
    @State private var injuriesForward = false
    /// The card taken off whichever sheet is up, before it is confirmed.
    ///
    /// **Outside the sheet.** Every "pick one of these" in the game used to hold its own
    /// choice, which left a controller with nothing to write to — see `takeTheOffer(_:)`.
    @State private var picked: CardPick?
    /// A mechanic somebody pressed on a card they were reading, and what it means.
    @State private var explaining: (title: String, says: String)?
    @State private var detail: Card?
    /// The card whose combo scene is open, over everything — see `ComboView`.
    @State private var comboOf: CardDescriptor?
    /// A raised card's bonus, and the BONUS button it hangs off.
    @State private var bonusOf: (card: CardDescriptor, at: CGPoint)?
    /// Traderous Tarmac's sheet, open while the player hands Clamps on.
    @State private var handingOff = false
    /// Varsitile's sheet, open while the player picks what to swap in.
    @State private var exchanging = false
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
    /// Whether the final card is showing the game's log rather than its result. **Over
    /// the result, not instead of it** — the score stays underneath, because the log is
    /// being read to work out how it got there.
    @State private var reviewingLog = false
    /// The roll the results card's poses come off. Once per game, so nobody changes
    /// stance every time the card redraws — see `Winner.pose(for:at:from:)`.
    @State private var winnerPose = Int.random(in: 0..<10_000)
    /// Where each player's PTS cell is, read off the board rather than guessed at.
    @State private var pointsCells: [Seat: CGPoint] = [:]
    /// Set once an opaque scene has covered the floor for longer than its fade — see
    /// `floorIsHidden`.
    @State private var floorAsleep = false

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
            ground
                .environment(\.floorIsHidden, floorIsCovered && floorAsleep)
                .zIndex(0)
            floorSheets.zIndex(1)
            prompts.zIndex(2)
            scenes.zIndex(3)
            calls.zIndex(4)
            // **Somebody leaving outranks the pause menu.** It is not a thing you
            // opened and can close; the game is stopped until it is answered.
            if !controller.walkedOut.isEmpty { walkedOut.zIndex(6) }
            else if paused { pauseMenu.zIndex(5) }
        }
        .environment(\.tutorialFocus, tutorial?.focus ?? TutorialFocus())
        .environment(\.ballInPlay, controller.shown.currentBall)
        .overlayPreferenceValue(TutorialFrames.self) { anchors in
            if let tutorial {
                GeometryReader { proxy in
                    TutorialOverlay(director: tutorial, rects: anchors.mapValues { proxy[$0] },
                                    onExit: onQuit)
                }
                .ignoresSafeArea()
            }
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
        // Asleep only once the scene is opaque, and awake the moment it starts to leave.
        .onChange(of: floorIsCovered) { floorAsleep = false }
        .task(id: floorIsCovered) {
            guard floorIsCovered else { return }
            try? await Task.sleep(for: .seconds(Self.floorSleepDelay))
            guard !Task.isCancelled else { return }
            floorAsleep = true
        }
        .onChange(of: controller.gate) { detail = nil; picked = nil; comboOf = nil; bonusOf = nil }
        // **Every press lands in one place.** Only this screen knows what is over the
        // floor, so it is the only thing that can say whether a button was answering the
        // hand or the pause menu on top of it.
        .onChange(of: pad.press) { _, press in
            guard let press else { return }
            // **A face button names a player while the table is asking for one.** The
            // four of them are a diamond and so are four seats, so the man on your left
            // is the button on the left and nobody has to walk a cursor to him.
            if let face = press.face, let seat = asked(for: face) {
                select(seat)
                return
            }
            take(press.action)
        }
        // The ring goes where the question does. A hand that gains a card leaves it
        // where it was; a new question puts it back at the start of the new row.
        .onChange(of: controller.gate) { cursor.settle(on: Row.at(controller)) }
        .onChange(of: controller.shownBag(of: GameRules.localSeat).count) {
            cursor.settle(on: Row.at(controller))
        }
        .onAppear { cursor.settle(on: Row.at(controller)) }
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
                            // leaves by its own side, all but an edge — see `Panels.peek`.
                            // Gone entirely read as a panel that had been taken away; a
                            // sliver says it is standing just off the screen.
                            IntangibleSlotsView(held: controller.shownIntangibles(of: GameRules.localSeat),
                                                dormant: controller.dormantIntangibles,
                                                slots: controller.shown.rules.intangibleSlots,
                                                onSelect: { inspecting = (card: $0, from: $1) })
                                .offset(x: standingAside ? -Panels.aside : 0)
                            Spacer()
                            debuffPlates
                                .offset(x: standingAside ? Panels.aside : 0)
                        }
                        .padding(.bottom, 4)
                        // Down a little: the flanks stand right above them.
                        .offset(y: Panels.drop)
                        .animation(.easeInOut(duration: 0.28), value: standingAside)
                        ActionBarView(controller: controller, ringed: ring,
                                      detail: $detail,
                                      onInspectReferees: { open(.referees) },
                                      onCombo: { comboOf = $0 },
                                      onBonus: { bonusOf = (card: $0, at: $1) },
                                      onHandOff: { handingOff = true },
                                      onExchange: { exchanging = true },
                                      allowsShooting: tutorial == nil)
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
                    InspectedCardView(card: inspecting.card, from: inspecting.from,
                                      onKeyword: explain)
                        .id(inspecting.card.id)
                        .zIndex(9)
                }
                if let explaining {
                    GlossaryPopup(title: explaining.title, says: explaining.says) {
                        withAnimation(.easeOut(duration: 0.15)) { self.explaining = nil }
                    }
                    .zIndex(9.4)
                }
                if let comboOf {
                    ComboView(card: comboOf) { self.comboOf = nil }
                        .transition(.opacity)
                        .zIndex(9.8)
                }
                if let bonusOf {
                    BonusBubble(lines: bonusOf.card.bonusLines, anchor: bonusOf.at) {
                        self.bonusOf = nil
                    }
                    .zIndex(9.9)
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
                    ShotCutsceneView(scene: scene, referee: controller.refereeOnFloor)
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
                if case .awaitingCounter(let cards) = controller.gate, !cards.isEmpty {
                    // **Every answer the hand holds.** Two fields let a card answer here
                    // and a hand can hold both, so the question is which one you spend —
                    // and it is asked in the cards' own words rather than one of theirs.
                    let mixed = Set(cards.map(\.descriptor.clearsOut)).count > 1
                    // Caught off a Lob with a dunk in hand: the Alley-Oop, asked for by name.
                    let dunking = cards.allSatisfy { $0.descriptor.special?.dunks == true }
                    CardChoiceView(title: dunking ? "Dunk It?"
                                   : (cards.count == 1 ? "\(cards[0].descriptor.name)?" : "Answer it?"),
                                   note: dunking
                                       ? "Finish the Lob: Alley-Oop, SHOT +10%"
                                       : (mixed
                                          ? "Step aside, or break them before they land"
                                          : (cards[0].descriptor.clearsOut
                                             ? "Step aside and the ball carries on"
                                             : "Break the clamps before they land")),
                                   offered: cards.map(\.descriptor),
                                   tint: CardPalette.orange,
                                   taking: dunking ? "Dunk it!" : "Play it!",
                                   declining: "No thanks",
                                   chosen: $picked, ringed: ring,
                                   onDecline: declineTheOffer,
                                   onPick: takeTheOffer)
                        .zIndex(11)
                }
                if case .awaitingOption(let option) = controller.gate {
                    // A card's "You may", asked with the card that says it.
                    CardChoiceView(title: option.question, note: option.note,
                                   offered: [option.card],
                                   tint: CardPalette.orange,
                                   taking: option.taking,
                                   declining: "No thanks",
                                   chosen: $picked, ringed: ring,
                                   onDecline: declineTheOffer,
                                   onPick: takeTheOffer)
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
                                     shade: CardPalette.orange, size: 20,
                                     run: declineTheOffer)
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
                                   chosen: $picked, ringed: ring,
                                   onDecline: declineTheOffer,
                                   onPick: takeTheOffer)
                    .zIndex(12)
                }
                if case .awaitingIntangibleDrop(let offered) = controller.gate {
                    // The one that just arrived is in the row, so "just discard it" is a
                    // pick rather than a second button.
                    CardChoiceView(title: "Too Many", note: "One has to go", offered: offered,
                                   tint: CardPalette.gold,
                                   chosen: $picked, ringed: ring,
                                   onPick: takeTheOffer)
                        .zIndex(12)
                }
                if case .awaitingInjuryPick(let card) = controller.gate {
                    CardChoiceView(title: card.name, note: "Take one",
                                   offered: controller.shown.injuriesOffered,
                                   hidden: controller.shown.injuriesHidden,
                                   chosen: $picked, ringed: ring,
                                   onPick: takeTheOffer)
                    .zIndex(12)
                }
                if case .awaitingCardFrom(let card, let victim) = controller.gate {
                    HandPickerView(card: card, victim: victim,
                                   hand: controller.shown[victim].bag.count,
                                   chosen: $picked, ringed: ring,
                                   onPick: { takeTheOffer(.position($0)) })
                    .zIndex(12)
                }
                if handingOff, case .awaitingMove(let seat) = controller.gate {
                    let receivers = Rules.handOffTargets(controller.shown, for: seat)
                    if !receivers.isEmpty {
                        ClampHandOffView(clamps: controller.shown[seat].clamps,
                                         receivers: receivers,
                                         onHandOff: { clamp, to in
                                             if controller.shown[seat].clamps.count <= 1 {
                                                 handingOff = false
                                             }
                                             controller.handOff(clamp: clamp, to: to)
                                         },
                                         onDone: { handingOff = false })
                            .zIndex(12)
                    }
                }
                if exchanging, case .awaitingMove(let seat) = controller.gate {
                    let options = Rules.exchangeOptions(controller.shown, for: seat)
                    SlotExchangeView(courts: options.courts, balls: options.balls,
                                     onExchange: { court, ball in
                                         exchanging = false
                                         controller.exchange(court: court, ball: ball)
                                     },
                                     onCancel: { exchanging = false })
                        .zIndex(12)
                }
                if let card = controller.sellOutChoice {
                    // S.O.S: the card held up, and the two ways it can go up.
                    ZStack {
                        DimLayer(on: true, amount: Theme.dimBrowser)
                        Color.clear.contentShape(Rectangle()).ignoresSafeArea()
                            .onTapGesture { controller.sellOut(asTwo: nil) }
                        VStack(spacing: 14) {
                            CardFrontView(descriptor: card.descriptor, displayWidth: 150,
                                          expanded: true)
                                .shadow(color: .black.opacity(0.55), radius: 20, y: 10)
                            ChunkyButton(title: "Shoot the three", fill: CardPalette.gold,
                                         stroke: CardPalette.gold, shade: CardPalette.orange,
                                         size: 20) { controller.sellOut(asTwo: false) }
                            ChunkyButton(title: "Two at double SHOT", fill: CardPalette.blue,
                                         size: 20) { controller.sellOut(asTwo: true) }
                        }
                        .padding(.horizontal, 40)
                    }
                    .transition(.opacity)
                    .zIndex(12)
                }
                if case .awaitingMode(let card) = controller.gate {
                    ModePickerView(card: card,
                                   ringed: { if case .mode(let at) = ring { return at }
                                             else { return nil } }()) {
                        controller.choose(mode: $0)
                    }
                        .zIndex(12)
                }
                // The star, over the floor and under everything else — it belongs to the
                // man, not to the scene above him.
                if controller.challenging != nil {
                    // Centred, because the camera has already gone to him — the star opens
                    // out of whoever the screen is holding on.
                    ChallengeStar()
                        .transition(.opacity)
                        .zIndex(11)
                }
                if case .awaitingChallenge(let card) = controller.gate {
                    ChallengeView(card: card,
                                  available: !controller.shown[GameRules.localSeat].challenged,
                                  onChallenge: { controller.challenge(true) },
                                  onDecline: { controller.challenge(false) })
                        .zIndex(12)
                }
                if case .awaitingPayoff(let clamp) = controller.gate {
                    PayoffPickerView(clamp: clamp,
                                     ringed: { if case .payoff(let which) = ring { return which }
                                               else { return nil } }()) {
                        controller.take(payoff: $0)
                    }
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
                if let flip = controller.coinFlip {
                    CoinFlipView(flip: flip)
                        .id(flip.id)
                        .transition(.opacity)
                        .zIndex(17)
                }
                // The player's own trip is a gate; an opponent's plays itself. Both use the
                // same scene, so a free throw looks the same from either seat.
                if case .awaitingFreeThrow(let trip) = controller.gate {
                    FreeThrowView(trip: trip, auto: nil,
                                  onResult: { controller.shootFreeThrow(made: $0) },
                                  referee: controller.refereeOnFloor)
                        .id(trip.attempted)
                        .transition(.opacity)
                        .zIndex(16)
                } else if let shot = controller.aiFreeThrow {
                    FreeThrowView(trip: shot.trip, auto: shot.made,
                                  referee: controller.refereeOnFloor)
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
                if let round = controller.roundCall {
                    RoundCallView(call: round,
                                  onFinished: { controller.roundCallFinished() })
                        .transition(.opacity)
                        .zIndex(42)
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

    /// **Clamps and Injuries, one behind the other.**
    ///
    /// Two full plates on the same flank would take the whole side of the screen, and an
    /// Injury is the thing that explains a greyed-out card — Torn Achilles holds a hand
    /// down and nothing on screen said so. Stacked, the one behind reads as the drop
    /// under the one in front, and tapping the back one brings it forward.
    ///
    /// Only the front plate takes taps on its slots; the back one takes one tap, which is
    /// the swap.
    private var debuffPlates: some View {
        ZStack(alignment: .topLeading) {
            plate(injuries: !injuriesForward)
                .offset(x: Panels.stack, y: Panels.stack)
                .allowsHitTesting(false)
                .overlay {
                    Color.clear
                        .contentShape(Rectangle())
                        .offset(x: Panels.stack, y: Panels.stack)
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.22)) {
                                injuriesForward.toggle()
                            }
                        }
                }
            plate(injuries: injuriesForward)
        }
    }

    private func plate(injuries: Bool) -> some View {
        DebuffSlotsView(cards: injuries ? controller.human.injuries
                                        : controller.human.clamps.map(\.card),
                        title: injuries ? "Injuries" : "Clamps",
                        fill: injuries ? CardPalette.teal : CardPalette.red,
                        shade: injuries ? CardPalette.darkRed : CardPalette.purple,
                        onSelect: { inspecting = (card: $0, from: $1) })
    }

    /// Opens a floor sheet, where that is allowed. The hold is the `onChange`'s job.
    private func open(_ inspection: Inspection) {
        guard controller.canInspect else { return }
        onFloor = inspection
    }

    private func closeFloor() { onFloor = nil }

    private enum Panels {
        /// How far a slot panel goes to get out of the way, less the sliver it leaves
        /// behind. It used to clear the screen entirely, which said the panel was gone
        /// rather than moved — an edge still showing is a thing you know is coming back.
        static let aside: CGFloat = 320 - peek
        /// What is left on screen of a panel that has stood aside.
        static let peek: CGFloat = 14
        /// And how far down they sit, out from under the flanks' feet.
        static let drop: CGFloat = 8
        /// How far the plate behind shows past the one in front — see `debuffPlates`.
        /// A drop's worth, because that is what it is standing in for.
        static let stack: CGFloat = 7
    }

    /// Whether the floor's own readings should get out of the way: something is being
    /// asked for out of the hand, and the hand is what the eye needs.
    /// The panels either side of the hand get out of the way for any question — they are
    /// never the answer to one.
    private var standingAside: Bool {
        switch controller.gate {
        case .awaitingDiscard, .awaitingGiveUp, .awaitingBid,
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
        case .awaitingDiscard, .awaitingGiveUp, .awaitingBid: return true
        default: return false
        }
    }

    private var floorIsTheQuestion: Bool {
        switch controller.gate {
        case .awaitingTarget, .awaitingNaming: return true
        default: return false
        }
    }

    /// Whether a scene that paints the whole screen is up, so nothing on the floor can be seen.
    private var floorIsCovered: Bool {
        if controller.cutscene != nil || controller.turnover != nil || controller.aiFreeThrow != nil {
            return true
        }
        if case .awaitingFreeThrow = controller.gate { return true }
        return false
    }

    /// A covering scene's 0.2s fade, and a little over.
    private static let floorSleepDelay: Double = 0.3

    private var dim: Double {
        if browsingDiscard { return Theme.dimBrowser }
        // Your own hand being asked for cards is the same question somebody else's hand
        // gets a dimmed floor for.
        switch controller.gate {
        case .awaitingDiscard, .awaitingGiveUp: return Theme.dimBrowser
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
                  onSelect: select,
                  faces: padGlyphs,
                  ringed: pad.isAttached && padFaces == nil ? cursor.seat : nil,
                  undelivered: controller.undelivered,
                  bound: controller.boundSeats,
                  spend: controller.spend,
                  // Nothing on the floor moves while something else has the screen.
                  // **Held still only when the screen is taken away from him.** Reading a
                  // card is not that: the game is still on, and a referee who stops
                  // moving every time somebody looks at their hand reads as a bug.
                  frozen: dim > 0 || onFloor != nil,
                  // The crew's two moments. He is stood behind whatever is on screen for
                  // both, which is the point — the floor is what the call is about.
                  callingRef: controller.callOnFloor,
                  shooting: controller.cutscene != nil,
                  showingClamps: beingRead?.clamp != nil,
                  // A lesson is about the cards; nobody on the floor opens.
                  onInspectPlayer: { seat in if tutorial == nil { open(.player(seat)) } },
                  onInspectReferees: { open(.referees) },
                  camera: controller.camera,
                  passThrow: controller.passThrow)
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
            // The floor and the ball in play, across from the SHOT.
            .overlay(alignment: .topLeading) { floorCorner }

            )
    }

    /// The Varena and the ball in play, top left of the court — and in a lesson, the bare
    /// spot its way out is drawn from instead.
    ///
    /// **Erased where it joins the court**, which is already as deep as SwiftUI can build.
    /// A plain `if` here is another conditional wrapping that whole type, and the walk ran
    /// off the end of the stack the moment a lesson made the second branch real — a crash
    /// in `court.getter` on opening a lesson, which is the same fault `court` itself
    /// carries a note about.
    private var floorCorner: AnyView {
        guard tutorial == nil else {
            // A lesson has no Varena. Its way out stands here — see `TutorialOverlay`.
            return AnyView(Color.clear
                .frame(width: 1, height: 1)
                .tutorialTarget(.exitSpot)
                .padding(.leading, 14)
                .padding(.top, 8))
        }
        return AnyView(FloorAndBallView(state: controller.shown,
                                        onSelect: { inspecting = (card: $0, from: $1) })
            .padding(.leading, 14)
            .padding(.top, 8))
    }

    /// Sits under the scoreboard: a scrim rather than a solid panel, so the top of the
    /// court still reads through it.
    ///
    /// **The only way it is drawn.** There were three — a panel, this, and nothing — on a
    /// button in the status bar. Two of them were there to be compared against this one
    /// while it was being settled, and it has been.
    private var logStrip: some View {
        ZStack {
            // **Actual black while the screen is dim.** A scrim over the court is a
            // lighter black than the dim lays over everything else, so the strip stood
            // out as a panel the moment the game stopped to ask something. Under the dim
            // it goes the whole way, and matches.
            Rectangle().fill(Color.black.opacity(dim > 0 ? 1 : 0.35))
                .animation(.easeInOut(duration: 0.22), value: dim > 0)
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
    }

    /// Where that seat sits on the scoreboard, which orders by score.
    private func scoreRow(of seat: Seat) -> Int {
        let ranked = controller.shown.players
            .sorted { ($0.score, $0.points) > ($1.score, $1.points) }
        return ranked.firstIndex { $0.seat == seat } ?? 0
    }

    private var statusBar: some View {
        HStack {
            // **Which round it is, at a size that says so.** Eleven points of system
            // type in the corner was there all along and nobody could find it.
            SmallCapsText(text: "Round \(controller.shown.round)"
                          + "/\(controller.shown.rules.roundsPerGame)",
                          font: Chrome.display, size: 19, tracking: 0.6)
                .foregroundStyle(.white)
                .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            shotClock

            HStack(spacing: 8) {
                SmallCapsText(text: "Half \(controller.shown.half)",
                              font: Chrome.display, size: 15, tracking: 0.6)
                    .foregroundStyle(CardPalette.gray)
                // A lesson leaves by its own button.
                if tutorial == nil { pauseButton }
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
    /// Who has gone, written out.
    ///
    /// **A sentence, not an expression.** This was four ternaries and three
    /// concatenations inline in the view, which is the shape that makes the type checker
    /// give up — and one of the ternaries chose between "their" and "their".
    private var leaversLine: String {
        let names = controller.walkedOut
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.playerName)
        guard let last = names.last else { return "" }
        let who: String
        if names.count == 1 {
            who = last
        } else {
            who = names.dropLast().joined(separator: ", ") + " and " + last
        }
        let have = names.count == 1 ? "has" : "have"
        // The rules were running on their device. There is no game here to carry on.
        if controller.hostGone {
            return "\(who) \(have) gone, and the game was running on their phone. "
                + "There is nothing here to carry on with."
        }
        return "\(who) \(have) gone. Carry on with the house playing their seat?"
    }

    /// What the table is asked when one of them goes.
    ///
    /// **No way to dismiss it.** Tapping the dark resumes the pause menu because a pause
    /// is yours to end; this is a question, and the game cannot go on either way until it
    /// is answered.
    private var walkedOut: some View {
        return ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()
            VStack(spacing: 18) {
                ScreenTitle(text: controller.hostGone ? "Game Over" : "They Left",
                            drop: CardPalette.red)
                Text(leaversLine)
                    .font(.custom(Chrome.display, size: 16))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                VStack(spacing: 12) {
                    // Not offered when there is no game left to play on with.
                    if !controller.hostGone {
                        ChunkyButton(title: "Play On", fill: CardPalette.blue) {
                            controller.keepPlaying()
                        }
                    }
                    ChunkyButton(title: "End Game", fill: CardPalette.red) {
                        controller.stopHere()
                        onQuit()
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
    }

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

            // **The number, once and large.** Everywhere else a man is written "#12 John";
            // here the name carries the sentence and the number goes in the corner at the
            // size a shirt would wear it. A tie has no one number, so it goes unwritten.
            if winners.count == 1 {
                Text("#\(Kit.numbers[safe: PlayerLook.shared.number(for: winners[0])] ?? "0")")
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.color(for: winners[0]).opacity(0.22))
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .topTrailing)
                    .padding(.trailing, 14)
                    .padding(.top, 10)
                    .allowsHitTesting(false)
            }

            // **Scrolled, because the card grew.** The winners, the verdict, a nine-row
            // board at its reading size and three buttons do not fit a phone between
            // them — and what went off the bottom was the way out of the screen.
            VStack(spacing: 14) {
                HStack(spacing: 22) {
                    ForEach(Array(winners.enumerated()), id: \.element) { place, seat in
                        // Facing the room with the ball, not jogging upcourt — the game
                        // is over and there is nowhere left to run. One pose each where
                        // more than one of them won, so a tie is not the same man twice.
                        HooperPortrait(pose: Winner.pose(for: seat, at: place,
                                                         from: winnerPose),
                                       // Only the player has chosen a face; the rest
                                       // wear their seat's, as on the court.
                                       kit: seat.isLocal ? HooperKit.shared : nil,
                                       seat: seat)
                            .scaleEffect(Winner.portraitScale, anchor: .bottom)
                            .frame(width: Theme.Figure.headDiameter * Winner.portraitScale,
                                   height: Theme.Figure.height * Winner.portraitScale,
                                   alignment: .bottom)
                    }
                }

                Text(verdict(for: winners))
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(winners.count == 1 ? Theme.color(for: winners[0]) : Theme.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .padding(.horizontal, 20)

                // Read rather than glanced at, so the board is given a taller row here
                // than the one it wears over the court.
                ScoreboardView(state: controller.shown, highlighted: Set(winners),
                               totalLabel: "SCORE", row: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 26)
                    .padding(.top, 4)

                // **Three ways off this screen, not one.** Playing again is the one
                // being offered, so it keeps the gold and the room; going back over the
                // game and leaving the table are the quieter pair under it.
                VStack(spacing: 10) {
                    finalButton("RUN IT BACK", fill: Theme.ball, ink: .black) {
                        onRunItBack()
                    }
                    HStack(spacing: 10) {
                        finalButton("GAME LOG", fill: CardPalette.blue, ink: .white) {
                            withAnimation(.easeOut(duration: 0.2)) { reviewingLog = true }
                        }
                        finalButton("BACK TO TITLE", fill: CardPalette.red, ink: .white) {
                            onQuit()
                        }
                    }
                }
                .padding(.top, 4)
                }
            // **The card's own margins.** It is laid out rather than scrolled: the column
            // fits the screen, and a scroll view under a result card reads as a list.
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .opacity(reviewingLog ? 0 : 1)

            if reviewingLog { logReview }
        }
    }

    /// One of the three off the final card. They are capsules rather than `ChunkyButton`s
    /// because this screen is a card being handed over, not the game's own chrome.
    private func finalButton(_ title: String, fill: Color, ink: Color,
                             _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title)
                .font(.system(size: 14, weight: .black)).tracking(1.2)
                .foregroundStyle(ink)
                .padding(.horizontal, 30).padding(.vertical, 12)
                .background(Capsule().fill(fill))
        }
    }

    /// The whole game, back to the tip, over the result it produced.
    private var logReview: some View {
        VStack(spacing: 12) {
            ScreenTitle(text: "Game Log", drop: CardPalette.blue)
            LogView(lines: controller.log)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 18)
            ChunkyButton(title: "Done", fill: CardPalette.blue) {
                withAnimation(.easeOut(duration: 0.2)) { reviewingLog = false }
            }
            .padding(.horizontal, 60)
        }
        .padding(.vertical, 34)
        .transition(.opacity)
    }

    /// Says what a mechanic is. **Only where there is something to say** — a marked word
    /// with no entry stays inert rather than opening an empty note.
    private func explain(_ word: String) {
        guard let found = Glossary.meaning(of: word) else { return }
        withAnimation(.easeOut(duration: 0.15)) { explaining = found }
    }

    // MARK: - The pad

    /// Where every press lands.
    ///
    /// **Read from the top down: whatever is nearest the player answers.** A button
    /// pressed while the pause menu is up is answering the pause menu, not the hand
    /// behind it, and a card held up to be read is between the two.
    private func take(_ action: Pad.Action) {
        if case .gameOver = controller.gate { return takeOnFinalCard(action) }
        if paused { return takeWhilePaused(action) }

        // Everything the player opened for themselves, and everything the game is
        // holding up to be looked at. All of it closes on the same two buttons.
        if browsingDiscard || onFloor != nil || inspecting != nil {
            guard action == .back || action == .tap else { return }
            browsingDiscard = false
            onFloor = nil
            inspecting = nil
            return
        }
        // A first sighting waits on the player, exactly as it does for a tap on glass.
        if controller.reveal != nil {
            if action == .tap || action == .back { controller.dismissReveal() }
            return
        }
        if controller.whistleReveal != nil {
            if action == .tap || action == .back { controller.dismissWhistleReveal() }
            return
        }

        switch action {
        case .pause:
            guard tutorial == nil else { return }
            controller.pause()
            withAnimation(.easeOut(duration: 0.2)) { paused = true }
        case .previous, .next:
            walk(action)
        case .up:
            // **Up takes a card and nothing else.** It is the flick, so it still throws
            // one at the table — but a thumb resting on the stick must never lean on a
            // button, which is what it was doing on every confirm in the game.
            if Row.runsDown(controller) { walk(.previous) } else { commitCard(cursor.at) }
        case .down:
            if Row.runsDown(controller) { walk(.next) } else { detail = nil }
        case .flick:
            commit(cursor.at)
        case .tap:
            press(cursor.at)
        case .primary:
            offered()
        case .back:
            if detail != nil { detail = nil } else { declineTheOffer() }
        case .inspect:
            look(at: cursor.at)
        }
    }

    /// The men the buttons stand for, laid out the way the floor lays them out.
    ///
    /// **The pad's diamond over the court's.** Square is the button on the left and the
    /// man on the left; cross is the one nearest you, at the bottom of both; circle is
    /// the right of both; triangle the far one. Nobody has to learn a mapping that is
    /// already on the screen, and the four never shuffle — a man keeps his button because
    /// he keeps his place on the floor.
    ///
    /// Where you are not one of the answers — an inbound, which cannot be thrown to
    /// yourself — the three who are left slide up the order and take square, cross and
    /// circle. Three men on three buttons beats three men on three of four.

    /// Whether the game is asking which of them at all.
    private var padFaces: Set<Seat>? {
        guard pad.isAttached else { return nil }
        switch controller.gate {
        case .awaitingInbound, .awaitingTarget, .awaitingNaming:
            let choosable = CourtView.choosable(at: controller.gate, in: controller.shown)
            return choosable.isEmpty ? nil : choosable
        default:
            return nil
        }
    }

    /// Where the ring is drawn — **nowhere at all without a pad.**
    ///
    /// The cursor exists either way, because it is where the game's attention is; the ring
    /// is the drawing of it, and a mark on the screen of somebody playing on glass is a
    /// mark that means nothing. One place, so no view has to remember to ask.
    private var ring: PadSpot? { pad.isAttached ? cursor.at : nil }

    /// The glyph each choosable man is wearing, when the faces are standing in for them.
    /// The button each man on offer wears.
    ///
    /// **Fixed to the seat, not handed out in order.** Dealing the four buttons along a
    /// list of whoever happens to be selectable moves them: with the near man not on
    /// offer, the right-hand player slid onto cross. The button is the one drawn where
    /// the player is drawn and it does not move — see `Seat.face(viewedFrom:)`.
    private var padGlyphs: [Seat: String] {
        guard let choosable = padFaces else { return [:] }
        var worn: [Seat: String] = [:]
        for seat in choosable {
            if let glyph = pad.glyph(for: seat.face(viewedFrom: GameRules.localSeat)) {
                worn[seat] = glyph
            }
        }
        return worn
    }

    /// **Whatever the screen is holding out.** The right trigger, which skips the row: on
    /// your turn that is the shot, at a bid it is the bid, on a sheet it is the take. One
    /// button for "the obvious thing", wherever the ring happens to be.
    private func offered() {
        switch controller.gate {
        case .awaitingMove:
            guard tutorial == nil,
                  Rules.legalMoves(controller.shown, for: GameRules.localSeat)
                .contains(.shoot) else { return }
            controller.shoot()
        case .awaitingBid, .awaitingDiscard, .awaitingGiveUp:
            confirm()
        case .awaitingOption:
            controller.choose(option: true)
        case .awaitingCounter, .awaitingToll, .awaitingIntangibleDrop,
             .awaitingInjuryPick, .awaitingCardFrom:
            if let picked { takeTheOffer(picked) }
        case .gameOver:
            onRunItBack()
        default:
            break
        }
    }

    private func walk(_ way: Pad.Action) {
        let row = Row.at(controller)
        cursor.settle(on: row)
        cursor.walk(way, along: row)
        // The reading does not follow the ring. Walking away from a card you were holding
        // up puts it back in the hand, which is what a finger does too.
        detail = nil
    }

    /// A press on whatever is focused. **The same two steps a finger gets**: a card comes
    /// up to be read, and a second press plays it.
    private func press(_ spot: PadSpot?) {
        switch spot {
        case .card(let id):
            guard let card = focused(id) else { return }
            if detail?.id == id {
                detail = nil
                controller.commit(card)
            } else {
                detail = card
            }
        case .shoot:   controller.shoot()
        case .finish(let type): controller.shoot(as: type)
        case .payoff(let payoff): controller.take(payoff: payoff)
        case .borrow:  controller.beginBorrow()
        case .confirm: confirm()
        case .decline: declineTheOffer()
        case .seat(let seat): select(seat)
        // **Exactly what a finger does.** A tap on a sheet takes the card off the table;
        // the button underneath is still what confirms it, and up is that button.
        case .offer(let pick): picked = pick
        case .mode(let at): controller.choose(mode: at)
        case nil: break
        }
    }

    /// The flick: what throwing a card at the table means, without the throw. It does not
    /// wait for the card to be read first — neither does a flick on glass.
    /// The flick, but only where a card is. **Buttons are pressed on purpose**: up is
    /// where a thumb rests, and leaning on it used to be a bid placed or a card given up.
    private func commitCard(_ spot: PadSpot?) {
        switch spot {
        case .card, .offer: commit(spot)
        default: break
        }
    }

    private func commit(_ spot: PadSpot?) {
        switch spot {
        case .card(let id):
            guard let card = focused(id) else { return }
            detail = nil
            controller.commit(card)
        // Up is the button under the sheet. What is picked goes, and a sheet with nothing
        // picked yet takes the one the ring is on — which is what the eye expects when
        // there is only ever one card being pointed at.
        case .offer(let pick):
            takeTheOffer(picked ?? pick)
        default:
            press(spot)
        }
    }

    /// A look at what is focused, without taking it.
    private func look(at spot: PadSpot?) {
        switch spot {
        case .card(let id): detail = focused(id)
        case .seat(let seat): if tutorial == nil { onFloor = .player(seat) }
        default: break
        }
    }

    /// The card the ring is on, wherever it is being offered from — your own hand at most
    /// gates, and the answers held out at a counter.
    private func focused(_ id: Card.ID) -> Card? {
        if let mine = controller.shownBag(of: GameRules.localSeat).first(where: { $0.id == id }) {
            return mine
        }
        if case .awaitingCounter(let cards) = controller.gate {
            return cards.first { $0.id == id }
        }
        return nil
    }

    /// **What taking a card off a sheet means, whichever sheet it is.** One owner: the
    /// tap on the card, the button under it and up on a pad all land here, so the three
    /// cannot answer the same question differently.
    private func takeTheOffer(_ pick: CardPick) {
        switch controller.gate {
        case .awaitingCounter(let cards):
            // A sheet answers by name where the card can be read and by its place in the
            // row where it cannot; either way it names one this hand was offered.
            let taken: Card?
            switch pick {
            case .named(let id):    taken = cards.first { $0.descriptor.id == id }
            case .position(let at): taken = cards[safe: at]
            }
            controller.choose(counter: taken?.id)
        case .awaitingOption:
            controller.choose(option: true)
        case .awaitingToll:
            controller.choose(toll: pick)
        case .awaitingIntangibleDrop:
            if case .named(let id) = pick { controller.choose(dropping: id) }
        case .awaitingInjuryPick:
            if case .named(let id) = pick { controller.choose(injury: id) }
        case .awaitingCardFrom(_, let victim):
            guard case .position(let at) = pick else { return }
            let hand = controller.shown[victim].bag
            guard hand.indices.contains(at) else { return }
            controller.choose(card: hand[at].id)
        default:
            break
        }
    }

    /// Saying no, where no is an answer — the button on the sheet, and circle.
    private func declineTheOffer() {
        if case .awaitingChallenge = controller.gate { controller.challenge(false); return }
        switch controller.gate {
        case .awaitingCounter: controller.choose(counter: nil)
        case .awaitingOption:  controller.choose(option: false)
        case .awaitingToll:    controller.choose(toll: nil)
        case .awaitingNaming:  controller.choose(naming: nil)
        default: break
        }
    }

    /// The bar's single confirm, whichever question is asking it.
    private func confirm() {
        if case .awaitingChallenge = controller.gate { controller.challenge(true); return }
        switch controller.gate {
        case .awaitingBid:      controller.submitBid()
        case .awaitingDiscard:  controller.submitDiscard()
        case .awaitingGiveUp:   controller.submitGiveUp()
        case .awaitingOption:   controller.choose(option: true)
        // The button under a sheet, which takes whatever has been picked off it.
        case .awaitingCounter, .awaitingToll, .awaitingIntangibleDrop,
             .awaitingInjuryPick, .awaitingCardFrom:
            if let picked { takeTheOffer(picked) }
        default: break
        }
    }

    /// The player this face button names, when the floor is what is being asked about.
    ///
    /// Nil at every other gate, which is what leaves the four buttons meaning what they
    /// ordinarily mean — see `Seat.face(viewedFrom:)`.
    private func asked(for face: Pad.Face) -> Seat? {
        let choosable = CourtView.choosable(at: controller.gate, in: controller.shown)
        guard !choosable.isEmpty else { return nil }
        return choosable.first { $0.face(viewedFrom: GameRules.localSeat) == face }
    }

    /// Picking a man off the floor. **The same answer for a tap and for the ring** —
    /// which is the point of asking for a player the way the game already asks for one.
    private func select(_ seat: Seat) {
        if case .awaitingTarget = controller.gate {
            controller.choose(target: seat)
        } else if case .awaitingNaming = controller.gate {
            controller.choose(naming: seat)
        } else {
            controller.inbound(to: seat)
        }
    }

    /// The pause menu is two buttons and no row: resume is the near one and quitting is
    /// deliberate, so it takes the button that means "the other thing".
    private func takeWhilePaused(_ action: Pad.Action) {
        switch action {
        case .tap, .back, .pause: resume()
        case .flick, .primary: paused = false; onQuit()
        default: break
        }
    }

    /// The final card. Its three ways off it, on three buttons rather than a row —
    /// nothing else is happening, and a ring here would be the only one in the game that
    /// had to be walked to reach a menu.
    private func takeOnFinalCard(_ action: Pad.Action) {
        if reviewingLog {
            if action == .back || action == .tap {
                withAnimation(.easeOut(duration: 0.2)) { reviewingLog = false }
            }
            return
        }
        switch action {
        case .tap:     onRunItBack()
        case .inspect: withAnimation(.easeOut(duration: 0.2)) { reviewingLog = true }
        case .back:    onQuit()
        default: break
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

extension EnvironmentValues {
    /// **Nothing on the floor can be seen.** An opaque scene has been over it for longer
    /// than its fade, so anything animating there may stop until this goes false again —
    /// which happens the moment the scene starts to leave. Owned by `GameView`.
    @Entry var floorIsHidden = false
}
