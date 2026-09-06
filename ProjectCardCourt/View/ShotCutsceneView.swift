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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Backdrop, ball, then the near half of the rim on top — the ball
                // passes between the two halves rather than over the ring.
                VStack {
                    HoopBackdrop(width: tuning.rimWidth, struckAt: struckAt,
                                 light: boardLight)
                        .padding(.top, 46)
                    Spacer()
                }
                .zIndex(0)

                // Whose shot this is, said across the top rather than under his feet: the
                // camera pushes in on the rim, and a plate on the floor is either off the
                // bottom of the shot or too small to read.
                VStack {
                    NameCallView(call: NameCall(seat: scene.shooter),
                                 reach: geo.size.width, isLeaving: nameLeaving)
                        .padding(.top, Name.drop)
                    Spacer()
                }
                .zIndex(1)

                // Held until the ball is actually at the rim.
                if let burst, showBurst {
                    EmojiBurst(emoji: burst.emoji, count: burst.count,
                               ink: scene.signature == .understood ? .white : nil,
                               drop: scene.signature == .understood ? CardPalette.blue : nil)
                        .position(rimPoint(in: geo.size))
                }

                Group {
                    if scene.made {
                        // **The plain word for a Lethal Shooter make.** A sentence set
                        // across the screen shrinks to fit and stops being readable, and
                        // the line's own joke — a genie, a fishing rod — is not the story
                        // on this one. The burst says the rest.
                        if showResult {
                            SwisshTitle(line: scene.signature == .understood
                                        ? .plain : scene.line)
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
                            .font(.system(size: scene.missCall == "BRRRICK" ? 40 : 34,
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
                        } else {
                            PlayerFigure(seat: scene.shooter, sprite: .shoot,
                                         playsOnce: true, fps: Theme.Figure.shootFPS,
                                         mirrored: false)
                        }
                    }
                    .scaleEffect(1.7)
                    Text("SHOT \(scene.chance)%")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }
                .position(x: geo.size.width / 2, y: geo.size.height - 132)

                PixelBallView(scale: tuning.ballScale
                              + (tuning.ballEndScale - tuning.ballScale) * min(flight, 1))
                    .opacity(released && !ballGone ? 1 : 0)
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
                    .zIndex(1)

                // Red and heavy while the layering is being sorted out.
                RimHalf(isNear: true, width: tuning.rimWidth * 0.54,
                        thickness: 8, tint: PixelPalette.vermilion)
                    .position(x: rimPoint(in: geo.size).x,
                              y: rimPoint(in: geo.size).y + geo.size.height * tuning.rimNearY)
                    .zIndex(2)
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

        showBurst = true
        // Only a make disturbs the net; a miss never reaches it.
        if scene.made { struckAt = Date() }
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
