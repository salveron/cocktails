# ADR: Base spirit on the recipe line

**Status:** Accepted

## Context

Base was ingredient flag (global). Wrong: bourbon base in Sour, modifier elsewhere. Per-recipe (FR-DIS-4).
Base never optional; marks mutually exclusive. Decided before M11/M14.

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

- FR-VOC-2→FR-REC-8. FR-DIS-4 keys on marked lines.
- M11 loses flag, M14 gains mark, M19 groups.
- Old files rejected as unknown-key.
- All ingredient info stays one line (FR-DAT-2).
