# ADR: The optimizer buys what is running low

**Status:** Accepted

## Context

FR-DIS-6: optimizer evaluates out-of-stock combinations. FR-DIS-7: restock reminders. Search pinned low ingredients on hand, never bought: one shopping trip split into two answers (one budget, one ranked). Widening the pool does not fix it: `canMake` counts low as makeable (FR-DIS-1, 5), so a low recipe is *already* can-make and a low ingredient unlocks nothing. A basket with low scores no better (ADR 15 drops it). Making low ingredients worth buying means moving basket scoring.

## Decision

**`purchasesWithin` takes `restocking` switch; FR-DIS-7 answered by switch, not separate list.**

- **Off (default)**: required line short when `out`.
- **On**: required line short when not `in_`; goal *fully stocked*; low ingredients join pool.
- One flag, one place in `_gapsOf`. Downstream (cross product, pool, search, shelves, rank) untouched; already reads "short".
- A low ingredient is reminded by appearing in what to buy, ranked with all budget options.

## Alternatives considered

- **Two counts per basket**: Missing→makeable and Low→Ready, reported separately, ranked new-drinks-first. Truer to vision; needs no control. Rejected: two numbers per row, compound ranking; shopping moods deserve clean lists, not blends.
- **Low always short, no switch**: smallest change. Rejected: loses the "broaden what I can make" answer; a bar with many lows is dominated by top-ups, with no way back.
- **Keep split**: out-of-stock search + standalone restock. Rejected: two lists one trip; restock answers no ranked question.

## Consequences

- FR-DIS-6 gains the switch; FR-DIS-7 stops asking for a separate list.
- Existing optimizer tests stand as the flag-off case, the low-ingredient one included; its subject changes from "never bought" to "not bought unless restocking".
- ADR 15's cost is cubic in the pool of ingredients worth weighing, and the switch grows that pool, so a bar with many lows pays. Measured over one collection of 400 recipes and 120 ingredients at N=3, two fifths out and a fifth low: **58 ms plain, 100 ms restocking**. Growth is real but far short of cubic, since the pool is bounded by the gaps' own ingredients, not the shelf. The performance test times both readings over that one collection, so the print shows the switch's cost.
- `canMake` does not move: the traffic light (FR-DIS-1), the random pick (FR-DIS-5) and the recipe list's order still read low as makeable. Only the optimizer's goal shifts, and only while the switch is on.
- A recipe already Ready is never bought under either reading, so the switch only lengthens the list of baskets, never reorders answers given.
