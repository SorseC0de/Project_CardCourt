import SwiftUI

struct GameView: View {
    @State private var controller = GameController()
    @State private var logStyle: LogStyle = .overlay
    @State private var detail: Card?
    /// A slotted passive or an active debuff, held up to be read.
    /// A slotted card held up, and the slot it came from.
    @State private var inspecting: (card: CardDescriptor, from: CGPoint)?
    @State private var browsingDiscard = false
    @State private var showingLobby = false

    /// The log keeps this height whether it sits in its own band or floats over the court.
    private let logHeight: CGFloat = 74

    var body: some View {
        ZStack {
            Theme.panel.ignoresSafeArea()

            // The court runs to the bottom of the screen; the bag sits straight on it.
            // Only the court art runs under the home indicator. Everything you touch
            // stays inside the safe area.
            VStack(spacing: 0) {
                statusBar
                ScoreboardView(state: controller.state, withheld: controller.withheldPoints)
                logStrip
                stage
            }
            .ignoresSafeArea(edges: .bottom)

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
                        IntangibleSlotsView(held: controller.human.intangibles,
                                            dormant: controller.dormantIntangibles,
                                            slots: controller.state.rules.intangibleSlots,
                                            onSelect: { inspecting = (card: $0, from: $1) })
                        Spacer()
                        DebuffSlotsView(cards: controller.human.clamps.map(\.card),
                                        onSelect: { inspecting = (card: $0, from: $1) })
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    ActionBarView(controller: controller, detail: $detail)
                }
                // Out of the way rather than washed over. Two translucent sheets meeting
                // multiply, and the seam where the hand's met the court's was a black
                // band across the screen — so the cards step down instead, which also
                // keeps them off the prompt.
                .offset(y: isChoosingInbound ? CourtView.Court.handDrop : 0)
                .animation(.easeOut(duration: 0.3), value: isChoosingInbound)
            }

            // One dim for the whole screen, always in the hierarchy and turned up when
            // something takes the screen over. Never inserted, so it can only ever fade.
            DimLayer(on: dim > 0, amount: dim, seconds: 0.22)
                .zIndex(9)

            if let scene = controller.cutscene {
                ShotCutsceneView(scene: scene)
                    .transition(.opacity)
                    .zIndex(10)
            }
            if let inspecting {
                InspectedCardView(card: inspecting.card, from: inspecting.from)
                    .id(inspecting.card.id)
                    .zIndex(9)
            }
            #if DEBUG
            VStack {
                HStack {
                    Spacer()
                    FrameRateView().padding(.trailing, 8)
                }
                Spacer()
            }
            .zIndex(99)
            #endif

            if let seat = controller.celebratingThree {
                ThreeCelebrationView(
                    seat: seat,
                    // Roughly that player's PTS cell: the board sits under the status bar,
                    // rows are even, and PTS is the first stat column.
                    scoreTarget: CGPoint(x: 78, y: 96 + 24 * CGFloat(scoreRow(of: seat))),
                    onScoreLands: { controller.threeScoreLanded() },
                    onFinished: { controller.threeCelebrationFinished() })
                    .zIndex(13)
            }
            if let played = controller.playedCard {
                PlayedCardView(played: played, width: 210)
                    .transition(.opacity)
                    .zIndex(7)
            }
            if browsingDiscard {
                DiscardBrowserView(cards: controller.state.discard,
                                   onDismiss: { browsingDiscard = false })
                    .transition(.opacity)
                    .zIndex(11)
            }
            if let call = controller.actionCall {
                ActionCallView(call: call) { controller.actionCallFinished() }
                    .transition(.opacity)
                    // Over everything, cards included. It is the game speaking.
                    .zIndex(40)
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
            if let scene = controller.whistleReveal {
                WhistleRevealView(scene: scene) { controller.dismissWhistleReveal() }
                    .transition(.opacity)
                    .zIndex(14)
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
            if let scene = controller.turnover {
                TurnoverCutsceneView(scene: scene)
                    .transition(.opacity)
                    .zIndex(15)
            }
            if case .gameOver = controller.gate {
                finalCard.zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: controller.cutscene)
        .animation(.easeInOut(duration: 0.2), value: controller.turnover)
        .animation(.easeInOut(duration: 0.2), value: controller.reveal)
        .onChange(of: controller.gate) { detail = nil }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: inspecting?.card)
        .background(keyboardCommands)
        .task { controller.begin() }
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
            Button("New game") {
                controller = GameController()
                controller.begin()
            }
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

    /// The way to a match, until there is a front screen for it to live on.
    private var matchButton: some View {
        Button { showingLobby = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13, weight: .heavy))
                SmallCapsText(text: "Play online", font: Chrome.display, size: 15)
            }
            .foregroundStyle(.white)
            .shadow(color: Chrome.shade, radius: 0, x: 2, y: 2)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(CardPalette.blue))
            .overlay(Capsule().strokeBorder(CardPalette.gold, lineWidth: 3))
            .compositingGroup()
            .shadow(color: CardPalette.orange, radius: 0, x: 4, y: 4)
        }
        .buttonStyle(.plain)
    }

    /// The court is asking the player to pick somebody to throw to.
    private var isChoosingInbound: Bool {
        if case .awaitingInbound = controller.gate { return true }
        return false
    }

    /// How dark the screen should be, whichever thing has taken it.
    private var dim: Double {
        if browsingDiscard { return Theme.dimBrowser }
        if controller.whistleReveal != nil { return Theme.dimWhistle }
        if controller.reveal != nil { return Theme.dimReveal }
        return 0
    }

    private var stage: some View {
        Group {
            if case .awaitingBid(let shooter) = controller.gate {
                ReboundCutsceneView(shooter: shooter, revealedBids: controller.revealedBids,
                                    state: controller.state, shot: controller.shownShot,
                                    deck: controller.shownDeck)
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
        return controller.state.lastPasser
    }

    private var receiverOnCourt: Seat? {
        #if DEBUG
        return controller.practicePass?.to
        #else
        return nil
        #endif
    }

    /// In every style but .panel the court claims the log's real estate.
    private var court: some View {
        CourtView(state: controller.state,
                  gate: controller.gate,
                  revealedBids: controller.revealedBids,
                  settledAt: controller.ballSettledAt,
                  shownBall: controller.shownBall,
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
                  onSelect: { controller.inbound(to: $0) })
            // No inset: the floor and the streaks run to the screen edges, and
            // `CourtGeometry` lays the diamond out across the whole width.
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                StatusHUDView(state: controller.state, shot: controller.shownShot,
                              deck: controller.shownDeck)
                    .padding(.trailing, 18)
                    .padding(.top, 6)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    // The only way into a match. It lived on the bench, which is compiled
                    // out of a release build — so on TestFlight there was no way to reach
                    // the lobby at all. It stays here until the game has a front screen to
                    // put it on.
                    matchButton
                    #if DEBUG
                    DebugActionsView(controller: controller)
                    #endif
                }
                .padding(.leading, 14)
                .padding(.top, 6)
            }
            .sheet(isPresented: $showingLobby) {
                MatchLobbyView(controller: controller)
            }
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
        let ranked = controller.state.players
            .sorted { ($0.score, $0.points) > ($1.score, $1.points) }
        return ranked.firstIndex { $0.seat == seat } ?? 0
    }

    private var statusBar: some View {
        HStack {
            Text("ROUND \(controller.state.round)/\(controller.state.rules.roundsPerGame)")
                .font(.system(size: 11, weight: .heavy)).tracking(1)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            shotClock

            HStack(spacing: 8) {
                Text("HALF \(controller.state.half)")
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
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .background(Theme.panel)
    }

    /// The last number the clock actually showed.
    ///
    /// It reads `--` only before the first inbound of a round. Everything else that
    /// clears it — a Whistle stopping play, a round turning over mid-scene — is an event,
    /// and blanking the clock for the length of one says the clock is gone when it is
    /// only waiting.
    @State private var lastClock: Int?

    private var shotClock: some View {
        let clock = controller.state.shotClock ?? lastClock
        return VStack(spacing: 3) {
            SevenSegmentClock(value: clock)
            Text("SHOT CLOCK")
                .font(.system(size: 7, weight: .bold)).tracking(1.3)
                .foregroundStyle(Theme.inkDim)
        }
        .animation(.easeOut(duration: 0.25), value: clock)
        .onChange(of: controller.state.shotClock) { _, now in
            if let now { lastClock = now }
        }
        // A new round starts the clock over, so the memory goes with it.
        .onChange(of: controller.state.round) { _, _ in lastClock = nil }
    }

    private var finalCard: some View {
        let winners = Rules.winners(of: controller.state)
        return ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(spacing: 22) {
                    ForEach(winners, id: \.self) { seat in
                        PlayerFigure(seat: seat, mirrored: false)
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

                ScoreboardView(state: controller.state, highlighted: Set(winners))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 26)
                    .padding(.top, 4)

                Button {
                    controller = GameController()
                    controller.begin()
                } label: {
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

#Preview { GameView() }
