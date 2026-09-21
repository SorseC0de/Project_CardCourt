import SwiftUI

#if DEBUG
/// **The shoe's own bench.** The real shot dome, drawn alone at its size, with nothing
/// else running under it — the in-game bench dragged the whole floor along with every
/// dial, and its list had grown too long to find anything in.
///
/// Pick a count of Moves, set where the shoe stands for it, pick the next. Only the stop
/// being set has dials, so there are three at a time rather than twelve. The numbers are
/// read straight off the dials; send them and they are frozen in `MoveHUDTuning`.
struct MoveHUDBench: View {
    @State private var tuning = MoveHUDTuning.shared
    /// Which count of Moves is being set, and so which stop the dials move.
    @State private var made = 0
    @State private var open = false

    private let ballWidth: CGFloat = 260

    var body: some View {
        VStack(spacing: 12) {
            // The dome as the bar draws it: the ball, its reading, and the meter under it.
            VStack {
                Spacer(minLength: 0)
                ShootDomeView(shot: 55, offered: [.layup, .three], moves: made,
                              moveLimit: 3, open: $open, width: ballWidth)
            }
            .frame(height: 300)
            .clipped()

            // **The count**, which is also the stop being set.
            HStack(spacing: 8) {
                ForEach(0..<tuning.shoeStops.count, id: \.self) { count in
                    Button {
                        made = count
                    } label: {
                        Text(count == 0 ? "none" : "\(count)")
                            .font(.system(size: 13, weight: .black))
                            .frame(minWidth: 44, minHeight: 30)
                            .background(RoundedRectangle(cornerRadius: 7)
                                .fill(made == count ? CardPalette.gold : CardPalette.navy))
                            .foregroundStyle(made == count ? CardPalette.navy : .white)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(heading)
                    .font(.system(size: 11, weight: .black)).tracking(1.2)
                    .foregroundStyle(Theme.inkDim)
                dial(tuning.shoeStops[made].fromCentre ? "x (from centre)" : "x",
                     binding(\.x), -500...500)
                dial("y", binding(\.y), -500...500)
                dial("rot", Binding(get: { tuning.shoeStops[made].rotation },
                                    set: { tuning.shoeStops[made].rotation = $0 }),
                     -180...180)
                Toggle("measured from the centre", isOn: Binding(
                    get: { tuning.shoeStops[made].fromCentre },
                    set: { tuning.shoeStops[made].fromCentre = $0 }))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .background(Theme.sceneGround)
    }

    /// Which stop this is, in the words the game uses.
    private var heading: String {
        switch made {
        case 0: return "SHOE — NO MOVES MADE"
        case tuning.shoeStops.count - 1: return "SHOE — THE BAR SPENT"
        default: return "SHOE — AFTER MOVE \(made)"
        }
    }

    private func binding(_ path: WritableKeyPath<ShoeStop, CGFloat>) -> Binding<Double> {
        Binding(get: { Double(tuning.shoeStops[made][keyPath: path]) },
                set: { tuning.shoeStops[made][keyPath: path] = CGFloat($0) })
    }

    private func dial(_ name: String, _ value: Binding<Double>,
                      _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: -2) {
            Text("\(name)  \(Int(value.wrappedValue.rounded()))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
            Slider(value: value, in: range, step: 1).tint(CardPalette.gold)
        }
    }
}

#Preview("Move HUD — shoe") {
    MoveHUDBench()
}
#endif
