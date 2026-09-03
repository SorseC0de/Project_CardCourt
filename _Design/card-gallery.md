# Card Gallery — TODO (targeting v1.0)

A collection screen that fills in as players meet cards during play. Two jobs: something to
complete, and somewhere to read card effects outside a match.

## Shape

- **Paged by card type** — Pass, Move, Special Move, Clamp, Whistle, Game Break, Intangible.
- Each page shows **how many cards of that type exist** and that many slots, so the gap is
  visible before it is filled. Unseen slots stay empty rather than hidden.
- A card is "seen" the first time it is encountered in play.
- **First sighting pops the card large on screen** with a **New** badge in a corner.

## Trophies

- One **named trophy per completed page**.
- One for the **completed catalogue**.

## What already exists to build on

- `CardFrontView` draws any `CardDescriptor` at any size, so gallery entries and the
  in-game reveal are the same view.
- `RevealCutsceneView` already pops a card large to the middle of the screen; the New badge
  is an overlay on that rather than a new scene.
- `MatchRules.cardPool` is the authoritative list per mode, so page counts derive from the
  mode rather than a second hand-kept list. **Classic and Standard have different pools** —
  decide whether the catalogue is per mode or the union of both.

## Open questions

- Does seeing a card in an opponent's hand count, or only cards you draw or that resolve on
  you? Cheapest is "any card that appears in the log or a cutscene".
- Persistence: this is the first thing in the game that outlives a match, so it needs a
  store. Nothing else currently persists.
