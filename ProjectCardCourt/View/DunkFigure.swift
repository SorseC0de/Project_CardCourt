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
    /// How far he travels toward the rim, in points, and how small he ends up.
    var rise: CGFloat = 150
    var arrivesAt: CGFloat = 0.55
    var scale: CGFloat = Theme.Figure.playerScale

    /// Where he is in the trip, nought to one, and which cell is showing.
    @State private var climbed: CGFloat = 0
    @State private var cell = 0
    @State private var gathering = true

    private enum Beat {
        /// The wind-up, and the climb. Both at the shot's own rate, which is the beat the
        /// whole scene is built on.
        static var fps: Double { Theme.Figure.shootFPS }
        /// How long he spends going up. Long enough to read as a rise rather than a cut.
        static let climb: Double = 0.55
    }

    var body: some View {
        SpriteAnimation(sprite: gathering ? .dunkPrepare : dunk.sheet, scale: scale,
                        isPlaying: false, restFrame: cell)
            .paletteSwap(PlayerLook.shared.kit(for: seat))
            .scaleEffect(1 + (arrivesAt - 1) * climbed)
            .offset(y: -rise * climbed)
            .task { await throwItDown() }
    }

    private func throwItDown() async {
        // Gathering: both cells of the wind-up, on the floor.
        for step in 0..<Sprite.dunkPrepare.frames {
            cell = step
            try? await Task.sleep(for: .seconds(1 / Beat.fps))
            if Task.isCancelled { return }
        }
        gathering = false
        cell = 0
        // Up. The climb runs on its own clock so the cells can be walked beside it.
        withAnimation(.easeOut(duration: Beat.climb)) { climbed = 1 }
        await walkTheClimb()
        if Task.isCancelled { return }
        // At the rim, and the rest of the sheet plays out there.
        for step in (dunk.climb?.upperBound ?? dunk.arrivesBy ?? 0)..<dunk.sheet.frames {
            cell = step
            try? await Task.sleep(for: .seconds(1 / Beat.fps))
            if Task.isCancelled { return }
        }
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
            let each = Beat.climb / Double(cells)
            for step in 0..<cells {
                cell = step
                try? await Task.sleep(for: .seconds(each))
                if Task.isCancelled { return }
            }
            return
        }
        let cells = Array(loop) * dunk.climbRepeats
        let each = Beat.climb / Double(cells.count)
        for step in cells {
            cell = step
            try? await Task.sleep(for: .seconds(each))
            if Task.isCancelled { return }
        }
    }
}

private func * (cells: [Int], times: Int) -> [Int] {
    Array(repeating: cells, count: max(1, times)).flatMap { $0 }
}
