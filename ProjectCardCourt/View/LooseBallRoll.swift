import SwiftUI

/// A loose ball arriving on an empty floor, as one animatable value.
///
/// Drops in from off-screen, bounces twice — each hop carrying it further the way it was
/// already going, never back the way it came — then runs on and curls down and around
/// into a tightening spiral. The path is an `@` turned upside down: the long tail is the
/// run and the curl, and the ball comes to rest in the middle of the `a`.
///
/// The **whole** path is measured once and walked by distance, under one speed that decays
/// to nothing. Giving each stretch its own share of the clock is what made this read as
/// several animations stitched together: a short stretch and a long one got the same time,
/// so the ball crawled through the bounces and then fired across the run. Spending time on
/// distance instead means the speed can never jump at a join, because there are no joins
/// left — there is one curve, and one ball slowing down along it.
struct LooseBallRoll: GeometryEffect {
    var t: CGFloat

    /// The whole arrival, measured once so it can be walked by distance.
    private let path: Polyline

    init(t: CGFloat, direction: CGFloat, entry: CGSize, run: CGFloat, bounce: CGFloat) {
        self.t = t
        self.path = Polyline(samples: 220) { v in
            Self.shape(at: v, direction: direction, entry: entry, run: run, bounce: bounce)
        }
    }

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let point = path.point(atDistance: path.length * Self.travelled(at: t))
        return ProjectionTransform(
            CGAffineTransform(translationX: point.width, y: point.height))
    }

    /// How much of the whole journey is behind it, 0 to 1.
    ///
    /// One profile for the entire path, which is what makes it read as a ball losing
    /// speed rather than as several animations in a row. It also drives the spin, so the
    /// ball can never turn faster than it travels.
    static func travelled(at t: CGFloat) -> CGFloat {
        1 - pow(1 - min(max(t, 0), 1), 2.5)
    }

    // MARK: - The shape

    /// Where each stretch of the path ends, as fractions of the shape — not of time.
    /// Time is spent on distance, so a long stretch simply takes longer.
    private enum Leg {
        static let landing: CGFloat = 0.30
        static let firstHop: CGFloat = 0.44
        static let secondHop: CGFloat = 0.54
        static let straight: CGFloat = 0.66
    }

    /// The floor is seen at an angle, so the curl is an ellipse rather than a circle.
    private static let flatten: CGFloat = 0.42
    /// How far round the curl goes before it runs out.
    private static let turns: CGFloat = 1.6
    /// How quickly it winds in. Above 1 pulls the radius down early, so the ball is into
    /// the tight part of the spiral rather than circling wide and then stopping short.
    private static let wind: CGFloat = 1.35

    private static func shape(at v: CGFloat, direction: CGFloat, entry: CGSize,
                              run: CGFloat, bounce: CGFloat) -> CGSize {
        // In and down.
        if v < Leg.landing {
            let u = v / Leg.landing
            let land = -direction * run * 0.8
            return CGSize(width: entry.width + (land - entry.width) * u,
                          height: entry.height * (1 - u * u))
        }
        if v < Leg.firstHop {
            return hop(from: -direction * run * 0.8, to: -direction * run * 0.35,
                       peak: bounce, u: (v - Leg.landing) / (Leg.firstHop - Leg.landing))
        }
        if v < Leg.secondHop {
            return hop(from: -direction * run * 0.35, to: -direction * run * 0.05,
                       peak: bounce * 0.62,
                       u: (v - Leg.firstHop) / (Leg.secondHop - Leg.firstHop))
        }
        // Still going the way it was thrown.
        if v < Leg.straight {
            let u = (v - Leg.secondHop) / (Leg.straight - Leg.secondHop)
            return CGSize(width: -direction * run * 0.05 + direction * run * 1.05 * u,
                          height: 0)
        }
        // Then down and back, tightening onto the resting point — the `a` of the `@`.
        let u = (v - Leg.straight) / (1 - Leg.straight)
        let radius = run * pow(1 - u, wind)
        let angle = u * turns * 2 * .pi
        return CGSize(width: direction * radius * cos(angle),
                      height: radius * sin(angle) * flatten)
    }

    /// One bounce: forward the whole time, with the height a simple arch over it.
    private static func hop(from start: CGFloat, to end: CGFloat,
                            peak: CGFloat, u: CGFloat) -> CGSize {
        CGSize(width: start + (end - start) * u,
               height: -peak * 4 * u * (1 - u))
    }
}

/// A curve sampled into straight pieces, with the distance to each one.
///
/// Cheap to read and built once. The point is being able to ask "where am I after
/// travelling this far", which a curve's own parameter cannot answer — that is what
/// keeps a constant speed constant.
struct Polyline {
    private let points: [CGSize]
    private let distances: [CGFloat]

    var length: CGFloat { distances.last ?? 0 }

    init(samples: Int, shape: (CGFloat) -> CGSize) {
        var points: [CGSize] = []
        var distances: [CGFloat] = []
        var total: CGFloat = 0
        for step in 0...samples {
            let point = shape(CGFloat(step) / CGFloat(samples))
            if let last = points.last {
                total += hypot(point.width - last.width, point.height - last.height)
            }
            points.append(point)
            distances.append(total)
        }
        self.points = points
        self.distances = distances
    }

    func point(atDistance distance: CGFloat) -> CGSize {
        guard let first = points.first else { return .zero }
        guard distance > 0 else { return first }
        guard distance < length else { return points[points.count - 1] }

        var low = 0, high = distances.count - 1
        while low + 1 < high {
            let mid = (low + high) / 2
            if distances[mid] <= distance { low = mid } else { high = mid }
        }
        let span = distances[high] - distances[low]
        let f = span > 0 ? (distance - distances[low]) / span : 0
        return CGSize(width: points[low].width + (points[high].width - points[low].width) * f,
                      height: points[low].height + (points[high].height - points[low].height) * f)
    }
}
