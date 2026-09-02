import SwiftUI

struct CourtView: View {
    let state: GameState
    let gate: GameController.Gate
    let revealedBids: [Seat: Int]?
    /// When the ball finished changing hands, so the catch plays in view.
    var settledAt: Date?
    /// Whose seat the court is drawn from. Multiplayer passes the local player's.
    var viewer: Seat = GameRules.humanSeat
    var flight: DrawFlight?
    var flightDuration: Double = 0.30
    var onOpenDiscard: () -> Void = {}
    var onSelect: (Seat) -> Void

    /// Fixed so a bid badge appearing cannot shift a figure off its footing.
    private var nodeHeight: CGFloat { Theme.Figure.height + 26 }

    @State private var sweep: CGFloat = 0
    /// Stamped when the ball changes hands, which starts the catch animation.
    @State private var tuning = CourtTuning.shared
    /// True while the ball is crossing between players.
    @State private var ballInFlight = false

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
                CourtStreaks()

                room(court)

                // Hung above the far baseline so the rim clears it rather than
                // sitting on North's head.
                FarHoop()
                    .position(x: court.centreX,
                              y: court.horizonY - 18 - geo.size.height * 0.05)

                // Painted far to near, so anything upcourt is overlapped by what
                // stands in front of it instead of by whatever draws last.
                ForEach(CourtItem.inDepthOrder(viewedFrom: viewer), id: \.self) { item in
                    place(item, on: court, in: geo.size)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7),
                           value: state.armedWhistles.isEmpty)

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

                if let holder = state.ball {
                    let footing = court.footing(of: holder)
                    let scale = court.scale(of: holder)
                    PixelBallView()
                        .scaleEffect(scale)
                        .position(x: footing.x + 26 * scale, y: footing.y - 22 * scale)
                        // Only visible on its way over: the dribbling sprite draws its
                        // own ball once someone has it.
                        .opacity(ballInFlight ? 1 : 0)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.72), value: state.ball)
            .task(id: settledAt) {
                guard settledAt != nil else { return }
                ballInFlight = true
                // Long enough to cross, then the receiver's sprite takes it over.
                try? await Task.sleep(for: .seconds(0.45))
                ballInFlight = false
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
        }
        .onAppear {
            withAnimation(.linear(duration: Perspective.sweepSeconds).repeatForever(autoreverses: false)) {
                sweep = 1
            }
        }
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
        case referee

        func depth(viewedFrom viewer: Seat) -> CGFloat {
            switch self {
            case .player(let seat): return Perspective.depth(of: seat.slot(viewedFrom: viewer))
            case .deck:             return Perspective.deckDepth
            case .referee:          return Perspective.refereeDepth
            }
        }

        static func inDepthOrder(viewedFrom viewer: Seat) -> [CourtItem] {
            (Seat.allCases.map(CourtItem.player) + [.deck, .referee])
                .sorted { $0.depth(viewedFrom: viewer) < $1.depth(viewedFrom: viewer) }
        }
    }

    @ViewBuilder
    private func place(_ item: CourtItem, on court: CourtGeometry,
                       in geo: CGSize) -> some View {
        switch item {
        case .referee:
            if !state.armedWhistles.isEmpty {
                let depth = Perspective.refereeDepth
                RefereeFigure()
                    .scaleEffect(court.scale(at: depth), anchor: .bottom)
                    .position(x: court.centreX + court.halfWidth(at: depth) * Perspective.refereeLateral,
                              y: court.y(at: depth))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        case .deck:
            let depth = Perspective.deckDepth
            DeckStackView(remaining: state.deck.count, width: 138)
                .scaleEffect(court.scale(at: depth), anchor: .bottom)
                .position(x: court.centreX + court.halfWidth(at: depth) * Perspective.deckLateral,
                          y: court.y(at: depth) + geo.height * 0.02)

            DiscardPileView(count: state.discard.count, width: 99)
                .scaleEffect(court.scale(at: depth), anchor: .bottom)
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpenDiscard)
                .position(x: court.centreX + court.halfWidth(at: depth) * Perspective.discardLateral,
                          y: court.y(at: depth) + geo.height * 0.02)
        case .player(let seat):
            let footing = court.footing(of: seat)
            let scale = court.scale(of: seat)
            node(seat)
                .scaleEffect(scale, anchor: .bottom)
                .frame(width: Theme.Figure.height, height: nodeHeight, alignment: .bottom)
                .position(x: footing.x,
                          y: footing.y - nodeHeight / 2
                             + Theme.Figure.height * Perspective.playerDrop)

            // A Clamp puts bodies on the floor next to its victim, one per defender the
            // card calls for, alternating sides so a Triple-Team reads as a crowd.
            let bodies = defenders(on: seat)
            ForEach(0..<bodies, id: \.self) { index in
                let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                let rank = CGFloat(index / 2 + 1)
                DefenderFigure()
                    .scaleEffect(scale, anchor: .bottom)
                    .position(x: footing.x + side * 26 * rank * scale,
                              y: footing.y - 4 * rank * scale)
                    .transition(.scale(scale: 0.01).combined(with: .opacity))
                    // Keyed to the seat, so a Clamp moving to another player reads as one
                    // defender leaving and a different one arriving — not as a single guy
                    // sprinting across the court.
                    .id("defender-\(seat.rawValue)-\(index)")
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.68), value: clampLayout)
        }
    }

    // MARK: - Players

    private func node(_ seat: Seat) -> some View {
        let selectable = selectableSeats.contains(seat)
        return VStack(spacing: 3) {
            PlayerFigure(
                seat: seat,
                isHolding: state.ball == seat,
                isActing: state.phase.actingSeat == seat,
                // The seat being asked to choose is never dimmed, even though it is
                // not a legal target for itself.
                isDimmed: !selectableSeats.isEmpty && !selectable
                    && state.phase.actingSeat != seat,
                marker: selectable ? Theme.live
                    : (state.phase.actingSeat == seat ? .white : nil),
                handCount: state[seat].bag.count,
                facing: state.lastPasser,
                caughtAt: state.ball == seat ? settledAt : nil)
            SmallCapsText(text: seat.playerName,
                          font: "AvenirNextCondensed-Heavy",
                          size: 20,
                          tracking: 20 * CardLayout.nameTracking)
                .foregroundStyle(.white)
                .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
                // Pulled up through the sheet's empty rows, or it sits a long way
                // under the feet at this scale.
                .offset(y: -Theme.Figure.height * Theme.Figure.spriteFootPadding)
                .foregroundStyle(Theme.inkDim)
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
