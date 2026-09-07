import SwiftUI

/// A player's name, drawn the one way it is drawn anywhere: white small caps over a hard
/// drop in the darker half of that seat's jersey.
///
/// One view rather than a treatment copied into every cutscene — a name on the floor and
/// the same name in a prompt are the same label, and they drifted apart when each scene
/// styled its own.
struct PlayerNameText: View {
    let seat: Seat
    var size: CGFloat = 26
    /// A share of the size, so the two stay in step.
    var tracking: CGFloat = 0.04

    /// Whole pixels. A fractional offset on a hard drop reads as a blur.
    private var drop: CGFloat { max(1, (size / 9).rounded()) }

    var body: some View {
        SmallCapsText(text: PlayerLook.shared.billing(for: seat),
                      font: "AvenirNextCondensed-Heavy",
                      size: size,
                      tracking: size * tracking)
            .foregroundStyle(.white)
            .shadow(color: PixelPalette.shade(for: seat), radius: 0, x: drop, y: drop)
    }
}
