import SwiftUI

/// The live SHOT reading, drawn the way the cards draw theirs — ball behind, number over
/// it, hard zero-blur shadows — just larger, and without a sign, since this is a total
/// rather than a change.
struct ShotBadgeView: View {
    let shot: Int
    var ballSize: CGFloat = 58
    /// Dim Dome: the number is not this player's to read.
    var hidden = false

    /// The SHOT is drawn on whichever ball is in play.
    @Environment(\.ballInPlay) private var ballInPlay
    @State private var pulse: CGFloat = 1
    /// Green on the way up, red on the way down, for a beat.
    @State private var flash: Color?

    private var numberSize: CGFloat { ballSize * 0.68 }
    /// The sign never matches the digits — see `ModeCardStyle.digitStandout`.
    private var signSize: CGFloat { numberSize * 0.5 }
    private var drop: CGFloat { ballSize * 0.06 }

    /// The wordmark's two inks, meeting at a line inside the letters — see
    /// `Chrome.hardSplit`. Per size, since the split is read against the cap band and the
    /// sign is set smaller than the number it qualifies.
    private func ink(_ size: CGFloat) -> AnyShapeStyle {
        // A rise or a fall paints the whole reading for a beat; the split is what it
        // wears the rest of the time.
        if let flash { return AnyShapeStyle(flash) }
        return AnyShapeStyle(LinearGradient.hardSplit(.white, CardPalette.lightBlue,
                                                      in: UIFont(name: Chrome.display,
                                                                 size: size)))
    }

    var body: some View {
        ZStack {
            let art = BallInPlay.vector(for: ballInPlay)
            Image(art)
                .resizable()
                .scaledToFit()
                .frame(width: ballSize, height: ballSize)
                // Flattened before `scaleEffect(pulse)` reaches it. A vector asset is
                // re-rasterised every time its rendered size changes, and this one is on
                // screen for the whole game — it was the agent's main meal. Applied to
                // the image alone so the number keeps its numeric transition.
                .drawingGroup()
                .shadow(color: CardPalette.blue, radius: 0, x: drop, y: drop)
            if BallInPlay.shines(ballInPlay) {
                BallShine(asset: art, side: ballSize)
            }

            HStack(alignment: .center, spacing: 0) {
                Text(hidden ? "??" : "\(shot)")
                    .font(.custom(Chrome.display, size: numberSize))
                    .tracking(numberSize * CardLayout.badgeTracking)
                    .contentTransition(.numericText())
                    .foregroundStyle(ink(numberSize))
                Text(hidden ? "" : "%")
                    .font(.custom(Chrome.display, size: signSize))
                    .foregroundStyle(ink(signSize))
            }
            .shadow(color: .black, radius: 0, x: max(3, drop * 0.7), y: max(3, drop * 0.7))
        }
        .scaleEffect(pulse)
        .animation(.easeOut(duration: 0.25), value: shot)
        .onChange(of: shot) { old, new in
            guard new != old else { return }
            flash = new > old ? Theme.live : Theme.danger
            withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) {
                pulse = new > old ? 1.35 : 0.78
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.18))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pulse = 1 }
                try? await Task.sleep(for: .seconds(0.22))
                withAnimation(.easeOut(duration: 0.25)) { flash = nil }
            }
        }
    }
}
