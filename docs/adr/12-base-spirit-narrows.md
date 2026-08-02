# ADR: Base spirit narrows the list, it does not group it

**Status:** Accepted

## Context

FR-DIS-4 asked for grouped browsing: every recipe filed under each base spirit, the unmarked ones
in a tail section. Base moved onto the line to make that possible ([ADR 06](06-base-spirit-on-the-line.md)),
and [ADR 11](11-substitutions-on-the-line.md) left the question it could not answer — where a recipe
built on `1 part gin / vodka (base)` files. Decided before M19.

The need underneath the requirement is real, and the search does not cover it: `gin` reaches the gin
rinse and the quarter-part float alike, where *base* means built on it — the distinction base moved
onto the line for.

## Decision

**Base spirit is a filter on the recipe list, not a layout of it.** A recipe matches when any
alternative of any of its base lines names the picked spirit.

- One chip in the filter row the tag chips already stand in, opening a menu: **Any base**, **No
  base**, then every base spirit in the collection, A→Z. It narrows alongside the search, the tag
  picks and the order, and combines with all three.
- **No base** is a choice of its own, not the absence of one: the recipes marking no base are a
  set worth reaching, and an unmarked recipe is otherwise reachable only by scrolling.
- A group marked `(base)` matches under **every** alternative it names — ADR 11's question
  dissolves rather than being answered, a predicate having no single place to file a recipe.
- Spirits are read off the recipes, never a vocabulary of their own: a bottle is a base spirit for
  as long as a line marks it one. Names carry the vocabulary's own spelling and compare through
  `nameKey`, as every name does (ADR 08).
- A pick that goes stale — the spirit renamed, deleted, or its last base mark cleared — stops
  narrowing rather than emptying the list, the rule the tag row already follows. No base mark
  anywhere means no chip.
- Screen state, like the search and the order: nothing about a way of looking reaches the file.

## Alternatives considered

- **Grouped browsing as written.** A second list layout on a screen already carrying search, tag
  filter, six orders and per-card expansion; it demotes availability — the order the list opens in,
  and the app's premise — to *within* a section; and a group would have to file one recipe under two
  headers, breaking the name-keyed placement `_place` and `ValueKey(name)` rest on, or pick one
  alternative arbitrarily.
- **A base sort order with section headers.** Keeps one layout, but collides with FR-DIS-8: the
  order is where availability lives, and a recipe with two base marks still has no single rank.
- **Dropping FR-DIS-4 outright.** The need is real, and `LineMark.base` would then feed nothing but
  a printed suffix.
- **Base spirit as a tag.** Costs the user a second bookkeeping job for something the lines already
  say, and drifts the moment a recipe is edited.

## Consequences

- FR-DIS-4 rewritten from grouping to narrowing; "grouping" leaves the domain's vocabulary.
- `groupByBaseSpirit` is never written. `discovery.dart` holds `basesOf`, `baseSpirits` and
  `marksBase` instead.
- ADR 06's "M19 groups" and ADR 11's deferred question both point here.
- `tagFilter` takes a leading filter, so the two narrowings share one row and one message; a
  collection with no recipe tags still gets the base chip.
- Non-base grouping stays out of scope; FR-DIS-5's "active filters" now include the base pick.
