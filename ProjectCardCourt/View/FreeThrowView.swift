import SwiftUI

/// Shooting from the line.
///
/// The only place in the game where the player's hands decide an outcome instead of a
/// roll. Flick the ball up: how far you pull decides the strength, and where your finger
/// finishes decides the aim.
///
/// An opponent's trip runs through the same view with `auto` set, so a free throw looks
/// the same whichever side of the table it is shot from.
struct FreeThrowView: View {
    let trip: FreeThrowTrip
    /// nil when the player is shooting. Otherwise the outcome the rules already rolled,
    /// which the view flicks the ball to match.
    let auto: Bool?
    var onResult: (Bool) -> Void = { _ in }

    /// How far up a perfect flick pulls, as a fraction of the screen.
    private static let perfectPull: CGFloat = 0.45
    /// The strength window, either side of perfect.
    private static let powerWindow: ClosedRange<CGFloat> = 0.70...1.35
    /// How far off line the flick may finish, as a fraction of the screen's width.
    private static let aimWindow: CGFloat = 0.15

    /// Where the ball rests before it is thrown, as a share of the scene's height.
    private static let restY: CGFloat = 0.80
    /// Big in the hands, ordinary by the time it reaches the ring.
    private static let ballStartScale: CGFloat = 24
    private static let ballEndScale: CGFloat = 7
    private static let rimWidth: CGFloat = 132
    private static let boardTop: CGFloat = 54

    /// Why a throw missed, so the word can say the true thing.
    private enum Verdict {
        case good, short, long, wide

        var word: String {
            switch self {
            case .good:  return "GOOD"
            case .short: return "SHORT"
            case .long:  return "LONG"
            case .wide:  return "OFF THE MARK"
            }
        }
    }

    @State private var drag: CGSize = .zero
    @State private var launched = false
    @State private var flight: CGFloat = 0
    @State private var verdict: Verdict?
    @State private var struckAt: Date?
    /// Where the flick sent it, held so the arc does not move once it is in the air.
    @State private var aim: CGFloat = 0
    @State private var power: CGFloat = 1

    /// The ring's own centre, read off `HoopBackdrop`'s stack rather than guessed.
    ///
    /// The backdrop lays out the board, then the net stack under it, then lifts that
    /// stack back over the board with an offset — which moves the ring visually without
    /// moving its layout. Anything placed on top of the ring has to walk the same three
    /// steps or it sits off it, which is exactly what the near half was doing.
    private var rimCentreY: CGFloat {
        Self.boardTop
            + Self.rimWidth * 0.67          // the board
            - Self.rimWidth * 0.04          // the net stack's lift
            + Self.rimWidth * 0.3 * 0.27 / 2   // half the ring's own height
    }

    var body: some View {
        GeometryReader { geo in
            let rest = CGPoint(x: geo.size.width / 2, y: geo.size.height * Self.restY)
            let rim = CGPoint(x: geo.size.width / 2, y: rimCentreY)

            ZStack {
                Color.black.ignoresSafeArea()

                // The painted floor, standing on the bottom of the scene. Its own
                // background fades up into near black, so it meets the dark above it
                // without a seam — no mask needed.
                Image("SwisshCourt")
                    .resizable()
                    // Fills the scene: this is the backdrop the whole thing stands in,
                    // not a strip of floor along the bottom. Cropped at the sides rather
                    // than letterboxed, since the key is what matters and the sidelines
                    // are not.
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    // Flattened once. It is the largest vector in the game and would
                    // otherwise be re-rasterised on any size change under it.
                    .drawingGroup()
                    .ignoresSafeArea()

                VStack {
                    HoopBackdrop(width: Self.rimWidth, struckAt: struckAt, light: light)
                        .padding(.top, Self.boardTop)
                    Spacer()
                }
                .zIndex(0)

                header.position(x: geo.size.width / 2, y: geo.size.height * 0.44)

                ball(rest: rest, rim: rim, in: geo.size).zIndex(1)

                RimHalf(isNear: true, width: Self.rimWidth * 0.54,
                        thickness: 8, tint: PixelPalette.vermilion)
                    .position(x: rim.x, y: rim.y)
                    .zIndex(2)

                // Clear from the top down to the ball's waist, then into black, so the
                // ball rises out of the dark instead of sitting on a dimmed screen.
                // Everything above it is untouched, and none of it takes a touch.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: Self.restY - 0.1),
                        // Not solid: the court is painted along this edge, and an opaque
                        // stop buried it. Dark enough to lift the ball off the floor,
                        // sheer enough to leave the floor there.
                        .init(color: .black.opacity(0.72),
                              location: Self.restY + ballRadius / geo.size.height - 0.05),
                    ],
                    startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(3)

                if !launched, auto == nil {
                    Text("FLICK UP TO SHOOT")
                        .font(.system(size: 11, weight: .heavy)).tracking(2)
                        .foregroundStyle(Theme.inkDim)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.94)
                        .zIndex(4)
                }
            }
            .contentShape(Rectangle())
            .gesture(auto == nil ? shooting(in: geo.size) : nil)
            .task { await playItself(in: geo.size) }
        }
    }

    /// Half the resting ball, which is where the gradient has to reach.
    private var ballRadius: CGFloat { 6 * Self.ballStartScale / 2 }

    // MARK: - Furniture

    private var header: some View {
        VStack(spacing: 5) {
            Text(trip.source.uppercased())
                .font(.system(size: 11, weight: .heavy)).tracking(2)
                .foregroundStyle(Theme.clockAmber)
            Text(trip.shooter.playerName.uppercased())
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Theme.color(for: trip.shooter))
            Text("FREE THROW \(trip.index) OF \(trip.total)")
                .font(.system(size: 12, weight: .bold)).tracking(1.4)
                .foregroundStyle(Theme.inkDim)

            if let verdict {
                Text(verdict.word)
                    .font(.system(size: verdict == .wide ? 26 : 34,
                                  weight: .black, design: .rounded))
                    .foregroundStyle(verdict == .good ? Theme.live : Theme.danger)
                    .compositingGroup()
                    .shadow(color: CardPalette.navy, radius: 0, x: 4, y: 4)
                    .padding(.top, 6)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: verdict)
    }

    /// The board only ever counts a free throw — it has nothing to take back.
    private var light: Color? {
        verdict == .good ? Theme.live : nil
    }

    private func ball(rest: CGPoint, rim: CGPoint, in size: CGSize) -> some View {
        PixelBallView(scale: Self.ballStartScale
                      + (Self.ballEndScale - Self.ballStartScale) * min(flight, 1))
            .opacity(flight > 1.7 ? 0 : 1)
            .animation(.easeOut(duration: 0.2), value: flight > 1.7)
            // Spin first, place second, travel third. Rotating after `.position` turns
            // the whole layer about the container's centre instead of the ball.
            .rotationEffect(.degrees(Double(flight) * 420))
            .position(rest)
            // Follows the finger before the throw, so the pull reads as loading a shot.
            .offset(launched ? .zero : CGSize(width: drag.width * 0.4,
                                              height: min(drag.height * 0.4, 0)))
            .modifier(BallFlight(t: flight,
                                 start: rest,
                                 control: CGPoint(x: rest.x + (target(in: size).x - rest.x) * 0.5,
                                                  y: rim.y - size.height * arcHeight),
                                 rim: target(in: size),
                                 after: after(rim: rim, in: size)))
    }

    // MARK: - The throw

    private func shooting(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !launched else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !launched else { return }
                // Straight down, or barely moved at all: not a throw.
                let pull = -value.translation.height
                guard pull > size.height * 0.06 else { drag = .zero; return }
                power = pull / (size.height * Self.perfectPull)
                aim = value.translation.width / size.width
                launch(in: size)
            }
    }

    /// An opponent's turn. Same flight, with the numbers worked backwards from the
    /// outcome the rules already decided — so its miss earns the same word yours would.
    private func playItself(in size: CGSize) async {
        guard let auto else { return }
        try? await Task.sleep(for: .seconds(0.55))
        if auto {
            power = .random(in: 0.88...1.12)
            aim = .random(in: -0.05...0.05)
        } else {
            switch Int.random(in: 0..<3) {
            case 0:  power = .random(in: 0.40...0.62)          // short
            case 1:  power = .random(in: 1.48...1.75)          // long
            default: power = .random(in: 0.90...1.10)          // on line, off target
                     aim = [-1, 1].randomElement()! * .random(in: 0.24...0.34)
            }
        }
        launch(in: size)
    }

    private func launch(in size: CGSize) {
        drag = .zero
        launched = true
        let called = call()

        withAnimation(.linear(duration: 0.62)) { flight = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.62))
            verdict = called
            if called == .good { struckAt = Date() }
            withAnimation(.easeIn(duration: called == .good ? 0.5 : 0.55)) { flight = 2 }
            try? await Task.sleep(for: .seconds(0.7))
            onResult(called == .good)
        }
    }

    /// What the throw actually did. An opponent's outcome is already decided, so its
    /// numbers are read the same way rather than being second-guessed.
    private func call() -> Verdict {
        if auto == true { return .good }
        if abs(aim) >= Self.aimWindow { return .wide }
        if power < Self.powerWindow.lowerBound { return .short }
        if power > Self.powerWindow.upperBound { return .long }
        return auto == false ? .wide : .good
    }

    /// How high the arc rides. A weak flick throws a flat one, which is half of why a
    /// miss looks like a miss rather than the same shot with a different verdict.
    ///
    /// This is the *control point*, and a quadratic reaches only about halfway to it — so
    /// the number has to be roughly twice the height actually wanted. At the old 0.21 the
    /// apex landed **below** the ring: the ball climbed straight into the rim instead of
    /// arcing over and dropping through, which is a jump shot, not a free throw.
    private var arcHeight: CGFloat {
        0.15 + 0.40 * min(max(power, 0.3), 1.6)
    }

    /// Where the ball actually arrives. A good throw is pulled onto the ring, so the
    /// give in the windows is visible rather than only arithmetic.
    private func target(in size: CGSize) -> CGPoint {
        let rimPoint = CGPoint(x: size.width / 2, y: rimCentreY)
        guard call() != .good else { return rimPoint }
        // Short falls in front of the ring, long carries past it, wide misses the side.
        let over = (power - 1) * size.height * 0.30
        return CGPoint(x: rimPoint.x + aim * size.width * 1.6,
                       y: rimPoint.y - over)
    }

    /// Down through the net, or off it and away.
    private func after(rim: CGPoint, in size: CGSize) -> CGPoint {
        let arrived = target(in: size)
        guard verdict == .good else {
            return CGPoint(x: arrived.x + (arrived.x < rim.x ? -1 : 1) * size.width * 0.7,
                           y: size.height * 1.2)
        }
        return CGPoint(x: rim.x, y: size.height * 1.2)
    }
}

#if DEBUG

/// Shot by hand. The trip is two so the second attempt can be reached — the live game
/// rebuilds the view per attempt, and `.id` here does the same.
#Preview("Free throw — you shoot") {
    FreeThrowPreview(trip: FreeThrowTrip(shooter: .south, offender: .north,
                                         source: "Flagrant Foul", remaining: 2))
}

#Preview("Free throw — opponent makes") {
    FreeThrowView(trip: FreeThrowTrip(shooter: .east, offender: .west,
                                      source: "Blocking Foul", remaining: 1),
                  auto: true)
}

#Preview("Free throw — opponent misses") {
    FreeThrowView(trip: FreeThrowTrip(shooter: .north, offender: nil,
                                      source: "Foul", remaining: 1),
                  auto: false)
}

/// Stands in for the controller: banks the result and hands back the next attempt, so a
/// trip can actually be shot through in the canvas rather than resetting after one.
private struct FreeThrowPreview: View {
    @State var trip: FreeThrowTrip
    @State private var line = "flick the ball"

    var body: some View {
        ZStack(alignment: .top) {
            if trip.remaining > 0 {
                FreeThrowView(trip: trip, auto: nil) { made in
                    trip.attempted += 1
                    trip.remaining -= 1
                    if made { trip.made += 1 }
                    line = "\(trip.made) of \(trip.attempted)"
                        + (trip.remaining > 0 ? " — one to go" : " — trip over")
                }
                .id(trip.attempted)
            } else {
                Color.black.ignoresSafeArea()
            }

            Text(line)
                .font(.system(size: 12, weight: .heavy)).tracking(1.5)
                .foregroundStyle(Theme.clockAmber)
                .padding(.top, 8)
        }
    }
}

#endif
