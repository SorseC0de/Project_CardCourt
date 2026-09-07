import SwiftUI

/// A finish at the rim, in place of a jump shot.
///
/// **Two cells of gathering, then a climb, then the finish.** All three dunks open on
/// `Sprite.dunkPrepare` and part company after it — see `Dunk`, which says how each one
/// goes up. What they share is the shape of the trip: he rises toward the far rim and
/// shrinks as he goes, because the rim is upcourt and upcourt is away.
///
/// The climb is not the whole sheet. A one-hand holds its first cell the whole way up and
/// spends the rest at the rim; a reverse cycles its first three; a whirlwind is already
/// going and simply has to *arrive* by its fifth. So the sheet is walked by hand rather
/// than played, and the rise is walked against the wall clock beside it.
struct DunkFigure: View {
    let seat: Seat
    let dunk: Dunk
    /// How it fails, or nil for one that goes down. **The trip is the same up to the
    /// point it stops being the same**: everything gathers and climbs, and what parts
    /// company is whether he arrives, how far past he carries, and whether the iron gets
    /// a say. See `DunkMiss`.
    var miss: DunkMiss?
    var scale: CGFloat = Theme.Figure.playerScale
    /// Called as he reaches the last couple of cells. **Every dunk sheet is drawn holding
    /// a ball from the first cell of the wind-up**, so the scene's own ball has to stay
    /// away until he has let go of this one — see `ShotCutsceneView`.
    var onBallLoose: () -> Void = {}
    /// Whether he is **behind** the men contesting him, called at every moment it
    /// changes. The rim is upcourt, so a man climbing toward it goes away from the camera
    /// and past the wall — he is in front of them gathering, behind them all the way up,
    /// and in front again once he is at the ring, which he comes through from behind.
    /// Modelled on `onRimPull`: he says what he is doing rather than the scene timing it.
    var onDepth: (Bool) -> Void = { _ in }
    /// How hard he is pulling on the rim, called at **every** moment he changes it and
    /// carrying the curve he is riding — nil for a snap.
    ///
    /// **Mirrored, not replayed.** The ring used to be handed one spring and asked to go
    /// down and come back on its own, with a `.delay` standing in for the beat he spends
    /// at the bottom. Two animations set on the same value in the same tick do not both
    /// run: the second wins, so the ring's descent never happened and only the first
    /// grab — where he snaps and so did it — looked right. Every change he makes is one
    /// call, and the two cannot drift.
    var onRimPull: (CGFloat, Animation?) -> Void = { _, _ in }

    @State private var tuning = DunkTuning.shared

    /// How far he goes, how small he gets, and how long he takes — this finish's own
    /// numbers, not the three sharing a set. See `DunkStyle.Trip`.
    private var tune: DunkStyle.Trip { tuning.trip(for: dunk) }

    /// How far up he is, as a share of `travel`.
    ///
    /// **Not the same value as how small he is.** They move together on a trip to the
    /// rim, and come apart on one that falls short: a man who does not get up to the ring
    /// is still as far upcourt as one who does, so he ends at the same size from a lower
    /// peak. One value for both put him at two-thirds size on the floor.
    @State private var risen: CGFloat = 0
    /// How far toward `arrivesAt` he has shrunk, nought to one — and past it on a trip
    /// that carries over the rim and away.
    @State private var shrunk: CGFloat = 0
    /// Points to the left, for a leap that goes clear of the board rather than into it.
    @State private var drifted: CGFloat = 0
    /// Art pixels he has come back down since the top. **Snapped, not tweened** — the
    /// sheet moves a pixel at a time and so does he.
    @State private var sunk: CGFloat = 0
    /// How many art pixels past his finish he is being pulled — `DunkStyle.grab` on the
    /// impact, the smaller `bounce` on every swing after it, nought when he is up.
    @State private var pulled: CGFloat = 0
    /// Which way the whirlwind is turning on the rim, once it has started.
    @State private var turned: Double?
    /// How far round a tumble has gone, in degrees. Its own value: the rim spin eases
    /// between two ends and this only ever goes one way.
    @State private var tumbled: Double = 0
    @State private var cell = 0
    /// Which sheet is up. Three of them across one trip — the wind-up, the finish, and
    /// the landing a short one ends on.
    @State private var showing: Sprite = .dunkPrepare

    /// How big he is drawn, which falls out of how far up he is. Carrying past the rim
    /// carries the shrink with it — floored, or the scale crosses zero and inverts him.
    private var drawnAt: CGFloat {
        max(DunkStyle.pastFloor, 1 + (tune.arrivesAt - 1) * shrunk)
    }

    /// How far up the top of this trip is, in points. A short one tops out under the ring.
    private var travel: CGFloat {
        miss == .short ? DunkStyle.shortPeak : tune.rise
    }

    var body: some View {
        SpriteAnimation(sprite: showing, scale: scale,
                        isPlaying: false, restFrame: cell,
                        face: PlayerLook.shared.faceOn(seat))
            .paletteSwap(PlayerLook.shared.kit(for: seat))
            .scaleEffect(drawnAt)
            // Pivoted on the hand holding the iron, not on the middle of the frame — a
            // man turning about his own belly is a man on a spit. A tumble has no hand on
            // anything, so it turns about the middle of him.
            .rotationEffect(.degrees(turned ?? 0), anchor: DunkStyle.hand)
            .animation(turned == nil ? nil
                       : .easeInOut(duration: DunkStyle.spinSeconds), value: turned)
            .rotationEffect(.degrees(tumbled))
            .offset(x: drifted,
                    y: -travel * risen + (sunk + pulled) * scale)
            .task { await throwItDown() }
    }

    private func throwItDown() async {
        // Gathering: both cells of the wind-up, on the floor. **Every trip opens here**,
        // whatever becomes of it.
        for step in 0..<Sprite.dunkPrepare.frames {
            cell = step
            try? await Task.sleep(for: .seconds(1 / tune.gatherFPS))
            if Task.isCancelled { return }
        }
        // Held coiled a beat longer when he is about to lose it — see
        // `DunkStyle.tumbleGather`.
        if miss == .tumbles {
            try? await Task.sleep(for: .seconds(DunkStyle.tumbleGather))
            if Task.isCancelled { return }
        }
        showing = dunk.sheet
        cell = 0
        // His feet are off the floor and the trip is upcourt: past the wall from here.
        onDepth(true)

        // **The tumble starts with the leap.** He has lost it the moment his feet leave
        // the floor, not once he is level with the ring — set going here, before the
        // climb, so the turn is already under way while he is still going up.
        if miss == .tumbles {
            withAnimation(.linear(duration: DunkStyle.tumbleSeconds)
                .repeatForever(autoreverses: false)) {
                tumbled = 360 * DunkStyle.tumbleTurns
            }
        }

        // Up. The climb runs on its own clock so the cells can be walked beside it —
        // and the shrink runs with it, all the way, whatever height this trip tops out
        // at. He is as far upcourt either way.
        withAnimation(.easeOut(duration: climbRun)) { risen = 1; shrunk = 1 }
        await walkTheClimb()
        if Task.isCancelled { return }

        if miss == .short { await comeUpShort(); return }

        // **Up and over.** He holds whatever he went up in and carries past the rim,
        // shrinking away with the same number that shrank him on the climb, and drifting
        // clear of the board rather than through it.
        if miss == .fliesPast || miss == .tumbles {
            withAnimation(.linear(duration: DunkStyle.pastSeconds)) {
                risen = DunkStyle.pastReach
                shrunk = DunkStyle.pastReach
                drifted = DunkStyle.pastDrift
            }
            await sailPast()
            return
        }
        // At the rim, and the rest of the sheet plays out there.
        //
        // **He peaks above where he ends.** The climb takes him to the top of the jump and
        // the last few cells bring him back down a pixel each — a man hanging off the rim
        // and dropping off it, rather than one stopping dead at the top and vanishing.
        let cells = Array((dunk.climb?.upperBound ?? dunk.arrivesBy ?? 0)..<dunk.sheet.frames)
        // **The sink is counted in pixels, not in cells.** A reverse spends two cells at
        // the rim and wants four pixels of drop, so the descent runs its own count and
        // carries on over the held last cell once the sheet is out of frames.
        // At the ring and coming through it — over the near half, and over the wall he
        // climbed past, which is well below him by now.
        onDepth(false)
        let steps = max(cells.count, tune.sink)
        for place in 0..<steps {
            cell = cells[min(place, cells.count - 1)]
            if place == max(0, cells.count - Self.lastCells) { onBallLoose() }
            if steps - place <= tune.sink { sunk += 1 }
            try? await Task.sleep(for: .seconds(1 / tune.finishFPS))
            if Task.isCancelled { return }
        }
        // And the rim gives. He pulls it past where he lands and it springs him back up
        // to the tuned finish — see `DunkStyle.grab`.
        pulled = DunkStyle.grab
        onRimPull(1, nil)
        try? await Task.sleep(for: .seconds(DunkStyle.grabHold))
        if Task.isCancelled { return }
        withAnimation(DunkStyle.grabSpring) { pulled = 0 }
        onRimPull(0, DunkStyle.grabSpring)
        await hangOnIt()
    }

    /// **He does not get up to it.** The leap tops out under the ring, he falls away from
    /// it, and only then does the landing play.
    ///
    /// Which landing depends on which way he is facing when he gets there, and that is
    /// the sheet's business rather than a rule: a reverse has already turned to the room
    /// on its own, so it lands face-on and there is nothing to turn around. The other two
    /// come down with their backs to you and have to be brought about — through the
    /// profile, which is the only cell there is between the two.
    private func comeUpShort() async {
        // A reverse falls on the last cell of its turn, which is the one facing you.
        if dunk == .reverse { cell = dunk.climb?.upperBound ?? 0 }
        // Held at the top, so the peak is somewhere he got to rather than a corner the
        // trip turns at — see `DunkStyle.shortHang`.
        try? await Task.sleep(for: .seconds(DunkStyle.shortHang))
        if Task.isCancelled { return }
        withAnimation(.easeIn(duration: DunkStyle.shortFall)) {
            risen = DunkStyle.shortLands
        }
        try? await Task.sleep(for: .seconds(DunkStyle.shortFall))
        if Task.isCancelled { return }
        // Back on the floor he took off from, which is in front of the wall.
        onDepth(false)

        await play(dunk == .reverse ? .land : .landBack, at: DunkStyle.landFPS)
        if Task.isCancelled || dunk == .reverse { return }

        // Turned to the room. One profile cell between the two, held for a beat, which
        // is what makes it a turn rather than a swap.
        showing = .right
        cell = 0
        try? await Task.sleep(for: .seconds(DunkStyle.turnHold))
        if Task.isCancelled { return }
        showing = .front
        cell = 0
    }

    /// One sheet, played through once at a given rate.
    private func play(_ sheet: Sprite, at fps: Double) async {
        showing = sheet
        for step in 0..<sheet.frames {
            cell = step
            try? await Task.sleep(for: .seconds(1 / fps))
            if Task.isCancelled { return }
        }
    }

    /// What he keeps doing on the way over the rim.
    ///
    /// **Whatever he was doing on the way up, still doing it.** He is going over the ring
    /// with the ball, not finishing, so the climb's own cells keep cycling: a one-hand
    /// holds its single cell, a reverse turns through its three, a whirlwind keeps
    /// spinning. A loop that stops in mid-air reads as the animation having broken.
    private func sailPast() async {
        let cells = dunk.climb.map(Array.init)
            ?? Array(0...(dunk.arrivesBy ?? 0))
        guard !cells.isEmpty else { return }
        while !Task.isCancelled {
            for step in cells {
                cell = step
                try? await Task.sleep(for: .seconds(1 / tune.leadFPS))
                if Task.isCancelled { return }
            }
        }
    }

    /// What he does once he is up there, which is not the same for all three.
    ///
    /// A one-hand lets go. A reverse keeps swinging on the iron; a whirlwind keeps turning
    /// on it. Both run until the scene takes the screen away, which is what cancels them.
    private func hangOnIt() async {
        switch dunk {
        case .oneHand:
            return
        case .reverse:
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tuning.bounceEvery))
                if Task.isCancelled { return }
                // **Snapped down, sprung back — the same shape as the impact.** Both
                // halves of the swing used to be springs, and the beat between them is
                // far shorter than either takes to run: each was cut off a seventh of the
                // way through and its leftover speed carried into the next, so no two
                // swings came out the same size and a replay never matched the last one.
                // One spring per swing, given the whole cycle to settle in.
                pulled = DunkStyle.bounce
                onRimPull(1, nil)
                try? await Task.sleep(for: .seconds(DunkStyle.grabHold))
                if Task.isCancelled { return }
                withAnimation(tuning.bounceSpring) { pulled = 0 }
                onRimPull(0, tuning.bounceSpring)
            }
        case .whirlwind:
            try? await Task.sleep(for: .seconds(DunkStyle.spinAfter))
            if Task.isCancelled { return }
            // Set going from one end, then walked to the other and back for as long as
            // he is up there. Each leg is its own change, so the turn eases at both ends.
            turned = -DunkStyle.spinTo
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(DunkStyle.spinSeconds))
                if Task.isCancelled { return }
                turned = (turned ?? 0) < 0 ? DunkStyle.spinTo : -DunkStyle.spinTo
            }
        }
    }

    /// How near the end he has to be before the ball is his no longer.
    private static let lastCells = 2

    /// How long the rise actually takes. The lead cells are held at their own rate and
    /// the dial is a budget, so a lead that outlasts it wins — see `DunkStyle.Trip`.
    private var climbRun: Double {
        max(tune.climb, Double(tune.leadCells) / tune.leadFPS)
    }

    /// How long one cell of the climb is held, given where it falls in the run.
    ///
    /// **Two rates, not one.** The opening cells are the drawing that has to be read —
    /// a whirlwind's spin, spread evenly over a short climb, is a blur — so they are held
    /// at a rate that divides the refresh and everything after them shares what is left.
    private func hold(_ place: Int, of count: Int) -> Double {
        guard place >= tune.leadCells else { return 1 / tune.leadFPS }
        let after = count - tune.leadCells
        guard after > 0 else { return 0 }
        return max(0, climbRun - Double(tune.leadCells) / tune.leadFPS) / Double(after)
    }

    /// The cells that play on the way up.
    ///
    /// A one-hand has one cell and holds it; a reverse has three and runs them three
    /// times; a whirlwind has no loop at all and simply walks its first five, timed so the
    /// last of them lands as he arrives. Whatever the sheet is doing, the climb takes the
    /// same time — the drawing fills it rather than deciding it.
    private func walkTheClimb() async {
        guard let loop = dunk.climb else {
            // The whirlwind: straight through, arriving on its own deadline.
            let cells = (dunk.arrivesBy ?? 0) + 1
            for step in 0..<cells {
                cell = step
                try? await Task.sleep(for: .seconds(hold(step, of: cells)))
                if Task.isCancelled { return }
            }
            return
        }
        let cells = Array(loop) * dunk.climbRepeats
        for (place, step) in cells.enumerated() {
            cell = step
            try? await Task.sleep(for: .seconds(hold(place, of: cells.count)))
            if Task.isCancelled { return }
        }
    }
}

private func * (cells: [Int], times: Int) -> [Int] {
    Array(repeating: cells, count: max(1, times)).flatMap { $0 }
}
