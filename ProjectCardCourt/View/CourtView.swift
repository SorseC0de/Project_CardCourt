import SwiftUI

struct CourtView: View {
    let state: GameState
    let gate: GameController.Gate
    let revealedBids: [Seat: Int]?
    /// Who is going up for the board, if anybody. The ball comes out of the hoop to meet
    /// him — see `ReboundBallView`.
    var rebound: ReboundLeap?
    /// When the ball finished changing hands, so the catch plays in view.
    var settledAt: Date?
    /// Who is drawn holding it, which lags the rules across a pass — see
    /// `GameController.shownBall`.
    var shownBall: Seat?
    /// Who the court is setting up for — see `GameController.inbounding`. Not read off
    /// the phase: the rules are a possession ahead of what is on screen.
    var inbounding: Seat?
    /// A throw-in in the air — see `GameController.throwing`.
    var throwing: ThrowIn?
    /// Who threw it, so the ball has somewhere to travel from.
    var passer: Seat?
    /// Stands in for the ball's holder while a practice pass is in the air, so the flight
    /// can be watched without the rules having moved anything.
    var receiver: Seat?
    /// Whose seat the court is drawn from. Multiplayer passes the local player's.
    var viewer: Seat = GameRules.localSeat
    var flight: DrawFlight?
    var deckRoutine: DeckStage.Routine = .rest
    /// A card the stage should throw, and to whom.
    var deal: (seat: Seat, id: UUID)?
    /// A one-off Clamp taking its cards from this seat, right now.
    var swipe: (seat: Seat, id: UUID)?
    var opening: OpeningDeal?
    var flightDuration: Double = 0.30
    var onOpenDiscard: () -> Void = {}
    var onSelect: (Seat) -> Void
    /// **Which button stands for which man**, while the game is asking which of them.
    /// The pad's own glyph for each face button, over the head of the man it names — see
    /// `GameView.padFaces`. Empty at every other moment, and for everybody on glass.
    var faces: [Seat: String] = [:]
    /// The man a controller is pointing at, and nobody when nobody has one plugged in.
    /// **The wedge already over his head, in the cursor's colour** — a ring round a
    /// figure would be the one box on a floor with no boxes on it.
    var ringed: Seat?
    /// The official the pad's ring is on, while a card is naming one.
    var ringedOfficial: UUID?
    /// Cards dealt but not yet landed — see `GameController.undelivered`. A bag count
    /// that ticks up before the card arrives is the same instant draw in miniature.
    var undelivered: Set<UUID> = []
    /// Who the floor may show coils on — see `GameController.boundSeats`. Not
    /// `state[seat].clamps`, which is a possession ahead of the scene.
    var bound: Set<Seat> = []
    /// A card being given up, from a hand to the pile — see `GameController.spend`.
    var spend: (seat: Seat, id: UUID)?

    /// Held: the floor stops moving because something else has the screen.
    var frozen = false

    /// A Whistle going off right now — see `GameController.whistleReveal`.
    /// **Which official is making a call**, by his own id rather than by his card — any
    /// of the three can be the one who sees a travel. Nil is a crew with nothing to say.
    var callingRef: UUID?
    /// A shot in the air, from the moment it is taken — see `GameController.cutscene`.
    var shooting = false

    /// True while a Clamp is being read, which is when who is already clamped matters.
    var showingClamps = false
    /// A tap on somebody who is not a legal target: read them instead of passing to them.
    var onInspectPlayer: (Seat) -> Void = { _ in }
    /// A tap on a referee: the man who was tapped, and where on screen, so his card can
    /// rise from him.
    var onTapReferee: (UUID, CGPoint) -> Void = { _, _ in }
    /// What the camera is framing — see `CourtCamera`. Nil is the whole floor.
    var camera: CourtCamera?
    /// The last pass thrown — see `GameController.passThrow`.
    var passThrow: PassThrow?
    /// **A referee's throw-in, while it is being played** — see `GameController.refereeThrow`.
    /// He stands where the player-thrower used to, and his own post is empty meanwhile.
    var refereeThrow: RefereeThrow?

    /// The name under a player's feet.
    ///
    /// Its own numbers, not the card's. A card tightens its name with a negative
    /// `CardLayout.nameTracking` to fit a fixed width; this one is read at a distance
    /// over a busy floor, so it wants the opposite — bigger, and opened up.
    private enum NamePlate {
        /// The old plate's size, kept only for the room it took — see `node`.
        static let size: CGFloat = 26
        static let tracking: CGFloat = 0.04
        /// Where the name's foot sits, in the figure's own points from the top of his
        /// frame: just over the crown of his head.
        static let overHead: CGFloat = (SpriteMetrics.headOrigin.y - 1)
            * Theme.Figure.playerScale - 2
        /// **How much higher the hand count rides, to leave the name room under it**: the
        /// name's own height, and this much air over it. In the figure's points, which his
        /// row scales — so the name, drawn the same size on every row, is taller in them
        /// the further off he stands. A fixed lift cleared nobody's name at the back.
        static let badgeAir: CGFloat = 12
        static func badgeLift(atScale scale: CGFloat) -> CGFloat {
            badgeAir + FloorName.size / scale
        }
    }

    /// Who the court draws as holding the ball.
    ///
    /// A practice pass puts it in the receiver's hands without the rules having moved
    /// anything, and every part of the catch has to agree — the sprite, the flight, and
    /// the ball's destination all read this rather than `state.ball` directly.
    private var holder: Seat? { receiver ?? shownBall ?? state.ball }

    /// How wide a pile is drawn before the bench's multiplier.
    private static let pileWidth: CGFloat = 138
    /// **How far outside a man on the same post a second referee stands**, in the figure's
    /// own points before his row scales him: half his frame, so the two stand shoulder
    /// to shoulder rather than one inside the other.
    private static let refereeAside: CGFloat = Theme.Figure.height / 2

    /// Fixed so a bid badge appearing cannot shift a figure off its footing.
    private var nodeHeight: CGFloat { Theme.Figure.height + 26 }

    @Environment(\.floorIsHidden) private var floorIsHidden
    /// Set once the moving scenery has finished fading out after the court stopped running.
    @State private var sceneryFaded = false
    /// Whether the swipe has landed and stepped in front. Reset with the swipe itself.
    @State private var swipeInFront = false
    /// Stamped when the ball changes hands, which starts the catch animation.
    /// Observed, not just read — otherwise moving a slider changes nothing on screen.
    @State private var render = RenderDebug.shared
    @State private var look = PlayerLook.shared
    /// Observed, not just read — otherwise moving a slider changes nothing on screen.
    @State private var prompt = InboundTextTuning.shared
    /// Observed, not just read — otherwise moving a slider changes nothing on screen.
    @State private var deckTuning = DeckTuning.shared
    /// How this warp comes apart. Rolled when somebody steps off the floor, so the same
    /// player leaving twice does not leave the same way — see `ColumnWarp.seed`.
    @State private var warpSeed: UInt64 = .random(in: .min ... .max)

    /// `thrower`, a warp late.
    ///
    /// **The two halves take a turn each.** Going out he comes apart on the floor and only
    /// then assembles on the line; coming back he leaves the line first and only then
    /// puts himself together where he stands. Both at once is one man in two places, which
    /// is what a teleport is meant to avoid.
    @State private var arrived: Seat?

    /// True for a warp's length either side of the floor rearranging itself.
    ///
    /// **A player set into the line is a player who was somewhere else a frame ago.** The
    /// thrower warps because he leaves; everybody else was simply appearing at their spot
    /// in the line and appearing back afterwards, which is the same teleport with none of
    /// the teleporting.
    @State private var settling = false

    /// He is off the floor: gone, going, or not yet back.
    ///
    /// Read off `thrower` rather than `inbounding`, because the throw itself is part of
    /// being away — the ball leaves his hands from the line, and he cannot be putting
    /// himself back together on the floor while it is still in the air.
    private func isAway(_ seat: Seat) -> Bool {
        thrower == seat || arrived == seat || settling
    }

    /// And he is standing on the line, which is only true once he has finished arriving.
    private var atLine: Seat? { thrower == arrived ? arrived : nil }

    /// True while the ball is crossing between players.
    @State private var ballInFlight = false
    /// 0 at the passer, 1 at the receiver. Named apart from the draw's `flight`.
    @State private var passFlight: CGFloat = 0
    /// When the ball actually arrived, which is what the catch counts from. Distinct from
    /// `settledAt`, which is when it *left* — feeding that to the catch played it over the
    /// top of the throw.
    @State private var landedAt: Date?
    /// The throw-in whose ball has already been caught, so it stops being drawn while
    /// `throwing` runs on through the hold that keeps the thrower on the line.
    @State private var caughtThrow: UUID?
    /// The stamp the ball has already been flown for. `.task(id:)` re-runs whenever its
    /// subtree is rebuilt, not only when the id changes — so without this the same pass
    /// can be thrown twice, which is what "players sometimes pass the ball twice" was.
    @State private var flewAt: Date?
    @State private var rebounding = ReboundTuning.shared
    /// The pass being thrown, for one play of the throw sheet.
    @State private var thrownBy: PassThrow?
    /// How far each seat's sprite clock has been moved — see `throwClock`.
    @State private var clockShift: [Seat: TimeInterval] = [:]

    private var selectableSeats: Set<Seat> { Self.choosable(at: gate, in: state) }

    /// **Which of the crew can be named**, when a card is asking. Empty every other time,
    /// which is what leaves a tap on a referee meaning "read the crew".
    private var namedOfficials: Set<UUID> {
        if case .awaitingRetirement(_, let choices) = gate {
            return Set(choices.compactMap { if case .official(let id) = $0 { return id } else { return nil } })
        }
        return []
    }

    /// Who can be picked off the floor, for whatever the table is asking.
    ///
    /// **One answer for the floor and for the pad.** The men wearing a wedge and the men
    /// a controller's ring can walk onto have to be the same men, and they are only the
    /// same by construction — see `Row`.
    static func choosable(at gate: GameController.Gate, in state: GameState) -> Set<Seat> {
        if case .awaitingInbound(let inbounder) = gate {
            // Altercation: the man you shoved is not standing there waiting for it.
            return Set(Seat.allCases.filter { $0 != inbounder && $0 != state.inboundBarred })
        }
        // A card that names a player is picked on the floor, the same way an inbound is.
        // One gesture for every "which of them" the game asks.
        if case .awaitingTarget(_, let choices) = gate { return Set(choices) }
        // Wide-Open Three names as many as it likes, so the ones already named stay lit
        // rather than dropping out of the picture.
        if case .awaitingNaming(_, let named) = gate {
            return Set(Seat.allCases.filter { $0 != state.ball && !named.contains($0) })
        }
        return []
    }

    var body: some View {
        GeometryReader { geo in
            let court = CourtGeometry(size: geo.size, viewer: viewer)

            ZStack {
                // Streaks live in the background, behind an opaque floor, so they read
                // as the space beyond the court rather than markings on it.
                // Nobody is moving during an inbound, so nothing should be streaming
                // past them. The court is a held breath.
                CourtStreaks(paused: sceneryAsleep)
                    .opacity(courtIsRunning ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: courtIsRunning)

                room(court)

                // Between the floor and the stage. The 3D piles are a layer of their
                // own, so a shadow drawn alongside them would land on top instead of
                // under.
                PileShadow(width: geo.size.width * Perspective.pileCardShare
                                  * deckTuning.size,
                           across: geo.size.width,
                           paused: pilesStill)
                    .position(deckPoint(on: court))

                PileShadow(width: geo.size.width * Perspective.pileCardShare
                                  * deckTuning.size,
                           across: geo.size.width,
                           phase: 0.5,
                           paused: pilesStill)
                    // Nothing is standing there to cast one.
                    .opacity(state.discard.isEmpty ? 0 : 1)
                    .animation(.easeOut(duration: 0.25), value: state.discard.isEmpty)
                    .position(discardPoint(on: court))

                // One scene for the whole floor. Everything on it is placed from the same
                // court points the sprites use, so the two cannot disagree.
                if render.courtStage {
                    CourtStage(deckAt: share(deckPoint(on: court), in: geo.size),
                               discardAt: share(discardPoint(on: court), in: geo.size),
                               deckLayers: DeckStackView.layers(for: state.deck.count),
                               discardLayers: state.discard.isEmpty ? 0
                                   : DeckStackView.layers(for: state.discard.count),
                               deckRoutine: deckRoutine,
                               flight: deal.map { deal in
                                   CardFlight(id: deal.id,
                                              from: share(deckPoint(on: court), in: geo.size),
                                              to: share(court.footing(of: deal.seat), in: geo.size),
                                              // **The same number the controller waits.**
                                              // It was taking the default and flying for
                                              // longer than anybody was waiting, so the
                                              // next draw cancelled it a little over half
                                              // way — which is a card that is large and
                                              // then simply gone, having never shrunk.
                                              seconds: flightDuration)
                               },
                               seatsAt: Dictionary(uniqueKeysWithValues: Seat.allCases.map {
                                   ($0, share(court.footing(of: $0), in: geo.size))
                               }),
                               opening: opening,
                               spend: spend.map { spent in
                                   CardFlight(id: spent.id,
                                              from: share(court.footing(of: spent.seat),
                                                          in: geo.size),
                                              to: share(discardPoint(on: court), in: geo.size),
                                              seconds: Pacing.spendFlight)
                               },
                               // The piles stand still for an inbound with everyone else.
                               frozen: frozen || isStill,
                               hidden: floorIsHidden)
                }

                // Hung above the far baseline so the rim clears it rather than
                // sitting on North's head.
                FarHoop()
                    .position(hoopPoint(on: court, in: geo.size))

                // Drawn here, before the figures, which is the entire point: the players
                // stand above it without anything being duplicated or measured against a
                // frame in another coordinate space. The cards below the court are dimmed
                // by a second scrim in `GameView` — see there for why it is not one.
                //
                // **Bounded to the court.** A view far larger than the screen in this
                // stack is not free: `CourtStage` is a RealityView in here, and an
                // oversized layer asks Metal for a drawable past its maximum texture size,
                // which fails validation and takes the render thread down with it.
                // Over the scenery, under the people. The deck goes under it with the
                // floor — during an inbound it is not what is being looked at.
                //
                // Exactly the court's own size. Anything larger grows the stack, and
                // `room` is a GeometryReader inside it that builds the floor from
                // whatever height it is handed — an oversized scrim changed the shape of
                // the court.
                DimLayer(on: isStill, amount: Court.dim, full: false)
                    .zIndex(Layer.dim)

                // Painted far to near, so anything upcourt is overlapped by what
                // stands in front of it instead of by whatever draws last.
                ForEach(CourtItem.inDepthOrder(viewedFrom: viewer, referees: floorCrew),
                        id: \.self) { item in
                    place(item, on: court, in: geo.size)
                        // People come up over the dim; the piles stay under it. Equal
                        // numbers keep their declaration order, so the far-to-near sort
                        // still decides who overlaps whom.
                        .zIndex(isStill && item.isPerson ? Layer.people : Layer.stage)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7),
                           value: floorCrew)

                // Over the player he is taking from, and gone again in under a second.
                if let swipe {
                    let footing = court.footing(of: swipe.seat)
                    DefenderSwipe(seat: swipe.seat,
                                  mirrored: swipe.seat.slot(viewedFrom: viewer) == .west,
                                  onFront: { swipeInFront = true })
                        .id(swipe.id)
                        .task(id: swipe.id) { swipeInFront = false }
                        .scaleEffect(court.scale(of: swipe.seat), anchor: .bottom)
                        .position(x: footing.x,
                                  y: footing.y - Theme.Figure.height / 2
                                     + Perspective.footDrop(
                                        at: court.scale(of: swipe.seat)))
                        .zIndex(swipeInFront ? 250 : Layer.behind)
                }

                // A card asking for a player uses the floor's own question, without the
                // sideline staging an inbound needs — nobody is throwing anything.
                if isChoosing {
                    inboundPrompt
                        .position(x: geo.size.width / 2, y: geo.size.height * Prompt.y)
                        .zIndex(Layer.prompt)
                }

                // **The official on the sideline**, in the spot a player used to throw
                // it in from: holding it, then throwing it. The other two stay at their
                // posts, where they already are.
                if let refereeThrow,
                   let whistle = state.armedWhistles.first(where: { $0.id == refereeThrow.official }) {
                    let depth = Perspective.throwInDepth
                    RefereeFigure(duty: refereeThrow.thrown ? .inbounding : .holdingBall,
                                  tone: look.refereeTone(for: whistle.id),
                                  frozen: true)
                        .scaleEffect(court.scale(at: depth), anchor: .bottom)
                        .position(x: court.centreX + prompt.throwerX * court.scale(at: depth),
                                  y: court.y(at: depth) - nodeHeight / 2
                                     + Perspective.footDrop(at: court.scale(at: depth)))
                        .zIndex(Layer.thrower)
                        .transition(.columnWarp())
                }

                if let thrower, atLine != nil {
                    // Dead centre, facing the line of three. He is not on the floor,
                    // so there is no side for him to be on.
                    let depth = Perspective.throwInDepth
                    // The ball leaves his hands the moment he throws, and he holds the
                    // pose he threw in until it lands.
                    InbounderFigure(seat: thrower, holdsBall: throwing == nil,
                                    frozen: throwing != nil)
                        .scaleEffect(court.scale(at: depth), anchor: .bottom)
                        .position(x: court.centreX + prompt.throwerX * court.scale(at: depth),
                                  y: court.y(at: depth) - nodeHeight / 2
                                     + Perspective.footDrop(at: court.scale(at: depth)))
                        // Behind everybody, wedges included — but in front of the dim.
                        .zIndex(Layer.thrower)
                        // He arrives on the line the way he left the floor.
                        .transition(.columnWarp())

                    // The question is answered once it is in the air.
                    if throwing == nil {
                        inboundPrompt
                            .position(x: geo.size.width / 2,
                                      y: geo.size.height * Prompt.y)
                            .zIndex(Layer.prompt)
                    }
                }

                // **The referee's throw**, the same ball crossing from his hands to the man
                // he threw it to. His throwing pose is drawn empty-handed.
                if let refereeThrow, refereeThrow.thrown {
                    InboundThrow(from: throwOrigin(on: court),
                                 to: ballPoint(of: refereeThrow.to, on: court, catching: false),
                                 seconds: Pacing.inboundThrow,
                                 scale: court.scale(of: refereeThrow.to))
                        .id(refereeThrow.id)
                        .zIndex(Layer.prompt)
                }

                // The throw itself, crossing from the sideline to whoever was chosen.
                if let throwing, caughtThrow != throwing.id {
                    InboundThrow(from: throwOrigin(on: court),
                                 to: ballPoint(of: throwing.to, on: court, catching: false),
                                 seconds: Pacing.inboundThrow,
                                 scale: court.scale(of: throwing.to, inbounding: throwing.from))
                        // Its own view each time. Without this the second throw-in reuses
                        // the first one's, whose `travelled` is already at one — so the
                        // ball starts where it should finish.
                        .id(throwing.id)
                        .zIndex(Layer.prompt)
                }

                if let flight {
                    let deck = CGPoint(
                        x: court.centreX + court.halfWidth(at: Perspective.deckDepth) * Perspective.deckLateral,
                        y: court.y(at: Perspective.deckDepth))
                    let seatFooting = court.footing(of: flight.seat)
                    DrawFlightView(from: deck,
                                   to: CGPoint(x: seatFooting.x, y: seatFooting.y - 24),
                                   startScale: court.scale(at: Perspective.deckDepth),
                                   endScale: court.scale(of: flight.seat),
                                   duration: flightDuration)
                        .id(flight.id)
                        .zIndex(300)
                }

                // Out of the hoop and into his hands. It leaves small, because it is
                // coming from the horizon — a ball that starts full size up there is a
                // ball the size of the rim.
                if let rebound {
                    ReboundBallView(
                        from: rebound.offTheGlass
                            ? ownToss(of: rebound.seat, on: court)
                            : boardLeaves(on: court, in: geo.size),
                        to: reboundPoint(of: rebound.seat, on: court),
                        end: court.scale(of: rebound.seat),
                        descent: rebounding.lift * Theme.Figure.playerScale
                            * court.scale(of: rebound.seat))
                        // One board, one ball. See `ReboundBallView`.
                        .id(rebound.id)
                        .transition(.identity)
                        .zIndex(280)
                }

                // The ball is only its own view while crossing — the dribbling sprite
                // draws one the rest of the time. It travels from the passer's hands to
                // the receiver's rather than appearing already arrived.
                if let holder, ballInFlight, let path = flightPath(on: court) {
                    let (from, to) = path
                    let scale = court.scale(of: holder)
                    PixelBallView()
                        .scaleEffect(scale)
                        .position(x: from.x + (to.x - from.x) * passFlight,
                                  y: from.y + (to.y - from.y) * passFlight)
                        // Never fades in or out. The sprite is already holding a ball, so
                        // anything but a hard cut reads as two balls dissolving through
                        // each other.
                        .transition(.identity)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.72), value: state.ball)
            // **Boxed before the camera and the tasks.** This body was 208 generics deep
            // and building it is a walk down all of them — which is a crash on a device,
            // arriving as EXC_BAD_ACCESS in whatever leaf the walk was in. See
            // `GameView.floorDepths`, which reads this number on every DEBUG launch.
            .erased()
            // **The camera.** The floor and everyone on it; the HUD over the court is hung
            // on outside this view and stays put. Clipped only while it is zoomed, so the
            // floor's usual overhang is left alone — **and not for a call**: the HUD has
            // faded back for it, and clipped at the court's top edge, the zoom sliced every
            // man it brought up past that line in half across the middle of the screen.
            .scaleEffect(camera?.zoom ?? 1)
            .offset(lensOffset(on: court, in: geo.size))
            .clipShape(Rectangle().inset(by: camera == nil || callingRef != nil
                                         ? -Lens.unclipped : 0))
            .animation(.easeInOut(duration: camera?.seconds ?? CourtCamera.release),
                       value: camera)
            // The throw-in has no `settledAt` of its own, so its landing is timed off the
            // same constant the ball is flown with.
            .task(id: throwing?.id) {
                guard let throwing else { return }
                landedAt = nil
                caughtThrow = nil
                try? await Task.sleep(for: .seconds(Pacing.inboundThrow))
                guard !Task.isCancelled else { return }
                // One instant, two things: the ball leaves the air and the hands close on
                // it. Apart, the thrown ball hung at the destination for the rest of the
                // hold while the receiver caught a second one.
                caughtThrow = throwing.id
                landedAt = Date()
            }
            .task(id: settledAt) {
                guard let settledAt, passer != nil, flewAt != settledAt else { return }
                flewAt = settledAt
                // Whatever happens after this, the ball is not left in the air. A stranded
                // `ballInFlight` makes its holder run forever instead of dribbling, since
                // a player waiting on a ball is drawn as running to meet it.
                defer {
                    var vanish = Transaction(); vanish.disablesAnimations = true
                    withTransaction(vanish) { ballInFlight = false }
                }
                landedAt = nil
                // **The wind-up first, and then the ball in one breath.** The throw sheet's
                // first cell is him still holding it, so the ball waits that long — but the
                // frame it appears on has to be the frame it starts travelling on. With the
                // wait between the two, it appeared at his hands and sat there.
                try? await Task.sleep(for: .seconds(PassTiming.windup))
                if Task.isCancelled { return }
                // On and off instantly — the sprite already holds a ball, so a fade
                // would read as two balls dissolving into each other.
                var appear = Transaction(); appear.disablesAnimations = true
                withTransaction(appear) { passFlight = 0; ballInFlight = true }

                // Every pass takes the same time, whoever it is between: the ball
                // simply travels faster across the diamond than to a neighbour. The
                // arrival is what the catch is timed against, so it stays put.
                withAnimation(.easeInOut(duration: Theme.Pass.flightSeconds)) { passFlight = 1 }
                try? await Task.sleep(for: .seconds(Theme.Pass.flightSeconds))

                landedAt = Date()
            }
        }
        // A body does not come apart the same way twice.
        .onChange(of: inbounding) { warpSeed = .random(in: .min ... .max) }
        // One play of the throw sheet. Checked against the clock, because a task re-runs
        // when its subtree is rebuilt and a throw already over is not thrown again.
        .task(id: passThrow?.id) {
            guard let passThrow,
                  Date().timeIntervalSince(passThrow.at) < PassTiming.throwSeconds else { return }
            clockShift[passThrow.from] = throwClock(for: passThrow)
            thrownBy = passThrow
            try? await Task.sleep(for: .seconds(PassTiming.throwSeconds))
            if thrownBy?.id == passThrow.id { thrownBy = nil }
        }
        // The scenery fades over 0.4s when the court stops; once it is gone it can stop.
        .task(id: courtIsRunning) {
            sceneryFaded = false
            guard !courtIsRunning else { return }
            try? await Task.sleep(for: .seconds(0.45))
            guard !Task.isCancelled else { return }
            sceneryFaded = true
        }
        // The whole floor takes its place in the line, and takes it back.
        .task(id: isStill) {
            settling = true
            try? await Task.sleep(for: .seconds(Pacing.warp))
            settling = false
        }
        // And it is in one place at a time: the far half waits a warp for the near one.
        .task(id: thrower) {
            let going = thrower
            try? await Task.sleep(for: .seconds(Pacing.warp))
            arrived = going
        }
    }

    // MARK: - Camera

    private enum Lens {
        /// How far out the clip sits while the camera is not zoomed: far enough to clip
        /// nothing.
        static let unclipped: CGFloat = 4000
    }

    /// Where the camera puts its subjects: their middle in the middle of the court, as
    /// far as the zoomed floor still covers every edge.
    private func lensOffset(on court: CourtGeometry, in size: CGSize) -> CGSize {
        guard let camera, camera.zoom > 1, !camera.subjects.isEmpty else { return .zero }
        let points = camera.subjects.map { focus(of: $0, on: court, in: size) }
        let x = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let y = points.map(\.y).reduce(0, +) / CGFloat(points.count)
        let slackX = (camera.zoom - 1) * size.width / 2
        let slackY = (camera.zoom - 1) * size.height / 2
        return CGSize(width: min(max(-(x - size.width / 2) * camera.zoom, -slackX), slackX),
                      height: min(max(-(y - size.height / 2) * camera.zoom, -slackY), slackY))
    }

    /// Where a subject is standing right now, in the court's own space.
    private func focus(of subject: CourtCamera.Subject, on court: CourtGeometry,
                       in size: CGSize) -> CGPoint {
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        switch subject {
        case .seat(let seat):
            let footing = court.footing(of: seat, inbounding: thrower)
            let scale = court.scale(of: seat, inbounding: thrower)
            return CGPoint(x: footing.x, y: footing.y - Theme.Figure.height * scale / 2)
        case .ball:
            // Followed across a pass: the flight's own animation carries the camera with it.
            if ballInFlight, let path = flightPath(on: court) {
                return CGPoint(x: path.0.x + (path.1.x - path.0.x) * passFlight,
                               y: path.0.y + (path.1.y - path.0.y) * passFlight)
            }
            guard let holder else { return middle }
            return ballPoint(of: holder, on: court, catching: false)
        case .referee(let place):
            guard refereeCrew.indices.contains(place) else { return middle }
            let post = refereeCrew[place].post
            let scale = court.scale(of: post)
            return CGPoint(x: court.footing(of: post).x,
                           y: court.y(at: post.depth) - Theme.Figure.height * scale / 2)
        }
    }

    /// **The throw keeps his feet.** A throw sheet is the run with its first eight cells
    /// redrawn, so it has to begin where the run cycle does. His clock is moved to put the
    /// cycle's first cell on the instant of the throw; the throw then counts from there, and
    /// the run carries on from its own first cell when the throw is done.
    private func throwClock(for pass: PassThrow) -> TimeInterval {
        let cycle = Double(Sprite.run.frames) / Theme.Figure.playerFPS
        let clock = pass.at.timeIntervalSinceReferenceDate + PlayerFigure.clockPhase(of: pass.from)
        return -clock.truncatingRemainder(dividingBy: cycle)
    }

    /// The sheet this seat throws on, while it is throwing.
    private func throwing(_ seat: Seat) -> (sheet: Sprite, at: Date)? {
        guard let thrownBy, thrownBy.from == seat else { return nil }
        return (Self.throwSheet(for: thrownBy, viewedFrom: viewer), thrownBy.at)
    }

    /// **Which way a pass goes on screen.** Far to near is over his shoulder, near to far is
    /// straight ahead, and anything else is to his left or right as the floor is drawn. A
    /// blind pass goes out behind him whoever it is for.
    static func throwSheet(for pass: PassThrow, viewedFrom viewer: Seat) -> Sprite {
        if pass.blind { return .passBehind }
        let from = pass.from.slot(viewedFrom: viewer)
        let to = pass.to.slot(viewedFrom: viewer)
        if from == .north, to == .south { return .passBehind }
        if from == .south, to == .north { return .passForward }
        func across(_ slot: Seat) -> Int {
            switch slot {
            case .west: return -1
            case .east: return 1
            case .north, .south: return 0
            }
        }
        return across(to) > across(from) ? .passRight : .passLeft
    }

    // MARK: - Floor

    /// Just the floor: a gradient that fades to nothing at the horizon, with a band of
    /// light travelling down it. No outline — the converging edges carry the perspective.
    private func room(_ court: CourtGeometry) -> AnyView {
        AnyView(Group {
            GeometryReader { geo in
                let band = geo.size.height * Perspective.sweepHeight
                ZStack {
                    Rectangle().fill(
                        LinearGradient(
                            stops: [
                                // The floor's own colour at zero, not `.clear`: a ramp out of
                                // transparent black takes the brown towards grey on the way.
                                .init(color: Theme.courtFloor.opacity(0),
                                      location: Perspective.horizon),
                                .init(color: Theme.courtFloor, location: Perspective.floorFadeEnd),
                            ],
                            startPoint: .top, endPoint: .bottom))

                    // On the boards, under the light that travels over them. Inside the
                    // mask, so the floor's own shape is what clips them and no streak can
                    // run off the edge onto the dark.
                    FloorStreaks(paused: sceneryAsleep)
                        .opacity(courtIsRunning ? 1 : 0)
                        .animation(.easeOut(duration: 0.4), value: courtIsRunning)

                    if !sceneryAsleep {
                        FloorSweep(band: band, height: geo.size.height)
                            // **The light only.** This sat on the whole stack, so an inbound took
                            // the floor away with it rather than stopping the thing moving over
                            // it — which is why everything standing on the floor looked far
                            // darker than the scrim over it could account for.
                            .opacity(courtIsRunning ? 1 : 0)
                            .animation(.easeOut(duration: 0.4), value: courtIsRunning)
                    }
                }
                .mask(CourtFloorShape())
            }
        })
    }

    /// Where the deck and the discard stand, as court points.
    private func deckPoint(on court: CourtGeometry) -> CGPoint {
        pilePoint(lateral: Perspective.deckLateral, on: court)
    }

    private func discardPoint(on court: CourtGeometry) -> CGPoint {
        pilePoint(lateral: Perspective.discardLateral, on: court)
    }

    /// Where a pile stands, nudged by the bench. Both renderers come through here, which
    /// is the only reason the flat pile and the staged one land on the same spot.
    private func pilePoint(lateral: CGFloat, on court: CourtGeometry) -> CGPoint {
        // **Mirrored**, which the bench always said it was and this never did: the deck
        // took the nudge one way and the discard took it the same way, so the pair slid
        // sideways instead of spreading. Which put the discard past the edge of the
        // stage's camera — where its flat shadow still drew and its 3D pile did not.
        CGPoint(x: court.centreX
                + court.halfWidth(at: Perspective.deckDepth) * lateral
                + court.size.width * deckTuning.x * (lateral < 0 ? 1 : -1),
                y: court.y(at: Perspective.deckDepth)
                + court.size.height * deckTuning.y)
    }

    /// A court point as a share of the view, which is the only language the stage speaks.
    private func share(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x / max(size.width, 1), y: point.y / max(size.height, 1))
    }

    /// Where the ball sits in a player's hands.
    ///
    /// Measured from the player's own footing in shares of a figure's height, then taken
    /// through that seat's court scale — so one pair of numbers puts the ball in the same
    /// spot on all four, however near or far they stand.
    private func ballPoint(of seat: Seat, on court: CourtGeometry,
                           catching: Bool, throwing: Bool = false) -> CGPoint {
        // Where he is *now*, which during a throw-in is not where he usually stands —
        // the viewer steps into the thrower's vacated place, and the ball has to land in
        // the hands that are actually there.
        let footing = court.footing(of: seat, inbounding: thrower)
        let scale = court.scale(of: seat, inbounding: thrower)
        let side = Theme.Figure.height * scale
        // The offset is measured on the unflipped sprite. A player who turns to meet the
        // pass catches with the other hand, so the offset turns with them. Only the
        // receiver flips — the thrower is still dribbling, and dribbling never mirrors.
        let flip: CGFloat = catching
            && PlayerFigure.catchIsMirrored(seat: seat, facing: passer) ? -1 : 1
        // **A throw leaves the throwing hand.** The four throw sheets are drawn
        // right-handed for every seat, so the ball starts on the near side of him rather
        // than the far side the dribble holds it on.
        let hand = throwing ? -Theme.Pass.handX : Theme.Pass.handX * flip
        return CGPoint(x: footing.x + side * hand,
                       y: footing.y - side * Theme.Pass.handY)
    }

    /// The rim on the horizon, which is where a board comes from.
    ///
    /// **Nothing tunable in it.** The spawn dials used to sit here, and since the hoop
    /// itself is drawn at this point they moved the rim and the ball together — so the
    /// two dials for where the ball leaves the rim could not move it relative to the rim.
    /// See `boardLeaves`.
    private func hoopPoint(on court: CourtGeometry, in size: CGSize) -> CGPoint {
        CGPoint(x: court.centreX,
                y: court.horizonY - 18 - size.height * 0.1)
    }

    /// Where the ball comes out of the rim: the rim, and the offset off it.
    private func boardLeaves(on court: CourtGeometry, in size: CGSize) -> CGPoint {
        let rim = hoopPoint(on: court, in: size)
        return CGPoint(x: rim.x + rebounding.spawnX, y: rim.y + rebounding.spawnY)
    }

    /// Where the ball meets him at the top of the leap: both hands over his head, plus
    /// the two pixels the jump adds beyond what the sheet can draw.
    /// His own hands, standing. Where a ball he throws up himself leaves from — the same
    /// place `reboundPoint` ends, without the leap under it.
    private func ownToss(of seat: Seat, on court: CourtGeometry) -> CGPoint {
        let footing = court.footing(of: seat, inbounding: thrower)
        let row = court.scale(of: seat, inbounding: thrower)
        let side = Theme.Figure.height * row
        // The same hands, on the floor: `reboundPoint` without the leap under it.
        return CGPoint(x: footing.x + side * rebounding.handX,
                       y: footing.y - side * rebounding.handY)
    }

    private func reboundPoint(of seat: Seat, on court: CourtGeometry) -> CGPoint {
        let footing = court.footing(of: seat, inbounding: thrower)
        let row = court.scale(of: seat, inbounding: thrower)
        let side = Theme.Figure.height * row
        return CGPoint(x: footing.x + side * rebounding.handX,
                       // Where his hands actually are at the top: the sheet's own reach,
                       // plus the lift the jump adds beyond what it can draw. Measured
                       // the way the figure spends it — art pixels through the sprite's
                       // scale and then the row's — or the two drift apart with distance.
                       y: footing.y - side * rebounding.handY
                          - rebounding.lift * Theme.Figure.playerScale * row)
    }

    /// Both ends of the throw, so the flight is drawn and timed off the same two points.
    private func flightPath(on court: CourtGeometry) -> (CGPoint, CGPoint)? {
        guard let holder else { return nil }
        let to = ballPoint(of: holder, on: court, catching: true)
        let from = passer.map {
            ballPoint(of: $0, on: court, catching: false, throwing: true)
        } ?? to
        return (from, to)
    }

    /// A referee on the floor, and the Whistle that called him out.
    ///
    /// **His identity is the Whistle, not the post he stands on.** One is spent and
    /// another arms and a different man comes out — but the crew is laid out from the
    /// first of them, so the new man can land on the post the old one was standing on.
    /// Keyed on the post alone the two collapsed into a single figure that never left
    /// and never arrived, which is why the warp-in only sometimes played.
    private struct RefereeCall: Hashable {
        let post: RefereePost
        let whistle: ArmedWhistle
        /// Stood just outside whoever else is on his post — see `floorCrew`.
        var outside = false
    }

    /// **The crew on the floor while one of them throws it in.** The throw-in spot is
    /// up the left wing, so a man on that post stood right beside the thrower: he crosses
    /// to the thrower's right — the right wing if nobody is on it, or just outside the
    /// man who is.
    private var floorCrew: [RefereeCall] {
        let crew = refereeCrew.filter { $0.whistle.id != refereeThrow?.official }
        guard refereeThrow != nil,
              let beside = crew.firstIndex(where: { $0.post == .leftWing }) else { return crew }
        var moved = crew
        moved[beside] = RefereeCall(post: .rightWing, whistle: crew[beside].whistle,
                                    outside: crew.contains { $0.post == .rightWing })
        return moved
    }

    private var refereeCrew: [RefereeCall] {
        guard let first = state.armedWhistles.first else { return [] }
        // Only the first is rolled — read off the round's first official's own id rather
        // than a random number, so a redraw cannot move the crew mid-round, and **kept
        // when he goes**: his replacement takes his post. Everyone after him is placed
        // relative to him.
        let anchor = state.crewAnchor ?? first.id
        let coin = withUnsafeBytes(of: anchor.uuid) { Array($0.prefix(2)) }
        let start: RefereePost = coin[0].isMultiple(of: 2)
            ? (coin[1].isMultiple(of: 2) ? .rightWing : .leftWing)
            : (coin[1].isMultiple(of: 2) ? .southEast : .southWest)
        return zip(RefereePost.crew(from: start), state.armedWhistles)
            .map { RefereeCall(post: $0.0, whistle: $0.1) }
    }

    /// What sits above what while an inbound is being asked for.
    ///
    /// Spelled out because a ZStack gives every child that does not ask for a number a
    /// zero, and a negative one therefore goes *behind the floor* rather than behind the
    /// people — which is how the scrim ended up showing only around the edges of the
    /// court and the thrower ended up under it.
    private enum Layer {
        /// The floor, the streaks, the piles. Everything that is scenery keeps the zero
        /// it already had.
        /// Everything standing on the floor. Above zero on purpose: the swipe needs a
        /// rung between the boards and the men, and there was none while they shared it.
        static let stage: Double = 0.5
        /// The swipe on its way in, under the man he is taking from.
        static let behind: Double = 0.25
        static let dim: Double = 1
        static let thrower: Double = 2
        static let people: Double = 3
        static let prompt: Double = 4
    }


    enum Court {
        /// How big the ball is as it leaves the rim. It is coming from the horizon, and a
        /// ball that starts at its own size up there is a ball the size of the hoop.
        static let ballFromHoop: CGFloat = 0.01

        /// How dark everything but the players goes. Shared with `GameView`, which dims
        /// the cards to the same depth.
        static let dim: Double = 0.66
        /// What a card wears while an inbound is being chosen. The same overlay that reds
        /// a card being discarded, in the palette's own dark.
        static let cardWash: Color = CardPalette.black.opacity(0.66)
        /// How long a figure takes to go, or arrive, in columns. A blink, not a wipe —
        /// and the loop waits out two of them, so see `Pacing.warp`, which owns it.
        static let warp: Double = Pacing.warp
        /// How far the hand drops out of the way while an inbound is being chosen. Moved
        /// rather than dimmed: two translucent layers over one another multiply, and the
        /// seam where the hand's own sheet met the court's was a black band across the
        /// screen.
        static let handDrop: CGFloat = 60
    }

    private enum Prompt {
        /// Where the two lines sit, as a share of the court's own height.
        static let y: CGFloat = 0.14
    }

    /// What the dimmed court is asking for.
    ///
    /// `Inbound` is picked out because it is the only word in the sentence that is a rule
    /// rather than English.
    /// What the two-line prompt says, which depends on what is being asked for.
    /// **A Clamp is Assigned, not played to.** "to Contest to!" is what the pass wording
    /// made of it; a defender is a defensive assignment, so the keyword is Assign and the
    /// card is what gets assigned.
    private var promptRuns: (top: String, verb: String, tail: String) {
        if case .awaitingTarget(let card, _) = gate {
            if card.clamp != nil { return ("Select a Player", "Assign", " \(card.name) to!") }
            return ("Select a Player", card.name, " to!")
        }
        if case .awaitingNaming(let card, _) = gate { return ("Name a Player", card.name, " to!") }
        return ("Select a Player", "Inbound", " to!")
    }

    private var inboundPrompt: AnyView {
        AnyView(Group {
            // Each line placed on its own, because the two are different sizes and the gap
            // that looks right between them is not a spacing — it is where each one sits.
            ZStack {
                ActionText(promptRuns.top, size: 46)
                    .offset(x: prompt.topX, y: prompt.topY)
                ActionText(runs: [.init("to "),
                                  .init(promptRuns.verb, ink: CardPalette.gold,
                                        drop: CardPalette.orange),
                                  .init(promptRuns.tail)],
                           size: 26)
                    .offset(x: prompt.bottomX, y: prompt.bottomY)
            }
            .fixedSize()
            .allowsHitTesting(false)
        })
    }

    /// Set and waiting for the throw-in.
    ///
    /// **Not the man who has already caught it.** The thrower is held on the line for a
    /// beat after the ball lands — see `Pacing.inboundHold` — and for the rest of that
    /// hold the receiver was dropping back into the pose that asks for a throw-in, with
    /// the ball in his hands.
    private func waitingForThrow(_ seat: Seat) -> Bool {
        // **A call is not an inbound.** It stills the floor too, and the men stood in the
        // receiving pose through it; they stand as they do for a rebound instead.
        guard isStill, callingRef == nil else { return false }
        if let throwing, throwing.to == seat, caughtThrow == throwing.id { return false }
        return true
    }

    /// Which way to turn to look at the thrower. He stands at one of two posts, so this
    /// is one answer for the whole floor.
    private func facesThrower(_ seat: Seat) -> Bool {
        // He stands in the middle, so everybody turns inward: the left-hand flank faces
        // right and the right-hand flank faces left.
        seat.slot(viewedFrom: viewer) == .east
    }

    /// The whole court is stationary — an inbound has been called and everyone is set.
    ///
    /// Told, not worked out. The gate only says `.awaitingInbound` when the throw-in is
    /// yours, so an opponent's used to go from a running court straight to a ball in the
    /// air; the phase says it a whole presentation early, so the floor set up behind the
    /// scenes that were still playing. The controller says when.
    /// A referee's throw-in holds the floor exactly as a player's does.
    private var isStill: Bool {
        throwing != nil || inbounding != nil || callingRef != nil || refereeThrow != nil
    }

    /// Whether the play is actually running, which is what the moving scenery asks.
    ///
    /// **The rule is the sprites'**: whenever the men are held in a still pose, nothing
    /// behind or under them should be streaming past — a court racing by while four
    /// players stand and watch a rebound reads as the camera moving rather than them
    /// stopping. Not folded into `isStill`, which also dims the floor and re-orders the
    /// stage; a rebound wants the scenery held and nothing else changed.
    private var courtIsRunning: Bool { !isStill && rebound == nil }

    /// Whether the streaks and the travelling light can stop: the floor is under an opaque
    /// scene, or the court stopped running and they have finished fading out.
    private var sceneryAsleep: Bool { floorIsHidden || (!courtIsRunning && sceneryFaded) }

    /// The piles standing still — the stage's own rule — or nobody able to see them.
    private var pilesStill: Bool { frozen || isStill || floorIsHidden }

    /// What the crew is doing. **The call wins over the shot**: a Whistle during one is
    /// the whole reason anybody is looking at him. Everything that holds the players in a
    /// pose stands him still, which is the same rule the scenery follows.
    private func refereeDuty(_ call: RefereeCall) -> RefereeFigure.Duty {
        if call.whistle.id == callingRef { return .calling }
        // **The rest of the crew turn to look at him.** Which way depends on where he is
        // standing against them, so a man to their left is looked at leftward.
        if let caller = crewPost(callingRef) {
            return .turned(caller.lateral < call.post.lateral ? 1 : 2)
        }
        // **Nobody watches an ordinary basket.** Three of them are out there every round
        // now, and three men turning to follow every shot read as a crowd rather than as
        // officials. A free throw still gets watched — see `FreeThrowView`.
        return courtIsRunning && !frozen ? .working : .waiting
    }

    /// Where on the floor the official making the call is standing.
    private func crewPost(_ id: UUID?) -> RefereePost? {
        guard let id else { return nil }
        return refereeCrew.first { $0.whistle.id == id }?.post
    }

    /// Whether this seat is watching somebody else go up for the board.
    ///
    /// The rebound is over when the leap is — `rebound` is put down at the end of it, on
    /// the same clock the leap runs on — so the three of them stand still for exactly as
    /// long as he is in the air, and are running again on the frame he starts dribbling.
    private func watching(_ seat: Seat) -> Bool {
        guard let rebound else { return false }
        return rebound.seat != seat
    }

    /// Whether the floor is being asked a question at all.
    private var isChoosing: Bool {
        if case .awaitingTarget = gate { return true }
        if case .awaitingNaming = gate { return true }
        return false
    }

    /// Whoever is on the sideline: the one being asked, or the one who has just thrown.
    private var thrower: Seat? { throwing?.from ?? inbounding }

    /// Where the throw leaves from. The same spot the thrower is drawn standing on.
    private func throwOrigin(on court: CourtGeometry) -> CGPoint {
        let depth = Perspective.throwInDepth
        return CGPoint(x: court.centreX + prompt.throwerX * court.scale(at: depth),
                       y: court.y(at: depth) - Theme.Figure.height * 0.4)
    }

    /// True while this seat is the one being asked to throw it back in.
    /// The same question `thrower` answers, so a man on the sideline is never also
    /// standing in his own spot. Asking the gate meant he only vanished from the floor
    /// for his own throw-ins — every other one drew him twice.
    private func isInbounding(_ seat: Seat) -> Bool { thrower == seat }

    /// The wedge means "you can pick this one". During an inbound the inbounder is the
    /// single seat you cannot pass to, so they wear nothing at all — marking them would
    /// point at the one illegal target on the floor.
    /// The button glyph over a man's head, while he is one of the answers.
    private enum Face {
        static let glyph: CGFloat = 26
        /// Above the wedge rather than through it — see `PlayerFigure.Wedge`.
        static let lift: CGFloat = -62
    }

    private func marker(for seat: Seat, selectable: Bool) -> Color? {
        if selectable { return seat == ringed ? CardPalette.gold : Theme.live }
        if case .inbound = state.phase { return nil }
        return state.phase.actingSeat == seat ? .white : nil
    }

    private func defenders(on seat: Seat) -> Int { state.defenders(on: seat) }

    /// Changes whenever any seat's defender count does, which is what drives the
    /// shrink-away and pop-in rather than a slide.
    private var clampLayout: [Int] { Seat.allCases.map(defenders(on:)) }

    // MARK: - Depth ordering

    /// Everything that stands on the floor, so one sort covers players and the deck.
    private enum CourtItem: Hashable {
        case player(Seat)
        case deck
        case referee(RefereeCall)

        /// A player or a referee, rather than the furniture.
        var isPerson: Bool { if case .deck = self { return false }; return true }

        func depth(viewedFrom viewer: Seat) -> CGFloat {
            switch self {
            case .player(let seat): return Perspective.depth(of: seat.slot(viewedFrom: viewer))
            case .deck:             return Perspective.deckDepth
            // The wing referees stand behind everybody, whatever their depth says.
            case .referee(let call): return call.post.isSouth ? call.post.depth : 0
            }
        }

        static func inDepthOrder(viewedFrom viewer: Seat,
                                 referees: [RefereeCall]) -> [CourtItem] {
            (Seat.allCases.map(CourtItem.player) + [.deck]
                + referees.map(CourtItem.referee))
                .sorted { $0.depth(viewedFrom: viewer) < $1.depth(viewedFrom: viewer) }
        }
    }

    @ViewBuilder
    private func place(_ item: CourtItem, on court: CourtGeometry,
                       in geo: CGSize) -> some View {
        switch item {
        case .referee(let call):
            let post = call.post
            // Framed and dropped exactly as a player is, so his feet land on the same
            // floor line theirs would at that depth. Top-aligned because he has no name
            // plate under him taking up the bottom of the box.
            let called = call.whistle
            // **His name is drawn at its own size wherever he stands.** The node is scaled
            // by his depth, so the label divides that back out and comes out at exactly
            // `FloorName.size` points — the same on every post and every phone.
            let nameScale = 1 / court.scale(of: post)
            // The sheet faces the right-hand touchline and the left-hand posts turn him
            // round. **A turned pose faces the caller instead**, and the sheet already
            // says which way, so it is never mirrored on top of that.
            let duty = refereeDuty(call)
            let turned = { if case .turned = duty { return true }; return false }()
            RefereeFigure(duty: duty,
                          runSheet: post.runSheet,
                          lookSheet: post.lookSheet,
                          mirrorsLook: post.mirrorsLook,
                          // **The call faces the court.** It is drawn facing right, so a
                          // man calling from the right-hand side is turned round to it.
                          // The turned poses already say which way they look.
                          mirrored: duty == .calling && !post.isLeft,
                          phase: post.phase,
                          tone: look.refereeTone(for: called.id),
                          frozen: frozen)
                // **What he is watching for, only while he can be picked.** At rest the
                // crew goes unlabelled — the HUD has their cards — and a card that names
                // an official is the one time the floor has to say which is which.
                .overlay(alignment: .top) {
                    if namedOfficials.contains(called.id) || called.id == ringedOfficial {
                        FloorName(text: called.card.name,
                                  ink: called.id == ringedOfficial ? CardPalette.gold : Theme.live)
                            .scaleEffect(nameScale, anchor: .bottom)
                            .offset(y: -FloorName.size * nameScale)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .global) { onTapReferee(called.id, $0) }
                .scaleEffect(court.scale(of: post), anchor: .bottom)
                .frame(width: Theme.Figure.height, height: nodeHeight, alignment: .top)
                .position(x: court.footing(of: post).x
                             + (call.outside ? Self.refereeAside * court.scale(of: post) : 0),
                          y: court.y(at: post.depth) - nodeHeight / 2
                             + Perspective.footDrop(at: court.scale(of: post)))
                // Referees do not walk on. They are there or they are not.
                .transition(.columnWarp())
        case .deck:
            let depth = Perspective.deckDepth
            let width = Self.pileWidth * deckTuning.size
            DeckStackView(remaining: state.deck.count, width: width, routine: deckRoutine,
                          showsPile: !render.courtStage)
                .scaleEffect(court.scale(at: depth), anchor: .bottom)
                .position(deckPoint(on: court))

            DiscardPileView(count: state.discard.count, width: width,
                            showsPile: !render.courtStage)
                .scaleEffect(court.scale(at: depth), anchor: .bottom)
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpenDiscard)
                .position(discardPoint(on: court))
        case .player(let seat):
            let footing = court.footing(of: seat, inbounding: thrower)
            let scale = court.scale(of: seat, inbounding: thrower)
            node(seat, on: court)
                .scaleEffect(scale, anchor: .bottom)
                .frame(width: Theme.Figure.height, height: nodeHeight, alignment: .bottom)
                .position(x: footing.x,
                          y: footing.y - nodeHeight / 2
                             + Perspective.footDrop(at: scale))

            // Being clamped is drawn on the player rather than beside them. Two little
            // red bodies on the floor read as two more players; the coils read as
            // something being done to this one. The defender himself shows up when they
            // actually shoot — that is when he matters.
            if bound.contains(seat), defenders(on: seat) > 0 {
                BindLines(height: Theme.Figure.height, paused: floorIsHidden)
                    .scaleEffect(scale, anchor: .bottom)
                    .position(x: footing.x,
                              y: footing.y - Theme.Figure.height / 2
                                 + Perspective.footDrop(at: scale))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .id("bind-\(seat.rawValue)")
                    .animation(.spring(response: 0.34, dampingFraction: 0.68),
                               value: clampLayout)
            }
        }
    }

    // MARK: - Players

    private func node(_ seat: Seat, on court: CourtGeometry) -> AnyView {
        AnyView(Group {
            let selectable = selectableSeats.contains(seat)
            return VStack(spacing: 3) {
                PlayerFigure(
                    seat: seat,
                    isHolding: holder == seat,
                    isActing: state.phase.actingSeat == seat,
                    // The seat being asked to choose is never dimmed, even though it is
                    // not a legal target for itself.
                    isDimmed: !selectableSeats.isEmpty && !selectable
                        && state.phase.actingSeat != seat,
                    marker: marker(for: seat, selectable: selectable),
                    clampCount: showingClamps ? state[seat].clamps.count : nil,
                    badgeLift: NamePlate.badgeLift(
                        atScale: court.scale(of: seat, inbounding: thrower)),
                    handCount: state[seat].bag.count { !undelivered.contains($0.id) },
                    // Set and waiting for it, like everybody else during an inbound — and
                    // turned to watch whoever is throwing it, rather than facing whichever
                    // way the run of play had left them. One of four ways of standing, so a
                    // line of four is not one man printed four times.
                    //
                    // **Nothing else on the court moves while somebody is going up.** The
                    // three who are not on the board stand and watch it, turned away — they
                    // were jogging on the spot through the whole leap, which read as a play
                    // carrying on behind the one thing everybody is meant to be looking at.
                    // They pick their running back up the moment he comes down with it.
                    // A call stops the play: everybody stands, turned away, while the
                    // official makes it — the same pose they hold for a rebound.
                    sprite: waitingForThrow(seat) ? .inboundReceiverBack
                        : ((watching(seat) || callingRef != nil) ? .back : nil),
                    spriteFrame: waitingForThrow(seat) ? look.waiting(for: seat).cell : nil,
                    facing: passer,
                    mirrored: waitingForThrow(seat) ? (look.waiting(for: seat).mirrored
                                                       ? !facesThrower(seat) : facesThrower(seat))
                        : nil,
                    // A throw-in is caught too. `holder` is not yet this seat during the
                    // throw — the rules moved the ball before the beat began — so the throw
                    // names its own receiver.
                    caughtAt: (holder == seat || throwing?.to == seat) ? landedAt : nil,
                    // Only the man who won it goes up, and only he comes down with it.
                    reboundID: rebound?.seat == seat ? rebound?.id : nil,
                    // Warping to a spot during a stoppage is arriving somewhere; a warp in
                    // the run of play is not, and landing out of one would stop him dead.
                    landsFromWarp: isStill,
                    // Nobody dribbles a ball that is still in the air. The thrower has let go
                    // and the receiver has not caught it yet, so both are simply running.
                    awaitingBall: ballInFlight && holder == seat,
                    throwing: throwing(seat),
                    clockShift: clockShift[seat] ?? 0,
                    // Whoever is inbounding is drawn on the sideline instead, further up this
                    // same stack. He warps off the floor rather than being cut from it — and
                    // the sprite alone comes apart, since a bag count in columns is a number
                    // falling to bits rather than a player leaving.
                    warp: isAway(seat) ? 1 : 0,
                    warpSeed: warpSeed)
                    .animation(.easeInOut(duration: Court.warp), value: isAway(seat))
                    // **His name, over his head and under his hand count** — small, in the
                    // referees' style, and the same size wherever he stands: the row's own
                    // scale is divided back out.
                    .overlay(alignment: .top) {
                        HStack(spacing: 3) {
                            FloorName(text: seat.playerName)
                            // Whoever has it, said twice: the sprite is dribbling one and
                            // this is the same fact at a glance.
                            if holder == seat {
                                BallView(diameter: FloorName.size)
                                    .shadow(color: CardPalette.navy, radius: 0, x: 1, y: 1)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.easeOut(duration: 0.2), value: holder == seat)
                        .scaleEffect(1 / court.scale(of: seat, inbounding: thrower), anchor: .bottom)
                        .frame(height: NamePlate.overHead, alignment: .bottom)
                        // The name goes with him, whole — it is a label, not a body.
                        .opacity(isAway(seat) ? 0 : 1)
                        .animation(.easeInOut(duration: Court.warp), value: isAway(seat))
                    }
                // **The room the old name plate took, kept.** Every player's feet were
                // placed on the floor with it under them, so taking it away would drop all
                // four by its height.
                PlayerNameText(seat: seat, size: NamePlate.size, tracking: NamePlate.tracking)
                    .fixedSize()
                    .hidden()
            }
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if let bid = revealedBids?[seat] {
                    Text("\(bid)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 9).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.color(for: seat).opacity(0.9)))
                        .offset(y: -14)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            // **A man who is not on the floor is not there to be tapped.** He warps out for
            // his own inbound and his node stays in the hierarchy, invisible — and its content
            // shape went on taking taps meant for whoever is standing behind it, answering
            // them with an inspection of the man who had left.
            .allowsHitTesting(!isAway(seat))
            .onTapGesture { selectable ? onSelect(seat) : onInspectPlayer(seat) }
            // The button that names him, over his head where the wedge is. Only ever while
            // the question is up, and only ever for a pad.
            .overlay(alignment: .top) {
                if let glyph = faces[seat] {
                    Image(systemName: glyph)
                        .font(.system(size: Face.glyph, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.navy, radius: 0, x: 3, y: 3)
                        .offset(y: Face.lift)
                        .allowsHitTesting(false)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: revealedBids?[seat])
        })
    }
}

/// The throw-in, crossing the floor.
///
/// Its own view so the flight owns its clock: the court redraws for every state change in
/// the game, and a ball whose position came from that would stutter across.
private struct InboundThrow: View {
    let from: CGPoint
    let to: CGPoint
    let seconds: Double
    var scale: CGFloat = 1

    @State private var travelled: CGFloat = 0

    var body: some View {
        PixelBallView(scale: Theme.Figure.playerScale * scale)
            .position(x: from.x + (to.x - from.x) * travelled,
                      y: from.y + (to.y - from.y) * travelled)
            .onAppear {
                withAnimation(.easeInOut(duration: seconds)) { travelled = 1 }
            }
            .allowsHitTesting(false)
    }
}

/// The board coming out of the rim and into his hands.
///
/// **Its own view, and a new one for every board.** The trip used to be three `@State`s
/// on the court, put back to nought at the top of the same task that then animated them —
/// and SwiftUI collapses both writes into one update, so it compared the value it last
/// drew (a 1 left over from the previous board) against the 1 the animation was heading
/// for, decided nothing had changed, and dropped the ball straight into his hands at full
/// size. The first rebound of a court's life animated and none after it did, which is why
/// the size dial looked like a knob wired to nothing.
///
/// A view made fresh for each board — see the `.id` on it — starts where it says it does,
/// so there is nothing left over to compare against.
private struct ReboundBallView: View {
    /// The rim it comes out of, and his hands at the top of the leap.
    var from: CGPoint
    var to: CGPoint
    /// How big it is when it gets there: his row's own scale.
    var end: CGFloat
    /// How far he comes down once he has it, in points.
    var descent: CGFloat

    @State private var tune = ReboundTuning.shared
    /// How far along the trip it is, and how far into his descent.
    @State private var flown: CGFloat = 0
    @State private var carried: CGFloat = 0
    @State private var gone = false

    var body: some View {
        Group {
            if !gone {
                PixelBallView()
                    .scaleEffect(tune.fromHoop + (end - tune.fromHoop) * flown)
                    .position(x: from.x + (to.x - from.x) * flown,
                              y: from.y + (to.y - from.y) * flown + descent * carried)
            }
        }
        .task { await travel() }
    }

    private func travel() async {
        // Thrown to arrive on the last cell of the leap.
        withAnimation(.easeIn(duration: tune.flight)) { flown = 1 }
        // **Held until he is up there**, not until the trip is over. A flight shorter
        // than the rise put the ball at the catch point early, and starting the descent
        // from there had it leave his hands and beat him down — the two were counted off
        // different clocks. See `ReboundTuning.catchAt`.
        try? await Task.sleep(for: .seconds(tune.catchAt + tune.hang))
        // Caught. It rides his descent rather than hanging in the air he has left — the
        // same beat he spends coming down still holding the catch.
        withAnimation(.easeIn(duration: tune.drop)) { carried = 1 }
        // Taken off when the dial says, which is once the sprite has a ball of its own to
        // draw. Not faded: it was being animated out of a view carrying
        // `.transition(.identity)`, which is no animation at all.
        try? await Task.sleep(for: .seconds(tune.vanish))
        gone = true
    }
}

/// The band of light travelling down the floor. **Its own view so it can be taken away**:
/// a `repeatForever` cannot be paused, so a hidden floor drops this and a returning one
/// builds a fresh sweep, which starts above the top edge where nobody sees it begin.
private struct FloorSweep: View {
    let band: CGFloat
    let height: CGFloat
    @State private var sweep: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Theme.courtSweep, .clear],
                                 startPoint: .top, endPoint: .bottom))
            .frame(height: band)
            // Driven by a modifier, so the sweep interpolates without rebuilding the view
            // every frame.
            .offset(y: -band + sweep * (height + band))
            .frame(maxHeight: .infinity, alignment: .top)
            .onAppear {
                withAnimation(.linear(duration: Perspective.sweepSeconds).repeatForever(autoreverses: false)) {
                    sweep = 1
                }
            }
    }
}

/// **A name on the floor**: small condensed caps with a one-point drop, drawn at its own
/// size wherever the man stands — the caller divides his depth's scale back out. Worn by
/// the players, and by a referee while a card is asking for one of the crew.
struct FloorName: View {
    let text: String
    var ink: Color = .white

    static let size: CGFloat = 11

    var body: some View {
        SmallCapsText(text: text.uppercased(), font: "AvenirNextCondensed-Heavy",
                      size: Self.size, scalesWithTextSize: false)
            .foregroundStyle(ink)
            .shadow(color: CardPalette.navy, radius: 0, x: 1, y: 1)
            .fixedSize()
    }
}
