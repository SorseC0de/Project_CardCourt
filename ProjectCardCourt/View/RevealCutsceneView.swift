import SwiftUI

/// A drawn Game Break or Intangible, held up for everyone to see. Intangibles then
/// shrink away toward their slots in the bottom-left.
struct RevealCutsceneView: View {
    let scene: RevealCutscene
    var onDismiss: () -> Void = {}

    @State private var arrived = false
    @State private var leaving = false

    private var accent: Color { scene.isIntangible ? Theme.clockAmber : Theme.ball }

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 10) {
                Text(scene.isIntangible ? "INTANGIBLE" : "GAME BREAK")
                    .font(.system(size: 10, weight: .black)).tracking(2.4)
                    .foregroundStyle(accent)

                CardFrontView(descriptor: scene.card, displayWidth: 210)
                    .shadow(color: accent.opacity(0.5), radius: 18)
                    .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
                    .overlay(alignment: .topTrailing) {
                        if scene.isNew { NewBadge().offset(x: 10, y: -10) }
                    }

                Text(scene.seat.playerName.uppercased())
                    .font(.system(size: 11, weight: .heavy)).tracking(1.4)
                    .foregroundStyle(Theme.inkDim)
                if scene.isNew { TapToContinue().padding(.top, 2) }
            }
            .scaleEffect(leaving ? 0.18 : (arrived ? 1 : 0.7))
            .opacity(leaving ? 0 : (arrived ? 1 : 0))
            // Toward the slots it is about to occupy.
            .offset(x: leaving ? -140 : 0, y: leaving ? 300 : 0)
        }
        .contentShape(Rectangle())
        // A card met for the first time is worth reading. Everything after is on a clock.
        .onTapGesture { if scene.isNew { onDismiss() } }
        .task {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { arrived = true }
            // A first sighting stays put until it is dismissed, so it must not fly off to
            // the slots underneath the player's own finger.
            guard scene.isIntangible, !scene.isNew else { return }
            try? await Task.sleep(for: .seconds(0.95))
            withAnimation(.easeIn(duration: 0.42)) { leaving = true }
        }
    }
}
