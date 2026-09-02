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
    static let flankSpread: CGFloat = 0.74
    /// Where the referee stands when a Whistle is armed — on the sideline, outside the
    /// flank players.
    /// How far a figure is dropped below its footing, as a share of its own height. The
    /// sprite frame is mostly padding above the character, so it floats without this.
    static let playerDrop: CGFloat = 0.25

    static let refereeDepth: CGFloat = 0.42
    static let refereeLateral: CGFloat = 0.94

    /// Where the draw pile sits: off the centre column, so it never sits on top of
    /// North. Lateral is a share of the floor's half-width at that depth.
    static let deckDepth: CGFloat = 0.30
    /// Mirrored from the discard, so the two flank the centre line.
    static var deckLateral: CGFloat { -discardLateral }
    /// The discard sits beside the deck, at the same depth.
    static let discardLateral: CGFloat = 0.42

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
    func footing(of seat: Seat) -> CGPoint {
        let slot = seat.slot(viewedFrom: viewer)
        let depth = Perspective.depth(of: slot)
        let half = halfWidth(at: depth) * Perspective.flankSpread
        switch slot {
        case .north, .south: return CGPoint(x: centreX, y: y(at: depth))
        case .east:          return CGPoint(x: centreX + half, y: y(at: depth))
        case .west:          return CGPoint(x: centreX - half, y: y(at: depth))
        }
    }

    func scale(of seat: Seat) -> CGFloat {
        scale(at: Perspective.depth(of: seat.slot(viewedFrom: viewer)))
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
