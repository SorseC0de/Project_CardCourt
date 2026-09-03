import SwiftUI

/// The connection, drawn as what it is.
///
/// Your half of a handshake goes up the moment you start looking, and hangs there with
/// nothing to hold. When somebody is found the other half comes in and the two clasp. A
/// spinner says the app is busy; this says what it is busy *with*, and that the thing it
/// is waiting for is a person.
///
/// **The art.** One image of two hands shaking, clipped down the middle — the left half is
/// yours, the right half is theirs. Drop the vector in as `Handshake` and set
/// `Art.hasVector`; until then it draws two raised hands as a stand-in, which moves the
/// same way and reads the same way at a glance.
struct HandshakeView: View {
    /// False while waiting, true once the other half has arrived.
    var clasped: Bool
    var side: CGFloat = 220

    private enum Art {
        /// Flip to true once `Handshake` is in the catalog.
        static let hasVector = false
        static let name = "Handshake"
        /// How far out each half starts, as a share of the whole.
        static let apart: CGFloat = 0.42
        /// The squeeze when they meet.
        static let clench: CGFloat = 1.08
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
    @ViewBuilder
    private func half(mine: Bool) -> some View {
        let shown = mine || clasped
        Group {
            if Art.hasVector {
                // The whole image, clipped to its own half, so one drawing serves both and
                // the two always line up exactly where the hands meet.
                Image(Art.name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)
                    .mask(alignment: mine ? .leading : .trailing) {
                        Rectangle().frame(width: side / 2)
                    }
            } else {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: side * 0.46, weight: .heavy))
                    .foregroundStyle(mine ? CardPalette.gold : CardPalette.blue)
                    .rotationEffect(.degrees(mine ? -28 : 28))
                    .scaleEffect(x: mine ? 1 : -1)
            }
        }
        .shadow(color: Chrome.shade, radius: 0, x: mine ? 4 : -4, y: 4)
        // Apart while waiting, together once clasped.
        .offset(x: clasped ? 0 : (mine ? -side * Art.apart : side * Art.apart))
        .opacity(shown ? 1 : 0)
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
