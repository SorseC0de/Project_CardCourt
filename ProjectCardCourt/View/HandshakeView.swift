import SwiftUI

/// The connection, drawn as what it is.
///
/// Your half of a handshake goes up the moment you start looking, and hangs there with
/// nothing to hold. When somebody is found the other half comes in and the two clasp. A
/// spinner says the app is busy; this says what it is busy *with*, and that the thing it
/// is waiting for is a person.
///
/// **The art.** Two drawings, `HandshakeL` and `HandshakeR`, on one viewBox — so they are
/// simply laid over each other at the same size and land where the hands actually meet.
/// Nothing is clipped and nothing has to be aligned by hand, which is why they are two
/// files rather than one.
struct HandshakeView: View {
    /// False while waiting, true once the other half has arrived.
    var clasped: Bool
    var side: CGFloat = 220

    private enum Art {
        /// How far out each half waits, as a share of the whole.
        static let apart: CGFloat = 0.42
        /// The squeeze when they meet.
        static let clench: CGFloat = 1.08
        /// The halves carry no fill of their own, so each is tinted — yours and theirs,
        /// which is the only thing on screen saying which is which.
        static let mine = CardPalette.gold
        static let theirs = CardPalette.blue
    }

    @State private var breath: CGFloat = 1
    @State private var impact: CGFloat = 1

    var body: some View {
        ZStack {
            // A ring that lands with the clasp and is gone a moment later — the only part
            // that says something *happened* rather than something is happening.
            Circle()
                .strokeBorder(CardPalette.gold, lineWidth: 6)
                .frame(width: side, height: side)
                .scaleEffect(clasped ? 1.5 : 0.7)
                .opacity(clasped ? 0 : 0)
                .animation(.easeOut(duration: 0.5), value: clasped)

            half(mine: true)
            half(mine: false)
        }
        .frame(width: side, height: side)
        .scaleEffect(breath * impact)
        .task(id: clasped) {
            guard clasped else {
                // Waiting: a slow breath, so the screen is never quite still.
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    breath = 1.05
                }
                return
            }
            withAnimation(.easeOut(duration: 0.18)) { breath = 1; impact = Art.clench }
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { impact = 1 }
        }
    }

    /// One half of the shake. Yours is always there; theirs arrives.
    ///
    /// Both halves are drawn at the same size on the same viewBox, so they are laid over
    /// one another rather than placed beside one another — the drawing decides where the
    /// hands meet, not this file.
    private func half(mine: Bool) -> some View {
        Image(mine ? "HandshakeL" : "HandshakeR")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .foregroundStyle(mine ? Art.mine : Art.theirs)
            .drawingGroup()
            .shadow(color: Chrome.shade, radius: 0, x: mine ? 4 : -4, y: 4)
            // Apart while waiting, together once clasped.
            .offset(x: clasped ? 0 : (mine ? -side * Art.apart : side * Art.apart))
            .opacity(mine || clasped ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: clasped)
    }
}

#if DEBUG
#Preview("Handshake") {
    struct Bench: View {
        @State private var clasped = false
        var body: some View {
            VStack(spacing: 40) {
                HandshakeView(clasped: clasped)
                ChunkyButton(title: clasped ? "Reset" : "Match found") { clasped.toggle() }
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Chrome.ground)
        }
    }
    return Bench()
}
#endif
