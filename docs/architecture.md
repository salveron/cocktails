# Architecture

Technical design for the pilot defined in [requirements.md](requirements.md); direction in
[vision.md](vision.md). Decision rationale lives in the [ADRs](adr/); this document records
the resulting design at system level, [components.md](components.md) at module level.

## Technology stack

- **Flutter (Dart)**, targeting Android in the pilot; desktop later is an added build target
  ([ADR 01](adr/01-technology-stack.md)).
- **Riverpod** for state management ([ADR 03](adr/03-app-structure-and-state.md)).
- Development on Linux with a physical Android phone over USB; no emulator required.
- Third-party dependencies are held to a deliberate minimum: `flutter_riverpod`, `yaml`,
  `path_provider`, `share_plus`, `file_picker`; anything beyond these is a considered
  addition, not a reflex. Riverpod is held at 2.x — 3.x pulls the analyzer, shelf, and test
  packages into the app's own dependency graph, and the pilot uses nothing it adds.

## System overview

A single offline app. The entire database — vocabularies, stock levels, recipes with
made-history, settings — is held in memory and persisted as one YAML file that is
byte-identical to the export format ([ADR 02](adr/02-persistence-and-export-format.md)).

- Export shares a copy of the store file; import validates a candidate file, auto-exports
  the current state (FR-DAT-3), then atomically replaces the store.
- Names are identity throughout: recipes reference ingredients and recipe tags by name and
  ingredients reference ingredient tags the same way, so a vocabulary rename (FR-VOC-1) is one
  model mutation that rewrites every reference before the single save.
- Writes are atomic (temp file, then rename) and rotate a small set of backups.
- Single-writer by design; future guest access is read-only publishing, never a second writer.

## Layers

Three layers ([ADR 03](adr/03-app-structure-and-state.md)):

- **Domain** — pure Dart, no Flutter imports: entities, availability computation,
  search/filter/grouping, the shopping optimizer, validation rules. Unit-testable on the dev
  machine without a device.
- **Data** — the storage interface and its YAML file adapter (codec, atomic writes, backups).
- **Presentation** — Flutter screens and widgets. All reads go through Riverpod providers;
  derived state (availability, filtered views, optimizer output) lives in computed providers
  that recompute automatically when their inputs change. All mutations go through model-update
  methods that also trigger persistence.

Each layer's public surface is its barrel file, over internals kept in `src/`; dependencies
point inward only. The rules, the interfaces between the layers, and the data flows across
them are in [components.md](components.md) ([ADR 04](adr/04-module-boundaries.md)).

## Storage isolation

All persistence sits behind a storage interface with load/save semantics. Domain and UI code
depend only on the interface — never on YAML, file paths, or the platform — so the store can
be swapped (e.g. to SQLite, should guests ever write data) by replacing one adapter, using
the export file as the data migration vehicle.

## Data format

The store file — identical to the export file ([ADR 02](adr/02-persistence-and-export-format.md)).
Example carrying every construct:

```yaml
format: 1

settings:
  part_ml: 30          # how many ml one part is (FR-SET-1)
  display: part        # part | ml

ingredients:
  - {name: bourbon, stock: in}
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
      - 1.5-2 part bourbon (base)
      - 0.75 part lemon juice
      - 0.5 part rich demerara syrup
      - 0.5 part egg white (optional)
    notes: dry shake, then shake with ice
    made: {last: 2026-07-18, times: 12}
```

Rules:

- `format` is the schema version; imports of unsupported versions are rejected (FR-DAT-4).
- Ingredient entries: `name` required; `stock` is `in` | `low` | `out` (default `out`); `tags`
  is a list of `ingredient_tags` names, absent when there are none.
- Tag entries: `name` and `color` both required — `color` is one of `teal` | `indigo` | `plum` |
  `rose` | `sand` | `slate`, the palette of [ADR 07](adr/07-tag-colour.md). The two tag
  sections are separate vocabularies of the same shape, each unique within itself; one name may
  stand in both.
- A `tags` list — on a recipe or on an ingredient — holds names only, resolved against that
  side's vocabulary. The colour lives with the tag, once.
- An ingredient line is `<amount> <unit> <ingredient name>`, optionally suffixed with one
  mark — ` (base)` or ` (optional)`, never both ([ADR 06](adr/06-base-spirit-on-the-line.md)).
  Amount is a decimal number or a range `a-b`; unit is one of
  `part ml oz dash barspoon drop piece` and is stored as entered. Both mark suffixes are
  reserved — ingredient names cannot end with one.
- `made` holds the made-history: `last` is an ISO date (`YYYY-MM-DD`, nothing looser),
  `times` a count. Absent = never made.
- Every recipe line and tag reference must resolve to the matching vocabulary; names are unique
  within their kind (FR-DAT-4 validation).
- Value rules (FR-DAT-4): names are non-empty, single-line, without surrounding
  whitespace; amounts are positive with range ends in order; `part_ml` is positive;
  `times` is at least 1; a `tags` list has no repeats.
- Unknown keys are structural errors (FR-DAT-4): on an import that replaces the whole
  database, a misspelled key must be reported, not silently drop its content.
- The app writes a canonical form: fixed key order, fixed indentation, no comments. Comments
  are legal in imported files but are not preserved once the app rewrites the store —
  the round-trip guarantee (FR-DAT-5) covers content, not comments.
- Unit, stock, mark and tag-colour tokens are declared as fields on their enums, never derived
  from Dart identifier spellings, so renaming a member cannot change the format.
- The pilot reads and writes format `1` only; a future format bump migrates old files on
  import inside the codec.
- The round-trip guarantee (FR-DAT-5) is over canonical files: a hand-written `1.50` or
  `2.0` normalises to `1.5` and `2` on the first rewrite. Content is preserved, byte-identity
  only from the app's own output onward.
- Dart's `yaml` package is parse-only, so the canonical writer is a small custom emitter —
  spec'd by this section and pinned by the round-trip tests.
- Validation failures (FR-DAT-4) report the YAML line and the offending value — "what is
  wrong and where" comes from the parser's source positions.

## Domain computations

- **Availability** (per recipe, over required lines only): all ingredients `in` → makeable;
  none `out` but some `low` → makeable-low; any `out` → missing. Computed in a Riverpod
  derived provider; nothing is ever stored.
- **Shopping optimizer** (FR-DIS-6): for each missing recipe, collect its set of `out`
  required ingredients; keep sets of size ≤ N. Candidate purchases are unions of these sets
  up to size N; each candidate is scored by how many recipes become can-make. Zero-yield
  candidates are dropped. At several hundred recipes this brute force is well inside NFR-2
  at N = 3.
- **Line parsing**: the compact-line grammar above has a single shared parser/formatter pair
  in the domain layer, used identically by the recipe form and the YAML codec, and covered
  by round-trip unit tests.

## Platform facts

- Store and backups: app-private documents directory, shared via Android share sheet (FR-DAT-1/3).
  `cocktails.yaml` is the store; each save copies the file it replaces into `cocktails.backup-1.yaml`,
  shifting the previous backups down and dropping `cocktails.backup-3.yaml`; `cocktails-export.yaml`
  is the shareable copy `exportSnapshot` writes. Writes land through a `.tmp` sibling and a rename.
- Android Auto Backup enabled; device loss/reset does not mean data loss.
- Application ID: `dev.salveron.cocktails` (permanent once installed).
- Minimum Android version: Flutter default (minSdk 21+); no special device features needed.
- UI language: English only; no i18n framework in pilot.

## Build & distribution

- Release APK built locally and sideloaded; no store presence in pilot.
- Keystore stored outside repo (outside CI); losing it requires reinstall.
- Play Store track possible later without rework.

## Testing

- **Unit tests** (pure Dart, no device) cover domain layer: availability, filtering/grouping, optimizer, import validation, YAML codec round-trip (FR-DAT-5).
- **Integration tests** on storage adapter: atomic write, backup rotation, corrupt-file recovery.
- **Widget tests** on critical flows: recipe form, stock toggle, import confirmation.
- CI runs format check, `flutter analyze`, and test suite on every push (local APK builds).
