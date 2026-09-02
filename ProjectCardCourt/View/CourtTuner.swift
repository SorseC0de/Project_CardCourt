import SwiftUI

/// Court positions still being eyeballed.
///
/// Observable on purpose while it is being tuned, which means the court rebuilds as a
/// slider moves. Freeze these into `Perspective` the way `CardLayout` was once they land.
@Observable
final class CourtTuning {
    static let shared = CourtTuning()

    /// The card's effect text.
    /// A multiple of the font's own leading. Below 1 closes the lines up, which
    /// `Text.lineSpacing` cannot do — it clamps at zero.
    var cardTextLineHeight: CGFloat = 0.75
    var cardTextY: CGFloat = 0.75
}

#if DEBUG

/// Debug actions, tucked under the log on the left. The sliders that lived here have
/// served their purpose — their values are frozen in `CardLayout`.
struct DebugActionsView: View {
    var controller: GameController

    var body: some View {
        HStack(spacing: 4) {
            action("draw") { controller.debugDraw() }
            action("dump hand") { controller.debugDiscardHand() }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.6)))
    }

    private func action(_ label: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(PixelPalette.gold))
        }
        .buttonStyle(.plain)
    }
}

#endif
