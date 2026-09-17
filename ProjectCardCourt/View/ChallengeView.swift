import SwiftUI

/// **A call, offered to the man it is against.**
///
/// The card is face down — he is not being told what was called, only that something was.
///
/// **The lantern is dark until somebody reaches for it.** On television it lights when a
/// coach actually challenges, not while he is deciding, so it sits unlit on deep teal
/// streaks under the question — and the moment the answer is yes it lights and the streaks
/// go green with it. Green is this scene's colour and nothing else's.
struct ChallengeView: View {
    let card: CardDescriptor
    /// False once his one is spent, which leaves the question unanswerable.
    var available = true
    var onChallenge: () -> Void = {}
    var onDecline: () -> Void = {}

    private let width: CGFloat = 210
    private var corner: CGFloat { width * CardLayout.cornerFraction }

    @State private var pulsing = false
    @State private var streaking = false
    /// Set the instant he says yes, which is what lights the lantern and turns the streaks.
    @State private var lit = false

    var body: some View {
        ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()
                .onTapGesture(perform: onDecline)

            VStack(spacing: 18) {
                ActionText(runs: [.init("CHALLENGE IT?",
                                        ink: lit ? Green.bright : Green.dark,
                                        drop: Green.deep)],
                           size: 30)
                back
                HStack(spacing: 12) {
                    ChunkyButton(title: "CHALLENGE", fill: Green.deep,
                                 stroke: Green.deep, shade: CardPalette.cobalt,
                                 size: 16) {
                        guard available, !lit else { return }
                        withAnimation(.easeOut(duration: Light.seconds)) { lit = true }
                        Task {
                            try? await Task.sleep(for: .seconds(Light.seconds))
                            onChallenge()
                        }
                    }
                    .opacity(available ? 1 : Light.spent)
                    ChunkyButton(title: "LET IT STAND", fill: CardPalette.gray,
                                 stroke: CardPalette.gray, shade: CardPalette.cobalt,
                                 size: 16, run: onDecline)
                }
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

    }

    /// **Streaks, not a wash.** Thin bars running across the back on the diagonal, so the
    /// card reads as something being looked at again rather than something lit up.
    private var streaks: some View {
        GeometryReader { box in
            let span = box.size.width + box.size.height
            HStack(spacing: span * Streak.gap) {
                ForEach(0..<Streak.count, id: \.self) { _ in
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, lit ? Green.bright : Green.dark,
                                                      .clear],
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
        Image(lit ? "challenge_lit" : "challenge_unlit")
            .resizable()
            .scaledToFit()
            .frame(width: width * Emblem.share)
            // Only a lit lantern glows, and only a lit one breathes.
            .shadow(color: Green.bright.opacity(lit ? Emblem.glow : 0),
                    radius: lit && pulsing ? Emblem.far : Emblem.near)
            .scaleEffect(lit && pulsing ? Emblem.swell : 1)
    }

    /// **The scene's own green.** Nothing else in the game uses it, which is what makes a
    /// challenge read as a challenge before a word is drawn.
    enum Green {
        static let bright = Color(red: 0x3C / 255, green: 0xE0 / 255, blue: 0x7A / 255)
        static let deep = Color(red: 0x14 / 255, green: 0x6B / 255, blue: 0x3C / 255)
        /// **Before the lantern is lit.** Deep teal rather than green: the colour is
        /// waiting there, but nothing has been said yet.
        static let dark = PixelPalette.deepTeal
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

    private enum Light {
        /// How long the lantern takes to come on, and how long before the scene follows.
        static let seconds: Double = 0.35
        /// A spent challenge leaves the button there, faded, rather than removing it.
        static let spent: Double = 0.35
    }
}
