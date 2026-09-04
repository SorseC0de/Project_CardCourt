import SwiftUI

struct CourtView: View {
    let state: GameState
    let gate: GameController.Gate
    let revealedBids: [Seat: Int]?
    /// When the ball finished changing hands, so the catch plays in view.
    var settledAt: Date?
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

    /// The name under a player's feet.
    ///
    /// Its own numbers, not the card's. A card tightens its name with a negative
    /// `CardLayout.nameTracking` to fit a fixed width; this one is read at a distance
    /// over a busy floor, so it wants the opposite — bigger, and opened up.
    private enum NamePlate {
        static let size: CGFloat = 26
        /// A share of the size, so the two stay in step.
        static let tracking: CGFloat = 0.04
        static let shadow: CGFloat = 3

        // Where it sits, as shares of a figure's height.

        /// Raheem stands at the back, where a name under his feet is covered by whoever
        /// is nearest the camera — so his goes out beside him instead.
        static let farX: CGFloat = 0.42
        static let farLift: CGFloat = 0.55
        /// The other three sit closer under their own feet.
        static let drop: CGFloat = 0.02
    }

    /// Who the court draws as holding the ball.
    ///
    /// A practice pass puts it in the receiver's hands without the rules having moved
    /// anything, and every part of the catch has to agree — the sprite, the flight, and
    /// the ball's destination all read this rather than `state.ball` directly.
    private var holder: Seat? { receiver ?? state.ball }

    /// How wide a pile is drawn before the bench's multiplier.
    private static let pileWidth: CGFloat = 138

    /// Fixed so a bid badge appearing cannot shift a figure off its footing.
    private var nodeHeight: CGFloat { Theme.Figure.height + 26 }

    @State private var sweep: CGFloat = 0
    /// Stamped when the ball changes hands, which starts the catch animation.
    /// Observed, not just read — otherwise moving a slider changes nothing on screen.
    @State private var render = RenderDebug.shared
    /// Observed, not just read — otherwise moving a slider changes nothing on screen.
    @State private var prompt = InboundTextTuning.shared
    /// Observed, not just read — otherwise moving a slider changes nothing on screen.
    @State private var deckTuning = DeckTuning.shared
    /// True while the ball is crossing between players.
    @State private var ballInFlight = false
    /// 0 at the passer, 1 at the receiver. Named apart from the draw's `flight`.
    @State private var passFlight: CGFloat = 0
    /// When the ball actually arrived, which is what the catch counts from. Distinct from
    /// `settledAt`, which is when it *left* — feeding that to the catch played it over the
    /// top of the throw.
    @State private var landedAt: Date?
    /// The stamp the ball has already been flown for. `.task(id:)` re-runs whenever its
    /// subtree is rebuilt, not only when the id changes — so without this the same pass
    /// can be thrown twice, which is what "players sometimes pass the ball twice" was.
    @State private var flewAt: Date?

    private var selectableSeats: Set<Seat> {
        if case .awaitingInbound(let inbounder) = gate {
            return Set(Seat.allCases.filter { $0 != inbounder })
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
                CourtStreaks()
                    .opacity(isStill ? 0 : 1)
                    .animation(.easeOut(duration: 0.4), value: isStill)

                room(court)

                // Between the floor and the stage. The 3D piles are a layer of their
                // own, so a shadow drawn alongside them would land on top instead of
                // under.
                PileShadow(width: geo.size.width * Perspective.pileCardShare
                                  * deckTuning.size,
                           across: geo.size.width)
                    .position(deckPoint(on: court))

                // One scene for the whole floor. Everything on it is placed from the same
                // court points the sprites use, so the two cannot disagree.
                if render.courtStage {
                    CourtStage(deckAt: share(deckPoint(on: court), in: geo.size),
                               discardAt: share(discardPoint(on: court), in: geo.size),
                               deckLayers: max(1, min(40, state.deck.count / 10)),
                               discardLayers: max(0, min(40, state.discard.count / 10)),
                               deckRoutine: deckRoutine,
                               flight: deal.map { deal in
                                   CardFlight(id: deal.id,
                                              from: share(deckPoint(on: court), in: geo.size),
                                              to: share(court.footing(of: deal.seat), in: geo.size))
                               },
                               seatsAt: Dictionary(uniqueKeysWithValues: Seat.allCases.map {
                                   ($0, share(court.footing(of: $0), in: geo.size))
                               }),
                               opening: opening)
                }

                // Hung above the far baseline so the rim clears it rather than
                // sitting on North's head.
                FarHoop()
                    .position(x: court.centreX,
                              y: court.horizonY - 18 - geo.size.height * 0.05)

                // Drawn here, before the figures, which is the entire point: the players
                // stand above it without anything being duplicated or measured against a
                // frame in another coordinate space. The cards below the court are dimmed
                // by a second scrim in `GameView` — see there for why it is not one.
                //
                // **Bounded to the court.** A view far larger than the screen in this
                // stack is not free: `CourtStage` is a RealityView in here, and an
                // oversized layer asks Metal for a drawable past its maximum texture size,
                // which fails validation and takes the render thread down with it.
                if isStill {
                    Rectangle()
                        .fill(.black.opacity(Court.dim))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // Painted far to near, so anything upcourt is overlapped by what
                // stands in front of it instead of by whatever draws last.
                ForEach(CourtItem.inDepthOrder(viewedFrom: viewer, referees: refereePosts),
                        id: \.self) { item in
                    place(item, on: court, in: geo.size)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7),
                           value: refereePosts)

                // Over the player he is taking from, and gone again in under a second.
                if let swipe {
                    let footing = court.footing(of: swipe.seat)
                    DefenderSwipe(seat: swipe.seat,
                                  mirrored: swipe.seat.slot(viewedFrom: viewer) == .west)
                        .id(swipe.id)
                        .scaleEffect(court.scale(of: swipe.seat), anchor: .bottom)
                        .position(x: footing.x,
                                  y: footing.y - Theme.Figure.height / 2
                                     + Theme.Figure.height * Perspective.playerDrop)
                        .zIndex(250)
                }

                if case .awaitingInbound(let thrower) = gate {
                    let post = RefereePost.inbounding(thrower.slot(viewedFrom: viewer))
                    InbounderFigure(seat: thrower, holdsBall: true,
                                    mirrored: !post.isLeft)
                        .scaleEffect(court.scale(at: post.depth), anchor: .bottom)
                        .position(x: court.centreX
                                  + court.halfWidth(at: post.depth) * post.lateral,
                                  y: court.y(at: post.depth) - nodeHeight / 2
                                     + Theme.Figure.height * Perspective.playerDrop)
                        .zIndex(200)

                    inboundPrompt
                        .position(x: geo.size.width / 2,
                                  y: geo.size.height * Prompt.y)
                        .zIndex(201)
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
                // On and off instantly — the sprite already holds a ball, so a fade
                // would read as two balls dissolving into each other.
                var appear = Transaction(); appear.disablesAnimations = true
                withTransaction(appear) { passFlight = 0; ballInFlight = true }
                landedAt = nil

                // Every pass takes the same time, whoever it is between: the ball
                // simply travels faster across the diamond than to a neighbour. The
                // arrival is what the catch is timed against, so it stays put.
                withAnimation(.easeInOut(duration: Theme.Pass.flightSeconds)) { passFlight = 1 }
                try? await Task.sleep(for: .seconds(Theme.Pass.flightSeconds
                                                    + Theme.Pass.holdSeconds))

                landedAt = Date()
            }
        }
    }

    // MARK: - Floor

    /// Just the floor: a gradient that fades to nothing at the horizon, with a band of
    /// light travelling down it. No outline — the converging edges carry the perspective.
    private func room(_ court: CourtGeometry) -> some View {
        GeometryReader { geo in
            let band = geo.size.height * Perspective.sweepHeight
            ZStack {
                Rectangle().fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: Perspective.horizon),
                            .init(color: Theme.courtFloor, location: Perspective.floorFadeEnd),
                        ],
                        startPoint: .top, endPoint: .bottom))

                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Theme.courtSweep, .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: band)
                    // Driven by a modifier, so the sweep interpolates without rebuilding
                    // the view every frame.
                    .offset(y: -band + sweep * (geo.size.height + band))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .mask(CourtFloorShape())
            // The light travelling down the floor stops with everything else.
            .opacity(isStill ? 0 : 1)
            .animation(.easeOut(duration: 0.4), value: isStill)
        }
        .onAppear {
            withAnimation(.linear(duration: Perspective.sweepSeconds).repeatForever(autoreverses: false)) {
                sweep = 1
            }
        }
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
        CGPoint(x: court.centreX
                + court.halfWidth(at: Perspective.deckDepth) * lateral
                + court.size.width * deckTuning.x,
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
                           catching: Bool) -> CGPoint {
        let footing = court.footing(of: seat)
        let scale = court.scale(of: seat)
        let side = Theme.Figure.height * scale
        // The offset is measured on the unflipped sprite. A player who turns to meet the
        // pass catches with the other hand, so the offset turns with them. Only the
        // receiver flips — the thrower is still dribbling, and dribbling never mirrors.
        let flip: CGFloat = catching
            && PlayerFigure.catchIsMirrored(seat: seat, facing: passer) ? -1 : 1
        return CGPoint(x: footing.x + side * Theme.Pass.handX * flip,
                       y: footing.y - side * Theme.Pass.handY)
    }

    /// Both ends of the throw, so the flight is drawn and timed off the same two points.
    private func flightPath(on court: CourtGeometry) -> (CGPoint, CGPoint)? {
        guard let holder else { return nil }
        let to = ballPoint(of: holder, on: court, catching: true)
        let from = passer.map { ballPoint(of: $0, on: court, catching: false) } ?? to
        return (from, to)
    }

    /// One referee per armed Whistle, each at his own post.
    ///
    /// Read off the Whistle's own id rather than rolled, so a redraw cannot move a
    /// referee mid-round — the skin tones re-rolling on every inbound taught that. The
    /// first byte is the coin flip for the side, the second picks between that side's two
    /// posts, and anyone finding both taken takes whatever is left.
    private var refereePosts: [RefereePost] {
        var free = Set(RefereePost.allCases)
        return state.armedWhistles.compactMap { whistle in
            let coin = withUnsafeBytes(of: whistle.id.uuid) { Array($0.prefix(2)) }
            let side: [RefereePost] = coin[0].isMultiple(of: 2)
                ? [.leftWing, .farLeft] : [.rightWing, .farRight]
            let wanted = coin[1].isMultiple(of: 2) ? side : side.reversed()
            guard let post = (wanted + RefereePost.allCases).first(where: free.contains)
            else { return nil }
            free.remove(post)
            return post
        }
    }

    enum Court {
        /// How dark everything but the players goes. Shared with `GameView`, which dims
        /// the cards to the same depth.
        static let dim: Double = 0.82
    }

    private enum Prompt {
        /// Where the two lines sit, as a share of the court's own height.
        static let y: CGFloat = 0.14
    }

    /// What the dimmed court is asking for.
    ///
    /// `Inbound` is picked out because it is the only word in the sentence that is a rule
    /// rather than English.
    private var inboundPrompt: some View {
        // Each line placed on its own, because the two are different sizes and the gap
        // that looks right between them is not a spacing — it is where each one sits.
        ZStack {
            ActionText("Select a Player", size: 46)
                .offset(x: prompt.topX, y: prompt.topY)
            ActionText(runs: [.init("to "),
                              .init("Inbound", ink: CardPalette.gold, drop: CardPalette.orange),
                              .init(" to!")],
                       size: 26)
                .offset(x: prompt.bottomX, y: prompt.bottomY)
        }
        .fixedSize()
        .allowsHitTesting(false)
    }

    /// Which way to turn to look at the thrower. He stands at one of two posts, so this
    /// is one answer for the whole floor.
    private var facesThrower: Bool {
        guard case .awaitingInbound(let thrower) = gate else { return false }
        return RefereePost.inbounding(thrower.slot(viewedFrom: viewer)).isLeft
    }

    /// The whole court is stationary — an inbound has been called and everyone is set.
    private var isStill: Bool {
        if case .awaitingInbound = gate { return true }
        return false
    }

    /// True while this seat is the one being asked to throw it back in.
    private func isInbounding(_ seat: Seat) -> Bool {
        guard case .awaitingInbound(let asked) = gate else { return false }
        return asked == seat
    }

    /// The seat furthest from the camera, whose label the nearest player sits over.
    private func isFarSeat(_ seat: Seat) -> Bool {
        seat.slot(viewedFrom: viewer) == .north
    }

    /// The wedge means "you can pick this one". During an inbound the inbounder is the
    /// single seat you cannot pass to, so they wear nothing at all — marking them would
    /// point at the one illegal target on the floor.
    private func marker(for seat: Seat, selectable: Bool) -> Color? {
        if selectable { return Theme.live }
        if case .inbound = state.phase { return nil }
        return state.phase.actingSeat == seat ? .white : nil
    }

    private func defenders(on seat: Seat) -> Int {
        state[seat].clamps.reduce(0) { $0 + ($1.card.clamp?.defenders ?? 1) }
    }

    /// Changes whenever any seat's defender count does, which is what drives the
    /// shrink-away and pop-in rather than a slide.
    private var clampLayout: [Int] { Seat.allCases.map(defenders(on:)) }

    // MARK: - Depth ordering

    /// Everything that stands on the floor, so one sort covers players and the deck.
    private enum CourtItem: Hashable {
        case player(Seat)
        case deck
        case referee(RefereePost)

        func depth(viewedFrom viewer: Seat) -> CGFloat {
            switch self {
            case .player(let seat): return Perspective.depth(of: seat.slot(viewedFrom: viewer))
            case .deck:             return Perspective.deckDepth
            case .referee(let post): return post.depth
            }
        }

        static func inDepthOrder(viewedFrom viewer: Seat,
                                 referees: [RefereePost]) -> [CourtItem] {
            (Seat.allCases.map(CourtItem.player) + [.deck]
                + referees.map(CourtItem.referee))
                .sorted { $0.depth(viewedFrom: viewer) < $1.depth(viewedFrom: viewer) }
        }
    }

    @ViewBuilder
    private func place(_ item: CourtItem, on court: CourtGeometry,
                       in geo: CGSize) -> some View {
        switch item {
        case .referee(let post):
            // Framed and dropped exactly as a player is, so his feet land on the same
            // floor line theirs would at that depth. Top-aligned because he has no name
            // plate under him taking up the bottom of the box.
            RefereeFigure(mirrored: post.isLeft, phase: post.phase)
                .scaleEffect(court.scale(at: post.depth), anchor: .bottom)
                .frame(width: Theme.Figure.height, height: nodeHeight, alignment: .top)
                .position(x: court.centreX + court.halfWidth(at: post.depth) * post.lateral,
                          y: court.y(at: post.depth) - nodeHeight / 2
                             + Theme.Figure.height * Perspective.playerDrop)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
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
            let footing = court.footing(of: seat)
            let scale = court.scale(of: seat)
            node(seat)
                // Nudged aside for the inbound, per seat, while that is being eyeballed.
                .offset(x: isStill ? (prompt.seatX[seat] ?? 0) * scale : 0)
                // Whoever is inbounding is drawn on the sideline instead, further up this
                // same stack. Hidden rather than skipped so nothing below them moves.
                .opacity(isInbounding(seat) ? 0 : 1)
                .scaleEffect(scale, anchor: .bottom)
                .frame(width: Theme.Figure.height, height: nodeHeight, alignment: .bottom)
                .position(x: footing.x,
                          y: footing.y - nodeHeight / 2
                             + Theme.Figure.height * Perspective.playerDrop)

            // Being clamped is drawn on the player rather than beside them. Two little
            // red bodies on the floor read as two more players; the coils read as
            // something being done to this one. The defender himself shows up when they
            // actually shoot — that is when he matters.
            let bodies = defenders(on: seat)
            if bodies > 0 {
                BindLines(defenders: bodies, height: Theme.Figure.height)
                    .scaleEffect(scale, anchor: .bottom)
                    .position(x: footing.x,
                              y: footing.y - Theme.Figure.height / 2
                                 + Theme.Figure.height * Perspective.playerDrop)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .id("bind-\(seat.rawValue)")
                    .animation(.spring(response: 0.34, dampingFraction: 0.68),
                               value: clampLayout)
            }
        }
    }

    // MARK: - Players

    private func node(_ seat: Seat) -> some View {
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
                handCount: state[seat].bag.count,
                // Set and waiting for it, like everybody else during an inbound — and
                // turned to watch whoever is throwing it, rather than facing whichever
                // way the run of play had left them.
                sprite: isStill ? .inboundReceiver : nil,
                facing: passer,
                mirrored: isStill ? facesThrower : nil,
                caughtAt: holder == seat ? landedAt : nil,
                // Nobody dribbles a ball that is still in the air. The thrower has let go
                // and the receiver has not caught it yet, so both are simply running.
                awaitingBall: ballInFlight && holder == seat)
            SmallCapsText(text: seat.playerName,
                          font: "AvenirNextCondensed-Heavy",
                          size: NamePlate.size,
                          tracking: NamePlate.size * NamePlate.tracking)
                .foregroundStyle(.white)
                .shadow(color: CardPalette.navy, radius: 0,
                        x: NamePlate.shadow, y: NamePlate.shadow)
                .fixedSize()
                // Pulled up through the sheet's empty rows, or it sits a long way under
                // the feet at this scale.
                .offset(x: isFarSeat(seat) ? Theme.Figure.height * NamePlate.farX : 0,
                        y: -Theme.Figure.height
                            * (Theme.Figure.spriteFootPadding
                               + (isFarSeat(seat) ? NamePlate.farLift : -NamePlate.drop)))
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
        .onTapGesture { if selectable { onSelect(seat) } }
        .animation(.easeOut(duration: 0.2), value: revealedBids?[seat])
    }
}
