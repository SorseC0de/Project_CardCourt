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
where the icon's top edge sits, 0.16 down the card against the plate's bottom edge at
0.186, so about a ninth of the icon is behind the plate at the default size.

**The icon is placed by its top edge, not its centre.** What the number has to hold is how
much of it the plate takes; anchored at the centre, every change of `iconScale` moved the
top and changed the cut. There is a `top` dial beside `size` on the card text bench.

## Colour drift

**All nine are on exact palette values now**, and `./Tools/icons.py` keeps them there:
anything within six points of a palette colour is rounding and gets snapped; anything
further is a decision, and is left alone and named on stderr. Fifty-two fills were off by
one to five points — one swatch drifting across four files at a time, `#A45FFD` for
`purple` being the worst of it.

Pure black and pure white count as palette members. Everything else has to be one of the
24.

## Still to do

- Import the nine into `Assets.xcassets` as **original** rendering, not template — the old
  type icons are template-rendered and these are full colour.
- Point `Card.artwork` at the type rather than the card, and collapse the per-icon scale
  multipliers into the one knob.
- Decide the two colour questions above.
- **Intangibles may break the mould later**: the wish is a unique full-colour icon per
  Intangible rather than one for the type. A lot of drawing, so it is a maybe.
