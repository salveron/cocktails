# ADR: A bottle answers to more than one name

**Status:** Accepted

## Context

[ADR 08](08-names-ignore-case.md) settled case; it left wording: "Bourbon Whiskey" and "bourbon" 
are one bottle but two to the vocabulary. Decided before aliases were built.

## Decision

**An ingredient carries aliases; the entry's own name stays its identity.**

- `Ingredient.aliases` — spellings a bottle answers to, written as `aliases: [bourbon whiskey, bourbon whisky]`.
- `Model.ingredientNamed` indexes aliases; resolution through one home.
- Uniqueness spans names and aliases under fold (ADR 08): no collisions across bottles or within.
- References stored canonical: line with alias resolves and stores under bottle's own name.
- Aliases searched, not displayed (except in edit dialog).
- No commas in alias (field is comma-separated; validation enforced).
- `format` stays `1`.

## Alternatives considered

- Resolution in form alone: search and importer would need rule again.
- Separate `aliases:` section: bottle identity in two places, rename requires sync.
- Alias stored in line: file holds two names for one bottle; resolve every read not once on load.
- Old name auto-aliased on rename: wrong forever (typo would stay aliased).
- Aliases on tags/recipes: none asked for; tags picked from list not typed.

## Consequences

- FR-VOC-1 gains aliases, FR-INV-1 searches them, FR-VOC-6 new.
- `aliases` key on entry; every spelling unique under fold.
- Recipe form no longer creates near-duplicates.
- Files with aliases rewrite canonical (like unit plurals).
- Name index carries aliases (built once per model).
