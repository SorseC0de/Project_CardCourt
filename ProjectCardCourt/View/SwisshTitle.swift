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

    /// The faces the two sizes resolve to, so the split can be placed against their
    /// capitals rather than against a frame that is mostly air.
    private var face: UIFont { Chrome.systemFace(size: size, weight: .black) }
    private var flourishFace: UIFont { Chrome.systemFace(size: size * 0.38, weight: .black) }

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
            .foregroundStyle(LinearGradient.hardSplit(top, bottom, in: flourishFace))
            .shadow(color: .black.opacity(0.6), radius: 2, y: 2)
            .fixedSize()
            .opacity(landed ? 1 : 0)
            .scaleEffect(landed ? 1 : 0.6)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: landed)
    }

    /// The letters themselves, in their arc. Built once and used twice — as the word and
    /// as its own mask — so both copies are laid out and animated identically.
    private var letterRow: some View {
        HStack(spacing: -size * 0.04) {
            ForEach(letters, id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: size, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient.hardSplit(top, bottom, in: face))
                    .rotationEffect(.degrees(landed ? tilt(index) : -35))
                    .offset(y: landed ? arc(index) : size * 1.6)
                    .scaleEffect(landed ? 1 : 0.2)
                    .opacity(landed ? 1 : 0)
                    .animation(.spring(response: 0.40, dampingFraction: 0.52)
                        .delay(Double(index) * 0.045), value: landed)
            }
        }
    }

    /// **One fill per letter, and the line placed against the letters.**
    ///
    /// These sit on an arc at alternating tilts and are all one size, so a single fill
    /// across the word would cross each letter somewhere different — the one at the
    /// bottom of the arc nearly all orange and the one at the top nearly none of it.
    /// Given to each letter it is the same inner shadow on every one, following the arc.
    ///
    /// The share is of the cap band rather than of the frame; see `Chrome.splitInFrame`,
    /// which is why this looked like a single colour before.
    private var word: some View {
        letterRow
        // Flattened before either shadow: on a stack SwiftUI casts one per letter, and a
        // hard offset copy of every glyph reads as a second, badly-set word.
        .compositingGroup()
        .shadow(color: glow.opacity(0.85), radius: 16)
        .shadow(color: CardPalette.blue, radius: 0, x: size * 0.09, y: size * 0.09)
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


