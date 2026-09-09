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

**If an icon is redrawn, re-check its circle**, and set the viewBox by that formula again.

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

## Colour drift

Most fills are one to five points off their palette value — Affinity rounding, the same
drift `Tools/palette.py` exists to catch. Two are real: `#FEFFFE` in Clamp, which is a
stray white rather than `cloud`, and `#F8D3A0` in SpecialMove, which is `sand` — the
colour that was dropped when the palette closed at 24.

## Still to do

- Import the nine into `Assets.xcassets` as **original** rendering, not template — the old
  type icons are template-rendered and these are full colour.
- Point `Card.artwork` at the type rather than the card, and collapse the per-icon scale
  multipliers into the one knob.
- Decide the two colour questions above.
- **Intangibles may break the mould later**: the wish is a unique full-colour icon per
  Intangible rather than one for the type. A lot of drawing, so it is a maybe.
