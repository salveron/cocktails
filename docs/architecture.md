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

Offline app: entire database in memory, one YAML file byte-identical to export 
([ADR 02](adr/02-persistence-and-export-format.md)).

- Export: file copy. Import: validate, auto-export state, atomically replace.
- Names are identity; recipes reference by name, case-insensitive ([ADR 08](adr/08-names-ignore-case.md)).
- Writes atomic (temp→rename); rolling backups.
- Single-writer (guest access read-only).

## Layers

Three layers ([ADR 03](adr/03-app-structure-and-state.md)):

- **Domain** — pure Dart: entities, availability, grouping, optimizer, validation. Search and 
  filtering are presentation: narrowing a list on screen, over the queries the domain answers. 
- **Data** — storage interface + YAML adapter (codec, atomicity, backups).
- **Presentation** — Flutter screens. Reads via Riverpod; derived state in computed providers.

Barrel file is public surface; `src/` is internal. Dependencies inward only. 
Details in [components.md](components.md) ([ADR 04](adr/04-module-boundaries.md)).

## Storage isolation

Persistence behind interface only. Store swappable by adapter replacement (e.g. SQLite).

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
  - {name: lime juice, tags: [citrus]}
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
      - 0.75 parts lemon juice / lime juice   # either one makes it (ADR 11)
      - 0.5 parts rich demerara syrup
      - 0.5 parts egg white (optional)
    notes: dry shake, then shake with ice
    made: {last: 2026-07-18, times: 12}
```

Rules:

- `format`: schema version; unsupported versions rejected (FR-DAT-4).
- `units`: measurement vocabulary ([ADR 09](adr/09-units-are-a-vocabulary.md)). `plural` 
  omitted where same as name. Absent = shipped seven (`part ml oz dash barspoon drop piece`). 
  Present = whole vocabulary. All spellings unique under fold; `part`/`ml` required.
- Ingredient entries: `name` required; `stock` = `in`|`low`|`out` (default); `tags` and 
  `aliases` (optional). Names and aliases: one namespace, unique under fold, no commas. 
  References resolve by any spelling, stored under entry's name.
- Tag entries: `name` and `color` required (palette: [ADR 07](adr/07-tag-colour.md)). 
  Two vocabularies separate; one name may exist in both.
- A `tags` list — on a recipe or on an ingredient — holds names only, resolved against that
  side's vocabulary. The colour lives with the tag, once.
- Line: `<amount> [unit] <ingredient>` with optional mark ` (base)` or ` (optional)`, 
  never both ([ADR 06](adr/06-base-spirit-on-the-line.md)). Amount: decimal or range `a-b`. 
  Unit: optional, resolves against vocabulary (name or plural), omitted = `part` (FR-REC-2). 
  Writer emits singular for 1, plural otherwise. Accepts input plurals. Unknown units reported.
- Alternatives on a line: `/`-separated, spaces optional on input, written back as ` / ` 
  ([ADR 11](adr/11-substitutions-on-the-line.md), FR-REC-9). Split is lexical — after the unit, 
  after the mark — so one amount, unit and mark govern the group and no reading depends on the 
  vocabulary. `/` barred from every ingredient spelling; a name repeated on one line reported.
- `made`: ISO date `YYYY-MM-DD` and count. Absent = never made.
- References must resolve to matching vocabulary; names unique within kind ([ADR 08](adr/08-names-ignore-case.md)). 
  Spelling preserved.
- Value rules (FR-DAT-4): names non-empty, single-line, no surrounding whitespace; 
  amounts positive, range ends ordered; times ≥ 1; no duplicate tags.
- Unknown keys reported as structural errors (FR-DAT-4).
- App writes canonical form (fixed order, indentation, no comments). FR-DAT-5 covers content only.
- Tokens declared as enum fields (stock, display, mark, colour), not Dart identifiers (ADR 09).
- Format 1 only; future bumps migrate on import.
- FR-DAT-5: hand-written `1.50 2 dash 1 gin` normalises to `1.5 2 dashes 1 part gin`. 
  Byte-identical from app's output onward.
- Custom canonical emitter spec'd here, pinned by round-trip tests.
- Validation failures report YAML line and offending value.

## Domain computations

- **Availability** (required lines only): all `in` = makeable; none `out` but some `low` = makeable-low; 
  any `out` = missing. A line stands at its best-stocked alternative (`stockOfLine`, FR-REC-9). 
  Derived provider, never stored. Lost bottles read as `out`.
- **Optimizer** (FR-DIS-6): collect `out` ingredients from each missing recipe; keep sets ≤ N. 
  Score candidate purchases by recipes becoming can-make. Zero-yield dropped.
- **Line parsing**: shared parser/formatter, both routes (form, codec); takes unit vocabulary 
  (decides unit vs. name). Codec reads `units` first.
- **Display transforms** (FR-REC-7, FR-SET-1): factor multiplies amounts (range ends together); 
  part converts at `part_ml` if reading ml. ×1 in parts = canonical line. Rounded to 2 decimals.

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

- **Unit tests** (pure Dart, no device): availability, grouping, optimizer, validation, 
  YAML round-trip (FR-DAT-5).
- **Integration tests**: atomic write, backup rotation, corrupt-file recovery.
- **Widget tests**: recipe form, stock toggle, import confirmation, list search and filtering.
- CI: format check, `flutter analyze`, test suite, local APK build on every push.
