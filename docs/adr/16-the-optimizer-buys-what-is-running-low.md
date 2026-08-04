# ADR: The optimizer buys what is running low

**Status:** Accepted

## Context

FR-DIS-6 asked the optimizer to evaluate *out-of-stock* combinations and report the recipes
becoming can-make; FR-DIS-7 asked, separately, for the running-low bottles to be listed as restock
reminders. M21 implemented exactly that, and pinned it: a low bottle counts as on hand and is never
bought.

That splits one shopping trip into two answers. The bottles you are out of and the bottles you are
nearly out of are bought on the same visit, out of the same budget, and only one of the two lists
was ranked by anything.

Widening the pool alone does not fix it. `canMake` counts low as makeable (FR-DIS-1, FR-DIS-5), so
a recipe standing at Low is *already* can-make and a low bottle unlocks nothing. Any basket holding
one would score no better than the same basket without it, and ADR 15's rule — a basket must beat
each of its own smaller selves — would drop it as a passenger. To make a low bottle worth buying,
what a basket is *scored on* has to move.

## Decision

**`purchasesWithin` takes `restocking`, and the screen carries it as a switch.**

- **Off (the default)** — a required line is short when it stands at `out`. Exactly M21's answer,
  whose tests stand unchanged as this case.
- **On** — a required line is short when it does not stand at `in_`. The goal becomes *fully
  stocked* rather than merely makeable, so low bottles join the pool of what is worth weighing and
  the baskets that spend the budget on them.

One flag, one place: the test in `_gapsOf` that decides whether a line is short. Everything
downstream — the cross product over a recipe's gaps, the pool, the search, the per-size shelves,
the ranking — is untouched, because all of it already reads "short" rather than "out".

**FR-DIS-7 is answered by that switch, not by a list of its own.** A bottle running low is reminded
of by appearing in what to buy, ranked among everything else the budget could go on. The
requirement is rewritten to say so.

## Alternatives considered

- **Two counts per basket** — recipes going Missing → makeable and recipes going Low → Ready,
  reported separately and ranked new-drinks-first. Truer to vision.md's "which 2–3 bottles unlock
  the most new drinks", and it needs no control at all. Rejected: every row then carries two numbers
  and a compound ranking to answer a question the reader can ask directly by flipping one switch,
  and the two shopping moods — broaden the bar, restock the bar — each deserve a clean list rather
  than a blended one.
- **Low always counts as short, no switch.** The smallest change. Rejected because it costs the
  answer to "what would broaden what I can make": a bar with many low bottles gets a list dominated
  by top-ups, and there is no way back to the other reading.
- **Keep the split** — the out-of-stock search plus a standalone restock list. What the requirements
  said, and what M21 built. Rejected as above: two lists for one trip, and the restock half answers
  no ranked question.

## Consequences

- FR-DIS-6 gains the switch; FR-DIS-7 stops asking for a separate list.
- M21's optimizer tests stand as the flag-off case, the low-bottle one included — its subject
  changes from "never bought" to "not bought unless restocking".
- ADR 15's cost is cubic in the pool of bottles worth weighing, and the switch grows that pool: a
  bar with many low bottles pays for it. Measured over one collection of 400 recipes and 120
  bottles at N=3, two fifths of them out and a fifth low: **58 ms plain, 100 ms restocking**. The
  growth is real but far short of cubic, the pool being bounded by the gaps' own bottles rather
  than by the shelf. The performance test therefore times both readings over the one collection,
  so the print says what the switch costs.
- `canMake` does not move. The traffic light behind FR-DIS-1, the random pick behind FR-DIS-5 and
  the recipe list's order all go on reading low as makeable — it is the optimizer's own goal that
  shifts, and only while the switch is on.
- A recipe already Ready is never bought for under either reading, so the switch can only ever
  lengthen the list of baskets, never reorder the answers it already gave.
