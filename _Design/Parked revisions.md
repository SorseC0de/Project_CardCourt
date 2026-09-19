# Parked revisions

Noted, deliberately **not** acted on. The night is for online multiplayer: it has been
broken for a week and that week has cost every tester who has not been onboarded.

Dunk cards are the one exception — those get done when they arrive.

---

## Open

- **Scoreboard UI.** Deferred from the overnight run to keep the usage on the queue.
  CardBlue ground, white Avenir, navy drop shadows at 3pt. Each player row is an HStack,
  left to right: `player_head` with the seat's colour dropped SE at 3pt, then the jersey
  number and name, then the point totals. The black band above the scoreboard becomes
  CardNavy. Reference shots are `menus_inspo_1..4`, `_6` and `gallery_inspo` in
  `_Graphic Assets/` — see `_Design/menus.md`, which already says what was taken from them
  and what was deliberately not.
- **One queue for everything** — prompts, ball movement, name display. Written up with
  the evidence in `_Design/one-queue.md`, including a way in that is not a rewrite.
- **Dribble to 20.** It should be the most plentiful Move — it is at 15. Nothing obvious
  to take it from; clamps are the suspicion. Wants a full game first, then decide.

## Done

- **Main menu, flying cards.** `View/FlyingCards.swift`, built to the brief: card backs
  emanating in rays from behind the wordmark, behind it and the buttons, looping while the
  menu is up, slow travel and slow spin, pixel backs counter-clockwise and the drawn one
  clockwise, growing and fading to nothing at the edges. One `Image` per card animated by
  modifiers with staggered delays — no `TimelineView` — `drawingGroup` on each, no shadow
  and no blur.

  **One thing decided on top of the brief.** A card grows by how far it has actually gone
  rather than by how far through its trip it is. The mark sits high on the screen, so a ray
  pointing up has about a fifth of the ground to cover that one heading into the bottom
  corner has; growing on trip fraction put full-size cards on the wordmark within a second.
  Growing with distance reads as depth instead — the ones with somewhere to go come
  forward, the ones without stay small and fade out at the top edge. Compared against two
  other arrangements before choosing.

  **And one thing found.** `Rasters/Swish Card Design_v2.png` is the PNG of the vector,
  and it is **stale**: it carries the old navy `#1F3665` from before the `#1C3261`
  correction. Re-exported from the current SVG as `Rasters/CardCourt_CardBack.png` at
  507×667 and imported as `CardBackRaster`. Worth re-exporting the old one or deleting it.
