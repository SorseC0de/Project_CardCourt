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
    var scale: CGFloat = Theme.Figure.playerScale
    /// Called as he reaches the last couple of cells. **Every dunk sheet is drawn holding
    /// a ball from the first cell of the wind-up**, so the scene's own ball has to stay
    /// away until he has let go of this one — see `ShotCutsceneView`.
    var onBallLoose: () -> Void = {}
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

    /// Where he is in the trip, nought to one, and which cell is showing.
    @State private var climbed: CGFloat = 0
    /// Art pixels he has come back down since the top. **Snapped, not tweened** — the
    /// sheet moves a pixel at a time and so does he.
    @State private var sunk: CGFloat = 0
    /// How many art pixels past his finish he is being pulled — `DunkStyle.grab` on the
    /// impact, the smaller `bounce` on every swing after it, nought when he is up.
    @State private var pulled: CGFloat = 0
    /// Which way the whirlwind is turning on the rim, once it has started.
    @State private var turned: Double?
    @State private var cell = 0
    @State private var gathering = true

    var body: some View {
        SpriteAnimation(sprite: gathering ? .dunkPrepare : dunk.sheet, scale: scale,
                        isPlaying: false, restFrame: cell)
            .paletteSwap(PlayerLook.shared.kit(for: seat))
            .scaleEffect(1 + (tune.arrivesAt - 1) * climbed)
            // Pivoted on the hand holding the iron, not on the middle of the frame — a
            // man turning about his own belly is a man on a spit.
            .rotationEffect(.degrees(turned ?? 0), anchor: DunkStyle.hand)
            .animation(turned == nil ? nil
                       : .easeInOut(duration: DunkStyle.spinSeconds), value: turned)
            .offset(y: -tune.rise * climbed
                    + (sunk + pulled) * scale)
            .task { await throwItDown() }
    }

    private func throwItDown() async {
        // Gathering: both cells of the wind-up, on the floor.
        for step in 0..<Sprite.dunkPrepare.frames {
            cell = step
            try? await Task.sleep(for: .seconds(1 / tune.gatherFPS))
            if Task.isCancelled { return }
        }
        gathering = false
        cell = 0
        // Up. The climb runs on its own clock so the cells can be walked beside it.
        withAnimation(.easeOut(duration: climbRun)) { climbed = 1 }
        await walkTheClimb()
        if Task.isCancelled { return }
        // At the rim, and the rest of the sheet plays out there.
        //
        // **He peaks above where he ends.** The climb takes him to the top of the jump and
        // the last few cells bring him back down a pixel each — a man hanging off the rim
        // and dropping off it, rather than one stopping dead at the top and vanishing.
        let cells = Array((dunk.climb?.upperBound ?? dunk.arrivesBy ?? 0)..<dunk.sheet.frames)
        // **The sink is counted in pixels, not in cells.** A reverse spends two cells at
        // the rim and wants four pixels of drop, so the descent runs its own count and
        // carries on over the held last cell once the sheet is out of frames.
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
