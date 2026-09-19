import SwiftUI

/// The court's perspective, in one place. Depth runs 0 at the horizon to 1 at the near edge.
enum Perspective {
    /// Where the horizon sits, as a share of the court's height. Everything above it is
    /// background — the hoop, and the streaks pouring out of the vanishing point.
    static let horizon: CGFloat = 0.17
    /// Half-width of the floor at the horizon and at the near edge, as shares of the width.
    /// A squat trapezoid: wide, shallow, and only gently tapered.
    static let farHalfWidth: CGFloat = 0.16
    /// Past the screen edge on purpose — the near corners run off the sides so the
    /// court is wide enough for the sprites at their real size.
    static let nearHalfWidth: CGFloat = 0.78

    /// The band of light that travels down the floor: how tall it is as a share of the
    /// court, and how long one pass takes. Lower seconds is faster.
    static let sweepHeight: CGFloat = 0.10
    /// Where the floor reaches full colour. Above this it fades out toward the horizon.
    static let floorFadeEnd: CGFloat = 0.42
    static let sweepSeconds: Double = 2.0

    /// How much the side edges bow outward, wide-angle style. 0 is the straight
    /// trapezoid; higher flares the near half of the court toward the viewer.
    static let curve: CGFloat = 0.35
    /// The depth whose edge tangent the streak lanes borrow. A curved edge has no one
    /// angle, so the lanes take the angle where the eye reads the court.
    static let laneSampleDepth: CGFloat = 0.55

    /// How big a figure at the horizon is next to one at the near edge. Steep enough
    /// that the near player reads as near and the far one as far.
    static let farScale: CGFloat = 0.40

    /// The depth everybody stands at during an inbound.
    ///
    /// The flanks' own, so the three of them make a line across the floor rather than a
    /// triangle — the upcourt player is a good deal smaller where he usually stands, and
    /// three people at three sizes does not read as a set play.
    static var inboundLine: CGFloat { depth(of: .east) }

    /// Where each seat stands. North is upcourt, South is nearest the camera.
    static func depth(of seat: Seat) -> CGFloat {
        switch seat {
        // Everyone sits in the upper half of the floor: the fanned hand covers the
        // near end, so the bottom of the court is deliberately empty.
        case .north: return 0.18
        case .east, .west: return 0.36
        case .south: return 0.52
        }
    }

    /// How far off centre East and West stand, as a share of the floor's half-width there.
    static let flankSpread: CGFloat = 0.64
    /// Where the referee stands when a Whistle is armed — on the sideline, outside the
    /// flank players.
    /// How far a figure is dropped below its footing, as a share of its own height. The
    /// sprite frame is mostly padding above the character, so it floats without this.
    ///
    /// **Private, and spent only through `footDrop(at:)`.** It is a share of the figure's
    /// *drawn* height, and every one of the five places that placed a figure spelled that
    /// out by hand — `Theme.Figure.height * playerDrop`, with no scale on it. So every
    /// seat was dropped the same number of points however small it was drawn, and the
    /// furthest one stood a fifth of his own body too low: his hands came down under a
    /// ball aimed where his hands should have been. One function, and there is nowhere
    /// left to forget the scale.
    static let playerDrop: CGFloat = 0.35

    /// How far below its footing a figure drawn at this scale sits, in points.
    ///
    /// **The only way the drop is ever spent.** On the rebound bench while the four of
    /// them are being judged against each other — see `ReboundTuning.footDrop`.
    @MainActor
    static func footDrop(at scale: CGFloat) -> CGFloat {
        Theme.Figure.height * scale * ReboundTuning.shared.footDrop
    }

    /// How far out a referee stands, as a share of the floor's half-width at his depth.
    /// Just past 1 puts him on the paint's outside line rather than in play.
    static let refereeLateral: CGFloat = 0.75
    /// How far up the floor he stands from the player he is posted beside.
    ///
    /// Was 0.06, which put the near pair close enough to the flank players to read as
    /// standing over them rather than watching from the sideline.
    static let refereeUpcourt: CGFloat = 0.12
    /// The near pair stand further up again. They are the two closest to the camera, so
    /// the same nudge that clears the far pair of North barely moves them off the flanks.
    static let refereeNearUpcourt: CGFloat = 0.20

    /// **Where the two wing posts stand now: halfway up to where the far posts were.**
    /// The far pair are gone; the user asked for the wings to move "halfway between where
    /// they stand now and where the far ones were." Worked from the two old depths rather
    /// than typed, so it moves if either of them does.
    static var refereeWingDepth: CGFloat {
        let wing = depth(of: .east) - refereeNearUpcourt
        let far = depth(of: .north) - refereeUpcourt
        return (wing + far) / 2
    }
    /// **The two posts either side of South**, a step nearer the camera than he stands
    /// and as far out as the screen allows — see `CourtGeometry.footing(of:)`.
    static let refereeSouthStep: CGFloat = 0.06

    /// **Where a player throws it in from.** It used to borrow the far referee posts'
    /// depth, which tied the sideline to posts that no longer exist.
    static var throwInDepth: CGFloat { depth(of: .north) - refereeUpcourt }

    /// How wide a card in a pile reads, as a share of the view. The stage sizes the piles
    /// to this and the deck's floor shadow is drawn from it, so the shadow cannot come out
    /// a different size from the thing casting it.
    static let pileCardShare: CGFloat = 0.19
    /// How flat something lying on the floor reads. The camera sits 34° above it, so a
    /// circle down there is an ellipse this much shorter than it is wide.
    static let floorSquash: CGFloat = 0.55

    /// Where the draw pile sits: off the centre column, so it never sits on top of
    /// North. Lateral is a share of the floor's half-width at that depth.
    static let deckDepth: CGFloat = 0.30
    /// Mirrored from the discard, so the two flank the centre line.
    static var deckLateral: CGFloat { -discardLateral }
    /// The discard sits beside the deck, at the same depth.
    static let discardLateral: CGFloat = 0.42

}

/// Where a referee can stand. Four posts, so the three a game can field never share one.
///
/// **Two up the wings and two beside South.** The far pair either side of North are gone;
/// the wings moved halfway up toward where they were, and two new posts went in south-east
/// and south-west of the south player.
///
/// Named for the slots they sit beside rather than the seats, so they stay in the same
/// places on screen whoever the court is being drawn for.
enum RefereePost: CaseIterable {
    /// Off the right-hand flank player's shoulder and the left-hand one's, up the floor.
    case rightWing, leftWing
    /// Either side of South, a step nearer the camera than he stands.
    case southEast, southWest

    /// Which side of the floor he is on.
    var isLeft: Bool { self == .leftWing || self == .southWest }

    /// True for the pair beside South, which are the two nearest the camera.
    var isSouth: Bool { self == .southEast || self == .southWest }

    var depth: CGFloat {
        isSouth ? Perspective.depth(of: .south) + Perspective.refereeSouthStep
                : Perspective.refereeWingDepth
    }

    /// Which side of the floor, and how far out. The south pair are placed against the
    /// screen's edge instead — see `CourtGeometry.footing(of:)` — so for them this only
    /// says they stand outside the wings, which is who the crew turns toward on a call.
    var lateral: CGFloat {
        (isSouth ? 1 : Perspective.refereeLateral) * (isLeft ? -1 : 1)
    }

    /// **The sheet he runs on — never mirrored.** Every post runs facing up the floor.
    var runSheet: Sprite { .refereeRunN }

    /// **And the one he glances into the game on**, often. The pair beside South look
    /// up into it — north-east from the left, north-west from the right. The wings are
    /// upcourt of most of the play, so they **look back** at it, over the shoulder nearer
    /// the middle: `Referee_Run_Look` is drawn over the left one, which is the right-hand
    /// wing's, and the left-hand wing's is the same turned round — see `mirrorsLook`. Every
    /// one is the same run cycle with the head turned, so the cut never breaks his stride.
    var lookSheet: Sprite {
        switch self {
        case .southWest: return .refereeRunNE
        case .southEast: return .refereeRunNW
        case .rightWing, .leftWing: return .refereeRunLook
        }
    }

    /// Whether the look back is turned round: the left-hand wing looks over his right
    /// shoulder, toward the middle. Only the glance is flipped, never the run.
    var mirrorsLook: Bool { self == .leftWing }

    /// The post on the other side *and* the other end of the floor.
    var opposite: RefereePost {
        switch self {
        case .rightWing: return .southWest
        case .leftWing:  return .southEast
        case .southEast: return .leftWing
        case .southWest: return .rightWing
        }
    }

    /// The same end of the floor, the other side of it.
    var across: RefereePost {
        switch self {
        case .rightWing: return .leftWing
        case .leftWing:  return .rightWing
        case .southEast: return .southWest
        case .southWest: return .southEast
        }
    }

    /// Where a whole crew stands, given where the first one did.
    ///
    /// Each referee is placed as far from the one before as the floor allows: the second
    /// takes the opposite corner, the third crosses back to the far one's other side. Two
    /// officials side by side read as a pair watching one thing; spread out they read as
    /// a crew watching the game.
    static func crew(from first: RefereePost) -> [RefereePost] {
        let second = first.opposite
        let third = second.across
        return [first, second, third, third.opposite]
    }

    /// Keeps two referees out of step with each other.
    var phase: TimeInterval {
        TimeInterval(RefereePost.allCases.firstIndex(of: self) ?? 0) * 0.4
    }
}

struct CourtGeometry {
    let size: CGSize
    /// Whose eyes the court is drawn through. Every seat is placed by its slot relative
    /// to this, never by its absolute compass position.
    var viewer: Seat = .south

    var horizonY: CGFloat { size.height * Perspective.horizon }
    var centreX: CGFloat { size.width / 2 }

    func y(at depth: CGFloat) -> CGFloat {
        horizonY + (size.height - horizonY) * depth
    }

    func halfWidth(at depth: CGFloat) -> CGFloat {
        let far = size.width * Perspective.farHalfWidth
        let near = size.width * Perspective.nearHalfWidth
        return far + (near - far) * shaped(depth)
    }

    /// Bowing the width's growth is what turns a straight taper into a wide-angle sweep.
    /// Everything on the court reads its position through `halfWidth`, so curving here
    /// curves the floor, the players and the streak lanes together.
    private func shaped(_ depth: CGFloat) -> CGFloat {
        CGFloat(pow(Double(max(0, depth)), Double(1 - Perspective.curve)))
    }

    /// Which way the edge is running at a given depth.
    private func edgeTangent(at depth: CGFloat) -> CGVector {
        let far = size.width * Perspective.farHalfWidth
        let near = size.width * Perspective.nearHalfWidth
        let exponent = Double(1 - Perspective.curve)
        let dx = Double(near - far) * exponent * pow(Double(max(depth, 0.0001)), exponent - 1)
        return CGVector(dx: CGFloat(dx), dy: size.height - horizonY)
    }

    func scale(at depth: CGFloat) -> CGFloat {
        Perspective.farScale + (1 - Perspective.farScale) * depth
    }

    /// The point on the floor a seat stands on — its feet, not its centre.
    /// During an inbound everybody stands on one line, so the upcourt player comes down
    /// to the flanks' depth instead of being half their size behind them.
    /// Where a seat stands, and where the *viewer* stands instead while a throw-in is
    /// being set up.
    ///
    /// The man taking it is drawn on the sideline, so his place in the line is empty —
    /// and the viewer's own place is the one nearest the camera, at the bottom of the
    /// screen behind everybody. So the viewer steps into the vacated place. Everyone else
    /// keeps theirs, which leaves three receivers in three slots and nobody doubled up.
    func footing(of seat: Seat, inbounding thrower: Seat? = nil) -> CGPoint {
        let slot = standing(seat, inbounding: thrower)
        let depth = self.depth(of: slot, inbounding: thrower != nil)
        let half = halfWidth(at: depth) * Perspective.flankSpread
        switch slot {
        case .north, .south: return CGPoint(x: centreX, y: y(at: depth))
        case .east:          return CGPoint(x: centreX + half, y: y(at: depth))
        case .west:          return CGPoint(x: centreX - half, y: y(at: depth))
        }
    }

    /// **Where a referee's feet are.** The wings stand on the floor's own lateral; the two
    /// beside South stand as far out as the screen allows, their whole frame still on it,
    /// less whatever inset they are tuned to — see `RefereeTuning`.
    @MainActor
    func footing(of post: RefereePost) -> CGPoint {
        let depth = post.depth
        let side: CGFloat = post.isLeft ? -1 : 1
        guard post.isSouth else {
            let out = halfWidth(at: depth) * RefereeTuning.shared.farSpread
            return CGPoint(x: centreX + side * out, y: y(at: depth))
        }
        let halfFrame = Sprite.refereeRunN.frameSize * Theme.Figure.playerScale
            * scale(at: depth) / 2
        let out = size.width / 2 - halfFrame - RefereeTuning.shared.nearInset
        return CGPoint(x: centreX + side * out, y: y(at: depth))
    }

    func scale(of seat: Seat, inbounding thrower: Seat? = nil) -> CGFloat {
        scale(at: depth(of: standing(seat, inbounding: thrower), inbounding: thrower != nil))
    }

    /// Which slot a seat is actually standing in right now.
    private func standing(_ seat: Seat, inbounding thrower: Seat?) -> Seat {
        let own = seat.slot(viewedFrom: viewer)
        guard let thrower, seat == viewer, thrower != viewer else { return own }
        return thrower.slot(viewedFrom: viewer)
    }

    private func depth(of slot: Seat, inbounding: Bool) -> CGFloat {
        inbounding && slot == .north
            ? Perspective.inboundLine : Perspective.depth(of: slot)
    }

    /// How much smaller everything at the horizon is than the same thing at the near
    /// edge. The floor's own taper, reused so the walls recede at the same rate.
    var farRatio: CGFloat { halfWidth(at: 0) / halfWidth(at: 1) }

    /// Sampled rather than four corners, because the edges are curves now.
    var floor: Path {
        let steps = 28
        var path = Path()
        path.move(to: CGPoint(x: centreX - halfWidth(at: 0), y: y(at: 0)))
        path.addLine(to: CGPoint(x: centreX + halfWidth(at: 0), y: y(at: 0)))
        for step in 1...steps {
            let depth = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: centreX + halfWidth(at: depth), y: y(at: depth)))
        }
        for step in stride(from: steps, through: 0, by: -1) {
            let depth = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: centreX - halfWidth(at: depth), y: y(at: depth)))
        }
        path.closeSubpath()
        return path
    }
}

/// The trapezoid, as a Shape so it can clip the warp field and take a stroke.
struct CourtFloorShape: Shape {
    func path(in rect: CGRect) -> Path {
        CourtGeometry(size: rect.size).floor.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// What the floating deck puts on the floor.
///
/// It tracks the drift rather than sitting still under the middle of it: a shadow that
/// does not move says the deck is not moving either, and a shadow that does not shrink
/// says it is not off the floor. Both are read from `DeckDrift`, which is the same clock
/// the pile itself is flying by.
struct PileShadow: View {
    /// How wide the shadow is with the deck at the bottom of its breath.
    var width: CGFloat
    /// How wide the court is on screen, which is what turns the drift into points.
    var across: CGFloat
    /// Where in the drift the pile it belongs to is. See `DeckDrift.offset`.
    var phase: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let rise = DeckDrift.rise(at: timeline.date, phase: phase)
            let drift = DeckDrift.offset(at: timeline.date, phase: phase)
            // Smaller and fainter the higher it rides, which is the whole reading.
            let size = width * (1 - Shadow.shrink * rise)

            RoundedRectangle(cornerRadius: size * 0.08)
                .fill(PixelPalette.warmBlack.opacity(Shadow.opacity
                                                     * (1 - Shadow.fade * rise)))
                .frame(width: size,
                       height: size / CardMetrics.aspect * Perspective.floorSquash)
                // The floor point under the deck: its lift does not move the shadow, only
                // its drift across the floor does.
                .offset(x: across * CGFloat(drift.x),
                        y: across * CGFloat(drift.z) * Perspective.floorSquash)
        }
    }

    private enum Shadow {
        static let opacity: CGFloat = 0.66
        /// How much smaller and fainter it gets at the top of the breath.
        static let shrink: CGFloat = 0.20
        /// Half of it at the top of the breath: 0.66 down to 0.33, where the pile is
        /// furthest off the floor and the shadow is smallest.
        static let fade: CGFloat = 0.50
    }
}

/// The hoop, seen from downcourt — small enough to read as distance.
struct FarHoop: View {
    var width: CGFloat = 34

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.10))
                RoundedRectangle(cornerRadius: 1.5)
                    .stroke(Color.white.opacity(0.70), lineWidth: 1)
                Rectangle()
                    .stroke(Color.white.opacity(0.75), lineWidth: 0.8)
                    .frame(width: width * 0.32, height: width * 0.22)
                    .offset(y: width * 0.09)
            }
            .frame(width: width, height: width * 0.56)

            Ellipse()
                .stroke(Theme.ball, lineWidth: 1.4)
                .frame(width: width * 0.46, height: width * 0.14)
                .offset(y: -1)
        }
    }
}
