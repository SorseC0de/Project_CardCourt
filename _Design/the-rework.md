# The Rework

The redesign the game is being rebuilt around. Everything here was decided in conversation;
where a thing is still open it says so rather than guessing. Nothing in here is built yet.

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

**Open:** when a card sets a different limit — Tri-Hard Tiling's `handLimit: 3` is the
existing precedent — does the conversion key off the match's five, or off whatever limit is
in force? The second makes Tri-Hard Tiling a SHOT engine rather than a drought.

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

Each round the three current refs are discarded and three new ones dealt.

**Being experimented with instead:** swap one per round, with the scorer choosing which to
bench — picking based on what makes it easier for them to score next round given the hand
they are holding. Closer to Pokémon's prize cards.

**Tabletop:** the three players who are not inbounding are the ones who shuffle the officials
deck and pluck the new ref, for the extra interaction.

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

Unsettled on purpose. What is settled is that shot selection has to be a read rather than a
default — without the refs it is flavour, and without the triangle the refs have nothing to
punish. They are one mechanic.

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

**Open:** which is the fifth colour in the main deck. Varenas can live on as it, or Clamps
can. Clamps are the larger pillar as written above; Varenas as five unique one-ofs read more
like field spells or stadium cards. Both were on the table and neither was closed.

**Open:** how a Varena enters play. A one-of in 300 arrives at a random moment, and something
that drastically changes how players interact landing mid-game is an earthquake nobody
planned for. Setting it at tip-off alongside the refs would make the whole pre-game one unit —
one arena and three officials, face-up before the jump — which is also the version that works
on a table.

**Open:** the 24 displaced Varenas. Most are good and would survive as ref conditions or
Intangibles rather than being cut. The rehoming rule wants deciding before picking which five
survive as arenas.

---

## 7. Cloud or black bodies

Card bodies move to Cloud — or black, as a dark-theme option. Colour lives on the name badge
and the inner ring only.

- More room for printed text, which the denser cards need.
- No keyword-colour or font-colour consistency problems against a coloured body.
- It simplifies what-is-what: the body is neutral, the badge tells you the type.

---

## Open questions, collected

1. Does the overflow conversion key off the match's limit of five, or off whatever limit is
   currently in force?
2. Refs: whole crew replaced each round, or one swapped with the scorer choosing?
3. Fifth colour: Varenas or Clamps?
4. How does a Varena enter play — drawn, or set at tip-off with the refs?
5. Where do the 24 displaced Varenas go?
6. What are the three shot types' actual conditions and trade-offs?
7. Do Injuries and Game Breaks survive the consolidation, and where?
8. Does the app need a browsable discard pile? The information game around bidding only exists
   if the pile can be read, which is free on a table and is not currently built.
