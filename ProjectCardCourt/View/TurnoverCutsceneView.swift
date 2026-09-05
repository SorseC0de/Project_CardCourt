import SwiftUI

/// The beat a turnover gets, so it lands instead of flashing past in the log.
///
/// Two scenes, because two things happened. An ordinary turnover is a **loose ball**: no
/// player at all, just the ball arriving on an empty floor and coming to rest — showing
/// someone catching it read as a completed pass, which is the opposite of what happened.
/// A shot-clock violation is the exception: there the ball *was* caught, and the whole
/// point is that it was still in their hands when the clock died.
struct TurnoverCutsceneView: View {
    let scene: TurnoverCutscene

    private enum Loose {
        /// Where the ball settles, as shares of the scene.
        static let restX: CGFloat = 0.5
        static let restY: CGFloat = 0.6
        static let ballSide: CGFloat = 46
        /// How far the roll carries after the bounce, as a share of the width.
        static let roll: CGFloat = 0.16
        static let bounce: CGFloat = 0.155
        /// The whole arrival, in and down and round.
        static let seconds = 2.4
        /// The spotlight, as shares of the width — built round, then squashed.
        static let lightWidth: CGFloat = 0.92
        static let lightFlatten: CGFloat = 0.38
    }

    private enum Held {
        /// Bigger than the court draws them — this is a close-up.
        static let spriteScale: CGFloat = 5
        /// The catch plays from the top and stops here — the ball is met and never
        /// gathered in. Fourth frame, counting the first as one.
        static let stopAtFrame = 3
        /// The reach, played slower than the court plays a catch.
        ///
        /// A close-up is a different tempo from live play, and this scene is built on the
        /// reach landing as a beat rather than as part of a possession. Its own number, so
        /// speeding the court's catch up cannot flick this one past in a sixth of a second.
        static let fps: Double = 10
        /// How long the first of the catch takes, which is also the ball's flight.
        static var reachSeconds: Double { Double(stopAtFrame + 1) / fps }

        /// Three hard cuts on the same held moment, each tighter than the last.
        ///
        /// Hard cuts on purpose: interpolating between them would be a camera push, which
        /// is a different thing and reads as slow rather than urgent. Only the zoom is
        /// listed — the framing offset is worked out from where the ball actually is, so
        /// every cut lands on his hands however the figure is placed.
        static let cuts: [CGFloat] = [1, 1.8, 2.7]
        static let cutSeconds = 0.5
    }

    private enum Name {
        static let drop: CGFloat = 26
        /// How long before the scene ends the plate starts its trip out, so the slide
        /// finishes on screen rather than being cut off with the view.
        static let lead: Double = 0.9
    }

    @State private var nameLeaving = false
    @State private var expired = false
    @State private var flash = false
    @State private var showCaption = false
    /// The loose ball's whole arrival, 0 to 1. One value, one path — see `LooseBallRoll`.
    @State private var roll: CGFloat = 0
    /// The shot-clock scene's ball, which simply flies to a hand.
    @State private var ball: CGPoint = .zero
    @State private var ballVisible = false
    @State private var lit = false
    /// Which of the three cut-ins is on screen. Back to the wide shot once they are done.
    @State private var cut = 0
    @State private var clockIn = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if case .whistle("Travel") = scene.kind {
                    TravelCutsceneView(bit: scene.travelBit ?? .footprints)
                } else if case .shotClock = scene.kind {
                    heldAsItDied(in: geo.size)
                    caption(in: geo.size, y: 0.56)
                } else {
                    looseBall(in: geo.size)
                    caption(in: geo.size, y: 0.34)
                }

                // Whose turnover it is, across the top. The loose-ball scene has nobody
                // in shot at all, and the shot-clock one is a close-up — neither has room
                // for a plate under a pair of feet.
                VStack {
                    NameCallView(call: NameCall(seat: scene.seat),
                                 reach: geo.size.width, isLeaving: nameLeaving)
                        .padding(.top, Name.drop)
                    Spacer()
                }
            }
            .task { await run(in: geo.size) }
            .task {
                try? await Task.sleep(for: .seconds(max(0.2, scene.hold - Name.lead)))
                nameLeaving = true
            }
        }
    }

    // MARK: - Loose ball

    /// Nobody in shot. A spotlight, and the ball rolling into it.
    private func looseBall(in size: CGSize) -> some View {
        let rest = CGPoint(x: size.width * Loose.restX, y: size.height * Loose.restY)
        let direction: CGFloat = scene.fromLeft ? 1 : -1
        let side = size.width * Loose.lightWidth
        return ZStack {
            // A circular gradient squashed into an oval, rather than an oval filled with
            // one. Filling the oval leaves the gradient circular inside a squat frame, so
            // it fades at the ends and is cut off flat top and bottom — the light has to
            // be built round and then flattened for it to fall away evenly all round.
            Circle()
                .fill(RadialGradient(
                    stops: [
                        // White all the way out. `.clear` is transparent black, and a glow
                        // that walks towards it dirties its own edge.
                        .init(color: .white.opacity(0.30), location: 0),
                        .init(color: .white.opacity(0.10), location: 0.45),
                        .init(color: .white.opacity(0), location: 1),
                    ],
                    center: .center, startRadius: 0, endRadius: side / 2))
                .frame(width: side, height: side)
                .scaleEffect(y: Loose.lightFlatten)
                .position(rest)
                .opacity(lit ? 1 : 0)

            if ballVisible {
                Image("BallVector")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Loose.ballSide)
                    // Spin first, place second, travel third — rotating after `.position`
                    // turns the whole layer about the container instead of the ball.
                    // Turned by how far it has actually rolled, so it never spins faster
                    // than it travels.
                    // Front-loaded against the travel, so the turning is spent before the
                    // ball is — it comes to a halt rather than creeping the last of it out.
                    .rotationEffect(.degrees(Double(direction) * 700
                                             * pow(Double(LooseBallRoll.travelled(at: roll)), 0.5)))
                    .shadow(color: .black.opacity(0.55), radius: 8, y: 6)
                    .position(rest)
                    .modifier(LooseBallRoll(
                        t: roll,
                        direction: direction,
                        entry: CGSize(width: -direction * size.width * 0.85,
                                      height: -size.height * 0.5),
                        run: size.width * Loose.roll,
                        bounce: size.height * Loose.bounce))
            }
        }
    }

    /// Sets the ball off. The path itself decides everything after that.
    private func rollIn() async {
        withAnimation(.easeOut(duration: 0.4)) { lit = true }

        var appear = Transaction(); appear.disablesAnimations = true
        withTransaction(appear) { roll = 0; ballVisible = true }

        // Linear: every phase carries its own shape, so easing the whole thing would
        // ease each of them twice.
        withAnimation(.linear(duration: Loose.seconds)) { roll = 1 }
        try? await Task.sleep(for: .seconds(Loose.seconds))
    }

    // MARK: - Shot clock

    /// The one turnover where the ball really was in their hands.
    private func heldAsItDied(in size: CGSize) -> some View {
        let side = Sprite.run.frameSize * Held.spriteScale
        // The figure on its own, so the hand can be measured from its feet — putting it
        // in a stack with its name centred the pair instead and moved the feet.
        let centre = CGPoint(x: size.width / 2, y: size.height - 150 - side / 2)
        let footing = CGPoint(x: centre.x, y: centre.y + side / 2)
        // Which way he is turned decides all three: the sprite, the hand the ball lands
        // in, and the side it flies in from. Reading them from separate places is what
        // let the ball arrive at his back — the court mirrors West always and the centre
        // line only for a pass from the left, and this scene was ignoring the seat.
        let fromEast = Seat.allCases.first {
            $0.slot(viewedFrom: GameRules.localSeat) == .east
        }
        let facingBall = PlayerFigure.catchIsMirrored(
            seat: scene.seat, facing: scene.fromLeft ? nil : fromEast)
        let flip: CGFloat = facingBall ? -1 : 1
        let hand = CGPoint(x: footing.x + side * Theme.Pass.handX * flip,
                           y: footing.y - side * Theme.Pass.handY)

        let scale = Held.cuts[min(cut, Held.cuts.count - 1)]
        // Pull the shot back so the zoom lands on the ball rather than on empty floor.
        let framing = CGSize(width: -(scale - 1) * (hand.x - size.width / 2),
                             height: -(scale - 1) * (hand.y - size.height / 2))

        return ZStack {
            VStack(spacing: 10) {
                shotClockBoard
                HoopBackdrop()
            }
            .position(x: size.width / 2, y: size.height * 0.24)
            .opacity(clockIn ? 1 : 0)

            // Player and ball framed as one, so a cut moves the whole shot rather than
            // sliding the ball out of his hands.
            ZStack {
                PlayerFigure(seat: scene.seat, sprite: .catchBall, playsOnce: true,
                             fps: Held.fps,
                             stopAtFrame: Held.stopAtFrame, mirrored: facingBall,
                             scale: Held.spriteScale)
                    .position(centre)

                // Gone the moment he has it — the sprite is holding one of its own from
                // here, and two balls in one pair of hands reads as a mistake.
                if ballVisible {
                    // The court draws the ball at whatever scale it draws the player, so
                    // this scene has to as well or it lands the wrong size in his hands.
                    PixelBallView(scale: Held.spriteScale)
                        .position(ball)
                }
            }
            .scaleEffect(scale)
            .offset(framing)
        }
        .onAppear {
            var appear = Transaction(); appear.disablesAnimations = true
            withTransaction(appear) {
                ball = CGPoint(x: hand.x + (facingBall ? -1 : 1) * size.width * 0.9,
                               y: -size.height * 0.2)
                ballVisible = true
            }
            // Exactly as long as the reach takes, so the ball lands on the frame his
            // hands close — one number, both halves.
            withAnimation(.easeOut(duration: Held.reachSeconds)) { ball = hand }
        }
    }

    /// The box on the backboard, lighting red as it dies — the NBA tell.
    private var shotClockBoard: some View {
        SevenSegmentClock(value: expired ? 0 : 1, digitSize: CGSize(width: 30, height: 56))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(flash ? Theme.clockRed : Color.white.opacity(0.25),
                                    lineWidth: flash ? 4 : 1.5)
                    }
                    .shadow(color: flash ? Theme.clockRed.opacity(0.9) : .clear, radius: 18)
            }
    }

    // MARK: - Word

    /// Floats down into place as it fades up, rather than popping.
    private func caption(in size: CGSize, y: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text("TURNOVER")
                .font(.system(size: 13, weight: .black)).tracking(2.4)
                .foregroundStyle(Theme.danger)
            Text(captionText)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 24)
                // Hard and south-east, like every other mark in the game. Flattened
                // first, or it is cast per glyph rather than once for the line.
                .compositingGroup()
                .shadow(color: CardPalette.red, radius: 0, x: 3, y: 3)
        }
        .opacity(showCaption ? 1 : 0)
        .offset(y: showCaption ? 0 : -34)
        .position(x: size.width / 2, y: size.height * y)
    }

    private var captionText: String {
        switch scene.kind {
        case .shotClock:            return "Shot Clock Violation"
        case .badReturn:            return "Nobody to give it back to"
        case .whistle(let name):    return name
        }
    }

    private func run(in size: CGSize) async {
        if case .shotClock = scene.kind {
            // He reaches, the ball arrives, and it is his. Then three cuts on it, then
            // the clock has its say. Set unanimated — a cut is a cut.
            try? await Task.sleep(for: .seconds(Held.reachSeconds))
            ballVisible = false
            try? await Task.sleep(for: .seconds(0.45))

            var hard = Transaction(); hard.disablesAnimations = true
            for step in 1..<Held.cuts.count {
                withTransaction(hard) { cut = step }
                try? await Task.sleep(for: .seconds(Held.cutSeconds))
            }
            // Held on the last cut. Pulling back out before the clock arrives threw the
            // moment away — the clock sits outside the framing and reads over him fine.
            withAnimation(.easeOut(duration: 0.4)) { clockIn = true }
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.easeOut(duration: 0.12)) { expired = true; flash = true }
            try? await Task.sleep(for: .seconds(0.28))
        } else if case .whistle("Travel") = scene.kind {
            return
        } else {
            await rollIn()
            try? await Task.sleep(for: .seconds(0.2))
        }
        withAnimation(.easeOut(duration: 0.5)) { showCaption = true }
    }
}

#if DEBUG
#Preview("Turnover — loose ball") {
    TurnoverCutsceneView(scene: TurnoverCutscene(seat: .south, kind: .whistle("Back Court Violation"),
                                                 fromLeft: true))
}

#Preview("Turnover — shot clock") {
    TurnoverCutsceneView(scene: TurnoverCutscene(seat: .east, kind: .shotClock, fromLeft: false))
}
#endif
