# Varenas and Variaballs

The game is **Variaball**. Game Breaks are being replaced by two slots of persistent,
global, replaceable board state — and the game is named after one of them.

| Slot | Type name | Card naming |
| --- | --- | --- |
| The floor | **∀rena** — written **Varena** |  Alliteration on an anchor: Arena, Court, Stadium, Gym, *-Top*, or a floor material — parquet, hardwood, maple, oak, blacktop, asphalt, concrete, rubber, tile |
| The ball | **Variaball** | `[X] Ball` — Blaze Ball |

**Printed colours:** a Varena in the purple the Game Breaks were printed in, a Variaball
in orange. Move gave the orange up for teal, and Injuries went grey.

**VA binds as a single glyph: ∀**, U+2200, the maths symbol for the universal quantifier —
*for all*. A Varena affects all four players, so the ligature means the thing the card type
does. Written and spoken it stays **Varena**; **∀rena** is the stylized form.

**Draw it, do not set it as text.** Geoform and other display faces almost certainly lack
U+2200, so typing it would silently fall back to a system serif. It goes through the existing
plate-and-subject icon system as art, weighted to match the rest of the set.

## The rules of the slots

- **The two slots are not symmetric.** The **Varena slot is never empty** — Cardwood is on
  the table from the start, exactly like Fluxx's basic rule card, and you replace rather than
  clear. The **Variaball slot starts empty**: a **Regulation Ball** is not a card, it is the
  absence of one, and Variaballs are overlays on it. In state that is a non-optional
  `courtCard` defaulting to Cardwood, and an optional `ballCard` where nil is Regulation.
- **Variaballs do not stack.** Playing one replaces whatever was on the ball.
- **Persistent.** A card stays out until somebody replaces it. This is what separates the
  mechanic from Fluxx churn: a state has to live long enough to be played *around*.
- **Global.** One Varena and one Variaball on the floor, affecting everybody.
- **Replaceable.** Playing one overwrites what was there.
- **One per player per possession**, and one for each slot. This limit is load-bearing —
  it is the governor on persistence, and loosening it turns strategy into noise.
- **Played on your own turn**, like a Move. Never out of turn: nothing in this game may
  ever wait on an absent player, which is the reason it takes to async at all.
- **Multiple copies per deck.** Not singletons.

**Cardwood** is the default floor — what the slot reads as when nothing is played on it.
**It is also a card you can play**: playing Cardwood changes the court back to basic.

## SHOT override hierarchy

An override-type effect replaces the SHOT number outright rather than adding to it. Highest
wins when more than one is in play:

**Intangible > Court (Varena) effect > Ball (Variaball) effect > everything else** (Moves,
Passes, ordinary additive play).

The court sets the terms of play; the ball plays by them. A Varena override (Spazzphalt) beats
a Variaball override (Bag'n Ball) beats ordinary additive play, and an Intangible beats all of
it. Only one override is live at a time — the highest-ranked one present wins outright.

## What the set has to cover

Converting the old Game Breaks faithfully would produce a set that is mostly about hand
size, because that is what one-shot events were for. **Coverage beats conversion**: the old
30 are a supply of names, images and effects to draw from, not a checklist owed.

Axes a **Varena** can touch: SHOT odds, shot *value* (2/3/4), the rebound board, draw
economy, hand size, **information** (hidden hands), whether Whistles fire, the shot clock,
possession flow, passing rewards, injuries.

Axes a **Variaball** can touch: the holder's SHOT, what passing does, what happens on a
miss, turnover risk, whether it can be clamped or stolen, and accumulating state.

**A card that changes a rule beats one that changes a number.** Cards in hand already move
SHOT — that is what Moves are for. These cards change the conditions those cards run under.

## Open questions

**Asymmetry is settled:** a card *may* single out a player, but **the game picks who, not the
player who played it** — by score, by who holds the ball, by who took the shot. No targeting,
no politics, and it plays identically on a table. MVPiquia is the precedent.
- **Whistles on these cards: resolved, yes.** See Tile Tampering and Over-Varing Evidence
  below. The old rule — no Whistle may ever fire on a Game Break — existed *because* they
  were not plays; these are plays now.
- **Dim Dome and the AI.** `AIPolicy` reads state directly, so hiding the SHOT number in the
  HUD is not enough — the model has to withhold it or the opponents play with perfect
  information while the player is blind.
- **The art budget.** An overlay on the existing court SVG — tint, markings, a badge — gets
  most of the read for a fraction of the work of unique floors. A few hero cards can earn
  full art.

## Settled

| Card | Slot | Effect | Count |
| --- | --- | --- | --- |
| **Prime Parquet** | Varena | SHOT +10% | 3 |
| **Lacktop** | Varena | SHOT −10%. The twin of Prime Parquet, and it retires Off Night | 3 |
| **Cardwood** | Varena | The default floor. Also playable: changes the court back to basic | 5 |
| **Smacktop** | Varena | "Clear All Whistles. Whistles Cannot Be Played. All Clamps are enhanced." Enhanced is a step more reduction, a card more discarded, a turn more locked | 3 |
| **Med Ball** | Variaball | SHOT cannot exceed 50%. The heavy ball, and it retires Rock Fight | 2 |
| **Dishcount Ball** | Variaball | Discard one fewer for card costs and Clamps | 2 |
| **Boarder Court** | Varena | Roswell Reach off your *own* miss: the shooter's Rebound bid counts as one card more. Still needs a bid of at least one. Retires Off the Backboard | 1 |
| **Blight Ball** | Variaball | Injuries travel with the ball — pass the token and your Injury *cards* go with it. New injuries join the pile, Katamari-style, so it escalates. Discarding the ball takes the pile with it, so anyone can end it by spending a Variaball — nobody wants to be the one who does | 3 |
| **Dim Dome** | Varena | The SHOT number is hidden from everyone but the ball holder. On a table you flip the % device face down | 1 |
| **Tri-hard Tiling** | Varena | Hand limit 3. *Tri* for the number, *try-hard* for the joke, tiling for the anchor — the card teaches its own rule | 3 |
| **Policeum** | Varena | Referees do not leave once triggered, so their restrictions run until the floor changes. The existing 3-ref cap bounds it. Police + policy + coliseum | 3 |
| **Kiddie Court** | Varena | A shrunk floor: no threes, every make counts 2. SHOT +10%, and dunks a further +10% on the low rim. Shuts off every `upgradesToThree` card | 3 |
| **Bench Ball** | Variaball | Receiving it by *pass* benches you: no draw, no turn, straight to the inbound. Inbounds are not passes, so the ball keeps moving and the chain cannot cascade. Retires Benched | 1 |
| **Dishtracting Ball** | Variaball | Receiving it costs you a discard, after the draw for turn. The inverse of Dishcount Ball. Retires Crowd Noise | 2 |
| **Recharging Resin** | Varena | Everyone refills to a hand of 5 at the start of their possession. Electric-themed, and the direct opponent of Tri-hard Tiling's cap of 3. Retires Designed Play | 3 |
| **Contact Court** | Varena | Being clamped sends you to the line for one free throw. The Clamp still lands. The expensive-clamping floor, against Smacktop's cheap one. Retires Foul | 3 |
| **MVPiquia** | Varena | The highest scorer refills to 5 at the start of their possession. *Piquia* is a real Brazilian hardwood used for heavy flooring, and MVP is literally in the word. Retires MVP Vote | 1 |
| **Hand Ball** | Variaball | Passing **swaps** hands: yours goes with the ball, theirs comes back. The sprite shrinks to handball size, which is the whole visual. The space is deliberate — it keeps the `[X] Ball` convention while sitting one space from the real sport. Retires Traded Mid-Game | 1 |
| **Polypaypylene** | Varena | Making a shot pays you 3 cards. *Polypropylene* is the real material in modular sport-court tiles, with *pay* in the middle of it. Retires All-Swissh Selection | 1 |
| **Foot Ball** | Variaball | **Moves and Passes are not consumed** — playing one locks it (`#[Lock]`, existing keyword) instead of discarding it, and the lock clears the moment your possession ends. A straight buff to ball movement: passing costs nothing, so you pass. Art is an orange soccer ball with the black hexagons | 1 |
| **Recharge Rock** | Variaball | Double your draw for turn. The electric ball, twin to Recharging Resin — they sit in different slots, so they stack. Retires All Star Selection | 5 |
| **Recoverena** | Varena | On play, discard all injuries. Standing, a new injury is discarded instead of applying and that player draws 1. Recover + Varena. Retires Hit the Bike | 3 |
| **Variaball** | Variaball | The eponymous 1-of signature card. On play: pull all Variaballs from the discard, shuffle them face-down, and flip the top card into the ball slot. Then discard this card. (Tabletop: pull from deck if the discard is empty; digital rolls programmatically.) Guarantees a change; can't fizzle. Retires Fresh Ball | 1 |
| **Shufflebag Ball** | Variaball | Persistent. Every possession, at the start of the active player's turn: shuffle their hand into the deck, draw the same number back, then proceed to their normal draw phase on top of that. Repeats every turn it's out — full hand randomization plus the normal draw, every single possession | 1 |
| **Carousel Court** | Varena | Hands rotate one seat in a declared direction, every possession. Retires Trade Deadline | 1 |
| **Traderous Tarmac** | Varena | During your turn, hand off any number of the Clamps on you to other players | 1 |
| **Clearcoat Court** | Varena | At the start of every possession: clear all referees, clamps, injuries, waiting effects (armed Whistles), and intangibles. The universal reset floor — every standing status type in the game, wiped each turn. Retires Official Timeout | 3 |
| **Malice Palace** | Varena | At the start of your possession, before your draw phase: discard your whole hand. Palace is real NBA arena vocabulary; the name also nods at the actual brawl. Retires Huge Altercation | 1 |
| **Turnstile Tile** | Varena | The shooter's SHOT alternates +25% / −25% each turn it's out. Visual: the floor recolors red/green each flip, Mario 3D flip-panel style — same cheap-recolor trick as Blight Ball's accumulation. Retires Home Court Advantage and Away Game | 3 |
| **Bag'n Ball** | Variaball | Draw 1 on activation. SHOT is overridden to equal the number of cards in your bag (hand). Art is styled after a Dragon Ball. Retires In The Zone | 1 |
| **Roleplayer Polymer** | Varena | At the start of each possession, everyone except the turn player draws 1. Doesn't lock anyone out — the excluded seat is whoever's shooting *this* turn, and that rotates every possession. Retires Role Player | 2 |
| **Variaball Vinyl** | Varena | The draw for turn goes to a random player each possession instead of the active player — can be them. A new addition, not tied to any of the original 30 | 1 |
| **Gravi-Gym** | Varena | SHOT −10%, no dunks. The inverse of Kiddie Court: one floor kills the arc and rewards the rim, this one kills the rim entirely and makes everything harder | 3 |
| **Blaze Ball** | Variaball | SHOT +10% each time it's passed, stacking. Fires on its own flat delta regardless of whatever else that pass is doing to SHOT — ignores other pass modifiers entirely | 5 |
| **Snow Ball It** | Variaball | SHOT −10% each time it's passed, stacking. Blaze Ball's opposite number, same independence from other pass modifiers. Retires Ice Wrap's freed name | 5 |
| **Vintage Varnish** | Varena | Shot clock 14. No threes. No Variaballs may be played while it's out. 1 Intangible per player. The retro floor — the only card that reaches into the *other* slot and shuts it off entirely | 3 |
| **S.O.S — Sell-Out Stadium** | Varena | A card that would shoot a three can instead be shot as a two, at double SHOT, keeping every other printed effect. Named for defenders selling out on the closeout, faked, and beaten for an easy two. The risk/reward mirror of Kiddie Court — choice instead of a flat rule | 3 |
| **Grayvstone** | Varena | Each possession, the ball is replaced by the last ball in the Variaball discard pile. Grave + gray + stone, softened from a literal graveyard read; the floor recolors gray to match. Reaches into the ball slot the way Vintage Varnish does. Before any ball has been discarded it tries, finds nothing, and play continues — ideally with a brief animation | 1 |
| **Con-crete** | Varena | Move cards lower SHOT −10%. Con as in cost, concrete as the genuinely brutal real surface — hard on the joints | 3 |
| **Brick Ball** | Variaball | SHOT is overridden to a flat 25%, always. No overlap with Med Ball (a ceiling) or Bag'n Ball (a formula) — a third, distinct kind of override | 2 |
| **Spazzphalt** | Varena | SHOT is overridden to a random value 0–100 in steps of 5, regardless of what ball is in play — the court dictates the terms. Loses only to an Intangible override. "Shooting on me? These are the rules" | 3 |
| **Frostbite Finish** | Varena | Playing a Move card requires discarding another card. If the Move is your whole hand, you cannot play it — there is nothing left to discard. The icy mirror of Foot Ball's buff; floor finish is the real term for a court's coating, so the ice literally is the finish | 2 |
| **Tick-Tock Tile** | Varena | Playing any card also ticks the shot clock, on top of its normal countdown and normal per-possession reset. Scoped to one floor instead of a blanket rule, which sidesteps the reset-behavior question the shelved version raised | 3 |
| **Monster Ball** | Variaball | Intangibles are absorbed into the ball and have no effect — on a table they stack under it, like Yu-Gi-Oh Xyz materials. When the ball is discarded, players rebound for the collected Intangibles one at a time. *Monstar Ball if the name is clear* | 1 |
| **Brand New Ball** | Variaball | 25% chance a shot attempt is a turnover instead | 3 |

**Overlapping cards at different power levels are deliberate**, on the HexHex model — a good
card and then a better one doing the same job. Not redundancy, and not something to flag.

**A bad ball is a weapon you hand someone.** Because all four players score individually,
passing Blight, Bench or Dishtracting is an *attack* — so the unpleasant balls drive ball
movement rather than suppressing it. Worth watching the set's ratio as it fills: if most
Variaballs are cards people want gone, the slot becomes a cleanup chore instead of a choice.

**Smacktop, Policeum, and Clearcoat Court are the officiating axis.** No refs, refs that
never leave, and refs (plus everything else standing) wiped every turn — three poles instead
of two, and Clearcoat Court is the one that answers every floor at once rather than just
Policeum. Retires Official Timeout entirely, both halves of its old effect.

**Smacktop's wording is settled**, three short lines: *Clear All Whistles. Whistles Cannot Be Played. All Clamps are enhanced.* Nothing is added to any Clamp face.

Parked, named, not yet designed:

- **Something for salary cap.** Salary Cap Increase and its old "everyone draws 2" effect are
  killed, but the theme is wanted for a future card — not yet designed.
- **Cardtan** — parked during the Foot Ball discussion, no effect or slot decided.

## Monster Ball's rebound scene

- The card sits where the ball normally is during a rebound, shaking lightly and quickly.
- **One scene, not one per Intangible.** A carousel shows the next two small, and they rotate
  in as players bid for them.
- When the scene ends, Project Stars' Capricorn coin-collection guided light beams sparks of
  random colours from the discard pile to each player who won one.

## Foot Ball's two gags

- **GOOOOAAAAAAAAL** as unique text when you score with it.
- **The goalie.** Shooting over defenders and missing brings another defender flying in from
  off screen — coin flip for which side — to block it like a keeper. Pure humour, and exactly
  the register the shot drama already plays in.

## Results screen — Most Variaball Player

Mario Party's bonus stars. Awarded at the results screen and **not** to the winner: things
like the wildest swing in score, most boards crashed, most Varenas played, biggest brick.
Computed from stats already tracked, and it answers the standing complaint that the win
screen has nothing on it but *Run It Back*.

## Whistles

Two Whistles resolved the open question above: **yes**, a Whistle can fire on a Varena or
Variaball play now that they're plays.

- **Tile Tampering** — cancels a played Varena. Turnover +1 for whoever played it.
- **Over-Varing Evidence** — the Variaball twin. Same effect. The name blends "overbearing
  evidence" (the legal idiom) with "over-varying" — the ball itself is the thing that morphs.

## Intangibles that read the slots

From the Intangible audit, 2026-09-13. Varsitile, Brawl Handler and Baller wait for the
Variaballs: dealt before then, they would do nothing.

- **Varsitile** — you can play more than 1 Varena and Variaball per turn. Once per possession,
  you can exchange the Varena and/or ball for one in the Discards. **One use can exchange both.**
- **Brawl Handler** — remove all your own Clamps when you change the ball.
- **Baller** — draw 1 card each time **you** change the ball. It was any change once.
- **Fundamentalist** — discards the current ball, once, on activation.
- **Like That** — Variaball effects still lower SHOT. The ball is what is altered, not the
  player, so Like That with Snow Ball out still loses SHOT. Not on the card.

## Killed

- **Ice Wrap** — Recoverena does it better, and *ice* is worth more as a ball.
- **Wet Spot** — the effect (fetch an Injury from the deck) had nothing to do with the name.
  The slick-floor concept survives unnamed; *Wet Wood* was killed on sight.
- **Crowd Noise**, **Foul**, **Benched**, **Traded Mid-Game**, **Designed Play**, **MVP Vote**,
  **All Star Selection**, **All-Swissh Selection**, **Off the Backboard**, **Off Night**,
  **Rock Fight**, **Swallowed Whistle**, **2-Minute Warning**, **Mic'd Up**, **Hit the Bike**,
  **Fresh Ball**, **Trade Deadline**, **Official Timeout**,
  **Huge Altercation**, **Home Court Advantage**, **Away Game**, **In The Zone**,
  **Role Player**, **Ice Wrap** — all retired into the cards above.
- **Salary Cap Increase** — killed outright ("all players draw 2," pure overlap with three
  other draw cards). The salary-cap theme is wanted again later, undesigned.
- **Back-and-Forth Game** — killed. Its entire premise ("discard the next 3 Game Breaks") no
  longer exists once Game Breaks aren't a drawable pool.
- **Team Doctor** — pure overlap with Recoverena and Clearcoat Court, no new angle. No
  replacement.
- **Floor Cleanup** — killed. It was listed as retiring into a Mop Maple that was never a card.
- **Altercation** — the weaker twin of Malice Palace, dropped outright. See the deck-space
  note below.

## All 30 resolved.

Every original Game Break has been converted, retired into a broader card, or killed
outright. **45 designed — 29 Varenas and 16 Variaballs** — several of them new
additions with no equivalent in the old 30.

## Deck space is a real constraint now

**79 slots.** The Game Breaks are out of the deck, and without them the Standard deck is 421
cards, which leaves 79 for Varenas and Variaballs. Cardwood takes 5, so it is 426 today.

**The ratio audit** (2026-09-13) came to **112 copies: 80 in courts, 32 in balls** — 33 over the 79,
on purpose for now. The whole deck gets reviewed again with them in it.

**Revised:** Cardwood to 5, and the 5-count courts to 3 — **101 copies, 69 in courts**, 22 over.

**Players should see more balls than courts** — the game is called Variaball. More Variaballs
are still to be designed, and the counts should end up weighted toward them.

**The rest of the deck was recounted** from playtesting (2026-09-13): 380 cards without
Varenas and Variaballs, 481 with the audit's 101. **Then** Close-Out, Zone, Man-To-Man and
Three-Ball took it to 390, and Monster Ball made the balls 33 — **492 in all**.

**The Intangible audit** (2026-09-13) cut three and added four: 391 without the slots. Brand New Ball made the balls 36 — **496 in all**.

Most of the old 30 were singletons. Every replacement here needs 5–10+ copies to actually
show up as a standing floor (Prime Parquet's count). That multiplies the deck's real estate
per card, so a HexHex-style weaker twin is no longer free just because it's a nice pattern —
it costs slots the set may need elsewhere. Weigh each tiered pair against that budget rather
than adding one by default.

## Shelved

Nothing currently shelved — the shot-clock idea moved into Hurry-Up Hardwood above.
