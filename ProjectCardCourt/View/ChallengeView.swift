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
    /// **Somebody else's challenge, watched rather than answered.** A player throwing a
    /// call out is the same event whoever does it, and an opponent doing it off screen
    /// read as the official dismissing himself. Set to the man taking it: the question
    /// becomes a statement, the buttons go, and the lantern lights on its own.
    var challenger: Seat?
    var onChallenge: () -> Void = {}
    var onDecline: () -> Void = {}

    private let width: CGFloat = 210
    private var corner: CGFloat { width * CardLayout.cornerFraction }

    /// Set the instant he says yes, which is what lights the lantern and turns the streaks.
    @State private var lit = false
    /// **One clock for the pulse and the streaks**, rather than two repeating animations.
    /// A `repeatForever` has no end, and a scene shown over and over leaves the last one
    /// still running under the next — see `SpectrumFill`.
    @State private var since = Date()

    private var pulsing: Bool { true }

    var body: some View {
        TimelineView(.animation) { tick in
            let beat = tick.date.timeIntervalSince(since)
            body(at: beat)
        }
    }

    private func body(at beat: TimeInterval) -> some View {
        // Nought to one and back on its own length, eased, for the lantern's breath.
        let swell = abs(((beat / Pulse.seconds).truncatingRemainder(dividingBy: 2)) - 1)
        let streaking = (beat / Streak.seconds).truncatingRemainder(dividingBy: 1)
        return ZStack {
            DimLayer(on: true, amount: Theme.dimBrowser)
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()
                .onTapGesture { if challenger == nil { onDecline() } }

            VStack(spacing: 18) {
                ActionText(runs: [.init(challenger.map { "\($0.playerName.uppercased()) CHALLENGES" }
                                        ?? "CHALLENGE IT?",
                                        ink: lit ? Green.bright : Green.dark,
                                        drop: Green.deep)],
                           size: 30)
                back(streaking: streaking, swell: swell)
                if challenger == nil {
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
        }
        // **Lit on its own when it is being watched.** Somebody else has already decided;
        // the light is the announcement rather than the answer.
        .task {
            guard challenger != nil else { return }
            try? await Task.sleep(for: .seconds(Light.watched))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: Light.seconds)) { lit = true }
        }
        .transition(.opacity)
    }

    /// The Z card, with green running across it.
    private func back(streaking: Double, swell: Double) -> some View {
        Image("CardBackFull")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .overlay { streaks(at: streaking) }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay { emblem(swell: swell) }
            .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
            .contentShape(Rectangle())

    }

    /// **Streaks, not a wash.** Thin bars running across the back on the diagonal, so the
    /// card reads as something being looked at again rather than something lit up.
    private func streaks(at through: Double) -> some View {
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
            .offset(x: -span * Streak.travel
                    + span * Streak.travel * 2 * CGFloat(through))
            .opacity(Streak.strength)
            .blendMode(.screen)
            .position(x: box.size.width / 2, y: box.size.height / 2)
        }
        .allowsHitTesting(false)
    }

    /// Lit while he has it, and breathing so it reads as offered rather than printed.
    private func emblem(swell: Double) -> some View {
        Image(lit ? "challenge_lit" : "challenge_unlit")
            .resizable()
            .scaledToFit()
            .frame(width: width * Emblem.share)
            // Only a lit lantern glows, and only a lit one breathes.
            .shadow(color: Green.bright.opacity(lit ? Emblem.glow : 0),
                    radius: lit ? Emblem.near + (Emblem.far - Emblem.near) * swell
                                : Emblem.near)
            .scaleEffect(lit ? 1 + (Emblem.swell - 1) * swell : 1)
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

    enum Light {
        /// How long the lantern takes to come on, and how long before the scene follows.
        static let seconds: Double = 0.35
        /// **Watched rather than answered**: how long the card stands there before the
        /// lantern lights on its own, so the scene reads as a decision being taken.
        static let watched: Double = 0.7
        /// A spent challenge leaves the button there, faded, rather than removing it.
        static let spent: Double = 0.35
    }
}
