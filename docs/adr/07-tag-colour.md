# ADR: Tags — two vocabularies, colour from a palette

**Status:** Accepted. Amended before either tag screen was built: ingredient tags added as a
second vocabulary, the `neutral` default dropped.

## Context

Colour persistence, two vocabularies (ingredients vs. recipes). Decided before any screen was
built on either.

## Decision

**Two tag vocabularies of one shape; every tag carries a colour.**

- `recipe_tags` and `ingredient_tags` are peer sections behind `Collection.recipeTags`/`ingredientTags`. 
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

- One vocabulary with scope: scope needed everywhere.
- Shared vocabulary: picker offers wrong list either way.
- Free hex: illegible in dark mode.
- Hash-derived: rename silently repaints.
- Scheme roles: collides with stock chips.
- Colour outside collection: orphans on rename/delete.
- Optional `neutral` default: grey on grey in inventory.

## Consequences

- Gain FR-VOC-4/INV-3. Per-vocabulary renames.
- Deletion blocked own-side only.
- Old shapes (no colour) rejected as errors.
- Tag screens read token→swatch map.
