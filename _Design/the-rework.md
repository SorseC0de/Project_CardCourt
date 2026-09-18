# The Rework

The redesign the game is being rebuilt around. Everything here was decided in conversation;
where a thing is still open it says so rather than guessing.

**Built on the `rework` branch, 2026-09-16.** What landed is marked through the document.
What is still open is collected at the end.

The measurements that motivated it are in `what-makes-it-fun.md` — the short version is that
the ball moves 0.24 times a possession and dies on its holder 57% of the time, 29% of
possessions are dead air, hands sit at a mean of 2.4, and 74% of all card loss is rebound
bidding. The rework is aimed at those numbers, but it is not a patch on the current game.
It changes what the game is made of.

---

## 1. The hand is capped at five

A hard limit of five cards. **Any draw past the limit converts into SHOT +10% instead**, one
per card that would have been drawn.

Why:

- You get value no matter what, so a draw is never dead. The standing complaint that draws
  are +0s — they break even instead of providing card advantage — stops applying at both
  ends: under the cap a surplus draw is tempo instead of nothing.
- It reins the game state in. Five cards is a board a new player can hold, and a table can
  lay out.
- It gives a reason to keep hand size *up* rather than only to spend it.
- The fiction already fits. Drawing cards is moving with the ball; overflow is getting open.
  It plays like a free Move card.

One exchange rate runs through the whole game as a result: **one card = one pass = 10% SHOT.**
Passing, drawing and getting open all speak the same unit.

**Built.** `MatchRules.handLimit` and `MatchRules.overflowShot`; the conversion is in
`Rules.draw`, which pays `adjustShot` and raises `.drawConverted`.

**Settled:** it keys off whatever limit is in force, so a floor that sets a stricter one
converts sooner. `GameState.handLimit` is the match's, or the floor's if that is lower.

---

## 2. Every Move draws at least one

Moves are the colour that keeps the game flowing, which is what they do in the sport. Giving
all of them a draw:

- gives Red an identity it currently lacks (today it is "dribble, draw a card" with no
  through-line),
- keeps the game moving by default rather than by exception,
- and makes stringing Moves together feel powerful — a run of them is a run of cards.

**Countered by a ref who calls a travel past three Move cards played.** The engine has a
speed limit, and the limit is public.

**Built.** Every `.move` descriptor carries a `drawCount` of at least one, and Travel is
the speed limit: `WhistleEffect.requiresMovesThisPossession = 3`, so the fourth Move of a
possession is the one that travels.

---

## 3. Refs move to the Officials Deck

Whistles leave the main deck and become their own pile, with their own look — referee
stripes, not a colour slot.

They also lose the trap-card theme. **Everyone can read what the refs are eyeing.** Three
officials are assigned, the way a real game has a three-person crew, and they set the stage
everyone plays under.

Sequence:

1. The main deck and the officials deck are both shuffled at the start of the game.
2. Hands of five are dealt.
3. The top three officials cards are turned face-up. Those are the rules for the round.

Each round the three current refs go to the bottom of the officials deck, the deck is
shuffled, and three new ones are dealt. **A Retired Ref goes to the bottom of the Ref deck,
never to Retirement** — so Retirement only ever holds main-deck cards, and the Ref deck is
simply reshuffled every round. The Equalizer is the exception: once Retired it leaves the game.

**Being experimented with instead:** swap one per round, with the scorer choosing which to
bench — picking based on what makes it easier for them to score next round given the hand
they are holding. Closer to Pokémon's prize cards.

**Tabletop:** the three players who are not inbounding are the ones who shuffle the officials
deck and pluck the new ref, for the extra interaction.

**Built**, in the first shape: both decks shuffled once at the start of the game, the whole
crew replaced each round. `GameState.officials` and `officialsDiscard` are the pile,
`Rules.assignCrew` deals it, and `ArmedWhistle.owner` is optional — nil is the crew's.
Nobody can play a Whistle from hand: the crew fills every slot, so `legalMoves` never
offers one. The referee on the floor wears his call over his head, and the inspect sheet
shows all three face up.

**Not built:** the one-a-round swap with the scorer choosing, and the tabletop shuffle.

Why it works:

- Visible negation is a wall you route around; hidden negation is a toll. Routing around a
  wall is agency.
- It is the Fluxx read — what am I building toward in *this* game — without Fluxx's actual
  complaint, which is that the goal churns before the plan can pay off.
- It means the same fixed deck plays differently every match. Which refs are assigned decides
  which cards are live tonight, so you get format rotation without shuffle variance.

---

## 4. Clamps become a pillar

Defenders persist. They do not fire and vanish; they stand in front of you until you deal
with them.

- **One per opponent.** Each opponent may assign you at most one. Matchups stay legible by
  ownership and can never stack into a lock.
- **The debuff is printed, and so is the counter.** "Discard this card at shot clock 05 or
  less." "Hand size 3 or more." The condition that clears them is on the card, in the open.
- A player spends the possession working to free themselves from the defender in front of
  them, or working toward the payout for clearing any defender. There are two games going at
  once for everybody.

### Two escapes

- **Blow by** — spend what it costs, beat him, take the payoff.
- **Shoot over** — free, no payoff, available when the matchup simply does not apply. A seven
  footer does not see the five-two defender.

### The payoff

Clearing a defender pays like Triple Threat — a menu, not a reward:

- draw 1, or
- shoot immediately at a boosted percentage, or
- pass with an additional benefit: pass and refill, pass and move the remaining clamps to the
  new player, or **pass and move the cleared clamp onto the new player instead of discarding
  it**.

That last one is the best of them. It is a defensive rotation — you blew by him, so he picks
up your teammate — it keeps the card on the field in a game that sheds cards faster than it
draws them, and it is political: you choose who gets hounded next.

### Pace

Hand size is public, so clamps can read it. A center who stops shots from players holding two
or fewer punishes slow play, and you counter him by going faster — by drawing. The inverse
card is a guard who is countered by shooting at a low hand.

This is the point of it: **low hand and high hand both become a matter of timing rather than
one always being good and one always being bad.** Only Infernity ever solved that in
Yu-Gi-Oh; in every other deck an empty hand meant a loss.

Because hand size is public, sending a high-hand punisher at a player sitting on five is an
obvious play — which means the threat works from your hand, before the card is ever spent.
It also makes the discard pile worth watching: a player who pitches their high-hand clamp for
a rebound has told the whole table it is safe to draw.

### Notes for when these get written

- **Tax, don't block.** An uncleared defender must leave the player able to act. The hard stop
  belongs to the pace condition alone, or persistence turns a bad turn into a bad game.
- **The good ones bring their own condition.** A center who punishes two-or-fewer is only
  frightening if something is draining that hand. Either he drains it himself, or he is the
  payoff half of a two-card plan. The ones that only wait are the ones people shoot over.
- **No legal pair covers the whole range.** With several defenders on one player there must
  always be a hand size that escapes, even an awkward one.
- **Clamps and refs are one matrix, not two lists.** Every shot type needs refs that punish it
  and clamps that force it, roughly evenly, or a tip-off draw can leave a player holding
  clamps with nothing to set up.

The combination is the centrepiece: a clamp forces a shot type, a ref punishes that shot type,
and both are face-up. The victim watches it happen. That is a checkmate rather than a trap,
and checkmate is the one people replay afterwards.

---

## 5. The shoot button splits three ways

One button becomes **two-pointer (layup?), three-pointer, and dunk**, in a triangle — each
with its own pros and cons, each interacting heavily with defenders, refs, hand state and
board state.

Sketches, not decisions:

- layups only attempted at an empty hand
- dunks above a SHOT threshold
- threes at a full hand of five

**Built**, with one change to the sketch: **the layup is never gated.** Gating all three
meant a player at three cards and a poor look could not shoot at all, which is a soft lock
rather than a decision. So the layup is always there and pays `emptyHandedLayupBonus`
(+25%) at an empty hand — the one place in the game where being broke is worth something —
while the dunk wants SHOT 50% and the three wants a full hand and is worth the extra point.

Each has an official watching it: Charge on the dunk, Foot On The Line on the three (which
downgrades rather than cancelling), Offensive Foul on the layup.

**Not built:** the make effects off each finish — a layup drawing, a dunk costing the
target a card, a three taking something off the floor. The triangle scores differently but
does not yet *do* three different things.

---

## 6. Aim at 300 cards or fewer

Many cards get absorbed into whatever survives; some are dropped outright.

What the rework displaces, at today's counts:

| | today | after |
|---|---|---|
| Pass + Move | 26 | Blue and Red, grown |
| Intangible | 29 | Green |
| Clamps / coverage | 9 | grown into a pillar |
| Variaball | 18 | Purple, one copy each |
| Whistle | 22 | Officials deck, striped |
| Varena | 29 | 5 |
| Special Move | 16 | dissolved into Move and Intangible; their shot identities become the triangle |

**Settled: Clamps are the fifth colour, and the Varenas are shelved.** Every match is played
on plain Cardwood. The descriptors are still in `CardLibrary.varenas` and still decodable by
id, so nothing about bringing them back is destructive.

**Built, at 299 cards:**

| | cards |
|---|---|
| Pass | 107 |
| Move | 70 |
| Clamp | 60 |
| Intangible | 29 |
| Variaball | 18 (one of each) |
| Special Move | 16 (one of each) |
| **Total** | **300** |

Injuries are parked with the Varenas.

### The spine's ratio

**The two swings are the same number, and the pass across is half of one.** Twenty-one,
twenty-one and ten — an odd swing has no exact half, and ten is the one that rounds down
and keeps the deck at three hundred. Hex Hex holds the same ratio between its Turn Asides and its Deflect Across, and
it is what keeps a four-handed table from playing as though the man opposite were as near
as the men beside you.

**Slots for new cards come out of the swings**, which is almost certainly how Smirk &
Dagger ended up with a number as odd as twenty-six — and every time the swings move, Skip
Pass follows them down to half. A test holds the ratio so it cannot drift.

The officials deck is 19 more, outside that count, as its own pile.

Special Moves were not dissolved into Move and Intangible — they became one-of each, which
takes them from a staple to a signature finish and is the same effect on the deck's shape.
The rewrite into other colours is still to do.

**Open:** how a Varena enters play, when they come back. A one-of in 300 arrives at a random
moment, and something that drastically changes how players interact landing mid-game is an
earthquake nobody planned for. Setting it at tip-off alongside the refs would make the whole
pre-game one unit — one arena and three officials, face-up before the jump — which is also
the version that works on a table.

---

## 7. Cloud or black bodies

Card bodies move to Cloud — or black, as a dark-theme option. Colour lives on the name badge
and the inner ring only.

- More room for printed text, which the denser cards need.
- No keyword-colour or font-colour consistency problems against a coloured body.
- It simplifies what-is-what: the body is neutral, the badge tells you the type.

**Built.** `CardFace.colour` and `CardFace.shade` are the type's pair, and every colour
table in `CardTextStyle` is built off them: cloud bodies throughout, the name badge in the
type's colour with its own shade as the drop, the inner ring in the type's colour, the text
overlay the same at 25%, and the wash over the words gone. **Moves are teal.** The outer
ring is the cloud body showing outside the inset stroke.

The officials deck has its own back — `RefereeCardBack`, the stripes off the face carried
down the length of the card with a gold whistle in the middle.

Black is the other option and it is one switch: `CardTextStyle.darkBodies` prints the whole
deck on black and flips the lettering to cloud. The badges and the rings are the type's
colour either way, so nothing else has to change.

---

## What the numbers say

200 Standard games, against the figures the rework was argued from:

| | before | after |
|---|---|---|
| longest run of boards with no basket | 16 | **10**, and only one run of 10+ in 200 games |
| hands as a possession opens | 2.4 | **2.77** |
| hands at one or none | 22% | **19%** |
| possessions where SHOT never moved | 48% | **39%** |
| shots made | 22–25% | **44%** |
| points a game | ~12.4 | **18.7** |
| bidding's share of card loss | 74% | 80% |

The one surviving brick run is a Foot Ball lock: the ball holds the Moves and Passes played
this possession, which can leave the shoot button as the only legal move at SHOT 0. That is
one card's problem rather than the system's.

Bidding's share of card loss went *up*, because everything else that took cards now takes
fewer. It is still the largest single drain in the game.

**And two numbers went the wrong way, which the rework does not fix:**

| | before | after |
|---|---|---|
| passes a possession | 0.24 | **0.23** |
| dead possessions (nobody played anything) | 29% | **37%** |

The ball still does not move. Nothing in the rework was aimed at that directly — the hand
limit, the Move draws and the officials all work on what a player *has* and what they may
do with it, not on where the ball goes. And dead possessions went up because a crew is
always out: ten calls a game is ten possessions where somebody's card was waved off.

Some of this is the opponent rather than the rules. `AIPolicy` has not been rewritten for
any of it — it does not chain Moves to run the draw engine, does not read a defender's
printed counter to decide whether to work on beating him, and picks a finish by a flat
preference rather than by what it is worth. Every number above is measured against an
opponent playing the old game with the new cards.

## Open questions, collected

1. Refs: whole crew replaced each round, or one swapped with the scorer choosing?
2. How does a Varena enter play, when the venue comes back — drawn, or set at tip-off with
   the refs?
3. Do the three finishes get their own make effects (layup draws, dunk discards, three
   destroys), or is the extra point enough?
4. Do Injuries and Game Breaks survive the consolidation, and where?
5. Does the app need a browsable discard pile? The information game around bidding only exists
   if the pile can be read, which is free on a table and is not currently built.
6. Do the Special Moves get rewritten into Move and Intangible, or stay as one-of finishes?
7. Whistles blow ten times a game now that a crew is always out. Technical Foul alone is one
   a game, and it cancels the first non-Whistle anybody plays.
