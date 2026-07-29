# ADR: Tags — two vocabularies, colour from a palette

**Status:** Accepted. Amended at M11b: ingredient tags added, the `neutral` default dropped.

## Context

Tags are the app's one labelling mechanism (FR-REC-4). Two questions about their shape had to
be settled before any screen was built on them, and the second reopened the first:

- A tag renders as a coloured chip, the colour chosen by the user and shown everywhere the tag
  appears. That makes colour user data: it persists, which puts it in the YAML schema — the
  public contract of [ADR 02](02-persistence-and-export-format.md).
- Ingredients want labels too — "citrus", "homemade", "amaro" — but not the *recipe* labels:
  "classic" says nothing about a bottle.

Decided before M12 builds the tag screen and before M13/M14 render tags inside recipes, which
would otherwise be built for the wrong shape.

## Decision

**Two tag vocabularies of one shape, and every tag carries a colour.**

- `recipe_tags:` and `ingredient_tags:` are peer top-level sections behind `Model.recipeTags`
  and `Model.ingredientTags`. One `Tag` type serves both — they differ in what they label, not
  in what they are. A name may exist in both and mean different things; uniqueness is per
  vocabulary.
- An ingredient references its tags the way a recipe always has: a flow list of names, here
  inside the existing one-line entry. References are names resolved against the matching
  vocabulary — the colour lives with the tag, once.
- `enum TagColor { teal, indigo, plum, rose, sand, slate }`, declared wire tokens like every
  other enum in the format. `Tag.color` is **required**: there is no unpainted tag, so a colour
  on screen is always a choice someone made rather than an absence.
- The palette holds no green, amber or red, which stock (FR-INV-1) and availability (FR-DIS-1)
  already spend on meaning; a colour on screen keeps one meaning.
- Token → swatch is a UI mapping, exhaustive over the enum and legible in both themes. The
  domain names no Flutter colour.
- The palette is **open**: a new member is additive, since files written before it simply do not
  use it — removing one is the breaking direction. The swatch map switches over `TagColor`
  exhaustively, so a member added without a swatch is a compile error rather than a surprise at
  runtime.
- `format` stays `1`, on [ADR 06](06-base-spirit-on-the-line.md)'s grounds: the schema is
  unreleased, and the one live store file carries an empty tag list.

## Alternatives considered

- **One vocabulary, scope on the tag** (`{name: citrus, scope: ingredient}`) — one list and one
  set of edits, but a name could then mean only one thing app-wide, uniqueness becomes "unique
  within scope", and every lookup, rename and delete-block has to carry a scope to be
  unambiguous. The scope argument reappears everywhere the second method set would have, plus a
  harder invariant.
- **One shared vocabulary** — nothing to keep in step, but a recipe's tag picker would offer
  "citrus" and an ingredient's "classic": neither list is ever the right one.
- **A free hex string** — every value legal, so the palette stops being one: nothing prevents a
  colour illegible on dark, and validation has no set to check against.
- **Colour derived from the name** (hash into the palette) — no schema change and no picker, but
  a rename silently repaints the tag and the choice is never the user's.
- **Scheme roles as the palette** (`primaryContainer` and friends) — theme-correct for free, but
  derived from the seed: moving the seed repaints every existing tag, and the roles collide with
  the stock chips, the defect those chips already had to be fixed for.
- **Colour kept outside the model**, in a settings map keyed by tag name — splits one fact across
  two homes, and the entries orphan on every rename and delete.
- **An optional colour defaulting to `neutral`** — what this record first decided. Omitting the
  key kept files terse and let a tag exist before anyone had thought about its colour. Dropped
  once the inventory screen chose bare dots for ingredient tags: a neutral dot is a grey mark on
  a grey card, carrying nothing while still taking space. Requiring the colour is what makes a
  dot worth drawing.

## Consequences

- Requirements gain FR-VOC-4 (ingredient tags) and FR-INV-3 (tag display and filtering);
  FR-VOC-3 becomes a requirement rather than a default. FR-VOC-2 stays retired by ADR 06 rather
  than reused, so no reference to it can mean two things.
- Renames propagate per vocabulary — a recipe tag rewrites recipes, an ingredient tag rewrites
  ingredients — and both carry the colour across, since a rename that dropped it is silent data
  loss.
- Deletion is blocked by references from a tag's own side only (FR-VOC-1), so the model answers
  both `recipesUsingTag` and `ingredientsUsingTag`.
- `Ingredient` now holds a list, so it stops being `const`-constructible, as `Recipe` already is.
- The shared name dialog gains a palette row, required wherever it names a tag and absent for
  ingredients; changing a colour afterwards is its own action on the tag screen.
- Files carrying an earlier shape — `tags:` as the section name, tag entries without a colour,
  tag entries as bare strings — are rejected as shape errors and hand-edited, as ADR 06's
  leftovers were.
- Every later tag surface — recipe view (M13), form (M14), filters (M18) — reads the one
  token → swatch map in `ui/`.
