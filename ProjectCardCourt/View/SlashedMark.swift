import SwiftUI

/// Punches a gap out of a view rather than drawing over it.
///
/// Lifted from Plentacle's Extensions: a full-bleed rectangle masks the view, and the
/// shape drawn into it with `.destinationOut` removes itself from that mask.
extension View {
    func reverseMask<Mask: View>(alignment: Alignment = .center,
                                 @ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            Rectangle()
                .overlay(alignment: alignment) {
                    mask()
                        .blendMode(.destinationOut)
                }
        )
    }
}

/// Anything with a slash struck through it, the way Plentacle's settings do it: a wide
/// gap cut out at 45°, then a thinner bar laid into that gap so the slash reads as a
/// separate mark rather than an overlap.
struct SlashedMark<Content: View>: View {
    var side: CGFloat
    var slash: Color
    /// Gap and bar, as fractions of the side.
    var gapWidth: CGFloat = 0.16
    var barWidth: CGFloat = 0.08
    var content: () -> Content

    var body: some View {
        content()
            .frame(width: side, height: side)
            // Wider than the icon, so the rotated bar always spans it fully.
            .reverseMask {
                Rectangle()
                    .frame(width: side * 1.9, height: side * gapWidth)
                    .rotationEffect(.degrees(45))
            }
            .overlay {
                Capsule()
                    .frame(width: side * 1.35, height: side * barWidth)
                    .rotationEffect(.degrees(45))
                    .foregroundStyle(slash)
            }
    }
}
