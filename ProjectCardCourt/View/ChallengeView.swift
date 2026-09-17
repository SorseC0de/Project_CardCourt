import SwiftUI

/// **A call, offered to the man it is against.**
///
/// The card is face down — he is not being told what was called, only that something was —
/// and the emblem sits on it, lit while he still has his one challenge and dark once it is
/// gone. Green runs through the whole thing, which is this scene's colour and nothing
/// else's: the streaks across the back, the glow under the emblem, and the star that goes
/// off when he takes it.
struct ChallengeView: View {
    let card: CardDescriptor
    /// False once his one is spent, which leaves the emblem dark and the answer forced.
    var available = true
    var onChallenge: () -> Void = {}
    var onDecline: () -> Void = {}

    private let width: CGFloat = 210
    private var corner: CGFloat { width * CardLayout.cornerFraction }

    @State private var pulsing = false
    @State private var streaking = false

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()
                .onTapGesture(perform: onDecline)

            VStack(spacing: 18) {
                ActionText(runs: [.init("CHALLENGE?", ink: Green.bright, drop: Green.deep)],
                           size: 30)
                back
                ChunkyButton(title: "LET IT STAND", fill: CardPalette.gray,
                             stroke: CardPalette.gray, shade: CardPalette.cobalt,
                             size: 16, run: onDecline)
            }
        }
        .task {
            withAnimation(.easeInOut(duration: Pulse.seconds).repeatForever(autoreverses: true)) {
                pulsing = true
            }
            withAnimation(.linear(duration: Streak.seconds).repeatForever(autoreverses: false)) {
                streaking = true
            }
        }
        .transition(.opacity)
    }

    /// The Z card, with green running across it.
    private var back: some View {
        Image("CardBackFull")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .overlay { streaks }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay { emblem }
            .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
            .contentShape(Rectangle())
            .onTapGesture { if available { onChallenge() } }
    }

    /// **Streaks, not a wash.** Thin bars running across the back on the diagonal, so the
    /// card reads as something being looked at again rather than something lit up.
    private var streaks: some View {
        GeometryReader { box in
            let span = box.size.width + box.size.height
            HStack(spacing: span * Streak.gap) {
                ForEach(0..<Streak.count, id: \.self) { _ in
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, Green.bright, .clear],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: span * Streak.width)
                }
            }
            .frame(width: span, height: span)
            .rotationEffect(.degrees(Streak.lean))
            .offset(x: streaking ? span * Streak.travel : -span * Streak.travel)
            .opacity(Streak.strength)
            .blendMode(.screen)
            .position(x: box.size.width / 2, y: box.size.height / 2)
        }
        .allowsHitTesting(false)
    }

    /// Lit while he has it, and breathing so it reads as offered rather than printed.
    private var emblem: some View {
        Image(available ? "challenge_lit" : "challenge_unlit")
            .resizable()
            .scaledToFit()
            .frame(width: width * Emblem.share)
            .shadow(color: Green.bright.opacity(available ? Emblem.glow : 0),
                    radius: pulsing ? Emblem.far : Emblem.near)
            .scaleEffect(available && pulsing ? Emblem.swell : 1)
    }

    /// **The scene's own green.** Nothing else in the game uses it, which is what makes a
    /// challenge read as a challenge before a word is drawn.
    enum Green {
        static let bright = Color(red: 0x3C / 255, green: 0xE0 / 255, blue: 0x7A / 255)
        static let deep = Color(red: 0x14 / 255, green: 0x6B / 255, blue: 0x3C / 255)
    }

    private enum Emblem {
        static let share: CGFloat = 0.62
        static let glow: Double = 0.9
        static let near: CGFloat = 8
        static let far: CGFloat = 26
        static let swell: CGFloat = 1.06
    }

    private enum Streak {
        static let count = 7
        static let width: CGFloat = 0.018
        static let gap: CGFloat = 0.075
        static let lean: Double = 24
        static let travel: CGFloat = 0.12
        static let strength: Double = 0.55
        static let seconds: Double = 2.4
    }

    private enum Pulse {
        static let seconds: Double = 0.9
    }
}
