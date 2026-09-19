import SwiftUI

/// A seven-segment digit. Segments are hexagons with mitred points, so adjacent
/// segments meet at a diagonal the way a real LED display does.
enum Segment: CaseIterable {
    case a, b, c, d, e, f, g

    static func lit(for digit: Int) -> Set<Segment> {
        switch digit {
        case 0: return [.a, .b, .c, .d, .e, .f]
        case 1: return [.b, .c]
        case 2: return [.a, .b, .g, .e, .d]
        case 3: return [.a, .b, .g, .c, .d]
        case 4: return [.f, .g, .b, .c]
        case 5: return [.a, .f, .g, .c, .d]
        case 6: return [.a, .f, .g, .e, .c, .d]
        case 7: return [.a, .b, .c]
        case 8: return [.a, .b, .c, .d, .e, .f, .g]
        case 9: return [.a, .b, .c, .d, .f, .g]
        default: return []
        }
    }
}

struct SevenSegmentDigit: View {
    let on: Set<Segment>
    var lit: Color = .white
    var unlit: Color = Color.white.opacity(0.12)

    var body: some View {
        ZStack {
            segments(lit: false)
            // **Only the lit segments glow**, in their own colour. A separate layer so the
            // glow falls outside the digit's own box instead of being clipped by it.
            segments(lit: true)
                .shadow(color: lit.opacity(Glow.coreStrength), radius: Glow.coreRadius)
                .shadow(color: lit.opacity(Glow.haloStrength), radius: Glow.haloRadius)
        }
    }

    /// **A core and a halo**: tight and full round the segment, then wide. One 4-point
    /// shadow at 0.8 barely left the segment's edge.
    private enum Glow {
        static let coreRadius: CGFloat = 3
        static let coreStrength: Double = 1
        static let haloRadius: CGFloat = 10
        static let haloStrength: Double = 0.9
    }

    private func segments(lit showsLit: Bool) -> some View {
        Canvas { context, size in
            let thickness = size.width * 0.14
            // Segments sit in their own rects and stop just short of each other.
            let gap = thickness * 0.09
            for segment in Segment.allCases where on.contains(segment) == showsLit {
                let box = rect(segment, in: size, t: thickness, gap: gap)
                guard box.width > 0, box.height > 0 else { continue }
                context.fill(hexagon(in: box, horizontal: box.width > box.height),
                             with: .color(showsLit ? lit : unlit))
            }
        }
    }

    /// Non-overlapping box for each segment. The bars stop short of the posts, and the
    /// posts stop short of both the bars above and below them.
    private func rect(_ segment: Segment, in size: CGSize, t: CGFloat, gap: CGFloat) -> CGRect {
        let midY = size.height / 2
        let barX = t + gap
        let barWidth = size.width - 2 * (t + gap)
        let upperTop = t + gap
        let upperBottom = midY - t / 2 - gap
        let lowerTop = midY + t / 2 + gap
        let lowerBottom = size.height - t - gap

        switch segment {
        case .a: return CGRect(x: barX, y: 0, width: barWidth, height: t)
        case .g: return CGRect(x: barX, y: midY - t / 2, width: barWidth, height: t)
        case .d: return CGRect(x: barX, y: size.height - t, width: barWidth, height: t)
        case .f: return CGRect(x: 0, y: upperTop, width: t, height: upperBottom - upperTop)
        case .b: return CGRect(x: size.width - t, y: upperTop, width: t, height: upperBottom - upperTop)
        case .e: return CGRect(x: 0, y: lowerTop, width: t, height: lowerBottom - lowerTop)
        case .c: return CGRect(x: size.width - t, y: lowerTop, width: t, height: lowerBottom - lowerTop)
        }
    }

    /// A hexagon filling the rect, with its two short edges collapsed to points.
    private func hexagon(in rect: CGRect, horizontal: Bool) -> Path {
        var path = Path()
        if horizontal {
            let half = rect.height / 2
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX + half, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - half, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - half, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + half, y: rect.maxY))
        } else {
            let half = rect.width / 2
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + half))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - half))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - half))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + half))
        }
        path.closeSubpath()
        return path
    }
}

/// The shot clock. nil shows dashes, matching the inbound phase where no clock runs yet.
struct SevenSegmentClock: View {
    let value: Int?
    var digitSize = CGSize(width: 20, height: 40)

    private var lit: Color { Theme.clockColor(for: value) }

    /// Always two digits, so single figures read as 09 rather than a blank and a 9.
    private var glyphs: [Set<Segment>] {
        guard let value else { return [[.g], [.g]] }
        return [Segment.lit(for: value / 10), Segment.lit(for: value % 10)]
    }

    var body: some View {
        HStack(spacing: digitSize.width * 0.16) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { _, on in
                SevenSegmentDigit(on: on, lit: lit)
                    .frame(width: digitSize.width, height: digitSize.height)
            }
        }
        .animation(.easeOut(duration: 0.18), value: value)
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach([nil, 10, 9, 7, 6, 4, 3, 2, 0] as [Int?], id: \.self) { value in
            SevenSegmentClock(value: value)
        }
    }
    .padding(30)
    .background(.black)
}
