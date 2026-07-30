# ADR: Base spirit on the recipe line

**Status:** Accepted

## Context

Base-ness was a flag on `Ingredient` (FR-VOC-2), making bottles globally base. Wrong: bourbon is 
base in Whiskey Sour, modifier elsewhere. Grouping (FR-DIS-4) is per-recipe. Base never optional 
(recipe without base is different recipe), so marks mutually exclusive. Decided before M11, M14 
build screens.

## Decision

**Base is a mark on the recipe line, exclusive with optional by construction.**

- `RecipeLine.mark` is `LineMark?` (`enum LineMark { base('base'), optional('optional') }` with 
  tokens). One field prevents both marks. `isBase`/`isOptional` are getters; `marked(LineMark?)` 
  sets/clears.
- Line grammar: ` (base)` suffix joins ` (optional)`; at most one, both reserved from ingredient names.
- `Ingredient` loses `isBase`, entry loses `base` key; unknown-key rule reports leftovers.
- `format` stays `1` (schema unreleased).

## Alternatives considered

- Two booleans + validation rule: illegal state exists, must catch in codec/form/validate. 
  One field prevents it free.
- `base:` key on recipe naming ingredient: second reference to sync on rename, can't carry 
  multiple bases (FR-DIS-4).
- Keep ingredient flag, derive per recipe: wrong domain; ingredient not base by itself.

## Consequences

- Requirements: FR-VOC-2→FR-REC-8; FR-DAT-1 drops base-spirit flags; FR-DIS-4 keys on marked lines.
- M11 loses base-spirit flag, M14 gains line mark, M19 groups by it.
- `groupByBaseSpirit` reads recipe lines; [signature](../components.md#computations) unchanged.
- Store files with `base: true` on ingredient rejected as unknown-key; hand-edit and re-add per recipe.
- Everything about an ingredient in recipe stays on one line (shape FR-DAT-2 and AI editing work with).
