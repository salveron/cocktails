# Architecture

Technical design for the pilot defined in [requirements.md](requirements.md); direction in
[vision.md](vision.md). Decision rationale lives in the [ADRs](adr/); this document records
the resulting design at system level, [components.md](components.md) at module level.

## Technology stack

- **Flutter (Dart)** targeting Android; desktop later ([ADR 01](adr/01-technology-stack.md)).
- **Riverpod** for state management ([ADR 03](adr/03-app-structure-and-state.md)).
- Development: Linux + physical Android phone over USB.
- Minimal dependencies: `flutter_riverpod`, `yaml`, `path_provider`, `share_plus`, `file_selector`. 
  Riverpod at 2.x (3.x adds unused packages). `scrollable_positioned_list` is the first taken for 
  ergonomics rather than structure ([ADR 13](adr/13-lists-scroll-by-index.md)), and the bar it sets 
  for the next: confined to one file, with the way out written down. `font_awesome_flutter` is the 
  next, taken under that bar ([ADR 14](adr/14-the-dice-comes-off-font-awesome.md)) — by caret where 
  the other is pinned, a package that still releases being the safer for keeping up with.

## System overview

Offline app: entire database in memory, one YAML file byte-identical to export 
([ADR 02](adr/02-persistence-and-export-format.md)).

- Export: file copy. Import: validate, auto-export state, atomically replace.
- Names are identity; recipes reference by name, case-insensitive ([ADR 08](adr/08-names-ignore-case.md)).
- Writes atomic (temp→rename); rolling backups.
- Single-writer (guest access read-only).

## Layers

Three layers ([ADR 03](adr/03-app-structure-and-state.md)):

- **Domain** — pure Dart: entities, availability, discovery, optimizer, validation. Search and 
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
  oz_ml: 29.5735       # and one ounce; ml is the anchor, so it needs none (ADR 17)
  display: part        # part | ml | oz — what the three read in

units:                                 # yours to manage (ADR 09)
  - {name: part, plural: parts}
  - {name: ml}                         # plural omitted = reads like the name
  - {name: oz}                         # fixed, like the two above (ADR 17)
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
  Present = whole vocabulary. All spellings unique under fold; `part`/`ml`/`oz` required.
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
- **Base spirit** (FR-DIS-4, [ADR 12](adr/12-base-spirit-narrows.md)): a predicate, not a placement. 
  Every alternative of every base line counts, so a group matches under each bottle it names; the 
  spirits offered are read off the recipes, deduped by name key and read A→Z.
- **Random pick** (FR-DIS-5): drawn from the rows on show, so every narrowing already holds; 
  `canMake` is the one reading of what counts (low does, unjudged does not), shared with the 
  optimizer below. The draw moves off the recipe already standing while another can be made, so a 
  second roll always answers differently.
- **Optimizer** (FR-DIS-6, [ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md)): a missing 
  recipe's gap is not one set of bottles but a choice between several — any one alternative of a 
  group closes its line (ADR 11) — so the ways of making it are the cross product over the lines it 
  is short of, cut at N. The bottles worth weighing are exactly those gaps', and every basket of ≤ N 
  drawn from them is scored by the recipes some part of it closes. A basket must beat each of its 
  own smaller selves, or it *is* one of them carrying a passenger; a sub-basket's recipes being 
  always a subset, comparing counts settles it. Ranked by recipes unlocked, then fewest bottles, 
  then A→Z. Zero-yield never arises — it cannot beat its own parts. What counts as short is the 
  one thing the reader sets ([ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md)): out of 
  stock, or anything short of full stock, which is what puts the bottles running low in the pool. 
  Keeping the best few *of each size* is also what makes one search answer every budget, since the 
  bottles a wider one adds close nothing on their own ([components.md](components.md#computations)).
- **Line parsing**: shared parser/formatter, both routes (form, codec); takes unit vocabulary 
  (decides unit vs. name). Codec reads `units` first.
- **Display transforms** (FR-REC-7, FR-SET-1): factor multiplies amounts (range ends together); 
  a line in one fixed unit converts into the one `display` names, through the two ml sizes 
  ([ADR 17](adr/17-the-fixed-units-interconvert.md)). ×1 in the settings' own unit = the card at 
  rest. Rounded to 2 decimals.

## Platform facts

- Store/backups: app-private directory. `cocktails.yaml` (store), `cocktails.backup-1/2/3.yaml`, 
  `cocktails-export.yaml` (shareable copy, encoded from the model on screen), 
  `cocktails-before-import.yaml` (what an import replaced, FR-DAT-3). Writes via `.tmp` + rename.
- The copy leaves through the Android share sheet, over the `FileProvider` `share_plus` ships 
  ([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)); the plugin re-copies it into 
  `cacheDir/share_plus/`, so the receiving app sees the basename above. No manifest entry is ours.
- A file comes back through `ACTION_OPEN_DOCUMENT` on `file_selector`, so no layer here holds a 
  `content://` URI. The Android plugin answers with an `XFile.fromData` — the bytes, not a path to 
  them — and `XFile.readAsString` **drops the encoding asked of it** on that branch, decoding byte 
  per character; `Orange Curaçao` came back `Orange CuraÃ§ao`. The pick seam reads the bytes and 
  decodes UTF-8 itself, and malformed input is refused rather than substituted, a U+FFFD being the 
  same loss made quieter. The pre-import copy is reachable only through Android Auto Backup: nothing 
  in the app reads it back.
- Android Auto Backup enabled.
- Application ID: `dev.salveron.cocktails`.
- Minimum Android: Flutter's own default, taken as it moves (minSdk 24 today).
- UI: English only.

## Build & distribution

- APK built locally, sideloaded; no Play Store in pilot.
- Keystore outside repo. Play Store later without rework.

## Testing

- **Unit tests** (pure Dart, no device): availability, discovery, optimizer, validation, 
  YAML round-trip (FR-DAT-5).
- **Integration tests**: atomic write, backup rotation, corrupt-file recovery.
- **Widget tests**: recipe form, stock toggle, import confirmation, list search and filtering.
- CI: format check, `flutter analyze`, test suite, local APK build on every push.
