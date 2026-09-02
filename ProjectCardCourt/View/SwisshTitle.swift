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

    @State private var landed = false
    @State private var pulsing = false

    private var letters: [(offset: Int, element: Character)] {
        Array(text.enumerated()).map { (offset: $0.offset, element: $0.element) }
    }

    var body: some View {
        HStack(spacing: -size * 0.04) {
            ForEach(letters, id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: size, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.clockAmber, Theme.ball],
                                       startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(landed ? tilt(index) : -35))
                    .offset(y: landed ? arc(index) : size * 1.6)
                    .scaleEffect(landed ? 1 : 0.2)
                    .opacity(landed ? 1 : 0)
                    .animation(.spring(response: 0.40, dampingFraction: 0.52)
                        .delay(Double(index) * 0.045), value: landed)
            }
        }
        .shadow(color: Theme.ball.opacity(0.85), radius: 16)
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
