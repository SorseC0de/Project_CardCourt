import SwiftUI

/// The live SHOT reading, drawn the way the cards draw theirs — ball behind, number over
/// it, hard zero-blur shadows — just larger, and without a sign, since this is a total
/// rather than a change.
struct ShotBadgeView: View {
    let shot: Int
    var ballSize: CGFloat = 58

    @State private var pulse: CGFloat = 1
    /// Green on the way up, red on the way down, for a beat.
    @State private var flash: Color?

    private var numberSize: CGFloat { ballSize * 0.68 }
    private var drop: CGFloat { ballSize * 0.06 }

    var body: some View {
        ZStack {
            Image("BallVector")
                .resizable()
                .scaledToFit()
                .frame(width: ballSize, height: ballSize)
                // Flattened before `scaleEffect(pulse)` reaches it. A vector asset is
                // re-rasterised every time its rendered size changes, and this one is on
                // screen for the whole game — it was the agent's main meal. Applied to
                // the image alone so the number keeps its numeric transition.
                .drawingGroup()
                .shadow(color: CardPalette.blue, radius: 0, x: drop, y: drop)

            HStack(alignment: .center, spacing: 0) {
                Text("\(shot)")
                    .font(.custom("AvenirNextCondensed-Heavy", size: numberSize))
                    .tracking(numberSize * CardLayout.badgeTracking)
                    .contentTransition(.numericText())
                Text("%")
                    .font(.custom("AvenirNextCondensed-Heavy", size: numberSize * 0.5))
            }
            .foregroundStyle(flash ?? .white)
            .shadow(color: .black, radius: 0, x: drop * 0.7, y: drop * 0.7)
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
