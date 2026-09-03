# Opponents

## The names *are* the archetypes

Not a name pool laid over a set of behaviours — one and the same thing. Rolling a match
against Stepand is rolling that archetype, and after a few games you know what you are
getting before the tip. A name that is only a label has to be learned twice; a name that is
the character is learned once.

So each name below is a player, and each player is a way of playing.

- Alvin Sniperson
- Stepand Carry
- Lebronze Gaines
- Yeaimissed Anditooktwomo
- Himmy Buster
- Ball Scourge
- Stae Skilledandalwaysanswer

## The archetypes

Shuffled and dealt to the opponents at the start of a game, so the same three seats are
never the same three players twice. Around seven eventually; six described so far.

| Archetype | Plays like |
| --- | --- |
| **Trigger-happy** | Shoots more often, and at lower percentages. |
| **Hater** | Sabotages whoever leads on points or hand size, through forced turnovers. |
| **Street Hooper** | Prefers Move cards. |
| **Team Player** | Prefers passing to shooting, even at a high SHOT. |
| **Whistleblower** | Prefers Whistles over every other type. |
| **AllStar** | The rare one. Plays as well as it can — strings combos, sizes bids, and knows when to pass instead of shoot. |

Pairing is still open, though three of the names arrive already knowing who they are:
*Yeaimissed Anditooktwomo* is Trigger-happy written out longhand, *Ball Scourge* is the
Hater, and *Lebronze Gaines* is an AllStar who would rather you did not look too closely at
the medal.

Seven names and six archetypes, so either one archetype is still unwritten or one name is
waiting for it.

## What has to happen first

`AIPolicy` is now a per-seat struct carrying its own RNG and its own `AITuning`, which is
the hook an archetype plugs into: an archetype is a tuning preset plus, where it needs one,
an override on a choice. That restructure is done, so a second policy no longer requires
one.

**Every hard cap has to become a likelihood**, tuned per archetype rather than globally.
The deterministic points today:

- `shootThreshold` — fires the instant SHOT crosses it. Wants a probability curve that
  rises with SHOT instead.
- `reboundBidCap` / `reboundReserve` — always bids exactly the cap, which makes a hidden
  auction solvable by bidding one more.
- `maxMovesPerPossession` — an AI stop, not a rule. Whatever replaces it still has to
  guarantee a Dribble loop terminates.
- `clockReserve` — a flat refusal to spend clock on Rhythm Dribble.
- `bestPass` and the inbound choice — pure argmax on lowest score, so every opponent feeds
  the same player every time.

`Tools/sim --sweep` prints the shoot-threshold curve — PTS/AST/REB/TOV, shots, make%, and
the share of rounds dying on the clock. Use it to place each archetype's threshold. Rounds
dying at a high threshold are expected; the spread across four seats is what settles it.
