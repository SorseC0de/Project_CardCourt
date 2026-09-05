import SwiftUI

/// Travel gets a bit — one of three, picked at random, with the word arriving only once
/// the joke has landed.
struct TravelCutsceneView: View {
    enum Bit: CaseIterable {
        case footprints, roadTrip, flight

        /// How long the whole bit needs, word included.
        ///
        /// One hold for all three left the prints sitting there long after the joke had
        /// landed — the number was set for the plane, which has a circuit to fly.
        var hold: Double {
            switch self {
            case .footprints: return 4.2
            case .roadTrip:   return 5.4
            case .flight:     return 6.2
            }
        }
    }

    let bit: Bit
    /// The word, once the animation has made its point.
    ///
    /// Going forward the word moves the way its scene moves — it drives past with the van,
    /// flies the same circuit as the plane. Any new bit should give it a matching entrance
    /// rather than reusing the pop.
    @State private var showWord = false
    /// Drives the word across the screen for the road trip, and round for the flight.
    @State private var wordTravel: CGFloat = 0

    init(bit: Bit = Bit.allCases.randomElement()!) {
        self.bit = bit
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch bit {
                case .footprints: Footprints(size: geo.size)
                case .roadTrip:   RoadTrip(size: geo.size)
                case .flight:     Flight(size: geo.size, wordShown: showWord)
                }

                if showWord { word(in: geo.size) }
            }
            .task {
                try? await Task.sleep(for: .seconds(wordDelay))
                switch bit {
                case .footprints:
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { showWord = true }
                case .roadTrip:
                    // Drives past, the way the van just did.
                    showWord = true
                    withAnimation(.linear(duration: 2.4)) { wordTravel = 1 }
                case .flight:
                    // Pops in first, then starts its circuit. Setting both at once put the
                    // word on screen fully formed before it had done anything.
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) {
                        showWord = true
                    }
                    try? await Task.sleep(for: .seconds(0.34))
                    withAnimation(.linear(duration: 1.9).repeatForever(autoreverses: false)) {
                        wordTravel = 1
                    }
                }
            }
        }
    }

    /// The word carries the motion of whatever bit it belongs to.
    @ViewBuilder
    private func word(in size: CGSize) -> some View {
        let base = Text("TRAVEL")
            .font(.system(size: 46, weight: .black, design: .rounded))
            .tracking(3)
            .foregroundStyle(CardPalette.red)
            .shadow(color: CardPalette.navy, radius: 0, x: 4, y: 4)

        switch bit {
        case .footprints:
            base.transition(.scale(scale: 0.3).combined(with: .opacity))
                .position(x: size.width / 2, y: size.height * 0.5)
        case .roadTrip:
            base.position(x: -size.width * 0.4
                             + (size.width * 1.8) * wordTravel,
                          y: size.height * 0.5)
        case .flight:
            // Anticlockwise: negated, so the word banks the way the plane does.
            base.transition(.scale(scale: 0.3).combined(with: .opacity))
                .modifier(RimRoll(angle: Double(wordTravel) * -2 * .pi,
                                  radius: size.width * 0.16, squash: 0.7))
                .position(x: size.width / 2, y: size.height * 0.38)
        }
    }

    private var wordDelay: Double {
        switch bit {
        case .footprints: return 2.6
        case .roadTrip:   return 3.4
        case .flight:     return 2.6
        }
    }
}

// MARK: - One: the prints multiply

private struct Footprints: View {
    let size: CGSize
    @State private var landed = 0

    /// Two deliberate steps, then the floodgates.
    private let arrivals: [Double] = [0, 0.75, 1.5, 1.75, 1.95, 2.1, 2.2, 2.3, 2.38,
                                      2.44, 2.5, 2.55, 2.6, 2.64, 2.68, 2.72, 2.76, 2.8]

    var body: some View {
        ZStack {
            ForEach(0..<arrivals.count, id: \.self) { index in
                if index < landed {
                    Image(systemName: "shoeprints.fill")
                        .font(.system(size: side(index), weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.navy, radius: 0, x: 3, y: 3)
                        .rotationEffect(.degrees(turn(index)))
                        .position(spot(index))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
        }
        .task {
            for (index, at) in arrivals.enumerated() {
                try? await Task.sleep(for: .seconds(index == 0 ? at : at - arrivals[index - 1]))
                withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { landed = index + 1 }
            }
        }
    }

    /// Laid out once, by rejection: a candidate is kept only if it clears everything
    /// already down. Scattering alone let prints land on top of each other.
    private var placements: [(point: CGPoint, side: CGFloat)] {
        var placed: [(CGPoint, CGFloat)] = [
            (CGPoint(x: size.width * 0.30, y: size.height * 0.32), 76),
            (CGPoint(x: size.width * 0.70, y: size.height * 0.66), 76),
        ]
        var attempt = 0
        while placed.count < arrivals.count && attempt < arrivals.count * 140 {
            let side = 34 + CGFloat(StreakStyle.scatter(attempt, 3)) * 106
            // Negative margin: a print may hang off an edge, which is what stops the
            // field reading as a rectangle of prints.
            let bleed = -side * 0.35
            let candidate = CGPoint(
                x: bleed + CGFloat(StreakStyle.scatter(attempt, 1)) * (size.width - bleed * 2),
                y: bleed + CGFloat(StreakStyle.scatter(attempt, 2)) * (size.height - bleed * 2))
            attempt += 1

            // The word owns the middle of the screen; nothing is allowed under it.
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let clearsWord = hypot(candidate.x - centre.x, candidate.y - centre.y)
                > size.width * 0.34 + side * 0.5
            let clearsPrints = placed.allSatisfy { other in
                hypot(candidate.x - other.0.x, candidate.y - other.0.y)
                    > (side + other.1) * 0.62
            }
            if clearsWord && clearsPrints { placed.append((candidate, side)) }
        }
        return placed.map { (point: $0.0, side: $0.1) }
    }

    private func spot(_ index: Int) -> CGPoint {
        let all = placements
        return index < all.count ? all[index].point : CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func side(_ index: Int) -> CGFloat {
        let all = placements
        return index < all.count ? all[index].side : 40
    }

    private func turn(_ index: Int) -> Double {
        switch index {
        case 0: return -8
        case 1: return 26
        default: return StreakStyle.scatter(index, 4) * 360
        }
    }
}

// MARK: - Two: the road trip

/// White line art, sized by width. `resizable` has to come before `foregroundStyle`,
/// which stops returning an `Image`; the template rendering is the asset's own, set in
/// the catalogue rather than asked for at every call.
private func whiteArt(_ name: String, width: CGFloat) -> some View {
    Image(name)
        .resizable()
        .scaledToFit()
        .frame(width: width)
        .foregroundStyle(.white)
}

private struct RoadTrip: View {
    let size: CGSize

    @State private var waverGone = false
    @State private var bob: CGFloat = 0
    /// 0 off screen, 1 on the roof.
    @State private var ballFlight: CGFloat = 0
    @State private var landed = false
    @State private var driven = false

    private var rvWidth: CGFloat { size.width * 0.36 }
    private var rvY: CGFloat { size.height * 0.55 }
    // Flush against the leading edge to begin with. Everything else in the bit — the
    // wave, the roof the ball lands on — is measured from here, so they come along.
    private var rvX: CGFloat { driven ? size.width * 1.6 : rvWidth / 2 }
    private var ballSize: CGFloat { rvWidth * 0.20 }
    private var roof: CGPoint {
        CGPoint(x: rvX + rvWidth * 0.05, y: rvY - rvWidth * 0.30 + bob)
    }

    var body: some View {
        ZStack {
            if !waverGone {
                whiteArt("TravelWave", width: size.width * 0.18)
                    .position(x: rvX + rvWidth * 0.62, y: rvY + size.height * 0.03)
                    .transition(.opacity)
            }

            rv.scaleEffect(x: -1).position(x: rvX, y: rvY)

            // In from off the trailing edge, on an arc, and it stays once it lands.
            ball.position(ballPoint)
        }
        .task { await run() }
    }

    private var ballPoint: CGPoint {
        let start = CGPoint(x: size.width * 1.25, y: -size.height * 0.15)
        let end = roof
        let t = ballFlight
        let lift = size.height * 0.22 * sin(Double(t) * .pi)
        return CGPoint(x: start.x + (end.x - start.x) * t,
                       y: start.y + (end.y - start.y) * t - CGFloat(lift))
    }

    /// Only the shell bobs. Wheels that hopped with it would read as the whole van
    /// bouncing rather than an engine idling.
    private var rv: some View {
        ZStack {
            whiteArt("TravelRVBody", width: rvWidth).offset(y: bob)
            whiteArt("TravelRVWheels", width: rvWidth)
        }
    }

    private var ball: some View {
        Image(systemName: "basketball.fill")
            .font(.system(size: ballSize))
            .foregroundStyle(.white)
    }

    private func run() async {
        try? await Task.sleep(for: .seconds(0.9))
        withAnimation(.easeIn(duration: 0.25)) { waverGone = true }

        withAnimation(.easeInOut(duration: 0.10).repeatForever(autoreverses: true)) {
            bob = -size.height * 0.012
        }

        try? await Task.sleep(for: .seconds(0.8))
        withAnimation(.easeIn(duration: 0.55)) { ballFlight = 1 }

        try? await Task.sleep(for: .seconds(1.5))
        withAnimation(.easeIn(duration: 1.4)) { driven = true }
    }
}

// MARK: - Three: the flight

private struct Flight: View {
    let size: CGSize
    let wordShown: Bool

    /// 0 at the leading edge, 1 at the door.
    @State private var boarding: CGFloat = 0
    @State private var boarded = false
    @State private var looping = false
    @State private var cruising = false
    @State private var hover: CGFloat = 0

    private var planeWidth: CGFloat { size.width * 0.34 }
    private var door: CGPoint { CGPoint(x: size.width * 0.44, y: size.height * 0.56) }

    var body: some View {
        ZStack {
            if cruising { Clouds(size: size) }

            if !boarded {
                // Larger as they set off, shrinking to the plane as they reach it.
                whiteArt("TravelBags", width: planeWidth * 1.4)
                    .scaleEffect(1 - boarding * 0.62)
                    .position(x: -size.width * 0.25
                                 + (door.x + size.width * 0.25) * boarding,
                              y: size.height * 0.62
                                 + (door.y - size.height * 0.62) * boarding)
            }

            plane
        }
        .task { await run() }
    }

    private var plane: some View {
        let y = cruising ? size.height * 0.62 + hover : size.height * 0.5
        return whiteArt("TravelPlane", width: planeWidth)
            .scaleEffect(x: -1)
            .rotationEffect(.degrees(looping ? -360 : 0), anchor: UnitPoint(x: 0.5, y: -0.6))
            .position(x: size.width / 2, y: y)
    }

    private func run() async {
        try? await Task.sleep(for: .seconds(0.45))
        withAnimation(.easeInOut(duration: 1.6)) { boarding = 1 }

        try? await Task.sleep(for: .seconds(1.65))
        boarded = true

        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.easeInOut(duration: 1.3)) { looping = true }

        try? await Task.sleep(for: .seconds(1.1))
        cruising = true
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            hover = -size.height * 0.02
        }
    }
}

/// Cloud emoji drifting the way the plane is facing.
private struct Clouds: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<9, id: \.self) { index in
                    cloud(index, now: now)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func cloud(_ index: Int, now: TimeInterval) -> some View {
        let speed = 90 + StreakStyle.scatter(index, 1) * 150
        let run = Double(size.width) + 220
        let travelled = (now * speed + Double(index) * 130).truncatingRemainder(dividingBy: run)
        let y = size.height * CGFloat(0.12 + StreakStyle.scatter(index, 3) * 0.76)
        return Text("☁️")
            .font(.system(size: 22 + CGFloat(StreakStyle.scatter(index, 2)) * 46))
            .position(x: size.width + 110 - CGFloat(travelled), y: y)
    }
}
