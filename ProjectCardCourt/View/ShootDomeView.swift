import SwiftUI

/// **Where the ball's middle is**, in the screen's own space — a long way under its
/// bottom edge. The hand is fanned on a circle round that point, so it has to be measured
/// rather than assumed: the hand's arc is *concentric* with the ball, which makes its
/// radius the distance from that middle up to the hand, not the ball's own radius.
struct BallCentre: PreferenceKey {
    static let defaultValue: CGPoint? = nil
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}

/// A trapezoid bent round a circle: one segment of the arc over the dome.
struct ArcSlice: Shape {
    var centre: CGPoint
    var inner: CGFloat
    var outer: CGFloat
    var from: Angle
    var to: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: centre, radius: outer, startAngle: from, endAngle: to,
                    clockwise: false)
        path.addArc(center: centre, radius: inner, startAngle: to, endAngle: from,
                    clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// **A word bent round a circle**, a letter at a time — each one turned to stand on the
/// curve it sits on, the way a word printed round a dial is.
struct CurvedWord: View {
    let word: String
    let centre: CGPoint
    let radius: CGFloat
    /// The middle of the run, in degrees — 0 is due right, -90 straight up.
    let middle: Double
    let size: CGFloat
    var ink: Color = .white

    /// How much of the circle one letter takes at this radius, in degrees.
    private var step: Double {
        Double(size * 0.58 / max(radius, 1)) * 180 / .pi
    }

    var body: some View {
        let letters = Array(word)
        let start = middle - step * Double(letters.count - 1) / 2
        return ZStack {
            ForEach(letters.indices, id: \.self) { index in
                let angle = start + step * Double(index)
                let radians = angle * .pi / 180
                Text(String(letters[index]))
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                    .shadow(color: CardPalette.navy, radius: 0, x: 1, y: 1)
                    .rotationEffect(.degrees(angle + 90))
                    .position(x: centre.x + CGFloat(cos(radians)) * radius,
                              y: centre.y + CGFloat(sin(radians)) * radius)
            }
        }
    }
}

/// **The ball you shoot with, sunk into the floor of the screen.**
///
/// Two thirds of the screen across and a third of it showing: the rest is under the
/// bottom edge, so the thing you press is the biggest object in the game and still takes
/// up a band rather than a corner. The board's number is on it.
///
/// **The arc over it is the Moves left in the possession** — segments bent round the
/// ball's shoulder, filling as the possession spends them. Press the ball and the same
/// segments become the three finishes, each with its own mark.
struct ShootDomeView: View {
    let shot: Int
    /// Dim Dome: the number is not this player's to read.
    var hidden = false
    /// Which finishes are on offer. The rest are drawn greyed, so the shape of the choice
    /// never changes and you can see what you are working toward.
    var offered: Set<ShotType> = []
    /// Moves spent this possession, and how many there is room for.
    var moves: Int = 0
    var moveLimit: Int = 3
    /// Whether the finishes are showing. The screen owns it: a press anywhere else puts
    /// them away — see `GameView`.
    @Binding var open: Bool
    /// What the pad's cursor is on, so a ring can sit on a segment.
    var ringed: PadSpot?
    var onShoot: (ShotType) -> Void = { _ in }
    /// How wide the ball is drawn — two thirds of the screen.
    var width: CGFloat = 260

    @Environment(\.ballInPlay) private var ballInPlay
    /// How big the wedges are drawn and how wide their seams run, while that is being
    /// eyeballed — see `MoveArcTuning`.
    @State private var tuning = MoveArcTuning.shared
    /// Green on the way up, red on the way down, for a beat.
    @State private var flash: Color?

    private enum Dome {
        /// How much of the ball is above the screen's edge.
        static let shown: CGFloat = 0.33
        /// The arc over it: how thick, and the air between it and the ball.
        static let arc: CGFloat = 0.19
        static let gap: CGFloat = 0.02
        /// How far round the ball's shoulder the arc runs. The seam between two of them
        /// is the dial's — see `MoveArcTuning`.
        static let span: Double = 150
        /// What stands on a segment, as shares of the arc's own thickness: the mark that
        /// leads it, and the word that follows the mark round.
        static let mark: CGFloat = 0.95
        static let letter: CGFloat = 0.46
        /// The number on the ball, and the word beside it. **Both inside the third that
        /// is above the screen's edge** — the reading sat where half a ball used to show.
        static let number: CGFloat = 0.20
        /// The per-cent sign never matches the digits — see `ModeCardStyle.digitStandout`.
        static let sign: CGFloat = 0.5
        static let word: CGFloat = 0.09
        static let wordGap: CGFloat = 0.025
        /// How far down the ball's own face the reading sits, as a share of its width.
        static let reading: CGFloat = 0.035
        static let greyed: Double = 0.45
    }

    /// The three, in the order they sit on the arc: left, middle, right.
    private static let finishes: [ShotType] = [.layup, .dunk, .three]

    private var radius: CGFloat { width / 2 }
    private var arcThickness: CGFloat { width * Dome.arc * tuning.scale }
    /// How far round the ball's shoulder the three wedges run, and the seam between two
    /// of them. A wedge grows as one object: thicker and wider together.
    private var span: Double { Dome.span * Double(tuning.scale) }
    private var seam: Double { tuning.spacing }
    private var arcGap: CGFloat { width * Dome.gap }
    /// The band this view takes: the arc, the air under it, and the ball's own third.
    private var height: CGFloat { arcThickness + arcGap + width * Dome.shown }
    /// The ball's middle, in this view's own space — well below its bottom edge.
    private var centre: CGPoint {
        CGPoint(x: width / 2, y: arcThickness + arcGap + radius)
    }

    /// Out because they were asked for, or because the pad is pointing at one.
    private var showing: Bool {
        if case .finish = ringed { return true }
        return open
    }

    var body: some View {
        ZStack(alignment: .top) {
            ball
                // **Placed by its middle**, which is a long way under the screen's edge:
                // laid out from the top of the band instead, the whole band showed — the
                // arc's height and the air under it on top of the ball's own third.
                .position(centre)
            ForEach(Array(Self.finishes.enumerated()), id: \.offset) { index, finish in
                slice(index, finish: finish)
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .background {
            GeometryReader { box in
                let screen = box.frame(in: .named(Chrome.screen))
                Color.clear.preference(key: BallCentre.self,
                                       value: CGPoint(x: screen.minX + centre.x,
                                                      y: screen.minY + centre.y))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: showing)
        .animation(.easeOut(duration: 0.25), value: moves)
    }

    // MARK: - The ball

    private var ball: some View {
        let art = BallInPlay.vector(for: ballInPlay)
        return ZStack(alignment: .top) {
            Image(art)
                .resizable()
                .scaledToFit()
                .frame(width: width, height: width)
                .drawingGroup()
            // The reading, on the part of it that is on screen: the ball's own top third.
            // The word stands beside the number rather than over it, in the plain heavy
            // type every other button on this bar is lettered in.
            // **Lettered like a card's own $[2X]**: the word and the figure are the same
            // kind of mark, and the ball is read at a glance rather than studied.
            HStack(alignment: .center, spacing: width * Dome.wordGap) {
                TwoXMark(size: width * Dome.word, text: "SHOOT")
                TwoXMark(size: width * Dome.number, text: hidden ? "??%" : "\(shot)%")
                    .foregroundStyle(flash ?? .white)
            }
            .offset(y: width * Dome.reading)
        }
        .frame(width: width, height: width)
        // Only the part of it that is on screen answers a press.
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) { open.toggle() }
        }
        .tutorialTarget(.shotHUD)
        .onChange(of: shot) { old, new in
            guard new != old else { return }
            flash = new > old ? Theme.live : Theme.danger
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                withAnimation(.easeOut(duration: 0.25)) { flash = nil }
            }
        }
    }

    // MARK: - The arc

    /// One segment: a Move the possession has, or a finish it could take.
    private func slice(_ index: Int, finish: ShotType) -> some View {
        let step = span / Double(max(1, Self.finishes.count))
        let start = -90 - span / 2 + Double(index) * step
        let from = Angle(degrees: start + seam / 2)
        let to = Angle(degrees: start + step - seam / 2)
        let shape = ArcSlice(centre: centre, inner: radius + arcGap,
                             outer: radius + arcGap + arcThickness, from: from, to: to)
        let live = offered.contains(finish)
        let spent = index < moves
        let within = index < moveLimit
        return shape
            .fill(showing ? (live ? Self.ink(for: finish) : CardPalette.gray)
                          : (spent ? moveShade : (within ? PixelPalette.deepTeal
                                                         : CardPalette.gray.opacity(0.4))))
            .overlay {
                shape.stroke(CardPalette.navy, lineWidth: 2)
            }
            .overlay { label(index, finish: finish, live: live) }
            .contentShape(shape)
            .onTapGesture {
                guard showing, live else { return }
                onShoot(finish)
            }
            .padRing(showing && ringed == .finish(finish), corner: arcThickness / 2)
    }

    /// **What a segment carries: a mark, and the word bent round after it.**
    ///
    /// Closed, that is the Move's own subject on each of the three it has to spend.
    /// Pressed, it is the finish's mark and its name, both following the curve they are
    /// standing on.
    @ViewBuilder private func label(_ index: Int, finish: ShotType, live: Bool) -> some View {
        let step = span / Double(max(1, Self.finishes.count))
        let from = -90 - span / 2 + Double(index) * step + seam / 2
        let to = from + step - seam
        let reach = radius + arcGap + arcThickness / 2
        let markSide = arcThickness * Dome.mark
        // How much of the arc the mark takes, in degrees at this radius.
        let markSpan = Double(markSide / reach) * 180 / .pi
        let ink = live || !showing ? Color.white : Color.white.opacity(Dome.greyed)
        if showing {
            ZStack {
                mark(Self.mark(for: finish), at: from + markSpan / 2, reach: reach,
                     side: markSide, ink: ink)
                CurvedWord(word: finish.name.uppercased(), centre: centre, radius: reach,
                           middle: (from + markSpan + to) / 2,
                           size: arcThickness * Dome.letter, ink: ink)
            }
        } else if index < moveLimit {
            mark("TypeMoveFront", at: (from + to) / 2, reach: reach,
                 side: markSide, ink: index < moves ? CardPalette.navy : .white)
        }
    }

    /// One mark standing on the arc, turned to sit on the curve.
    private func mark(_ art: String, at angle: Double, reach: CGFloat,
                      side: CGFloat, ink: Color) -> some View {
        let radians = angle * .pi / 180
        return Image(art)
            .resizable()
            // **Filled, not fitted.** A shoe drawn to fit its box is a shoe with air all
            // round it; on a band this thin that read as a smudge.
            .scaledToFill()
            .frame(width: side, height: side)
            .foregroundStyle(ink)
            .rotationEffect(.degrees(angle + 90))
            .position(x: centre.x + CGFloat(cos(radians)) * reach,
                      y: centre.y + CGFloat(sin(radians)) * reach)
    }

    /// **The drop under the arc, by how much running is gone.** The Moves plate's own
    /// ramp: cloud with the whole possession ahead, red once there is none left.
    private var moveShade: Color {
        switch moves {
        case 0:  return CardPalette.cloud
        case 1:  return CardPalette.gold
        case 2:  return CardPalette.orange
        default: return CardPalette.red
        }
    }

    /// **The colour each finish wears.** Orange is the shot that is always there; the two
    /// that have to be earned say so by not being it.
    private static func ink(for finish: ShotType) -> Color {
        switch finish {
        case .layup: return CardPalette.orange
        case .dunk:  return CardPalette.red
        case .three: return CardPalette.gold
        }
    }

    /// The mark each finish is drawn with, the same one its cards wear.
    private static func mark(for finish: ShotType) -> String {
        switch finish {
        case .layup: return "ShootIcon"
        case .dunk:  return "DunkIcon"
        case .three: return "ThreeHandWhole"
        }
    }
}

#if DEBUG
#Preview("Dome") {
    struct Bench: View {
        @State private var open = false
        var body: some View {
            VStack {
                Spacer()
                ShootDomeView(shot: 65, offered: [.layup, .three], moves: 2,
                              open: $open, width: 260)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.sceneGround)
        }
    }
    return Bench()
}
#endif
