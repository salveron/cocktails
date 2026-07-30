# ADR: Tags — two vocabularies, colour from a palette

**Status:** Accepted. Amended at M11b: ingredient tags added, the `neutral` default dropped.

## Context

Tags are the one labelling mechanism (FR-REC-4). Two shape questions must be settled before 
screens built on them:

- Tag renders as coloured chip; colour chosen by user, persists (YAML schema, [ADR 02](02-persistence-and-export-format.md)).
- Ingredients want labels ("citrus", "homemade") but not recipe labels ("classic" irrelevant to bottle).

Decided before M12 (tag screen) and M13/M14 (tag rendering).

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

- Requirements gain FR-VOC-4 (ingredient tags), FR-INV-3 (display/filtering); FR-VOC-3 is requirement, 
  not default. FR-VOC-2 stays retired (no two meanings).
- Renames per-vocabulary (recipe tag→recipes, ingredient tag→ingredients); colour carries across 
  (dropping it = data loss).
- Deletion blocked by own-side references only (FR-VOC-1); model answers `usersOfTag(kind, name)`.
- `Ingredient` holds a list (not `const`-constructible, like `Recipe`).
- Name dialog gains palette row (required for tags, absent for ingredients); colour change is own 
  action on tag screen.
- Earlier shapes (bare strings, no colour, `tags:` section) rejected as errors; hand-edit like 
  ADR 06 leftovers.
- Every tag surface (M13, M14, M18) reads token → swatch map in `ui/`.
