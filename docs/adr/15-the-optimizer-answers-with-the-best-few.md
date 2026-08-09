# ADR: The optimizer answers with the best few

**Status:** Accepted

## Context

FR-DIS-6 asks for the purchases of at most N bottles that turn the most missing recipes makeable,
ranked by how many. It does not say how many such purchases to report, and the obvious reading —
all of them — turned out to be the expensive one.

Measured on a generated collection of 400 recipes over 120 ingredients at N=3, roughly the shape
NFR-2 names:

| | |
|---|---|
| Distinct recipe gaps | 389 |
| Bottles worth weighing | 72 |
| Baskets searched | 62,268 |
| Baskets that unlock something | ~35,000 |
| **Searching them all** | **43 ms** |
| **Dressing them all as answers** | **~320 ms** |

The search is cheap. Naming 35,000 baskets — sorting each one's recipes A→Z, then ranking the lot
— is seven times the cost of finding them, and it grows with the cube of the ingredient pool while
the useful part of the answer stays about twenty rows long. A first cut that built every basket
before ranking took 6.8 s.

## Decision

**`purchasesWithin` returns the best `most` baskets of each size, `most` defaulting to 25.**

- A basket is weighed by its recipe *count* during the search and only named — bottles and recipes
  spelled out, A→Z — if it survives into what is returned. At N=3 that is 75 objects built instead
  of 35,000, and the phone never holds a list it cannot show.
- **Per size, not overall.** A three-bottle basket almost always unlocks more than any one-bottle
  basket, so a single global cut would fill with three-bottle answers and bury the cheap wins. A cap
  per size keeps the best of each, which is what leaves the screen free to read them as one ranked
  list *or* as a section per size without the domain changing.
- **A basket must beat each of its own smaller selves.** Otherwise it is one of them carrying a
  passenger — `gin` unlocking five and `gin + campari` unlocking the same five are one answer and
  one impostor. A sub-basket's recipes are always a subset of its parent's, so equal counts mean
  equal answers and the count settles it without comparing the sets. This subsumes the weaker rule
  it replaced (drop a bottle that closes nothing at all) and is why zero-yield baskets need no rule
  of their own: a basket unlocking nothing cannot beat its parts.

## Alternatives considered

- **Return every basket.** The honest reading of the requirement, and it is what the first
  implementation did. Rejected on the numbers above: 320 ms of the 364 ms was spent building answers
  no screen would ever show, and it is the term that grows cubically.
- **A single global cap.** Cheaper still and simpler to explain, but it forecloses the section-per-
  size presentation, which was left open deliberately when the ranking was chosen.
- **Rank by recipes per bottle.** Would surface cheap wins in one flat list without a per-size cap.
  Rejected when the ranking was settled: it stops the top line answering the question the budget
  selector asks — *I am buying three bottles, which three?*
- **Search only the gaps' unions rather than every basket.** The candidate space is genuinely
  smaller, but only by half here (35,196 of 62,268 subsets of the pool are unions of gaps), and it
  costs far more per candidate — measured at 1.4 s against 43 ms for the plain scan.

## Consequences

- 400 recipes at N=3 answers in **~140 ms**, from 6.8 s. The performance test pins a regression
  guard rather than a stopwatch, since CI machines vary.
- `most` is a parameter, so a screen wanting a longer list asks for one. The default is the domain's
  guess at what a phone can show, not a limit on what the search can find.
- The optimizer no longer promises *every* purchase worth making, only the best few of each size.
  Anything that needs the whole space — a "surprise me" over purchases, say — must raise `most`
  and pay for it.
- The best few are all a screen can narrow. The shopping tag filter (FR-DIS-10) sifts this list rather
  than the search behind it, so a basket cut here for ranking poorly overall is offered under no tag it
  would have led — a niche category can read empty while a good basket for it exists. `most` is the
  relief, and re-running the search over the tagged recipes alone is the answer if it ever is not.
- Cost still grows with the cube of the pool of out-of-stock bottles, not with the recipe count. A
  collection short of far more bottles than this one will cost more, and the budget selector is the
  relief: N=1 is linear and N=2 quadratic.
