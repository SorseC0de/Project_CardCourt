# Overnight — the board, and the hand on the front screen

## Session log — 2026-09-09, overnight

> **Correction, the morning after.** Neither of these was what was asked for. The brief was
> already written down in `Parked revisions.md` and I did not read it. The front screen has
> been rebuilt to that brief — see **Done** in that file, and `View/FlyingCards.swift`; the
> fan of backs described in §2 below is gone. The board is being redesigned by hand.

**What to look at when you wake up.** Two things were assigned and both are done, on the
branch **`one-queue`**, unpushed. Build is clean, `./Tools/sim --test` is `ALL PASS`.
Nothing about the rules moved: this is all drawing.

## 1 · The scoreboard

`View/ScoreboardView.swift`, rewritten. It was the last thing in the game still drawn as a
spreadsheet — hairline columns, system type, two greys — while everything around it is
flat colour with a heavy rim and a hard drop.

**A row is a slab now.**

- Filled in `black`, which is the palette's tone for a surface that has to sit *beside*
  the dark rather than under it. That is what a row on the game screen's ground is.
- **The rim says whose row it is.** Grey for a table you are watching, your own seat's
  colour for yours.
- **A called-out row** — the winners, on the results screen — drops the black, is filled
  with the seat outright, and takes the gold rim and orange drop that everything being
  offered in this game wears.
- The drop under a row is `cobalt`. Navy on a dark ground is not a drop.
- **The stats are white with a hard navy drop, on every row**, and **the score is white
  with the seat's colour behind it**. The score is the number the board is read for, and
  a seat's colour on a black row is the dimmest thing on it — blue and red especially. So
  the colour moved to the drop, which is the rule everywhere else in this game: a drop is
  a second colour, not a darker one.
- The seat is a **square**, not a dot: everything else with an edge in this game is a
  rounded rectangle, and a circle read as a bullet.

**One number sets the whole board.** `row` — 26 over the court, where it is glanced at, and
34 on the results screen, where it is read. Everything else is a share of it, the way the
rest of the kit is written.

Two things deliberately kept:

- **`PointsCells` is untouched.** A three still flies to the exact cell it is about to
  change rather than to a place that cell is usually near.
- **The earn animation.** A stat still plumps and flashes its own colour when it goes up,
  and only its own — a rebound cannot make the points twitch. The flash colours moved to
  palette values; AST is `lightBlue` rather than the old blue, which was too near the row.

**One thing I tried and backed out of:** standing the board on the menus' navy. It looked
like a third band wedged between the status bar and the log, both of which stand on
`Theme.panel`. Compared them side by side before deciding. The board keeps `Theme.panel`
and the rows do the work.

There is a `#Preview` at the foot of the file with both sizes, so you can judge it in the
canvas without starting a match.

### Worth knowing while you are in there

`Theme.color(for: Seat)` and `Chrome.color(for: Seat)` **disagree**. Theme gives the court
a pastel set — north gold, east teal, south blue, west purple — and Chrome gives the menus
the palette's own blue, gold, orange and red. The board follows `Theme`, so it matches the
figures on the floor rather than the lobby. Making them one map is a real improvement and
a real visual change to the court, so I left it alone. Same family of fault as
`Theme.color(for: CardType)`, noted in `todo.md`.

## 2 · The hand on the front screen

`View/EntryCards.swift`, new. A fan of seven backs across the top of the entry screen,
behind the wordmark and spilling off both edges.

It is written the way `DeckStage` is — **routines with names, off one clock** — rather than
as a pile of one-off animations:

- **Deal** — one card at a time from below and off to the right, each turning up into its
  place and going a little past it before it settles. A card that decelerates cleanly looks
  placed; one that overshoots looks thrown, which is what a deal is.
- **Breathe** — every card sways on its own phase, so the arc reads as held rather than
  printed. The phases are 1.618 apart, far enough that seven cards never line back up.
- **Riffle** — every seven seconds a lift runs from the first card to the last, the way a
  thumb runs down a hand being squared up. One bump travelling once, not a standing wave.

**It is wider than the screen on purpose.** A fan that fits inside the edges reads as a
picture of a hand rather than as one being held out.

Three things it is careful about:

- It is declared **first** in the entry screen's stack, so everything is drawn over it, and
  it takes **no taps at all** — the buttons and the pad ring are untouched.
- **The drop is a rounded rectangle, not a `shadow`.** Every card is redrawn each frame,
  and a shadow costs an offscreen pass apiece for something that is only ever the card's
  own outline moved three points.
- **Reduce Motion** gets the hand as it ends up, with no clock running at all.

The clock only exists while the entry screen does — `ProjectCardCourtApp` switches screens
rather than stacking them, so nothing is animating behind a match.

## The numbers, if you want to move them

Front screen: `EntryScreenView.Front.hand` (a card's width, 100) and `.handLift` (how far
the fan sits above the mark's top, 44). Inside `EntryCards`: `count`, `step`, `spread`,
`arc`, and the four routine enums — `Deal`, `Breath`, `Riffle`, `Drop`.

Board: `ScoreboardView.row`, and the shares in `Board`.

## Not touched

The jam-packed card text and the Intangible's two golds are both still open and still first
in `todo.md`. Neither was in tonight's assignment.
