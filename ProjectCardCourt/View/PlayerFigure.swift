import SwiftUI

/// A player: capsule body under a circle head.
/// A squat downward wedge that sits over a marked player's head.
struct MarkerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A player: the pixel sheet, wearing that seat's colours.
///
/// One sheet serves all four. The uniform is a palette swap on the two jersey entries,
/// which the ball and the skin never use — so a recolour cannot touch anything but the
/// clothes, and there is no second sheet to keep in step.
struct PlayerFigure: View {
    let seat: Seat
    var isHolding = false
    var isActing = false
    var isDimmed = false
    var marker: Color?
    /// Clamps already on this player, shown above their head while a Clamp is being read.
    /// Nil the rest of the time — a running count of nothing on four heads is clutter.
    var clampCount: Int?
    /// Cards in this player's bag, shown above their head.
    var handCount: Int?
    /// Overrides what they are doing. The cutscenes use it to make someone shoot.
    var sprite: Sprite?
    /// Which cell of that sheet to hold on. A sheet of poses rather than of frames — the
    /// receivers pick one and stand in it.
    var spriteFrame: Int?
    /// Stops on the last frame instead of looping. The shot does not repeat.
    var playsOnce = false
    /// Overrides the usual rate for a sprite that wants its own pace.
    var fps: Double?
    /// Plays up to this frame and holds there, counting from zero. The turnover runs the
    /// first of the catch and stops on the reach, so the ball is met but never gathered in.
    var stopAtFrame: Int?
    /// Who last passed, which is who the human turns to face as they catch.
    var facing: Seat?
    /// Overrides which way the sprite faces. A cutscene knows which side the ball is
    /// coming in from outright, where the court has to work it out from who threw it.
    var mirrored: Bool?
    /// When this player took possession, which starts the catch.
    var caughtAt: Date?
    /// The board he is going up for, named by the court. Nil for everybody else, and a
    /// fresh id every time — two boards in a row are two jumps.
    var reboundID: UUID?
    /// Whether arriving out of a warp is landed rather than simply appeared. Only for a
    /// warp during a stoppage — a man relocating for an inbound has come down somewhere;
    /// one going somewhere mid-play has not.
    var landsFromWarp = false
    /// The ball is still crossing to them. They have not got it yet, so they are not
    /// dribbling it — they are running to meet it.
    var awaitingBall = false
    var scale: CGFloat = Theme.Figure.playerScale
    /// Warping off the floor, or back on to it — see `ColumnWarp`. **The sprite only.**
    /// What is hung on him is a reading rather than a body: a bag count cut into columns
    /// is a number coming apart, which says nothing about a player going anywhere.
    var warp: Double = 0
    var warpSeed: UInt64 = 0

    @State private var look = PlayerLook.shared
    @State private var catching = false
    /// Where he is in a jump, if he is in one.
    @State private var leap: Leap = .none
    /// When the cell being shown started. Its own clock, like the catch's.
    @State private var leapFrom: Date?
    /// The two extra pixels, on or off. **Snapped, never tweened** — it is a whole
    /// number of art pixels in a game drawn in them.
    @State private var lifted = false
    /// How far off the floor he reads as being, which is the shadow's business rather
    /// than the sprite's. Unlike the lift this one is a ramp: a shadow is a soft blob and
    /// has nothing to snap to.
    @State private var airborne: CGFloat = 0
    @State private var leapTune = ReboundTuning.shared
    /// Raised for a beat when a card arrives — see `Bag`.
    @State private var bagTook = false

    private enum Leap: Equatable {
        case none
        /// Going up, one pass of the rebound sheet.
        case rising
        /// Held on its last cell with the ball in his hands.
        case hanging
        /// Coming down, one pass of the landing sheet.
        case landing
    }
    /// When this catch began. The sheet is counted from here, not from the wall clock.
    @State private var caughtFrom: Date?
    /// A one-shot sprite counts from here; without it the frame index never advances.
    @State private var startedAt: Date?
    /// Two positions, held a beat each — a hop rather than a glide.
    @State private var hop: CGFloat = 0
    /// When he last came down on the floor, so the dust can be counted off it.
    @State private var dustAt: Date?
    /// Whether this landing ends facing the room. Only a rebound does. See `action`.
    @State private var facingYou = false

    /// This figure's offset into the sprite clock, so four players do not run in unison.
    /// Read by the dust as well as by the sheet — a puff on a different phase is a bounce
    /// somebody else made.
    private var clockPhase: TimeInterval { Double(seat.rawValue) * 1.3 }

    private var tint: Color { Theme.color(for: seat) }

    /// The bag and the count above a player's head.
    private enum Bag {
        static let number: CGFloat = 34
        /// The art is trimmed to its own subject rather than squared off, so this is not
        /// the number's own size — it is what reads as the same size beside it.
        static let side: CGFloat = 34
        static let gap: CGFloat = 3
        /// How big it goes when a card lands in it, and how long it stays there.
        ///
        /// **The hold has to outlast the spring.** At a sixth of a second against a
        /// spring that takes a quarter to arrive, it was told to come back before it had
        /// finished going — which is a bag that does not swell so much as flinch.
        static let swell: CGFloat = 1.45
        static let swellHolds: Double = 0.26
        static let swellSpring: Double = 0.16
    }

    /// The rate this sprite runs at. The catch has its own, and the hold that keeps
    /// `catching` true is measured from the same number — set them apart and the sprite
    /// finishes before the state does, or keeps playing after it.
    private var frameRate: Double {
        if let fps { return fps }
        return action == .catchBall ? Theme.Pass.catchFPS : Theme.Figure.playerFPS
    }

    /// A cutscene pose is a resting pose. The catch interrupts it and hands it back —
    /// otherwise an inbound receiver stands frozen in his waiting cell while the ball
    /// lands in his arms.
    private var pose: Sprite? { catching ? nil : sprite }
    private var poseFrame: Int? { catching ? nil : spriteFrame }

    /// Catching for a beat as the ball arrives, then dribbling; jogging without it.
    private var action: Sprite {
        // **A jump outranks a pose.** The pose is what a cutscene left him in; this is
        // the floor's own event, happening now.
        switch leap {
        case .rising, .hanging: return .rebound
        // **A board turns him round to face the room; nothing else does.** Every other
        // landing — warping into place for a throw-in, coming down off a dunk — ends with
        // his back to you, which is the sheet the court is drawn from.
        case .landing:          return facingYou ? .land : .landBack
        case .none:             break
        }
        if let pose { return pose }
        if catching { return .catchBall }
        guard isHolding, !awaitingBall else { return .run }
        return .dribble
    }

    /// Everything the leap takes over while it runs: its own rate, its own clock, and a
    /// cell to hold on at the top.
    private var leapRate: Double? {
        switch leap {
        case .rising, .hanging: return leapTune.riseFPS
        case .landing:          return leapTune.landFPS
        case .none:             return nil
        }
    }

    private var leapFrame: Int? {
        leap == .hanging ? Sprite.rebound.frames - 1 : nil
    }

    /// **A leap owns the sheet while it runs.**
    ///
    /// The pose a stoppage holds him in is a `spriteFrame`, and a sheet handed a rest
    /// frame does not play — so a man relocating for an inbound was landing on a single
    /// still cell of the landing sheet, which is no animation at all.
    private var leaping: Bool { leap != .none }

    /// Idle opponents jog and glance back every few seconds. The human never does —
    /// they are at the near edge facing upcourt, with nothing behind them to look at.
    private var glance: Sprite? {
        guard sprite == nil, !isHolding, !seat.isLocal else { return nil }
        return .runLook
    }

    /// The other shoulder, for the seat that has one drawn. He looks over each in turn.
    private var glanceOr: Sprite? {
        guard glance != nil, seat == .north else { return nil }
        return .runLook2
    }

    /// Now and then he waves at somebody instead of looking behind him.
    private var glanceRare: Sprite? { glance == nil ? nil : .wave }

    /// The whole jump: up, hang, down.
    ///
    /// One sequence rather than a chain of `onChange`s, because every beat of it is timed
    /// off the one before — the ball is thrown to arrive on the sheet's last cell, and it
    /// is thrown by the court against the same numbers.
    private func goUpForIt() async {
        // He comes down off a board holding it, turned to the room.
        facingYou = true
        leapFrom = Date()
        lifted = false
        leap = .rising
        withAnimation(.easeOut(duration: leapTune.rise)) { airborne = 1 }

        // The lift comes in where the sheet runs out of frame, not at the start: the
        // first cells are him leaving the floor, which the drawing already says.
        let toLift = Double(Theme.Figure.reboundLiftFrom) / leapTune.riseFPS
        try? await Task.sleep(for: .seconds(toLift))
        withAnimation(.easeOut(duration: max(0, leapTune.rise - toLift))) { lifted = true }
        try? await Task.sleep(for: .seconds(max(0, leapTune.rise - toLift)))

        // It is in his hands. Held there on the last cell — for the hang, and for
        // however much longer the ball takes to reach him. See `ReboundTuning.hold`.
        leap = .hanging
        try? await Task.sleep(for: .seconds(leapTune.hold))

        // **Down still holding the catch.** The landing sheet is what touching the floor
        // looks like, and playing it while he is still in the air had him land twice: once
        // in the drawing, on the way down, and again when he actually arrived. So the leap
        // stays `hanging` — last cell of the rebound sheet, ball in his hands — for the
        // whole descent, and the sheet changes when the floor does.
        withAnimation(.easeIn(duration: leapTune.drop)) { lifted = false; airborne = 0 }
        try? await Task.sleep(for: .seconds(leapTune.drop))
        await comeDown()
    }

    /// One pass of the landing sheet, on the floor, and back to whatever he was doing.
    private func comeDown() async {
        leapFrom = Date()
        // He is on the floor as this begins — the sheet is the arrival, not the fall —
        // so the dust goes up on the same instant.
        dustAt = Date()
        leap = .landing
        try? await Task.sleep(for: .seconds(leapTune.landing))
        leap = .none
    }

    /// Whether a seat catches flipped, given who threw it.
    ///
    /// Static and shared on purpose: the ball's hand offset is measured on the unflipped
    /// sprite, so anything putting something *in* those hands has to ask the same
    /// question the figure does — see `CourtView.ballPoint`. Two copies of this rule
    /// would drift and the ball would sit on the wrong hip for half the table.
    /// True when the ball is arriving from the player's **right**.
    ///
    /// Which is the same thing as asking which hand it lands in: the sheet holds the ball
    /// on its left, so a mirrored sprite holds it on its right. West is always turned that
    /// way and East never is; the two on the centre line turn to meet whichever side the
    /// pass came from. It read `facing == .west` before, which put the ball in the far
    /// hand — a pass from John arrived at the far side of the player receiving it.
    static func catchIsMirrored(seat: Seat, facing: Seat?) -> Bool {
        switch seat {
        case .west:  return true
        case .south, .north: return facing == .east
        case .east:  return false
        }
    }

    /// Dribbling is never mirrored — everyone dribbles right-handed. Only the catch and
    /// the idle glance turn, and the human only turns to meet the pass.
    private var isMirrored: Bool {
        // Turning to meet the ball beats any pose the cutscene had them held in.
        if action == .catchBall { return Self.catchIsMirrored(seat: seat, facing: facing) }
        if let mirrored { return mirrored }
        guard action != .dribble else { return false }
        // West faces the other way whatever they are doing; the centre line only turns
        // to meet a pass.
        if seat == .west { return true }
        guard action == .catchBall else { return false }
        return Self.catchIsMirrored(seat: seat, facing: facing)
    }

    var body: some View {
        // Bottom-aligned: the shadow is drawn for the 32-pixel frame, and every sheet
        // that is larger has its extra rows above the character rather than below.
        ZStack(alignment: .bottom) {
            SpriteShadow(scale: scale, lift: airborne)
                // Nothing to cast one while he is between places.
                .opacity(warp > 0 ? 0 : 1)
            // Kicked up where he lands, and where the ball comes back off the floor.
            // Under the sprite: it is dust at his feet, not something thrown over him.
            if warp == 0 {
                SmokePuff(startedAt: dustAt, scale: scale)
                if action == .dribble {
                    DribbleDust(scale: scale, phase: clockPhase)
                }
            }
            SpriteAnimation(sprite: action, scale: scale,
                            fps: leapRate ?? frameRate,
                            // A pose rather than a loop: held on one cell, not played.
                            isPlaying: leaping ? leap != .hanging : poseFrame == nil,
                            restFrame: leaping ? (leapFrame ?? 0) : (poseFrame ?? 0),
                            // A catch is a one-shot like the shot is. Looping it meant its
                            // frame came from `timeIntervalSinceReferenceDate % frames` — the
                            // wall clock — so every catch began on whatever frame the world
                            // happened to be on, and no two played the same.
                            playsOnce: leap == .rising || leap == .landing
                                || playsOnce || action == .catchBall,
                            // Nothing cuts away mid-jump, and nothing else says where it
                            // stops: a leap plays its own sheet through.
                            alternate: playsOnce || leaping ? nil : glance,
                            alternateOr: playsOnce || leaping ? nil : glanceOr,
                            alternateRare: playsOnce || leaping ? nil : glanceRare,
                            phase: clockPhase,
                            // A catch on the court counts from when the ball landed; one a
                            // cutscene asks for directly counts from when it appeared.
                            startedAt: leap == .none
                                ? (action == .catchBall ? (caughtFrom ?? startedAt) : startedAt)
                                : leapFrom,
                            stopAtFrame: leaping ? nil : stopAtFrame)
                // **The sprite goes up; the shadow stays on the floor.** Which is why it
                // is here and not around the pair of them.
                .offset(y: lifted ? -leapTune.lift * scale : 0)
                .scaleEffect(x: isMirrored ? -1 : 1)
                // Never animated. Interpolating a flip runs the sprite through zero width,
                // which reads as a sheet of cardboard turning rather than a player facing
                // the other way.
                .animation(nil, value: isMirrored)
                .onAppear { if playsOnce { startedAt = Date() } }
                .paletteSwap(PlayerLook.shared.kit(for: seat))
                .opacity(isDimmed ? Theme.Figure.dimmed : 1)
                // Here rather than around the whole figure, so the badges below keep their
                // own edges — and the overlay is placed against a frame the offsets do not
                // change, so nothing moves with the columns.
                .columnWarp(warp, pixel: scale, seed: warpSeed)
                .overlay(alignment: .top) {
                    // What is hung on him goes with him, but whole: a count cut into
                    // columns is a number coming apart, which says nothing about a player
                    // going anywhere.
                    Group {
                    if let clampCount {
                        // Red over purple: the coils' own colours, so the number reads as
                        // the same fact the bind lines are already drawing.
                        Text("×\(clampCount)")
                            .font(.custom("AvenirNextCondensed-Heavy", size: Bag.number))
                            .foregroundStyle(CardPalette.red)
                            .shadow(color: CardPalette.purple, radius: 0, x: 4, y: 4)
                            .contentTransition(.numericText())
                            .offset(y: -5 - Bag.side)
                            .transition(.scale.combined(with: .opacity))
                    }
                    if let handCount {
                        // The bag says what the number is counting. Its own hard drop in the
                        // seat's colour is what ties the pair to its player now that there is
                        // no ring doing it.
                        HStack(spacing: Bag.gap) {
                            Image("BagIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: Bag.side, height: Bag.side)
                            Text("\(handCount)")
                                .font(.custom("AvenirNextCondensed-Heavy", size: Bag.number))
                                .contentTransition(.numericText())
                        }
                        // **It takes the card.** The bag swells for a beat as the count
                        // ticks over, so the arrival lands on something rather than a
                        // number quietly becoming a different number.
                        .scaleEffect(bagTook ? Bag.swell : 1)
                        // Its own animation, keyed to its own flag. Raised inside a
                        // `withAnimation` on a hopped task it was being swallowed by the
                        // implicit animations further out, which are keyed to the count.
                        .animation(.spring(response: Bag.swellSpring, dampingFraction: 0.5),
                                   value: bagTook)
                        .foregroundStyle(.white)
                        // One drop for the pair. Without this SwiftUI casts one per child and
                        // the bag's falls across the number.
                        .compositingGroup()
                        .shadow(color: tint, radius: 0, x: 4, y: 4)
                        .offset(y: -5)
                    }
                    if let marker {
                        MarkerTriangle()
                            .fill(marker)
                            .frame(width: 28, height: 14)
                            .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
                            .offset(y: -35 + hop)
                    }
                    }
                    .opacity(warp > 0 ? 0 : 1)
                }
                .onChange(of: marker == nil) { hop = 0 }
                .task(id: marker == nil) {
                    guard marker != nil else { return }
                    while !Task.isCancelled {
                        hop = hop == 0 ? -12 : 0
                        try? await Task.sleep(for: .milliseconds(340))
                    }
                }
                .animation(.easeOut(duration: 0.22), value: marker)
                .animation(.easeOut(duration: 0.25), value: handCount)
                .onChange(of: handCount) { was, now in
                    guard let was, let now, now > was else { return }
                    bagTook = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(Bag.swellHolds))
                        bagTook = false
                    }
                }
                .animation(.easeOut(duration: 0.22), value: clampCount)
                .animation(.easeOut(duration: 0.22), value: isDimmed)
                .task(id: reboundID) {
                    guard reboundID != nil else { return }
                    await goUpForIt()
                }
                // **On arriving, not on being here.** A man who has warped somewhere
                // during a stoppage has come down there, so the falling edge is the whole
                // signal — keyed on the state itself it fired for everybody standing
                // still the moment the view appeared. Mid-play he has not landed
                // anywhere; he is still going, and a landing would stop him dead.
                .onChange(of: warp) { was, now in
                    guard was > 0, now == 0, landsFromWarp, leap == .none else { return }
                    Task {
                        // The value flips the instant the trip home starts — the columns
                        // are animated from it — so wait out the arrival. Landing while
                        // he is still in pieces is a landing nobody can see.
                        try? await Task.sleep(for: .seconds(Pacing.warp))
                        guard leap == .none else { return }
                        // Arriving for a throw-in, which he does facing upcourt.
                        facingYou = false
                        await comeDown()
                    }
                }
                .task(id: caughtAt) {
                    // The court decides who catches — it is the only thing that stamps
                    // this, and it stamps nobody but the receiver.
                    guard caughtAt != nil else { return }
                    // Stamped before the sheet swaps in, or the first frame is drawn against
                    // a start time that does not exist yet.
                    caughtFrom = Date()
                    catching = true
                    // One pass of the catch sheet at its own frame rate.
                    try? await Task.sleep(for: .seconds(Theme.Pass.catchSeconds))
                    catching = false
                }
        }
    }
}

/// The ball on the court: the 6px sprite, scaled with the players so it sits in their
/// hands at the right size.
struct PixelBallView: View {
    var scale: CGFloat = Theme.Figure.playerScale
    var shot: Int?

    private var side: CGFloat { 6 * scale }

    var body: some View {
        Image("Ball")
            .interpolation(.none)
            .resizable()
            .frame(width: side, height: side)
            .overlay(alignment: .bottom) {
                if let shot {
                    // Beside the ball rather than on it: at 18pt there is no room for a
                    // number, and scaling the ball up would break step with the sprites.
                    Text("\(shot)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                        .overlay(Capsule().stroke(PixelPalette.orange, lineWidth: 1))
                        .fixedSize()
                        .offset(y: 15)
                        .contentTransition(.numericText())
                }
            }
    }
}

/// The rebound cutscene's ball, drawn large enough to want the vector.
struct BallView: View {
    var diameter: CGFloat = 20

    var body: some View {
        Image("BallVector")
            .resizable()
            .scaledToFit()
            .frame(width: diameter, height: diameter)
    }
}
