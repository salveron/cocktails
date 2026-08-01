# ADR: Units are a vocabulary

**Status:** Accepted

## Context

Units were a closed enum with declared wire tokens — `part ml oz dash barspoon drop piece`. The
singular was the token; the plural was accepted on input by stripping an `s` or an `es`, and nothing
ever wrote one, so a card and a file both read "2 dash". Two things an enum cannot give: a unit the
app never shipped ("tsp", "splash", "cube"), and a plural the app cannot guess ("leaves").

Decided before M17b, and before the units screen (M17c) is built on the result.

## Decision

**Units are a user vocabulary in the file; `part` and `ml` are members no one can remove.**

- `Unit` becomes an entity — a name and a plural, the plural empty where it reads the same as the
  name (`ml`, `oz`). A `units:` section holds them, seeded with today's seven; an absent section
  reads as those seven, so every file written before this loads unchanged.
- `RecipeLine.unit` is the unit's name, as `ingredient` is the bottle's: a reference resolved
  against the vocabulary and folded like every other name ([ADR 08](08-names-ignore-case.md)).
  Rename propagates into every line; delete is blocked while a line uses it — FR-VOC-1's rule, with
  a fourth vocabulary under it.
- Every spelling is unique under the fold, plurals included: a plural repeating another unit's name
  would leave `2 dashes` meaning two things.
- **The grammar takes the vocabulary.** A word is a unit where it matches a name or a plural,
  ignoring case, with the `s`/`es` strip kept as a fallback for units whose plural is unwritten;
  anything else belongs to the ingredient name, as before, and an omitted unit is still `part`
  (FR-REC-2). `tryParseRecipeLine` and `formatRecipeLine` therefore take the units, and every caller
  — the codec, the recipe form, the display transforms — hands them over. Nothing reaches for
  ambient state.
- **The plural is written.** An amount other than exactly 1 reads in the plural, on a card and in
  the file alike: `1 part lemon juice`, `2 dashes Angostura`, `1.5-2 parts bourbon (base)`. The
  invariant that a card at ×1 in parts *is* the canonical line survives; what changes is which way
  the normalisation runs — `2 dash` becomes `2 dashes` on the first rewrite.
- **`part` and `ml` are fixed.** The ratio and the display toggle (FR-SET-1) are anchored to those
  two names, so the screen offers neither rename nor delete for them, while their plurals stay
  editable. `Settings.display` stays a two-valued enum: it chooses between the two fixed units, not
  among the vocabulary. A hand-edited file that drops one is reported, not repaired.
- A line whose unit the vocabulary no longer holds prints as written and is reported as an unknown
  unit — the treatment a line naming a lost bottle already gets.
- `format` stays `1` ([ADR 06](06-base-spirit-on-the-line.md): the schema is unreleased).

## Alternatives considered

- Keep the enum, edit plurals only: no new section and no grammar change, but "tsp" stays
  impossible and the plural earns its keep only while typing.
- Units as data with nothing fixed: `part` and `ml` renameable, the conversion then anchored to a
  role flag on the entry — a second concept carrying a fact the two names already carry.
- A unit carrying its ml equivalence, so `oz` and `dash` convert too: a bigger feature than the one
  asked for, and additive later — an optional key on an entry that will already exist.
- Plural on cards only: display and file would disagree about the same line, and the ×1 invariant
  would have to be retired.
- Storing the whole `Unit` on the line instead of its name: every line would carry a copy of the
  vocabulary, and a rename would rewrite data rather than references.

## Consequences

- Requirements: FR-REC-2's unit list becomes the seeded default of a managed vocabulary, FR-SET-1
  names `part` and `ml` as fixed, and a new FR-VOC-5 covers managing units and their plurals.
- The data format gains a `units:` section and the plural rule. The round-trip guarantee (FR-DAT-5)
  is untouched — canonical output stays canonical, spelled the new way.
- The line grammar is no longer context-free: parsing and formatting both need the vocabulary in
  hand, which every domain signature that touches a line now says out loud.
- Existing files need no migration and no re-entry: they load as they are and are rewritten on the
  next save.
- An ingredient whose name opens with a word later added as a unit ("cube sugar" once a "cube" unit
  exists) parses differently. The pre-existing rule stands — a word that resolves is a unit — and
  the remainder fails to resolve as a bottle, which is where it surfaces.
