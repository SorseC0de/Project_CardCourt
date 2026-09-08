import SwiftUI

struct ShotCutsceneView: View {
    let scene: ShotCutscene

    @State private var flight: CGFloat = 0
    @State private var showResult = false
    /// Where the men contesting the shot stand.
    ///
    /// Three used to be a row of three at one depth, elbow to elbow and nearly as tall as
    /// the shooter. They stand off him now, and the middle one stands **behind** the
    /// other two rather than beside them — which is what a double or triple team actually
    /// looks like, and what lets three read as three rather than as a smear.
    private enum Wall {
        static let scale: CGFloat = 1.25
        /// How far apart, and how far up the court a man standing back is.
        static let spread: CGFloat = 96
        static let lift: CGFloat = 46
        static let base: CGFloat = 196
        /// How much smaller the man at the back is.
        static let shrink: CGFloat = 0.16
        /// The contest is live, so the wall never quite stands still: a slow lateral
        /// shuffle, each man on his own clock so the three do not sway as one board.
        static let shuffle: CGFloat = 9
        static let shuffleSeconds: Double = 1.8
        static let shuffleStagger: Double = 0.35

        /// `x` in multiples of the spread, `back` in multiples of the lift.
        static func spots(for count: Int) -> [(x: CGFloat, back: CGFloat)] {
            switch count {
            case 0:  return []
            case 1:  return [(0, 0)]
            case 2:  return [(-0.6, 0), (0.6, 0)]
            case 3:  return [(-0.9, 0), (0, 1), (0.9, 0)]
            // Four or more is not a thing the rules can produce, but a Clamp stack that
            // grows one day should spread rather than pile up on the same three marks.
            default:
                return (0..<count).map { index in
                    let along = CGFloat(index) / CGFloat(count - 1) * 2 - 1
                    return (along * 1.1, index.isMultiple(of: 2) ? 0 : 1)
                }
            }
        }
    }

    /// Where a man stands, and what he stands relative to.
    ///
    /// **A jumper stands on the floor; a man finishing at the rim stands under the ring.**
    /// They are not the same anchor. The floor is counted up from the bottom of the
    /// screen and moves with it; the board is pinned to the top by `Hoop.drop` and never
    /// does — so a trip tuned at one height arrives above the ring at another, which is
    /// why every dunk was two or three art pixels over the iron on a phone after being
    /// tuned in the preview canvas. The climb is measured against the ring, so he is
    /// placed against it too.
    private enum Stage {
        /// How far up from the bottom of the screen a man stands.
        static let floor: CGFloat = 132
        /// What the whole figure is blown up by once it is placed.
        static let gather: CGFloat = 1.7
    }

    /// What is drawn over what. **Named, because two of them move**: a man finishing at
    /// the rim climbs from in front of the wall to behind it and back out over the ring.
    private enum Depth {
        static let backdrop: Double = 0
        /// Whose shot this is, said across the top.
        static let name: Double = 1
        /// The ball, and a man on his way up to the ring — both between the board and
        /// the men on the floor.
        static let climbing: Double = 1
        static let ball: Double = 1
        /// The contest, and the near half of the ring they stand level with.
        static let wall: Double = 2
        static let rim: Double = 2
        /// Whoever is taking the shot, over everything on the floor.
        static let shooter: Double = 3
        /// What comes off the ring, over all of it.
        static let burst: Double = 4
    }

    private enum Name {
        static let drop: CGFloat = 26
        /// How long before the scene ends the plate starts its trip out. Long enough that
        /// the slide finishes on screen rather than being cut off with the view.
        static let lead: Double = 0.9
    }

    @State private var nameLeaving = false
    /// Flipped once when the scene opens; the wall's shuffle repeats off it forever.
    @State private var shuffling = false
    /// Raised when the shot animation has run out, on the shots that turn him around.
    @State private var facingYou = false
    @State private var showBurst = false
    /// When the ball reached the rim, which is what the net decays from.
    @State private var struckAt: Date?
    /// Kept off the flight animation, so the ball appears rather than fading in.
    @State private var released = false
    @State private var ballGone = false
    /// The camera pushing in while the ball is at the rim.
    @State private var zoom: CGFloat = 1
    /// The ball's whole performance at the rim, as one value.
    @State private var drama: CGFloat = 0
    /// Set when a robbery turns: the board goes red as the ball starts climbing out.
    @State private var robbed = false
    /// Set once it is all the way out, which is when the word is taken back.
    @State private var siiike = false
    /// Observed, not just read — otherwise moving a slider changes nothing on screen.
    @State private var tuning = ShotTuning.shared
    /// The ball a dunk leaves behind: whether it is out yet, and whether it has fallen.
    @State private var dunkBallOut = false
    @State private var dunkBallFell = false
    /// How hard the rim is being hung on, nought to one. Both halves read it, or the
    /// ring comes apart down the middle.
    @State private var rimPull: CGFloat = 0
    /// When the rim gave, so the burst off it plays once from there — cleared when it
    /// has finished, which is what takes it off the screen.
    @State private var rimGaveAt: Date?
    /// Whether there is a loose ball to draw at all: he keeps his unless the rim takes
    /// it off him, and a make has one dropping out of the net.
    private var dunkBallShows: Bool {
        scene.made || scene.dunkMiss?.reachesTheRim == true
    }

    /// How far a ball off the iron carries as it falls, against one dropping through the
    /// net. Kept out rather than dropped in, so it does not read as a late make.
    private var caromAway: CGFloat { scene.made ? 1 : DunkBall.carom }

    /// Whether the rim has already answered. **Its own flag, not `rimGaveAt == nil`**:
    /// that is cleared the moment the burst ends, so a reverse's next swing found it
    /// empty and set the whole thing off again, once a second, for the rest of the scene.
    @State private var rimAnswered = false
    /// Whether the man finishing at the rim is behind the men contesting him. **He climbs
    /// past them**: the ring is upcourt, so the trip goes away from the camera. He says
    /// when it changes — see `DunkFigure.onDepth`.
    @State private var dunkBehind = false
    /// Which burst this finish throws — see `DunkStyle.Trip.burst`.
    @State private var dunkTuning = DunkTuning.shared

    /// What drops out of the net after one is thrown down.
    private enum DunkBall {
        /// How far it falls, against the rim's own width.
        static let fall: CGFloat = 0.9
        /// **Fast, and fast from the first frame.** It was easing *in* over two seconds,
        /// which is a ball being lowered — a dunked one leaves the hand at speed and the
        /// drop is the only thing carrying that. Out, not in, and a third of a second.
        static let drop: Double = 0.35
        static let curve = Animation.easeOut(duration: drop)
        /// How long it sits before it goes: a ball that fades as it appears never reads
        /// as having been there at all.
        static let hold: Double = 0.25
        static let fade: Double = 0.40
        /// How much further one the iron kept travels on its way down. It is leaving,
        /// not arriving.
        static let carom: CGFloat = 1.6
        /// A beat on the rim before it goes anywhere, so there is a ball there to watch
        /// come off it. One frame at sixty is not a beat; three is.
        static let leaves: Double = 3.0 / 60
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Backdrop, ball, then the near half of the rim on top — the ball
                // passes between the two halves rather than over the ring.
                VStack {
                    HoopBackdrop(width: tuning.rimWidth, struckAt: struckAt,
                                 light: boardLight, pull: rimPull)
                        .padding(.top, Hoop.drop)
                    Spacer()
                }
                .zIndex(Depth.backdrop)

                // Whose shot this is, said across the top rather than under his feet: the
                // camera pushes in on the rim, and a plate on the floor is either off the
                // bottom of the shot or too small to read.
                VStack {
                    NameCallView(call: NameCall(seat: scene.shooter),
                                 reach: geo.size.width, isLeaving: nameLeaving)
                        .padding(.top, Name.drop)
                    Spacer()
                }
                .zIndex(Depth.name)

                // Held until the ball is actually at the rim.
                if let burst, showBurst {
                    EmojiBurst(emoji: burst.emoji, count: burst.count,
                               ink: scene.signature == .understood ? .white : nil,
                               drop: scene.signature == .understood ? CardPalette.blue : nil)
                        .position(rimPoint(in: geo.size))
                }

                Group {
                    if scene.made {
                        if showResult {
                            if scene.signature == .understood {
                                understood
                            } else {
                                SwisshTitle(line: scene.line)
                            }
                        }
                    } else if scene.drama == .robbery {
                        // It counts, right up until it doesn't. The make's word holds
                        // until the robbery arrives, then clears out from under it —
                        // stacked, the two are unreadable.
                        ZStack {
                            if showResult {
                                SwisshTitle()
                                    .opacity(siiike ? 0 : 1)
                                    .animation(.easeOut(duration: 0.15), value: siiike)
                            }
                            if siiike {
                                SwisshTitle(text: "Siiike!!!", top: Theme.ball,
                                            bottom: Theme.danger, glow: Theme.danger)
                            }
                        }
                    } else {
                        Text(scene.missCall)
                            // The long one has to fit; the loud one gets to be loud.
                            .font(.system(size: scene.missCall == "BRRRICK" ? 40
                                                : (scene.missCall.count > 10 ? 26 : 34),
                                          weight: .black, design: .rounded))
                            .tracking(scene.missCall == "BRRRICK" ? 2 : 0)
                            .foregroundStyle(Theme.danger)
                            .compositingGroup()
                            .shadow(color: CardPalette.navy, radius: 0, x: 4, y: 4)
                            .opacity(showResult ? 1 : 0)
                            .scaleEffect(showResult ? 1 : 0.7)
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height * 0.42)

                // Whoever was contesting is still contesting.
                ForEach(Array(Wall.spots(for: scene.defenders).enumerated()),
                        id: \.offset) { index, spot in
                    // Turned to face the shooter, so a pair of them close from both
                    // sides rather than both looking the same way.
                    DefenderFigure(seat: scene.shooter, mirrored: spot.x < 0)
                        // Further back stands smaller, which is what stops the middle man
                        // of three reading as a giant behind the other two.
                        .scaleEffect(Wall.scale * (1 - Wall.shrink * spot.back),
                                     anchor: .bottom)
                        // Sliding while the shot is up. Alternating directions and a
                        // stagger apiece, or the wall sways as one piece of scenery.
                        .offset(x: (shuffling ? 1 : -1) * Wall.shuffle
                                * (index.isMultiple(of: 2) ? 1 : -1))
                        .animation(.easeInOut(duration: Wall.shuffleSeconds)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * Wall.shuffleStagger),
                                   value: shuffling)
                        .position(x: geo.size.width / 2 + Wall.spread * spot.x,
                                  y: geo.size.height - Wall.base - Wall.lift * spot.back)
                        // A band of their own, so a man climbing past them has somewhere
                        // to be. Level with the ring: a contest happens at it.
                        .zIndex(Depth.wall)
                }

                VStack(spacing: 8) {
                    // Never mirrored here, whoever is shooting. On the court West faces
                    // the other way; in a cutscene there is no court to face, and one
                    // player turned around reads as a mistake rather than as staging.
                    // **Two poses, one figure.** The shot plays out as it always does;
                    // on the shots that are about the shooter rather than the ball, he
                    // turns to the room the moment it is done with him.
                    Group {
                        if facingYou {
                            // The follow-through, held. He is watching it go in.
                            PlayerFigure(seat: scene.shooter, sprite: .gooseneck,
                                         spriteFrame: 0, mirrored: false)
                        } else if let dunk = scene.dunk {
                            // **He does not shoot it.** A finish at the rim is its own
                            // trip — gather, climb, arrive — and it replaces the jumper
                            // rather than dressing it up. See `DunkFigure`.
                            DunkFigure(seat: scene.shooter, dunk: dunk,
                                       miss: scene.dunkMiss, onBallLoose: {
                                // **Out first, then away.** Both were raised in the same
                                // tick, so the ball was created already at the end of its
                                // trip: no bounce off the iron ever played, because there
                                // was nothing between where it appeared and where it was
                                // going. It leaves his hands on one frame and starts
                                // travelling on the next.
                                dunkBallOut = true
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(DunkBall.leaves))
                                    dunkBallFell = true
                                }
                            }, onDepth: { behind in
                                dunkBehind = behind
                            }, onRimPull: { amount, spring in
                                // Whatever he just did to it, on his curve. He calls this
                                // at every change he makes, so nothing here has to guess
                                // at his timing.
                                if let spring {
                                    withAnimation(spring) { rimPull = amount }
                                } else {
                                    rimPull = amount
                                }
                                // The burst is the first grab only. One a swing would be
                                // the rim throwing sparks for the rest of the scene.
                                if amount == 1, !rimAnswered {
                                    rimAnswered = true
                                    // **A miss gets no light off the rim.** The burst is
                                    // the ring answering a ball put through it; one that
                                    // came back out has nothing to celebrate.
                                    guard scene.made else { return }
                                    let burst = dunkTuning.trip(for: scene.dunk ?? .oneHand)
                                    let skipped = Double(burst.burstSkip) / burst.burstFPS
                                    // **Started part-played.** Dating it back by the
                                    // cells being cut puts the sheet straight into its
                                    // bang — a wind-up here is a rim that gives half a
                                    // second before anything comes off it.
                                    let at = Date().addingTimeInterval(-skipped)
                                    rimGaveAt = at
                                    // **Taken away when it is done.** `playsOnce` holds
                                    // the last cell rather than clearing it, so whatever
                                    // the drawing ends on sat over the rim for the rest
                                    // of the scene. Nothing else on the floor shows,
                                    // because everything else that plays once is a man
                                    // who is meant to still be standing there.
                                    let over = Double(burst.burst.frames) / burst.burstFPS
                                        - skipped
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .seconds(over))
                                        if rimGaveAt == at { rimGaveAt = nil }
                                    }
                                    // **And the emoji go now, with the slam.** They are
                                    // timed off the ball reaching the rim everywhere
                                    // else, and a dunk has no ball in the air — that
                                    // clock counts a release cell off the shoot sheet
                                    // and a flight neither of which happens here, so
                                    // they were landing three quarters of a second after
                                    // he had already put it in.
                                    showBurst = true
                                    if scene.made { struckAt = Date() }
                                }
                            })
                        } else {
                            PlayerFigure(seat: scene.shooter, sprite: .shoot,
                                         playsOnce: true, fps: Theme.Figure.shootFPS,
                                         mirrored: false)
                        }
                    }
                    .scaleEffect(Stage.gather)
                    Text("SHOT \(scene.chance)%")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }
                .position(x: geo.size.width / 2, y: stageY(in: geo.size))
                // **Over the ring, not behind it.** A jumper is downcourt of the rim and
                // reads right behind its near half; a man finishing at it is on top of it
                // — except on the way up, where he is climbing past the wall and the ring
                // both. See `DunkFigure.onDepth`.
                .zIndex(dunkBehind ? Depth.climbing : Depth.shooter)

                PixelBallView(scale: tuning.ballScale
                              + (tuning.ballEndScale - tuning.ballScale) * min(flight, 1))
                    .opacity(scene.dunk == nil && released && !ballGone ? 1 : 0)
                    .animation(released ? .easeOut(duration: 0.25) : nil, value: ballGone)
                    // Spin the ball itself, then place it, then move it. Rotating after
                    // `.position` swings the whole layer around the container's centre
                    // rather than turning the ball, and any translation after that is
                    // composed with the rotation — which is what threw it across the
                    // screen.
                    .rotationEffect(.degrees(Double(flight) * 540 + Double(drama) * 360))
                    .position(startPoint(in: geo.size))
                    .modifier(DramaPath(progress: drama, drama: scene.drama,
                                        rim: tuning.rimWidth * 0.5))
                    .modifier(BallFlight(t: flight,
                                         start: startPoint(in: geo.size),
                                         control: controlPoint(in: geo.size),
                                         rim: rimPoint(in: geo.size),
                                         after: afterPoint(in: geo.size)))
                    .zIndex(Depth.ball)

                // **The one a dunk leaves.** It comes out of the net once he has let go
                // of the one drawn in his hands, drops, and fades — a ball settling after
                // the fact rather than a shot arriving.
                // **Only a ball that got to the rim comes off it.** He carries his own
                // through the whole trip — it is drawn into every dunk sheet — so one
                // that sails past or falls short never lets go of it, and there is
                // nothing here to draw.
                if scene.dunk != nil, dunkBallOut, dunkBallShows {
                    PixelBallView(scale: tuning.ballEndScale)
                        .position(rimPoint(in: geo.size))
                        // A ball kept by the iron rattles it or kicks off the back of it
                        // before it drops — see `ShotDrama.offTheIron`.
                        .modifier(DramaPath(progress: dunkBallFell ? 1 : 0,
                                            drama: scene.drama,
                                            rim: tuning.rimWidth * 0.5))
                        .offset(y: dunkBallFell
                                ? tuning.rimWidth * DunkBall.fall * caromAway : 0)
                        .animation(DunkBall.curve, value: dunkBallFell)
                        .opacity(dunkBallFell ? 0 : 1)
                        .animation(.easeOut(duration: DunkBall.fade).delay(DunkBall.hold),
                                   value: dunkBallFell)
                        .zIndex(Depth.ball)
                }

                // **What the rim gives back.** The ring springing on its own is a part
                // moving; this is the energy coming off it, out of the net and upward.
                if let rimGaveAt {
                    let finish = dunkTuning.trip(for: scene.dunk ?? .oneHand)
                    SpriteAnimation(sprite: finish.burst,
                                    scale: DunkStyle.burstScale,
                                    fps: finish.burstFPS,
                                    playsOnce: true, startedAt: rimGaveAt)
                        .position(rimPoint(in: geo.size))
                        .allowsHitTesting(false)
                        .zIndex(Depth.burst)
                }

                // Red and heavy while the layering is being sorted out.
                RimHalf(isNear: true, width: tuning.rimWidth * Hoop.ring,
                        thickness: 8, tint: PixelPalette.vermilion)
                    .position(x: rimPoint(in: geo.size).x,
                              y: rimPoint(in: geo.size).y + geo.size.height * tuning.rimNearY)
                    .offset(y: rimPull * tuning.rimWidth * DunkStyle.rimDrop)
                    .zIndex(Depth.rim)
            }
            .scaleEffect(zoom, anchor: UnitPoint(x: tuning.rimX, y: tuning.rimY))
            .task { shuffling = true }
            // **At the release, not at the end of the sheet.** The gooseneck *is* the
            // follow-through — he holds it while the ball is up, which means turning to
            // the room the moment it leaves his hand. Timed off the whole thirteen cells
            // he turned as the ball came down, with nothing left to watch. Off the same
            // dial the ball leaves on, so the two cannot drift apart.
            .task {
                guard scene.signature != .none else { return }
                try? await Task.sleep(for: .seconds(tuning.releaseDelay
                                                    / max(0.1, tuning.tempo)))
                facingYou = true
            }
            .task { await run() }
        }
    }

    /// What the hoop throws back. Deliberately gapped — an ordinary make or a
    /// respectable miss gets nothing, so the burst always means something.
    private var burst: (emoji: [String], count: Int)? {
        // He knew, so it is arithmetic rather than confetti — and it is the only burst:
        // the line's own emoji would otherwise arrive alongside it.
        if scene.signature == .understood, scene.made {
            return (Understood.marks, Understood.count)
        }
        if let banked = scene.drama.burst { return banked }
        if scene.made {
            // A line brings its own — the emoji is part of the joke, so it beats both the
            // fire and the spoils rather than being averaged with them.
            if !scene.line.emoji.isEmpty { return (scene.line.emoji, 22) }
            if scene.chance >= 80 { return (["🔥"], 24) }
            // Buckets, flying cash or a bag of it — a decent make is worth something.
            if scene.chance >= 50 { return ([scene.spoils], 20) }
            return nil
        }
        return scene.chance < 40 ? (["🧱"], 22) : nil
    }

    /// Where the man stands — see `Stage`. A dunk is placed under the ring; everything
    /// else stands on the floor, where it always did.
    private func stageY(in size: CGSize) -> CGFloat {
        let floor = size.height - Stage.floor
        guard let dunk = scene.dunk else { return floor }
        // **The floor he stands on is the jumper's, and always was.** Hanging him off the
        // ring instead was meant to make the two agree at any height; it made the trip
        // worse, and the drawing is the thing being judged. He stands where he stood, a
        // few pixels lower.
        let pixel = Theme.Figure.playerScale
            * dunkTuning.trip(for: dunk).arrivesAt * Stage.gather
        return floor + dunkTuning.overTheRim * pixel
    }

    private func rimPoint(in size: CGSize) -> CGPoint {
        return CGPoint(x: size.width * tuning.rimX, y: size.height * tuning.rimY)
    }

    /// A make lights the board green. A robbery counts first and is taken back after, so
    /// its green hangs off the very same flag a make's does and lands on the same clock.
    private var boardLight: Color? {
        if scene.drama == .robbery {
            if robbed { return Theme.danger }
            return showResult ? Theme.live : nil
        }
        return scene.made && showResult ? Theme.live : nil
    }

    private func startPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * tuning.startX, y: size.height * tuning.startY)
    }

    private func controlPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * (0.5 + tuning.archX),
                y: rimPoint(in: size).y - size.height * tuning.archHeight)
    }

    /// Down through the net, or off the iron — up and away at an angle, clear of the
    /// screen before the rebound takes over.
    private func afterPoint(in size: CGSize) -> CGPoint {
        let rim = rimPoint(in: size)
        return scene.made
            ? CGPoint(x: rim.x, y: size.height * 1.25)
            : CGPoint(x: rim.x + size.width * 0.9 * scene.caromSide, y: -size.height * 0.35)
    }

    /// What a Lethal Shooter make throws instead of confetti: the operators, a target, a
    /// brain, and the ones and noughts under all of it.
    private enum Understood {
        static let marks = ["🧠", "🎯", "✖️", "➕", "➗", "♾️", "√", "√", "1", "0", "1", "0"]
        static let count = 26
        /// Big enough to read across a room, and it stays that size.
        static let size: CGFloat = 34
        static let drop: CGFloat = 3
    }

    /// He is not being congratulated; he is being told he was right.
    ///
    /// **Not `ActionText`.** That face is a word or two shouted across the screen, and a
    /// whole sentence set in it has to shrink to fit — by the time it fits, it cannot be
    /// read. This one holds its size and wraps instead.
    private var understood: some View {
        Text(understoodLine)
            .font(.system(size: Understood.size, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: CardPalette.blue, radius: 0,
                    x: Understood.drop, y: Understood.drop)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 26)
    }

    /// "Raheem understands it now.", and "You understand it now."
    private var understoodLine: String {
        let seat = scene.shooter
        return "\(seat.playerName) \(seat.verb("understands", "understand")) it now."
    }

    private func run() async {
        let tempo = max(0.1, tuning.tempo)
        // Its own clock, so the name is not waiting on the ball's business at the rim.
        Task { @MainActor in
            let scene = Pacing.cutscene + self.scene.drama.seconds - Name.lead
            try? await Task.sleep(for: .seconds(max(0.2, scene)))
            nameLeaving = true
        }
        try? await Task.sleep(for: .seconds(tuning.releaseDelay / tempo))
        released = true
        // Linear: easing out here made the ball decelerate into the rim and stall.
        withAnimation(.linear(duration: tuning.flightSeconds / tempo)) { flight = 1 }

        // Fire and forget, so the word keeps its own clock and can land while the ball
        // is still in the air. Awaiting it would just stall everything behind it.
        // A robbery is a make for as long as it lasts, so its word keeps a make's clock
        // instead of waiting the drama out like every other variant's does.
        let wordDelay = tuning.wordDelay / tempo
            + (scene.drama == .robbery ? 0 : scene.drama.seconds)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(wordDelay))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { showResult = true }
        }

        try? await Task.sleep(for: .seconds(tuning.flightSeconds / tempo))
        await playDrama(tempo: tempo)

        // A dunk has already done both of these, off the rim rather than off the ball.
        if scene.dunk == nil {
            showBurst = true
            // Only a make disturbs the net; a miss never reaches it.
            if scene.made { struckAt = Date() }
        }
        // A make drops; a miss carries its speed off the top of the screen.
        withAnimation(.easeIn(duration: scene.made ? 0.55 : 0.6)) { flight = 2 }
        try? await Task.sleep(for: .seconds(0.42))
        ballGone = true
    }

    /// The ball's business at the rim. Every branch ends where the rules already decided
    /// it would; the variant only chooses how long it takes to admit it.
    private func playDrama(tempo: Double) async {
        guard scene.drama != .none else { return }
        let seconds = scene.drama.seconds / tempo

        // Every variant but the robbery pushes in. A real make never does, and a camera
        // move here would announce the miss before the board takes the points back.
        if scene.drama != .robbery {
            withAnimation(.easeInOut(duration: 0.28)) { zoom = 1.75 }
        }

        // A robbery really does go through, so the net has to whip — otherwise the ball
        // reads as passing in front of it. The green is already up by now; this is the
        // moment it is taken away.
        if scene.drama == .robbery {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds * Double(Robbery.through)))
                struckAt = Date()
                try? await Task.sleep(for: .seconds(seconds * Double(Robbery.reverse - Robbery.through)))
                robbed = true
            }
        }
        // One value, one curve. The path itself decides what the ball does.
        withAnimation(scene.drama == .robbery ? .linear(duration: seconds)
                                              : .easeInOut(duration: seconds)) { drama = 1 }
        try? await Task.sleep(for: .seconds(seconds))
        if scene.drama == .robbery { siiike = true; return }

        withAnimation(.easeInOut(duration: 0.3)) { zoom = 1 }
    }
}
