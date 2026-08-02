# ADR: Tags — two vocabularies, colour from a palette

**Status:** Accepted. Amended at M11b: ingredient tags added, the `neutral` default dropped.

## Context

Two shape questions before screens built: colour persistence, two vocabularies (ingredients 
vs. recipes). Decided before M12/M13/M14.

## Decision

**Two tag vocabularies of one shape; every tag carries a colour.**

- `recipe_tags` and `ingredient_tags` are peer sections behind `Model.recipeTags`/`ingredientTags`. 
  One `Tag` type serves both; differ in what they label, not what they are. Names may exist in both 
  (different meanings); uniqueness per vocabulary.
- Ingredients reference tags like recipes: name list inside one-line entry. References are names 
  resolved against matching vocabulary; colour lives with tag once.
- `enum TagColor { teal, indigo, plum, rose, sand, slate }` with tokens. `Tag.color` **required** 
  (no unpainted tag; colour is a choice, not absence).
- Palette holds no green/amber/red (stock and availability already use). One meaning per colour on screen.
- Token → swatch is UI mapping (exhaustive, legible in both themes). Domain names no Flutter colour.
- Palette **open**: new member is additive (old files don't use). Swatch map switches exhaustively 
  (missing swatch = compile error).
- `format` stays `1` ([ADR 06](06-base-spirit-on-the-line.md): schema unreleased, one live file empty).

## Alternatives considered

- One vocabulary with scope: one list, but name means one thing app-wide; every lookup/rename 
  needs scope.
- One shared vocabulary: nothing to sync, but recipe picker offers "citrus", ingredient's "classic"; 
  wrong list either way.
- Free hex string: palette collapses; nothing prevents illegible dark-mode colours.
- Hash-derived colour: no schema change/picker, but rename silently repaints; not user's choice.
- Scheme roles (`primaryContainer`): theme-correct free, but moves with seed; collides with stock chips.
- Colour outside model (settings map): splits fact across homes; entries orphan on rename/delete.
- Optional colour defaulting `neutral`: files terse, tags exist before colour chosen. Dropped when 
  inventory chose bare dots: neutral dot = grey on grey, nothing while taking space.

## Consequences

- Gain FR-VOC-4/INV-3. Per-vocabulary renames.
- Deletion blocked own-side only.
- Old shapes (no colour) rejected as errors.
- Tag screens read token→swatch map.
