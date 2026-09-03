# Recording the game

TODO. Record everything silently from the first tip-off, so two screens can be built on
top of it later. Nothing here changes play — it only watches.

## What to record

Per game, per seat:

- Shots: attempts, makes, and the SHOT% each was taken at
- Free throws: attempts and makes
- Cards played, by name and by type
- PTS / AST / REB / TOV, already in `PlayerState`
- Rounds led, biggest single possession, longest pass chain

Per card, across all games: times played, times it led to a make, times it was cancelled.

## Two screens

**End of game** — a broadcast-style report. Shooting splits, card usage, the run of the
game. Reads like a half-time report rather than a spreadsheet.

**Career** — totals across every game, in the spirit of the card gallery: most-played
card, the Special Move you have the most makes with, best shooting round, worst brick.

## How

`GameEvent` is already the complete record of a match — every shot, card, rebound and
turnover passes through it. A recorder folding events into a stats struct needs no new
hooks and cannot drift from what actually happened, which is the reason to do it there
rather than instrumenting `Rules`.

Career totals persist; a game's own log does not need to.

See also [card-gallery.md](card-gallery.md), which wants the same per-card counters.
