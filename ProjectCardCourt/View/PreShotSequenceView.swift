import SwiftUI

/// **How a shot got to its number**, played before it goes up.
///
/// The screen dims and the SHOT plate stands in the middle at the raw reading — what the
/// Moves built, and nothing else. Everything adding to it waits in a line on the left,
/// everything taking away on the right. The adders go in one at a time and the plate
/// swells green as it climbs, past a hundred if that is where it goes; then the detractors,
/// red, the other way. A last swell settles the total where the rules cap it, the plate
/// goes to the corner and the shot plays.
///
/// **Built from the rules' own breakdown**, not worked out again — see `ShotResolution`,
/// whose steps are the cards in the order they were applied with the running total after
/// each. The plate's own pulse and flash do the rest: it already swells and colours
/// whenever its number moves.
struct PreShotSequenceView: View {
    let breakdown: ShotResolution

    /// Nil until the first frame, so the line starts full.
    @State private var startedAt: Date?

    /// One thing that moved the number: the card if it is one, and by how much.
    struct Beat: Identifiable {
        let id: Int
        let card: CardDescriptor?
        let label: String
        let delta: Int
    }

    var body: some View {
        TimelineView(.animation) { tick in
            let t = startedAt.map { tick.date.timeIntervalSince($0) } ?? 0
            GeometryReader { screen in
                scene(at: t, in: screen.size)
            }
        }
        .allowsHitTesting(false)
        .onAppear { startedAt = Date() }
    }

    // MARK: - The beats

    /// Every step that moved the number, split by which way it moved it. Adders first and
    /// then detractors, whatever order the rules applied them in; the last swell settles
    /// on the rules' own total either way, so a multiplier read out of order still lands
    /// on the right figure.
    private var beats: (up: [Beat], down: [Beat]) {
        var previous = breakdown.base
        var up: [Beat] = []
        var down: [Beat] = []
        for (index, step) in breakdown.steps.enumerated() {
            let delta = step.total - previous
            previous = step.total
            guard delta != 0 else { continue }
            let beat = Beat(id: index, card: Self.card(named: step.label),
                            label: step.label, delta: delta)
            if delta > 0 { up.append(beat) } else { down.append(beat) }
        }
        return (up, down)
    }

    /// The card a step is named for, when it is one.
    private static func card(named label: String) -> CardDescriptor? {
        CardLibrary.byID.values.first { $0.name == label }
    }

    // MARK: - Timing

    /// The whole sequence, in seconds — never past five however much is stacked.
    static func duration(for breakdown: ShotResolution) -> Double {
        let moved = breakdown.steps.indices.filter { index in
            let before = index == 0 ? breakdown.base : breakdown.steps[index - 1].total
            return breakdown.steps[index].total != before
        }.count
        return Beat.dimIn + beatLength(moved) * Double(moved) + Beat.settle + Beat.leave
    }

    /// How long one card takes, shorter when there are many so the whole stays quick.
    private static func beatLength(_ count: Int) -> Double {
        min(Beat.longest, Beat.budget / Double(max(1, count)))
    }

    // MARK: - Drawing

    private func scene(at t: Double, in size: CGSize) -> some View {
        let (up, down) = beats
        let ordered = up + down
        let beat = Self.beatLength(ordered.count)
        let beatsEnd = Beat.dimIn + beat * Double(ordered.count)
        let leaveAt = beatsEnd + Beat.settle
        let middle = CGPoint(x: size.width / 2, y: size.height * Layout.plateY)
        let corner = CGPoint(x: Layout.cornerInset, y: Layout.cornerInset * 2.2)

        // Where the reading stands at this moment: the raw figure, plus every card that
        // has landed, and the rules' own total once the last one is in.
        let landed = ordered.enumerated().filter { index, _ in
            t >= Beat.dimIn + beat * (Double(index) + Beat.landsAt)
        }.map(\.element)
        let reading = t >= beatsEnd
            ? breakdown.chance
            : breakdown.base + landed.reduce(0) { $0 + $1.delta }

        let leaving = min(1, max(0, (t - leaveAt) / Beat.leave))
        let dim = t < leaveAt ? min(1, t / Beat.dimIn) : 1 - leaving

        return ZStack {
            Color.black.opacity(Layout.dim * dim).ignoresSafeArea()

            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, item in
                queued(item, index: index, up: index < up.count,
                       place: index < up.count ? index : index - up.count,
                       at: t, beat: beat, middle: middle)
            }

            ShotBadgeView(shot: reading, ballSize: Layout.plate)
                .scaleEffect(1 - leaving * Layout.shrinkToCorner)
                .position(x: middle.x + (corner.x - middle.x) * leaving,
                          y: middle.y + (corner.y - middle.y) * leaving)
                .opacity(1 - leaving * 0.6)
        }
    }

    /// One card in its line, then on its way into the plate, then gone.
    @ViewBuilder
    private func queued(_ item: Beat, index: Int, up: Bool, place: Int,
                        at t: Double, beat: Double, middle: CGPoint) -> some View {
        let start = Beat.dimIn + beat * Double(index)
        let lands = start + beat * Beat.landsAt
        if t < lands {
            let travel = min(1, max(0, (t - start) / (lands - start)))
            let side: CGFloat = up ? -1 : 1
            let home = CGPoint(x: middle.x + side * (Layout.firstInLine
                                                     + CGFloat(place) * Layout.overlap),
                               y: middle.y)
            Group {
                if let card = item.card {
                    CardFrontView(descriptor: card, displayWidth: Layout.card)
                } else {
                    Text(item.label.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(CardPalette.navy))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            .overlay(alignment: .top) {
                Text(item.delta > 0 ? "+\(item.delta)" : "\(item.delta)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(item.delta > 0 ? Theme.live : Theme.danger)
                    .shadow(color: .black, radius: 0, x: 1, y: 1)
                    .offset(y: -16)
                    .opacity(1 - travel)
            }
            .scaleEffect(1 - travel * 0.75)
            .opacity(1 - travel * 0.4)
            .position(x: home.x + (middle.x - home.x) * travel,
                      y: home.y + (middle.y - home.y) * travel)
            .zIndex(Double(100 - place))
        }
    }

    // MARK: - Measurements

    fileprivate enum Layout {
        static let plate: CGFloat = 110
        static let plateY: CGFloat = 0.42
        static let card: CGFloat = 58
        /// How far the first card in each line stands from the plate, and how much of the
        /// next one shows behind it.
        static let firstInLine: CGFloat = 96
        static let overlap: CGFloat = 26
        static let dim: Double = 0.62
        static let cornerInset: CGFloat = 52
        static let shrinkToCorner: CGFloat = 0.55
    }
}

private extension PreShotSequenceView.Beat {
    /// The dim coming down, and how long the plate holds after the last card before it
    /// settles, and the trip to the corner.
    static let dimIn: Double = 0.25
    static let settle: Double = 0.45
    static let leave: Double = 0.4
    /// How far into its beat a card is when it lands — the rest is the plate reacting.
    static let landsAt: Double = 0.6
    /// The longest one card is given, and what they share between them however many there
    /// are, so the whole is never more than five seconds.
    static let longest: Double = 0.45
    static let budget: Double = 3.4
}

#if DEBUG
#Preview("Pre-shot") {
    ZStack {
        Theme.sceneGround.ignoresSafeArea()
        PreShotSequenceView(breakdown: ShotResolution(
            base: 40,
            steps: [ShotStep(label: "Sniper", total: 65),
                    ShotStep(label: "Contest", total: 40),
                    ShotStep(label: "Hot Hand", total: 55)],
            chance: 55))
    }
}
#endif
