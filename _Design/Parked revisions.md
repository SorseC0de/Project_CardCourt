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
- **Main menu, flying cards.** Deferred with the above. Card backs emanating radially in
  rays from behind the Swissh wordmark, drawn behind the wordmark and the buttons, looping
  for as long as the menu is up. Slow travel, slow spin — **pixel backs counter-clockwise,
  the high-quality one clockwise** — scaling up and fading to nothing as they reach the
  edges. Both versions are in the folder; a PNG of the vector now exists, which matters:
  a vector re-rasterises every time its drawn size changes, so anything that scales must
  be the raster. Cheapest shape is one `Image` per card, animated by modifiers with
  staggered delays rather than a `TimelineView`, no shadow and no blur, `.drawingGroup()`
  each. Authoring resolution does not matter since they fade out before they are large.
- **One queue for everything** — prompts, ball movement, name display. Written up with
  the evidence in `_Design/one-queue.md`, including a way in that is not a rewrite.
- **Dribble to 20.** It should be the most plentiful Move — it is at 15. Nothing obvious
  to take it from; clamps are the suspicion. Wants a full game first, then decide.

## Done

_(nothing yet)_
