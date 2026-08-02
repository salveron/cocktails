# Architecture

Technical design for the pilot defined in [requirements.md](requirements.md); direction in
[vision.md](vision.md). Decision rationale lives in the [ADRs](adr/); this document records
the resulting design at system level, [components.md](components.md) at module level.

## Technology stack

- **Flutter (Dart)** targeting Android; desktop later ([ADR 01](adr/01-technology-stack.md)).
- **Riverpod** for state management ([ADR 03](adr/03-app-structure-and-state.md)).
- Development: Linux + physical Android phone over USB.
- Minimal dependencies: `flutter_riverpod`, `yaml`, `path_provider`, `share_plus`, `file_picker`. 
  Riverpod at 2.x (3.x adds unused packages).

## System overview

Offline app: entire database in memory, persisted as one YAML file byte-identical to export 
([ADR 02](adr/02-persistence-and-export-format.md)).

- Export: file copy. Import: validate, auto-export current state, atomically replace.
- Names are identity: recipes reference ingredients/tags by name, compared ignoring case
  ([ADR 08](adr/08-names-ignore-case.md)). Rename is one mutation rewriting all references.
- Writes atomic (temp → rename); rolling backups.
- Single-writer by design (future guest access is read-only publishing).

## Layers

Three layers ([ADR 03](adr/03-app-structure-and-state.md)):

- **Domain** — pure Dart: entities, availability, search/filter/grouping, optimizer, validation. 
  Unit-testable without device.
- **Data** — storage interface + YAML adapter (codec, atomic writes, backups).
- **Presentation** — Flutter screens/widgets. Reads through Riverpod providers; derived state 
  (availability, filtered views, optimizer output) in computed providers. Mutations through 
  model-update methods that trigger persistence.

Each layer's public surface is its barrel file; internals in `src/`. Dependencies point inward only. 
Rules, interfaces, data flows in [components.md](components.md) ([ADR 04](adr/04-module-boundaries.md)).

## Storage isolation

Persistence behind storage interface. Domain and UI depend only on the interface — never on 
YAML, file paths, or platform — so store can be swapped (e.g. SQLite) by replacing one adapter.

## Data format

The store file — identical to the export file ([ADR 02](adr/02-persistence-and-export-format.md)).
Example carrying every construct:

```yaml
format: 1

settings:
  part_ml: 30          # how many ml one part is (FR-SET-1)
  display: part        # part | ml

units:                                 # yours to manage (ADR 09)
  - {name: part, plural: parts}
  - {name: ml}                         # plural omitted = reads like the name
  - {name: dash, plural: dashes}

ingredients:
  - {name: bourbon, stock: in, aliases: [bourbon whiskey]}  # also answers to (ADR 10)
  - {name: lemon juice, stock: low, tags: [citrus]}
  - {name: rich demerara syrup, tags: [syrup, homemade]}   # stock omitted = out
  - {name: egg white, stock: in}                           # untagged

ingredient_tags:                       # what a bottle can be labelled
  - {name: citrus, color: sand}
  - {name: homemade, color: slate}
  - {name: syrup, color: indigo}

recipe_tags:                           # a separate vocabulary (ADR 07)
  - {name: sour, color: rose}
  - {name: classic, color: teal}

recipes:
  - name: Whiskey Sour
    tags: [sour, classic]
    lines:
      - 1.5-2 parts bourbon (base)
      - 0.75 parts lemon juice
      - 0.5 parts rich demerara syrup
      - 0.5 parts egg white (optional)
    notes: dry shake, then shake with ice
    made: {last: 2026-07-18, times: 12}
```

Rules:

- `format` is the schema version; imports of unsupported versions are rejected (FR-DAT-4).
- `units` is the measurement vocabulary ([ADR 09](adr/09-units-are-a-vocabulary.md)): `name`
  required, `plural` written only where it differs from the name. An **absent** section reads as
  the seven the app ships with — `part ml oz dash barspoon drop piece` — so a file written before
  units were data loads unchanged; a section that is present is the whole vocabulary, empty
  included. Every spelling in it, plurals counted, is unique under the fold, and `part` and `ml`
  must be among the names: an omitted unit is a part (FR-REC-2) and the ratio converts between the
  two (FR-SET-1). A file dropping one is reported, not repaired.
- Ingredient entries: `name` required; `stock` is `in` | `low` | `out` (default `out`); `tags`
  is a list of `ingredient_tags` names, absent when there are none; `aliases` is a list of the
  other spellings the bottle answers to ([ADR 10](adr/10-ingredient-aliases.md)), absent likewise.
  Names and aliases share one namespace: every spelling in the section, whosever it is, is unique
  under the fold, and none holds a comma. A reference resolves against every spelling and is
  stored under the entry's own name, so a hand-written `2 parts bourbon whiskey` reads back as
  `2 parts bourbon`.
- Tag entries: `name` and `color` both required — `color` is one of `teal` | `indigo` | `plum` |
  `rose` | `sand` | `slate`, the palette of [ADR 07](adr/07-tag-colour.md). The two tag
  sections are separate vocabularies of the same shape, each unique within itself; one name may
  stand in both.
- A `tags` list — on a recipe or on an ingredient — holds names only, resolved against that
  side's vocabulary. The colour lives with the tag, once.
- An ingredient line is `<amount> [unit] <ingredient name>`, optionally suffixed with one
  mark — ` (base)` or ` (optional)`, never both ([ADR 06](adr/06-base-spirit-on-the-line.md)).
  Amount is a decimal number or a range `a-b`; the unit is a reference into the `units` section,
  written in either spelling, and may be left out altogether — an omitted unit is `part`
  (FR-REC-2). A word is a unit only where the vocabulary answers to it, so anything else belongs
  to the ingredient name: `1.5 cup sugar` is 1.5 part of "cup sugar", caught where the name fails
  to resolve rather than as an unknown unit. The writer emits the spelling the amount calls for —
  the singular for exactly 1, the plural otherwise — so a stored line reads as English does. A
  plural a unit never wrote is still accepted on the way in (`2 cups`), and a line whose unit the
  vocabulary has lost prints as written and is reported as unknown. Both mark suffixes are
  reserved — ingredient names cannot end with one.
- `made` holds the made-history: `last` is an ISO date (`YYYY-MM-DD`, nothing looser),
  `times` a count. Absent = never made.
- Every recipe line and tag reference must resolve to the matching vocabulary; names are unique
  within their kind (FR-DAT-4 validation). Names compare ignoring case, so "Gin" and "gin" are
  one name — as a duplicate where both are entries, and as a match where one references the
  other ([ADR 08](adr/08-names-ignore-case.md)). Spelling is kept as written.
- Value rules (FR-DAT-4): names are non-empty, single-line, without surrounding
  whitespace; amounts are positive with range ends in order; `part_ml` is positive;
  `times` is at least 1; a `tags` list has no repeats.
- Unknown keys are structural errors (FR-DAT-4): on an import that replaces the whole
  database, a misspelled key must be reported, not silently drop its content.
- The app writes a canonical form: fixed key order, fixed indentation, no comments. Comments
  are legal in imported files but are not preserved once the app rewrites the store —
  the round-trip guarantee (FR-DAT-5) covers content, not comments.
- Stock, display-unit, mark and tag-colour tokens are declared as fields on their enums, never
  derived from Dart identifier spellings, so renaming a member cannot change the format. Unit
  tokens are not among them: a unit's spelling is the user's, held in the file (ADR 09).
- The pilot reads and writes format `1` only; a future format bump migrates old files on
  import inside the codec.
- The round-trip guarantee (FR-DAT-5) is over canonical files: a hand-written `1.50`, `2.0`,
  `2 dash`, `1 gin` or `1 part GIN` normalises to `1.5`, `2`, `2 dashes`, `1 part gin` and the
  bottle's own spelling on the first rewrite. Content is preserved, byte-identity
  only from the app's own output onward.
- Dart's `yaml` package is parse-only, so the canonical writer is a small custom emitter —
  spec'd by this section and pinned by the round-trip tests.
- Validation failures (FR-DAT-4) report the YAML line and the offending value — "what is
  wrong and where" comes from the parser's source positions.

## Domain computations

- **Availability** (per recipe, over required lines only): all ingredients `in` → makeable;
  none `out` but some `low` → makeable-low; any `out` → missing. Computed in a Riverpod
  derived provider; nothing is ever stored. A recipe always has a required line to judge
  (FR-REC-2), and a line naming a bottle the vocabulary lost reads as `out`.
- **Shopping optimizer** (FR-DIS-6): for each missing recipe, collect its set of `out`
  required ingredients; keep sets of size ≤ N. Candidate purchases are unions of these sets
  up to size N; each candidate is scored by how many recipes become can-make. Zero-yield
  candidates are dropped. At several hundred recipes this brute force is well inside NFR-2
  at N = 3.
- **Line parsing**: the compact-line grammar above has a single shared parser/formatter pair
  in the domain layer, used identically by the recipe form and the YAML codec, and covered
  by round-trip unit tests. Both halves take the unit vocabulary — it decides where a unit ends
  and a name begins, and how an amount is spelled — so the codec reads `units` before the
  recipes and every other caller hands its own model's list over.
- **Display transforms** (FR-REC-7, FR-SET-1): a factor multiplies every amount, both ends of
  a range together; a part-based amount converts at `part_ml` where the reading asks for ml,
  and anything already measured shows as entered. The result is text alone — a display value
  rounds to two decimals, since multiplying a decimal in binary lands a hair off — computed
  where a card is drawn and stored nowhere. At ×1 in parts it is the canonical line again, so
  the display path and the file path cannot disagree.

## Platform facts

- Store/backups: app-private directory via Android share sheet. `cocktails.yaml` (store), 
  `cocktails.backup-1/2/3.yaml`, `cocktails-export.yaml` (shareable copy). Writes via `.tmp` + rename.
- Android Auto Backup enabled.
- Application ID: `dev.salveron.cocktails`.
- Minimum Android: Flutter default (minSdk 21+).
- UI: English only.

## Build & distribution

- APK built locally, sideloaded; no Play Store in pilot.
- Keystore outside repo. Play Store later without rework.

## Testing

- **Unit tests** (pure Dart, no device): availability, filtering/grouping, optimizer, validation, 
  YAML round-trip (FR-DAT-5).
- **Integration tests**: atomic write, backup rotation, corrupt-file recovery.
- **Widget tests**: recipe form, stock toggle, import confirmation.
- CI: format check, `flutter analyze`, test suite, local APK build on every push.
