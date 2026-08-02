# ADR: A bottle answers to more than one name

**Status:** Accepted

## Context

[ADR 08](08-names-ignore-case.md) settled case; it left wording: "Bourbon Whiskey" and "bourbon" 
are one bottle but two to the vocabulary. Decided before M17d.

## Decision

**An ingredient carries aliases; the entry's own name stays its identity.**

- `Ingredient.aliases` — the spellings a bottle answers to, held in the entry beside its name and
  written as `aliases: [bourbon whiskey, bourbon whisky]`, absent where there are none.
- **One home for resolution.** `Model.ingredientNamed` indexes aliases beside names, so every caller
  already asking "which bottle does this name mean" — availability, delete blocking, the recipe
  form, the reference rules — understands an alias without a line of its own.
- **Uniqueness widens to every spelling.** Within the ingredient vocabulary, names and aliases share
  one namespace under the fold: an alias may repeat neither another bottle's name, nor another
  bottle's alias, nor its own entry's name. `Model` throws and `validateModel` reports — ADR 05's
  two contracts, unchanged.
- **References are stored canonical.** A line naming a bottle by an alias resolves and is stored
  under the bottle's own name — in the form on save, and on load for a file that was hand-edited, so
  the next save writes it back canonical. One derivation does it, wherever the line came from.
- **Aliases are for finding, not for showing.** Nothing displays them but the dialog that edits
  them; the inventory search matches them, so a bottle can be found by any name it answers to, and
  the row it finds reads under the one name the app calls it.
- **No commas in an alias.** They are entered as one comma-separated field, so the separator cannot
  appear inside a value. The rule lives in validation, so a hand-edited file cannot hold what the
  field could never produce.
- `format` stays `1`.

## Alternatives considered

- Resolution in the recipe form alone: the search, the importer and every later reader would each
  need the rule again, or go without it.
- An `aliases:` section of its own mapping alias → ingredient: a second place a bottle's identity
  lives, and a rename would have to keep two sections in step.
- Keeping the alias in the stored line: the file would hold two names for one bottle, and every
  reader would resolve on every read rather than once on the way in.
- The old name becoming an alias automatically on rename: convenient once, wrong forever after — a
  corrected typo would go on answering for the bottle.
- Aliases on tags and recipes too: nothing asked for them, and a tag is picked from a list rather
  than typed.

## Consequences

- FR-VOC-1 gains aliases, FR-INV-1 searches them, FR-VOC-6 new.
- `aliases` key on entry; every spelling unique under fold.
- Recipe form no longer creates near-duplicates.
- Files with aliases rewrite canonical (like unit plurals).
- Name index carries aliases (built once per model).
