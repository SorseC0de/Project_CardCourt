import SwiftUI

/// A row of choices, one of them on. The game's own segmented control.
///
/// Built rather than borrowed: `Picker(.segmented)` is a system control wearing system
/// paint, and every other piece on these screens is a slab with a rim and a hard drop.
/// One out-of-place control is the thing that makes a screen look assembled from parts.
struct SlabPicker<Option: Identifiable & Equatable>: View {
    let options: [Option]
    @Binding var choice: Option
    /// What a chip says. Kept as a closure so an enum, a colour or a number can all use
    /// the same control.
    let label: (Option) -> String

    var fill: Color = CardPalette.gold
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let on = option == choice
                SmallCapsText(text: label(option), font: Chrome.display, size: size,
                              tracking: size * 0.06)
                    .foregroundStyle(on ? CardPalette.navy : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.vertical, size * 0.5)
                    .frame(maxWidth: .infinity)
                    .background {
                        if on {
                            Capsule().fill(fill)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 2)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { choice = option }
            }
        }
        .background(Capsule().fill(CardPalette.navy))
        .overlay(Capsule().strokeBorder(CardPalette.gray, lineWidth: 3))
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: choice)
    }
}

/// A row of colour discs. What is being chosen is a colour, so the swatch is the label.
struct SwatchPicker: View {
    let swatches: [Color]
    @Binding var choice: Int
    var side: CGFloat = 34

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(swatches.indices, id: \.self) { index in
                    let on = index == choice
                    Circle()
                        .fill(swatches[index])
                        .frame(width: side, height: side)
                        // The ring is the selection, and it sits outside the disc rather
                        // than over it — a check mark on a colour hides the colour.
                        .overlay {
                            Circle().strokeBorder(on ? CardPalette.gold : CardPalette.navy,
                                                  lineWidth: on ? 4 : 2)
                        }
                        .scaleEffect(on ? 1.12 : 1)
                        .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
                        .onTapGesture { choice = index }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: choice)
    }
}

/// A slider that only ever stops on a value.
///
/// A jersey number is one of a hundred and one things, not a point on a line, so the
/// handle steps and the readout never shows anything the shirt could not.
struct SteppedSlider: View {
    @Binding var index: Int
    let count: Int
    /// What the current stop is called, for the readout above the track.
    let label: (Int) -> String

    private enum Track {
        static let height: CGFloat = 14
        static let knob: CGFloat = 30
    }

    var body: some View {
        GeometryReader { box in
            let usable = max(1, box.size.width - Track.knob)
            let step = usable / CGFloat(max(count - 1, 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CardPalette.navy)
                    .frame(height: Track.height)
                    .overlay(Capsule().strokeBorder(CardPalette.gray, lineWidth: 3))

                Capsule()
                    .fill(CardPalette.gold)
                    .frame(width: Track.knob / 2 + step * CGFloat(index),
                           height: Track.height)

                Circle()
                    .fill(CardPalette.gold)
                    .frame(width: Track.knob, height: Track.knob)
                    .overlay(Circle().strokeBorder(CardPalette.navy, lineWidth: 3))
                    .offset(x: step * CGFloat(index))
            }
            .frame(height: Track.knob)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let along = (drag.location.x - Track.knob / 2) / step
                        index = min(count - 1, max(0, Int(along.rounded())))
                    }
            )
            // Snappy: the handle lands on the stop rather than being dragged to it.
            .animation(.spring(response: 0.18, dampingFraction: 0.8), value: index)
        }
        .frame(height: Track.knob)
    }
}
