# Menus

## Where the look comes from

Six reference shots sit in `_Graphic Assets/`: `menus_inspo_1` through `_6`, and
`gallery_inspo`. They are *reference*, not a target to reproduce — what was taken from them
is the structure, not the artwork:

- **Rows are cards.** A list is a stack of slabs, each one flat saturated colour with a
  heavy outline, not a table with separators.
- **Everything is outlined and everything drops.** One dark outline colour, one hard
  zero-blur shadow at one offset. This is already how the playing cards are drawn — the
  menus just carry it off the table.
- **State is a tag, not a sentence.** A small ribbon on a panel's shoulder says what the
  row is, in one or two words.
- **Readings are pills.** A dark capsule, a glyph on the left, the number on the right.
- **Buttons are chunky.** Full-width capsules in a saturated fill with the outline and the
  drop, and heavy condensed type carrying its own smaller drop so it stays legible on the
  colour.

What was deliberately *not* taken: the gradients, the sunburst backgrounds, the gloss, the
notification dots on everything, and the cluttered density. CardCourt's cards are flat and
so are its menus.

## The palette

### Where it comes from

Two things at once, which is why it holds together: a Honda Summer Event ad — deep navy
ground, gold, magenta accents — and the Golden State Warriors' City Edition colours from
last season. The second one is the part that matters. This is a basketball game made by a
Warriors fan and the palette is not neutral about that.

Worth knowing before adding a colour: matching the numbers is necessary but not sufficient.
A colour can sit perfectly in the chroma band and still be wrong because it is not a colour
those two sources would ever have used.

### The rule

Six colours, and no others: **navy, blue, orange, gold, grey, red**. Green and purple exist
in `CardPalette` for two card types and are not UI colours.

Six is enough because of how they divide up, and the division is the whole system:

- **Navy** is the only dark, so it is the ground, and it is the shadow.
- **Grey** is therefore the outline. A navy outline on a navy ground is not an outline —
  which is the one thing about this palette that has to be worked around rather than
  ignored. Every piece wears a grey rim with a thinner navy line inside it, so the edge
  reads as a *thickness* rather than as a border painted on.
- **Blue, orange, gold, red** are the four saturated fills — and there are four seats, so
  each chair gets one. `Chrome.color(for:)` owns that map.

Strokes are heavy. The weight is the style; a thin line reads as a web page.

### Expanding it

Green, magenta and purple were added by measuring rather than picking. Every one of the six
sits at 91–96% of the most chroma sRGB can hold at its own lightness and hue — but that
rule does not transfer, because green and magenta can go far further in sRGB and 93% of
their maximum is neon. What transfers is the **chroma band it produces: 0.137 to 0.228 in
OKLCH, mean 0.182**. A new colour is built at its hue, dropped into that band, and given a
lightness near the family's 0.647.

- `green` `#2EA93E` — mid band, sits with blue and gold
- `magenta` `#D34BD2` — top of the band, at red's own chroma
- `purple` `#A45FFF` — likewise

The old `purple` was `#8B1FD6`, chroma 0.248 and lightness 0.517 — above the band and below
it respectively, which is exactly why it never looked like it belonged.

### The not-black black

`black` `#2F3143`. Not a UI ground — navy keeps the lobby. This is for dark surfaces that
have to sit *beside* navy rather than under it, Intangibles first among them.

**The rule: the lightest black that still reads as black.** Not a dark that happens to
work — the top of the range, found by walking up until it stops being one. That is what to
repeat if the palette ever needs a second dark.

Three things mark where it stops, and each neighbour on the grid fails one:

- **Not desaturated enough to be greyscale.** Drop the chroma further and it leaves the
  palette entirely and becomes a neutral, which belongs to no one.
- **Not blue enough to compete with navy.** Raise the chroma, or turn the hue back toward
  263, and there are suddenly two navies on screen arguing.
- **Not too dark.** Take the lightness down and it stops being a surface things sit on and
  becomes a hole in the screen.

Navy's hue turned toward red to 279, chroma a sixth of what the gamut allows, L 0.32 — an
OKLab distance of 0.061 from navy. Worth knowing that lightness and separation-from-navy
pull directly against each other: every step lighter closes the gap, so chroma is the only
lever that buys distance without going darker.

## The kit

`View/Chrome.swift`. `Panel`, `ChunkyButton`, `Chip`, `RibbonTag`, `StatPill`,
`ScreenTitle`, and the constants they share. Assemble screens from these rather than
drawing new ones — the whole point is that two screens built a month apart still look like
the same game.

The type is `AvenirNextCondensed-Heavy`, the same face the cards and the name plates use,
through `SmallCapsText`.

## Screens

**Lobby** (`Net/MatchLobbyView.swift`) — built as the table rather than as a form. Four
chairs down the screen, one panel each in that seat's colour, filling with names as people
arrive; an empty chair says "House". The seat you are in leans out of the row. You can see
the whole game before you are in it, which is the only thing a lobby is for.

Still to do: the card gallery (see `card-gallery.md` and `gallery_inspo`), and whatever
front screen the game opens on.
