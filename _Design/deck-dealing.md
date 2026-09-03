# Dealing, with the 3D deck

The opening deal is a scene the deck plays, rather than cards appearing in hands. The deck
is written as an **enchanted object** — see [[deck-is-an-enchanted-object]] — so it has a
repertoire it can be asked for by name rather than a pile of one-off animations.

## Built

- **`CourtStage`** — one RealityView spanning the court, holding the deck, the discard and
  anything in flight. Replaced a renderer per pile, which is what let a card leave the deck
  at all: a pile in its own small frame clips at that frame's edge.
- **Placement** — everything is positioned from the *2D* court. Callers hand over fractions
  of the view, exactly as `CourtGeometry` computes them, and `floorPoint` fires them through
  the camera onto the floor plane. Nothing re-derives the court's perspective, so a pile
  cannot drift from the sprite beside it.
- **`DeckStage`** — the repertoire: `.shuffle`, `.landing`, `.deal`, plus `travel(to:)`.
  Every slab remembers where it belongs, so any routine can be interrupted and still find
  its way back to square.
- **`CardDealer`** — one card thrown across the court, with its own arc: lift, bow across
  the line of travel, spin and tumble all rolled per throw. Walked in steps rather than
  tweened, because `move(to:)` interpolates in a straight line.
- **The opening** — in from beyond the far edge, round the table dealing to each seat,
  home, then the hard landing.

Bench buttons: `stage on/off`, `deal`, `open`, `shuffle`, `land`.

## Still to do

- **Face-down, then flipped in unison.** The dealt cards land as blank slabs. Turning all
  twenty over together at the end wants the card fronts as textures on the slab.
- **Reveals wait for the flip.** Only Intangibles can surface during a deal — a Game Break
  drawn while dealing is put back and reshuffled (`Rules.draw(duringDeal:)`) — so the flip
  only has to hold Intangible reveals, and mid-game draws are untouched.
- **Replacing `DrawFlightView`.** The 2D card flight still runs the in-game draws; the
  stage should take them over once the opening is settled.
- **Whether the deck flies in every round** or only at tip-off and halftime.

## Notes

`RenderDebug.courtStage` gates the whole thing, defaulting off, so the old per-pile
renderers stay until the stage is judged better.
