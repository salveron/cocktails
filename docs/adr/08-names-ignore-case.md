# ADR: Names compare ignoring case

**Status:** Accepted

## Context

Names are identity ([architecture.md](../architecture.md#system-overview)): a recipe line references a
bottle by its name, and rename is the one mutation that rewrites every reference. Comparison was `==`
on the raw string, so capitalisation forked identity — the recipe form matched "gin" against a
vocabulary holding "Gin", found nothing, and offered to add a second, out-of-stock bottle; the
inventory took both; a recipe "negroni" could join "Negroni". No screen shows what separates them:
two rows of the same word, one of them empty.

Decided during the quality-of-life pass after M16, before M18/M20/M21 read names in bulk.

## Decision

**One fold — lowercase — behind every name comparison; the stored spelling is untouched.**

- `nameKey(name)` and `name.sameName(other)` in the domain are the only comparison there is.
  `duplicateNameIndexes` keys on the fold, so both contracts of [ADR 05](05-validation-contract.md)
  refuse "Gin" beside "gin" — `Model` throws, `validateModel` reports — in all four vocabularies.
- Resolution folds with it: `ingredientNamed`, `recipeNamed`, `hasTag`, the unknown-ingredient and
  unknown-tag rules, `recipesUsingIngredient`, `usersOfTag`, `wornInOrder`, and the rename rewriters.
  A line reading "gin" resolves to the bottle "Gin" wherever it is read.
- Spelling is data, not identity: an entry displays as it was written, and nothing rewrites what a
  file already holds. Value equality stays exact — `Ingredient('Gin') != Ingredient('gin')` — so a
  recapitalisation is a change the controller saves, while remaining a name the vocabulary already
  has.
- The recipe form writes the vocabulary's spelling into the line it saves, so what the app produces
  never mixes two spellings of one name.
- A rename that only changes case is a rename of that entry, not a collision — the `other…Names` a
  form validates against exclude the entry by the same fold.
- `format` stays `1`.

## Alternatives considered

- Fold in the recipe form only: fixes the reported symptom, leaves the inventory able to create the
  pair and the name field able to duplicate a recipe; two rules for one question.
- Fold on write (store names lowercased): comparison becomes free, but the vocabulary loses
  "Campari" — how a name is capitalised is the user's to decide.
- Case-insensitive lookup, case-sensitive uniqueness: both spellings exist and one of them silently
  wins every lookup.
- Locale-aware or Unicode case folding: the pilot is English-only
  ([architecture.md](../architecture.md#platform-facts)); `toLowerCase` is the smaller rule until a
  locale asks for more.

## Consequences

- Requirements: the uniqueness rule behind FR-DAT-4 and the data-format rules read "unique ignoring
  case"; FR-REC-2's line grammar is unaffected.
- An imported file holding both spellings is rejected with a duplicate-name issue on its second
  entry — hand-edit and re-import, as with the [ADR 06](06-base-spirit-on-the-line.md) and
  [ADR 07](07-tag-colour.md) leftovers.
- Sorting already folds (`byName`) and search always did (`matchesQuery`), so no list moves.
- Adding an ingredient from the recipe form can no longer create a near-duplicate bottle: the "add
  missing ingredients?" offer lists only names the vocabulary genuinely lacks.
