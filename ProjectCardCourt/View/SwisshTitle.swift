import SwiftUI

/// The game's name, thrown up on every make.
///
/// Letters arrive one at a time from below with a spring, land on a shallow arc, and
/// settle at alternating tilts so the word reads as hand-lettered rather than typeset.
/// Every letter is its own view driven off one state flip, so the whole thing
/// interpolates without rebuilding per frame.
struct SwisshTitle: View {
    var text = "Swissh!!!"
    var size: CGFloat = 46
    /// The line the word is part of, set around it. Nothing by default — most makes are
    /// just the word.
    var line: SwisshLine = .plain
    /// The lettering top to bottom, and what it throws off. A robbery wears the same
    /// treatment with red where the orange sits.
    var top: Color = Theme.clockAmber
    var bottom: Color = Theme.ball
    var glow: Color = Theme.ball

    @State private var landed = false
    @State private var pulsing = false

    private var letters: [(offset: Int, element: Character)] {
        Array(text.enumerated()).map { (offset: $0.offset, element: $0.element) }
    }

    var body: some View {
        // The word keeps the middle; the rest of the sentence hangs off its shoulders.
        ZStack {
            word
            if let before = line.before {
                flourish(before).offset(x: -size * 1.9, y: -size * 0.86)
            }
            if let after = line.after {
                flourish(after).offset(x: size * 1.9, y: size * 0.86)
            }
        }
    }

    /// Small, straight, and in the same colours. Deliberately not arced or tilted — two
    /// hand-lettered curves fighting each other reads as a mistake, and the word is the
    /// one meant to be looked at.
    ///
    /// Arrives *with* the word rather than after it. Waiting for the letters to finish
    /// meant the eye read "Swissh" and then, separately, a fragment — so it never landed
    /// as one sentence.
    private func flourish(_ text: String) -> some View {
        Text(text)
            .font(.system(size: size * 0.38, weight: .black, design: .rounded))
            .foregroundStyle(LinearGradient(colors: [top, bottom],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.6), radius: 2, y: 2)
            .fixedSize()
            .opacity(landed ? 1 : 0)
            .scaleEffect(landed ? 1 : 0.6)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: landed)
    }

    private var word: some View {
        HStack(spacing: -size * 0.04) {
            ForEach(letters, id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: size, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [top, bottom],
                                       startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(landed ? tilt(index) : -35))
                    .offset(y: landed ? arc(index) : size * 1.6)
                    .scaleEffect(landed ? 1 : 0.2)
                    .opacity(landed ? 1 : 0)
                    .animation(.spring(response: 0.40, dampingFraction: 0.52)
                        .delay(Double(index) * 0.045), value: landed)
            }
        }
        .shadow(color: glow.opacity(0.85), radius: 16)
        .shadow(color: .black.opacity(0.6), radius: 3, y: 3)
        .scaleEffect(pulsing ? 1.05 : 1)
        .task {
            landed = true
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }

    /// A shallow smile: the ends ride higher than the middle.
    private func arc(_ index: Int) -> CGFloat {
        let t = Double(index) / Double(max(letters.count - 1, 1)) - 0.5
        return CGFloat(-cos(t * .pi) * 7)
    }

    private func tilt(_ index: Int) -> Double {
        let t = Double(index) / Double(max(letters.count - 1, 1)) - 0.5
        // The exclamation marks kick out harder than the word does.
        return t * 16 + (letters[index].element == "!" ? 6 : 0)
    }
}

/// What a made shot says, and what it throws.
///
/// The word itself never changes — it is the game's name. These set it inside a sentence,
/// with the emoji the hoop throws back chosen to match rather than picked at random.
struct SwisshLine: Equatable {
    /// Sits north-west of the word.
    let before: String?
    /// Sits south-east of it.
    let after: String?
    /// What bursts on the make. nil leaves the usual spoils.
    let emoji: String?

    static let plain = SwisshLine(before: nil, after: nil, emoji: nil)

    static let all: [SwisshLine] = [
        SwisshLine(before: nil, after: "upon a star!", emoji: "💫"),
        SwisshLine(before: nil, after: "cheese!", emoji: "🧀"),
        // No lamp emoji reads as a genie's, so this one takes the genie and the second
        // genie line goes, per the rule set when they were written.
        SwisshLine(before: "As you", after: nil, emoji: "🧞‍♂️"),
        SwisshLine(before: nil, after: "a ninja would!", emoji: "🥷"),
        SwisshLine(before: "Going", after: "-ing!", emoji: "🎣"),
        SwisshLine(before: "Hit \'em with the", after: "up!", emoji: "🆙"),
    ]

    /// Most makes are the plain word. A line is a treat, not the default.
    static func roll() -> SwisshLine {
        Int.random(in: 0..<3) == 0 ? all.randomElement() ?? .plain : .plain
    }
}
