# ADR: The optimizer buys what is running low

**Status:** Accepted

## Context

FR-DIS-6: optimizer evaluates out-of-stock combinations. FR-DIS-7: restock reminders. The search as first built pinned: low bottle counts on-hand, never bought. One shopping trip split into two answers, one budget, one ranked. Widening pool does not fix it: `canMake` counts low as makeable (FR-DIS-1, 5), so low recipe is *already* can-make; low bottle unlocks nothing. Basket with low scores no better; ADR 15 drops it. To make low bottle worth buying, basket scoring must move.

## Decision

**`purchasesWithin` takes `restocking` switch; FR-DIS-7 answered by switch, not separate list.**

- **Off (default)**: required line short when `out`. The answer as first built, tests unchanged.
- **On**: required line short when not `in_`. Goal *fully stocked*, low bottles join pool.
- One flag, one place in `_gapsOf`. Downstream (cross product, pool, search, shelves, rank) untouched; already reads "short".
- Low bottle reminded by appearing in what to buy, ranked with all budget options.

## Alternatives considered

- **Two counts per basket**: Missing→makeable and Low→Ready, reported separately, ranked new-drinks-first. Truer to vision; needs no control. Rejected: two numbers per row, compound ranking, two shopping moods deserve clean lists not blended.
- **Low always short, no switch**: smallest change. Rejected: costs "broaden what I can make" answer; bar with many low gets dominated by top-ups, no way back.
- **Keep split**: out-of-stock search + standalone restock. What the domain was first built as. Rejected: two lists one trip, restock answers no ranked question.

## Consequences

- FR-DIS-6 gains the switch; FR-DIS-7 stops asking for a separate list.
- The optimizer's existing tests stand as the flag-off case, the low-bottle one included — its
  subject changes from "never bought" to "not bought unless restocking".
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
