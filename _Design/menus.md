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
