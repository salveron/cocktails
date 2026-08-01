# ADR: A bottle answers to more than one name

**Status:** Accepted

## Context

[ADR 08](08-names-ignore-case.md) settled that a name is identity, whatever case it is written in.
It left one thing unsaid: "Bourbon Whiskey" and "bourbon" are one bottle to the person typing them
and two to the vocabulary. Typing the long form into a recipe line offers to add a second,
out-of-stock bottle — the trap ADR 08 closed for capitalisation, still open for wording.

Decided before M17d.

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

- Requirements: FR-VOC-1's ingredient entry gains aliases, FR-INV-1's search covers them, and a new
  FR-VOC-6 states what an alias is and where it is understood.
- The data format gains an `aliases` key on an ingredient entry, and the rule that every spelling in
  the vocabulary — name or alias — is unique under the fold.
- Adding a bottle from a recipe line can no longer create a near-duplicate: an aliased name resolves
  before the "add missing ingredients?" offer is built.
- A file whose lines use aliases is rewritten on the next save — content preserved, spelling
  canonical, the same normalisation the unit plural performs ([ADR 09](09-units-are-a-vocabulary.md)).
- Deleting a bottle still names the recipes standing in the way; a line that referenced it by an
  alias counts, resolution running through the same index.
- The vocabulary is searched by more spellings than it has entries, so the name index carries every
  alias too — built once per model, as the name index already is.
