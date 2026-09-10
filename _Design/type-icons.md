# The type icons

Nine full-colour icons, one per card type, in `_Graphic Assets/Vectors/*_Icon_new.svg`:
Pass, Move, SpecialMove, Clamp, Whistle, Intangible, GameBreak, Injury, DevaInjury.

**They replace per-card artwork.** The old scheme gave a handful of cards a drawing of
their own and left the rest to a symbol, each with its own size multiplier in
`Card.artwork` because the drawings were trimmed to their subjects. One icon per type
retires all of that.

## Every circle is in the same place

Each icon is built on a circle backdrop, and **all nine circles are now identical in
canvas coordinates**: centred, with a radius of **0.4 of the canvas side**. So the icon is
80% circle and 10% clear on every edge, and one scale knob sizes all nine — no per-icon
multiplier, and no icon that reads bigger than its neighbour because its art happened to
run to the edge.

Done by moving each file's `viewBox` rather than touching a single path, so the drawings
open in Affinity exactly as they were drawn:

    viewBox = "cx − 1.25r   cy − 1.25r   2.5r   2.5r"

where `cx, cy, r` are that file's own circle. Four of them were built on a full-bleed
circle (r = half the canvas) and four on a 0.4826 circle carrying a y offset of up to 14
units — SpecialMove sat lowest — which is what made them read as different sizes.

**Run `./Tools/icons.py` after every export.** Affinity writes the artboard back out as
the viewBox, so a file saved again loses its framing — either reset to `0 0 800 800`, or,
if it was opened with a negative origin, with that origin baked into the top transform and
the box moved to zero. Both have happened already. The tool measures the circle out of the
geometry, sets the viewBox from it, and snaps the colours in the same pass.

## Things spilling out of the circle are deliberate

Several icons break their circle on purpose — Clamp's hands reach furthest, to 1.21 radii
right and 1.12 left. The 10% margin exists for them, and it fits the widest of them with
room to spare; nothing is clipped. **The circle is the alignment reference, not the
bounding box** — do not trim a canvas to its art.

## Every icon carries its type's colour

Not the backdrop — the backdrop is usually a contrasting quiet colour — but somewhere
prominent in the drawing. Pass is blue on tan, Move orange on tan, SpecialMove gold on
blue, GameBreak magenta on teal, Whistle gold on plum.

Two do not obviously follow it and are worth a look: **Intangible** carries no `black`
at all (its backdrop is `steel`), and **DevaInjury** is red and purple rather than
`darkRed`.

## They go behind the name plate

The plate is drawn **over** the icon, and the icon runs up behind it and is cut off — the
two are on different planes rather than stacked in a column. `CardTextStyle.iconTop` is
where the top of the circle sits, 0.16 down the card against the plate's bottom edge at
0.186, so about an eighth of the circle is behind the plate at the default size.

**Placed by the top of the circle**, not by its centre and not by its frame. What the
number has to hold is how much of it the plate takes: anchored at the centre, every change
of `iconScale` moved the top and changed the cut; anchored at the frame, the clear tenth
every icon carries around its circle counted as part of the drawing.

`plateOverIcon` on the bench swaps the two, so the plate can be seen drawn under the icon
instead — the A and the B.

## In the game

Imported as `TypePass`, `TypeMove`, `TypeSpecialMove`, `TypeClamp`, `TypeWhistle`,
`TypeIntangible`, `TypeGameBreak`, `TypeInjury` and `TypeDevaInjury`, all **original**
rendering rather than template — the old type icons are template-rendered and these are
full colour. `Card.typeIcon(for:injury:)` is the map, and an Injury takes its own drawing
by how long it lasts.

`Card.artwork` answers for the type now, at scale 1, so **the size is one dial**. Four
things that were built against particular drawings are off with it, each marked in
`Card.swift` where it stands:

- `iconRepeat` — two of the same type icon says the type twice, not that two men are on
  you. Double-Team and Triple-Team.
- `accentSymbol` — the ball on a Fadeaway, the prints on a Travel. Placed against a
  drawing that is no longer there.
- `iconRotation` and `iconYAdjust` — Shot Creator's symbol had no upright.
- `isSlashed` — Swallowed Whistle. A slash belongs over a picture of the thing being
  denied, not over a Game Break's own mark.

**The three basic passes keep their arrows.** Swing Left, Swing Right, Skip Pass and
Behind-the-Back are drawn by `passArt`, which is untouched — the arrow says a direction,
which is the one thing a type icon cannot.

## The plate is printed between two layers of the icon

The circle belongs **behind** the name plate and the thing standing in it belongs **over**
it — the ball on a Pass, the ankle on a Move, the star and the ball on a Special Move,
clipping the banner's top edge. So the drawing is in two layers with the plate between
them.

The drawings live in `_Graphic Assets/Vectors/Card Icons/`, two files per type:

- **`X_plate.svg`** — everything behind the banner: the circle and what stands in it.
- **`X_subject.svg`** — what is printed over the banner.

They are exported from one canvas, so **the plate's circle frames both** — a subject is
never measured on its own, because a ball on its own has no circle to be measured against.
`./Tools/icons.py` reads the circle out of the plate and writes that viewBox into every
layer of the type, then snaps the colours.

A type with no `_subject` keeps `X_Icon_new.svg` and is drawn whole, behind the banner —
which is the fallback rather than a state any type is in: **all nine are split.**

They import as `TypePass` and `TypePassFront`, and so on.

`Card.artworkFront` only **names** it — the model is built headless and compiled by
`./Tools/sim` on a Mac, where there is no UIKit and no asset catalog. `CardFrontView` asks
whether the drawing is actually there, so a type without a front layer keeps its whole icon
behind the banner and nothing has to be switched on.

## Colour drift

**All nine are on exact palette values now**, and `./Tools/icons.py` keeps them there:
anything within six points of a palette colour is rounding and gets snapped; anything
further is a decision, and is left alone and named on stderr. Fifty-two fills were off by
one to five points — one swatch drifting across four files at a time, `#A45FFD` for
`purple` being the worst of it.

Pure black and pure white count as palette members. Everything else has to be one of the
24.

## Still to do

- Decide the two colour questions above, on the card rather than on the sheet.
- The old per-card art is still in the catalog and nothing draws it. Leave it until the
  type icons are settled.
- **Intangibles may break the mould later**: the wish is a unique full-colour icon per
  Intangible rather than one for the type. A lot of drawing, so it is a maybe.
