# ADR: Base spirit narrows the list, it does not group it

**Status:** Accepted

## Context

FR-DIS-4 asked grouped browsing under base spirits (ADR 06). ADR 11's substitutions left unanswered: where does `1 part gin / vodka (base)` file? Search covers gin rinse and float alike; *base* distinguishes "built on it".

## Decision

**Base spirit filters the recipe list, not layouts it. Recipe matches when any base line alternative names the picked spirit.**

- Chip in filter row: **Any base**, **No base**, all base spirits A→Z. Narrows with search, tags, order.
- **No base** is a choice (recipes marking no base); otherwise unreachable by scrolling.
- Group marked `(base)` matches **every** alternative: predicate with no single file location.
- Spirits from recipes, never a separate vocabulary. Ingredient is base while marked; names use fold (ADR 08).
- Stale pick (renamed, deleted, or mark cleared): stop narrowing not emptying list (like tags).
- Screen state only: nothing reaches file.

## Alternatives considered

- **Grouped layout**: second list on search/tag/six-order screen; demotes availability to within section; breaks name-keyed `_place`/`ValueKey(name)` or picks arbitrary alternative.
- **Base sort with headers**: one layout, but collides with FR-DIS-8 (order is availability); recipe with two bases has no rank.
- **Drop FR-DIS-4**: need is real; `LineMark.base` becomes unused suffix.
- **Base as tag**: user bookkeeping for what lines already say; drifts on edit.

## Consequences

- FR-DIS-4 rewritten from grouping to narrowing; "grouping" leaves the domain's vocabulary.
- `groupByBaseSpirit` is never written. `discovery.dart` holds `basesOf`, `baseSpirits` and
  `marksBase` instead.
- ADR 06's "the list groups on the mark" and ADR 11's deferred question both point here.
- `tagFilter` takes a leading filter, so the two narrowings share one row and one message; a
  collection with no recipe tags still gets the base chip.
- Non-base grouping stays out of scope; FR-DIS-5's "active filters" now include the base pick.
