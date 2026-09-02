import SwiftUI

#if DEBUG

/// Frames per second, in the corner. Ported from Project Stars.
///
/// It counts its own ticks rather than asking `CADisplayLink`, because the question is
/// whether *this view tree* is keeping up — a court full of `TimelineView` canvases can
/// fall behind while the display runs at its full rate perfectly happily. So the counter
/// rides the same clock every animation here rides, and measures the interval between the
/// ticks it actually receives.
///
/// The sample is a reference held in `@State`: a rolling window has to survive between
/// body evaluations without invalidating anything, which a value type cannot do. The box
/// changes, the binding does not, and the redraw comes from the `TimelineView` that is
/// already ticking.
struct FrameRateView: View {

    @State private var window = FrameWindow()

    var body: some View {
        TimelineView(.animation) { timeline in
            let rate = window.record(timeline.date)

            Text(rate > 0 ? "\(Int(rate.rounded())) FPS" : "— FPS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(colour(for: rate))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.7)))
        }
        .allowsHitTesting(false)
    }

    /// Thresholds rather than a gradient: the number is already the precise answer, and
    /// what the colour is for is being readable out of the corner of your eye.
    private func colour(for rate: Double) -> Color {
        switch rate {
        case 50...:   return PixelPalette.green
        case 30..<50: return PixelPalette.gold
        default:      return PixelPalette.vermilion
        }
    }
}

/// A rolling average of the last second or so of frame intervals.
///
/// Averaged rather than instantaneous because a single frame's interval is mostly noise —
/// one long frame in thirty is not a drop from 60 to 20, and a counter that says so is
/// worse than none.
@Observable
private final class FrameWindow {

    private var last: Date?
    private var intervals: [TimeInterval] = []
    /// About a second at full rate.
    private let capacity = 60

    func record(_ now: Date) -> Double {
        defer { last = now }
        guard let last else { return 0 }

        let elapsed = now.timeIntervalSince(last)
        // A gap that large is the app having been suspended, not a slow frame.
        guard elapsed > 0, elapsed < 1 else { return average }

        intervals.append(elapsed)
        if intervals.count > capacity { intervals.removeFirst() }
        return average
    }

    private var average: Double {
        guard !intervals.isEmpty else { return 0 }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        return mean > 0 ? 1 / mean : 0
    }
}

#endif
