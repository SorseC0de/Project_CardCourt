# What makes it fun

Research, September 2026, against a game that had just been measured. Everything here is
either a number off `./Tools/sim` or a sourced position from somebody who designs or plays
card games for a living. Where the two disagree, the number wins.

**The measuring tools all live in `Tools/`** and re-run in about a minute each:
`--discards` (where cards go), `--bricks` (scoreless stretches), `--shots` (attempts by
what they were worth), `--tempo` (swings, battles, dead air), `--variety` (how much of the
deck a player meets), `--density` (how much each card does).

---

## What the game actually is right now

| | |
|---|---|
| The ball moves | **0.24 times a possession** — it dies on the holder **57%** of the time |
| Possessions where nobody plays anything | **29%** |
| Rounds holding a back-and-forth of three or more swings | **6%** |
| Reaching into somebody else's turn | **1.25 a round**, almost all of it Clamps |
| Whistles firing | **0.16 a round** — one every six rounds |
| Attempts taken at 0% | **24%** of all shots |
| Cards leaving hands | **0.92 a possession**, of which **74% is rebound bidding** |
| Hand as a possession opens | **mean 2.4** · empty 7% · one-or-none 22% |
| Different cards a player meets in a whole game | **16 of 158** |
| Cards needed to cover 80% of all plays | **70** |
| Things the average card does | **2.41** — but the spine does **1** |
| Scoring | **6.2 makes a game at 2.08 points each**, capped by rounds ending on a basket |

Hex Hex XL, measured the same way for comparison: the chain travels **2.45 hops** and dies
on the first player **2.3%** of the time, off a deck where **46%** of cards can answer —
and, crucially, **every hand is discarded and redealt to 5 at the end of each round**, so
that density never decays. Variaball's hands erode to 2.4 and stay there.

---

## The one test players apply

Across every forum, every game, every argument: **did I have an input, and did it matter?**

- A long turn is fine *if you can react during it*.
- Randomness is fine *if a decision is attached to it*.
- Catch-up is fine *when it is an option the player behind spends*, not a tax the leader absorbs.
- Interaction reads as fair when it is **visible, costly and dodgeable**, and unfair when the
  answer is broader or cheaper than the thing it answers.

What players complain about is not turn count or minutes. It is **the gap between when the
game is decided and when it ends**, and **how long the non-active player sits idle**.

---

## 1. The ball is already the right mechanic. It just doesn't move.

The games that produce stories make the threat **an object with a current holder** — Hex
Hex's hex, Exploding Kittens' Attack, Cockroach Poker's card, Uno's stacked draw. Chains
stay alive when the response is cheap, several players could answer, each link carries a
**target choice**, and the payload **escalates as it travels**.

Variaball already has all four in concept: the ball has a holder, SHOT grows as it moves,
and passes name a receiver. The problem is purely density — 21% of the deck can move it,
against Hex Hex's 46%, and hands sit at 2.4 rather than 5.

**Five things Hex Hex does that Variaball does not**, all of them small:

1. **The hand resets every round.** Whole hand discarded, five dealt. Nobody ever plays a
   round crippled, so the response density is the same on round eight as on round one.
2. **The loser gets one last window** — some cards are playable *only while hexed*. The
   "you're hit — unless" beat is the emotional centre of the chain.
3. **The payload escalates**: boost and split cards make a long chain worth more, so the
   table wants it to continue while nobody wants to be holding it.
4. **The chain costs a point, not a position.** One Voice, no elimination, and the game is a
   fixed length — two rounds per player as first caster — so performance never changes how
   long you sit there.
5. **Rot punishes everyone who touched it**, not just the last link — a lever for when
   chains run too long.

**Exploding Kittens' design history is the sharpest lesson here.** The prototype had players
draw and die, and it was flat. Defuse made the game: it doesn't remove the threat, it lets
you *choose where to put it back*. The catch was never the point; placing it was.

## 2. Out-of-turn cards are the fix for dead air, and yours are switched off

The single most reliable downtime fix in the literature is **cards playable on other
people's turns** — Nope, Coup's challenge/block, Hex Hex's responses, Munchkin's combat
interference. Rosewater states it flatly: instants "allow you to act during a time that
normally is focused on your opponent," and calls creatures and instants Magic's two tools
for interactivity.

Variaball has this layer built — Whistles — and it fires **0.16 times a round**. That is a
rumour, not a threat. 29% of possessions are dead air on the holder's side while the other
three players have nothing to do with their hands either.

**Hearthstone built this and then removed it.** Early builds had "Combat Tricks" — cards
playable on the opponent's turn. Cutting them "made the game more fun, as well as further
improving its speed." Secrets are what survived: reactive, but pre-committed, pre-paid and
hidden, so the decision happens on your own turn and nobody waits on a response window.

**Legends of Runeterra spent the budget more precisely.** Riot's rule: response windows are
a cost, so spend them only where the swing is big. Removal and multi-unit plays are Slow or
Fast (interruptible); card draw and healing resolve at Burst speed because "incremental
stuff... was cumbersome when they involved full reaction windows." They also bank *spell
mana* specifically so players "constantly have opportunities to interact" — counterplay as a
default state rather than a lucky one.

**The caveat that matters for a tabletop game:** Hearthstone's community voted 79.4%
*against* adding instants, because priority windows mean constant attention and stalling.
The pattern that survived is the **pre-committed face-down response** — Secrets, paid for in
advance, played around rather than reacted to. That enacts physically at a table. Priority
windows do not.

## 3. Hand economy: two knobs, and they are coupled

The transferable rule is Yu-Gi-Oh's: aim for a **75%+ chance of opening your core enabler**,
counted as 9–12 accessible copies in 40. Hypergeometric, `P = 1 − C(N−K, n) / C(N, n)`.

At Variaball's 498 cards, to hold a Pass 75% of the time:

| hand | Passes needed | share of deck |
|---|---|---|
| 7 | 89 | 18% |
| 5 | 121 | 24% |
| 3 | 184 | 37% |
| 2 | 249 | 50% |

Today: 105 Passes (21%) at a hand of 2.4 → **43%**, which is exactly what the simulation
measured. The maths and the sim agree, so this table can be designed against directly.

**Zero-hand states are a known trap.** Magic's Hellbent paid you for an empty hand and was
judged "too hard to execute on"; the team's own prototype fix was *one or fewer*. Variaball
sits at 7% empty and 22% one-or-none — the workable target is the one-or-fewer band.

## 3b. Deck size is the density lever, and 300 does the job by itself

Yu-Gi-Oh players optimise toward the *smallest legal deck* for one reason: to see the core
cards more often. The same arithmetic runs the other way for a designer — you set the deck
size, so you set how often the spine shows up.

Holding the pass suite at 105 cards and changing only the deck size:

| deck | pass density | holds one at hand 2.4 | at hand 5 |
|---|---|---|---|
| 550 | 19% | 35% | 65% |
| 498 (today) | 21% | 38% | 70% |
| 400 | 26% | 46% | 78% |
| **300** | **35%** | **58%** | **89%** |
| 250 | 42% | 66% | 94% |

**Cutting to 300 lands on Hex Hex's density without touching a single Pass card.** The cuts
have to come from the tail — the 88 cards below the 80%-of-plays line — not from the spine.

The structural shape that follows is the one Yu-Gi-Oh decks converge on and Hex Hex ships
by default: **a small, dense engine plus a large interaction suite**. In a constructed TCG
the player curates that ratio; in a shared-deck multiplayer game the designer does, because
nobody gets to deckbuild. The deck list *is* the decklist.

## 4. Card advantage means something different when cards are dense

Yu-Gi-Oh's economy language (+1 / 0 / −1 on every play) works because each card is two to
four effects: seeing more cards is seeing more **options**. Variaball averages 2.41 things
per card — but the distribution is backwards. The cards with the most copies do the least:

- Swing Left ×20 — **1 thing**. Swing Right ×20 — **1 thing**. Skip Pass ×10 — **1 thing**.
- Hand-Off, Kick-Out, 2-Hand Jam, Tomahawk — **6 things**, at 5–10 copies.

Two coherent models exist. **Hex Hex**: thin cards, many copies, and the chain carries the
fun. **Yu-Gi-Oh**: thick cards, few copies, and the draw carries it. Variaball's spine is
thin *and* sparse while its interesting cards are thick *and* rare — neither model.

## 5. The bidding problem has a name and a literature

In multiplayer, a 1-for-1 answer costs the answerer a card and benefits everyone who paid
nothing, so the rational play is to let somebody else answer. Rebound bidding is exactly
this: **74% of every card that leaves a hand**, 1.5 cards a board, paid by whoever cares
most, with the board going to one of them.

Documented mitigations, none clean:

1. **Lean in** — make bash-the-leader the engine (Cosmic Encounter).
2. **Make yourself expensive, not invisible** — attack taxes redirect aggression rather than
   preventing it, because attackers pick the cheapest target.
3. **Pay the interactor** — deals, votes, bribes: convert a card cost into a table cost.
4. **Make catch-up systemic** so no individual spends cards enforcing it.
5. **Reduce interaction** — kills the problem and the drama together.

Watch for the two known failure modes: the endless bash loop, and the non-participant
winning because the contenders exhausted each other.

## 6. Take-that is forgiven when the damage is collectively authored

Hex Hex spreads blame through the redirect chain — you launch it, the table aims it.
Munchkin's level-9 pile-on is one player choosing one victim, and it is the single
most-criticised thing in the category.

Variaball's split: **Clamps are 0.75 of the 1.25 interactions a round and they are aimed at
one victim** — the grudge shape. Bidding is impersonal and everyone participates. The
literature's line is between **game-state-driven targeting** (fine, even healthy) and
**relationship-driven targeting** (what actually breaks tables).

Always give the target a mitigation, a counter, or a reason it was predictable.

## 6b. Cool cards versus accessible cards is a false choice

The research answer is that these are different budgets and only one of them is scarce.

- **Comprehension complexity** — understanding what a card does — is the expensive kind, and
  it is paid by every new player on every card they meet.
- **Board complexity** — tracking how things interact once they're out — is the modern
  failure mode: "an interconnected web that prevents the average player from being able to
  track what's happening."
- **Strategic complexity** — knowing how best to use it — is nearly free, because beginners
  are blind to it. "If you can keep your card low in comprehension and board complexity, you
  can sneak in quite a bit of strategic complexity."

Brode states the same thing as a ratio: "cards with the highest ratio of depth to complexity
are the best designs," and depth can live in **combinations** rather than on the card face —
one short line that plays deep because of what it meets.

So the resolution is structural, not per-card: **put the accessibility in the spine's
density and the coolness in the tail's rarity.** A new player meets Swing constantly, learns
the game in one hand, and treats the 1-of Variaballs as events. That is exactly Hex Hex's
shape — 52 Turn Aside and a tail of singletons — and exactly the shape the Yu-Gi-Oh decks
converge on from the other direction.

## 7. Learnability is a copy-count problem, not a rules problem

A player meets **16 of 158 cards** in a game. **70 cards** are needed to cover 80% of plays.
Eleven cards never appeared in 200 games. Nothing repeats often enough to become a pattern,
so every hand is a first sighting.

Hex Hex's shape is the counterexample: 52 Turn Aside in 150 means you learn the core card in
one hand and everything else decorates a pattern you already have.

Rosewater's tools for this are worth stealing wholesale:
- **Lenticular design** — simple to the beginner, deep to the expert. Keep comprehension and
  board complexity low; hide the depth in strategy.
- **The complexity budget is a spendable resource**, and the modern failure mode is not card
  text but **tracking the web of interactions between permanents**.
- **Put the fun where winning is** — players optimise for winning, so any mechanic that taxes
  the fun behaviour kills the fun behaviour.

## 8. Scoring is capped by the round structure, not by SHOT

A made basket ends the round, and there are 8 rounds. Makes a game is therefore pinned near
6.2 whatever else improves — every lever measured so far moved *quality* (make rate 26% →
31%, boards 4,389 → 2,937) and left the score untouched.

Points a game has exactly three inputs: **rounds**, **points per make** (2.08 — threes are
almost never happening), and **free throws** (negligible). That is why the old 20% SHOT bump
was the only thing that ever seemed to work, and why the three-shot-type idea (layup / three
/ dunk) is the more honest version of it: it raises points per make instead of inflating
SHOT.

On endings, the strongest consensus found anywhere in the research: **end it when it's
decided**. Anticlimax — a finish nobody caused — is rated worse than losing.

---

## 9. Miscellaneous findings worth keeping

- **Konami's stated restriction trigger** is not power: it is "preventing Decks from being
  too difficult to counter, and ensuring the game's tactical element is not compromised by
  overly short and/or one-sided Duels."
- **Slay the Spire:** "Going infinite is the number one thing we try to make really rare. It
  makes the actual playing of the game trivial." A loop doesn't beat the game, it deletes it.
- **Marvel Snap:** "It's not about the number of decisions per game; it's the density of
  decisions and how fun they are to make." Also Brode's line on spectacle cards — "If the
  best part of the game is Galactus, then it's not the best part of the game."
- **Characteristics of Games** on both ends of the game: players must believe they can still
  win at the end, *and* feel their early actions mattered. Rubber-banding too hard breaks
  the second half of that sentence.
- **Coup's structure** is worth stealing for whistles: every action is interruptible by the
  whole table, and a block is itself a claim that can be challenged — so the chain is made
  of counters, not of one answer.
- **Blizzard nerfs for frustration independent of power**, and their lever is time: Mind
  Control cost more so the victim got more turns with the minion first. The feel-bad is the
  theft landing before the card ever paid off.
- **Divisive cards are allowed to exist if they are weak.** Ayala: unfun-but-thrilling cards
  are fine "as long as they aren't too powerful," because power sets how often you meet them.

## 10. The scoring system is a steering wheel

Knizia: "I want the scoring system to be elaborate enough so that I CANNOT keep track, but
simple enough so that I have a feeling of where I stand." And the design claim underneath
it: "Scoring systems guide the way we play, therefore they fundamentally influence the game
play and our choices. A good scoring system promotes those activities we would naturally
take in the role we are playing."

That is the sharpest available test for Variaball, because the role is *a basketball
player*. The activities a player would naturally take are passing, moving the ball, working
a look, and shooting when it's there. Right now the scoring promotes exactly one of those:
shooting, because SHOT is the only number, a board carries it over, and a hand with no Pass
can only shoot or stall. **48% of possessions end with SHOT never having moved.**

Also worth holding onto, from the same interview: "the market is flooded with complex games
— and complexity is not a measure for game quality or joy."

## 11. Every card should have a place

Slay the Spire's balance goal, verbatim off the GDC slide: "Every card should have a place!
(also avoid anything too warping)." Both ends kill the choice — a card that is never the
right pick is a non-decision, and a card strong enough to warp the game collapses everything
around it.

Variaball has **11 cards that never appeared in 200 games**, and Buzzer Beater at 8 plays.
Those are non-decisions occupying slots and rules space.

From the same talk, and worth taking personally given how much of this document is numbers:
**"Data is evidence, but not a conclusion."**

## 12. Inspire interaction, don't dictate it

Eric Lang: "the best designs don't dictate interaction, they inspire it," and on card design
specifically — "I do my best to design card abilities with a firm logical framework, but
open-ended enough where I as designer cannot possibly see all ends. If I can be surprised by
player discoveries in the game, then I believe I have succeeded."

He also draws the line on variance in one sentence: luck is good while it "forces variance
and adaptability without (usually) simply smashing anyone out of contention." Perturbing
plans is agency; removing a player's ability to compete is not.

The Variaball read: the combo system is the open-ended half (cards meeting cards), and it is
almost entirely undiscovered — combos land rarely enough that the COMBO button is mostly
decoration. That is the part of the game most likely to produce a player surprising
themselves, and it is currently the quietest.

## What is not settled

- **"Input randomness good, output randomness bad" is not safe.** A 2021 study found pure
  input randomness *hurt* satisfaction. What players want is a **decision attached to the
  roll**, whichever end it enters.
- **No published numbers exist for turn or round length.** Every source refuses to name one
  and says playtest it. If a target is wanted, it has to come from your own table.
- **Hand-size floors have no literature**, only Hellbent's failure and the one-or-fewer fix.
- **Kingmaking is genuinely contested** — Cole Wehrle's GDC talk defends it as a design goal
  rather than a flaw, resolved by social consent up front rather than by mechanics.

## Gaps in this research

Konami has published almost nothing on *why* hand traps exist; the Master Duel banlist notice
is the only stated rationale found. Kevin Tewart's design writing lives on forums that block
automated fetching. Garfield's own writing beyond Magic (the 2006 randomness essay, the ITU
"Luck in Games" talk) is not available as text. Turn-length targets are undocumented
everywhere — every source says playtest it. Reddit and BoardGameGeek both block automated fetching, so player-side
material came via forums that don't (MTG Salvation, HearthPwn, Blizzard, Steam, PokéBeach).

## Sources worth reading directly

- Rosewater, *Ten Things Every Game Needs* — https://magic.wizards.com/en/news/making-magic/ten-things-every-game-needs-part-1-2011-10-24
- Rosewater, *Lenticular Design* — https://magic.wizards.com/en/news/making-magic/lenticular-design-2014-03-31
- Rosewater, *New World Order* — https://magic.wizards.com/en/news/making-magic/new-world-order-2011-12-05
- Rosewater, *Twenty Years, Twenty Lessons* — https://magic.wizards.com/en/news/making-magic/twenty-years-twenty-lessons-part-1-2016-05-30
- Reid Duke, *Tempo and Card Advantage* — https://magic.wizards.com/en/news/feature/tempo-card-advantage-delicate-balance-2014-11-17
- Elan Lee on Exploding Kittens' Defuse breakthrough — https://tim.blog/2023/02/04/elan-lee-transcript/
- Andrew Looney, *Game Design Principles* — https://www.wunderland.com/WTS/Andy/Games/DesignPrinciples.html
- *7 Ways to Reduce Downtime* — https://entrogames.substack.com/p/7-ways-to-reduce-downtime-in-your
- *Catch-Up Mechanisms* taxonomy — https://thethoughtfulgamer.com/2017/03/28/catch-up-mechanisms/
- Wehrle, *"King Me": A Defense of King-Making* — https://www.gdcvault.com/play/1025683/Board-Game-Design-Day-King
- Hearthstone community on instants (79.4% against) — https://www.hearthpwn.com/forums/hearthstone-general/general-discussion/205903-instants-in-hearthstone
- CCG randomness study — https://arxiv.org/abs/2107.08437
- Riot on spell mana and response windows — https://outof.games/news/405-legends-of-runeterra-reddit-developer-ama-recap/
- Brode on decision density (Marvel Snap) — https://justingarydesign.substack.com/p/think-like-a-game-designer-42-ben-e6a
- Brode on complexity versus depth — https://www.hearthpwn.com/news/2195-ben-brode-on-defining-complexity-depth-and-design
- Blizzard's balance philosophy — https://hearthstone.blizzard.com/en-us/news/12383909
- Hearthstone's cut "Combat Tricks" — https://hearthstone.wiki.gg/wiki/Design_and_development_of_Hearthstone
- Slay the Spire on going infinite — https://www.gamedeveloper.com/design/how-i-slay-the-spire-i-s-devs-use-data-to-balance-their-roguelike-deck-builder
- Curt Covert on take-that and the table's social contract — https://omada.play.nobleknight.com/publisher-spotlight-smirk-dagger/
- Hex Hex rules detail (hand reset, Voice, fixed length) — https://geekdad.com/2011/05/game-review-hex-hex-xl/
- Knizia on scoring systems — https://web.archive.org/web/20101205153514/http://jesweb.net/old/coin/knizia/knizia-en.html
- Eric Lang on inspiring interaction — https://opinionatedgamers.com/2012/08/13/the-art-of-design-interviews-to-game-designers-21-eric-m-lang/
- Slay the Spire, GDC 2019 slides — https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf
