# ADR: Units are a vocabulary

**Status:** Accepted. Amended by [ADR 17](17-the-fixed-units-interconvert.md): `oz` joins the fixed units and `Settings.display` names one of the three, the reasoning below standing otherwise.

## Context

Units were closed enum (seven members). Plural guessed on input, never written. Cannot add units ("tsp", "splash") or irregular plurals ("leaves").

## Decision

**Units are a user vocabulary in the file; `part` and `ml` are members no one can remove.**

- `Unit` becomes an entity: a name and a plural (empty where it equals the name: `ml`, `oz`). A `units:` section holds them, seeded with today's seven; an absent section reads as those seven, so older files load unchanged.
- `RecipeLine.unit` is the unit's name, as `RecipeLine.ingredients` are the entries': a reference resolved against the vocabulary and folded like any name ([ADR 08](08-names-ignore-case.md)). Rename propagates into every line; delete is blocked while a line uses it, FR-VOC-1's rule with a fourth vocabulary under it.
- Every spelling is unique under the fold, plurals included: a plural repeating another unit's name would leave `2 dashes` meaning two things.
- **The grammar takes the vocabulary.** A word is a unit if it matches a name or plural, ignoring case; the `s`/`es` strip remains a fallback for unwritten plurals. Anything else stays in the ingredient name, as before, and an omitted unit is still `part` (FR-REC-2). `tryParseRecipeLine` and `formatRecipeLine` take the units; every caller (the codec, the recipe form, the display transforms) passes them.
- **The plural is written.** An amount other than exactly 1 reads in the plural, on a card and in the file alike: `1 part lemon juice`, `2 dashes Angostura`, `1.5-2 parts bourbon (base)`. The invariant that a card at ×1 in parts *is* the canonical line survives. What flips is the normalisation's direction: `2 dash` becomes `2 dashes` on the first rewrite.
- **`part` and `ml` are fixed.** The ratio and the display toggle (FR-SET-1) are anchored to those two names, so the screen offers neither rename nor delete for them, while their plurals stay editable. `Settings.display` stays a two-valued enum: it chooses between the two fixed units, not among the vocabulary. A hand-edited file that drops one is reported, not repaired.
- A line whose unit the vocabulary no longer holds prints as written and is reported as an unknown unit, the treatment a line naming a lost ingredient already gets.
- `format` stays `1` ([ADR 06](06-base-spirit-on-the-line.md): the schema is unreleased).

## Alternatives considered

- Keep the enum, edit plurals only: no new section and no grammar change, but "tsp" stays impossible and the plural earns its keep only while typing.
- Units as data, nothing fixed: `part` and `ml` renameable, the conversion anchored to a role flag on the entry — a second concept carrying a fact the two names already carry.
- A unit carrying its ml equivalence, so `oz` and `dash` convert too: a bigger feature than asked for, and additive later (an optional key on an entry that will already exist).
- Plural on cards only: display and file would disagree about the same line, and the ×1 invariant would have to be retired.
- Storing the whole `Unit` on the line, not its name: every line would carry a copy of the vocabulary, and a rename would rewrite data, not references.

## Consequences

- FR-REC-2 becomes seeded default, FR-VOC-5 manages units/plurals.
- Data format gains `units:` section; FR-DAT-5 unchanged.
- Existing files rewrite on save.
- Ingredient names with unit words parse differently (edge case).
