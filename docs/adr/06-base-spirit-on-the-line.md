# ADR: Base spirit on the recipe line

**Status:** Accepted

## Context

Base-ness was a flag on `Ingredient` (FR-VOC-2), making a bottle a base globally. It is not:
bourbon is the base of a Whiskey Sour and a modifier elsewhere. The grouping FR-DIS-4 needs is
per recipe. A base is also never optional — a recipe without its base is another recipe — so
the two line marks are mutually exclusive. Decided before M11 and M14, which would otherwise
build screens for the old shape.

## Decision

**Base is a mark on the recipe line, exclusive with optional by construction.**

- `RecipeLine.mark` is `LineMark?` — `enum LineMark { base('base'), optional('optional') }`
  with declared wire tokens. One field, so both marks cannot be set. `isBase`/`isOptional`
  stay as getters; `marked(LineMark?)` sets and clears.
- Line grammar: suffix ` (base)` joins ` (optional)`; at most one, both reserved against
  ingredient names.
- `Ingredient` loses `isBase` and the ingredient entry loses its `base` key, with no
  replacement — the existing unknown-key rule reports leftovers.
- `format` stays `1`: the schema is unreleased, so no file needing migration exists.

## Alternatives considered

- **Two booleans plus a validation rule** — the illegal state exists and must be caught in the
  codec, the recipe form, and `validateRecipe`; one field prevents it for free.
- **A `base:` key on the recipe naming an ingredient** — a second reference to keep in sync on
  rename, and cannot carry the two bases FR-DIS-4 allows.
- **Keep the ingredient flag, derive per recipe** — the wrong domain: an ingredient is not a
  base for anything by itself.

## Consequences

- Requirements move: FR-VOC-2 becomes FR-REC-8; FR-DAT-1 drops "base-spirit flags"; FR-DIS-4
  keys on marked lines.
- M11 loses the base-spirit flag, M14's line editor gains the mark, M19 groups by it.
- `groupByBaseSpirit` reads recipe lines instead of the vocabulary; its
  [signature](../components.md#computations) is unchanged.
- Store files carrying `base: true` on an ingredient are rejected as unknown-key errors and
  hand-edited; the mark is re-added per recipe.
- Everything about an ingredient in a recipe stays on its one line — the shape FR-DAT-2's
  hand and AI editing works with.
