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
  addition, not a reflex.

## System overview

A single offline app. The entire database — vocabularies, stock levels, recipes with
made-history, settings — is held in memory and persisted as one YAML file that is
byte-identical to the export format ([ADR 02](adr/02-persistence-and-export-format.md)).

- Export shares a copy of the store file; import validates a candidate file, auto-exports
  the current state (FR-DAT-3), then atomically replaces the store.
- Names are identity throughout: recipes reference ingredients and tags by name, and a
  vocabulary rename (FR-VOC-1) is one model mutation that rewrites every reference before
  the single save.
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
  - {name: bourbon, base: true, stock: in}
  - {name: lemon juice, stock: low}
  - {name: rich demerara syrup}        # stock omitted = out
  - {name: egg white, stock: in}

tags: [sour, classic]

recipes:
  - name: Whiskey Sour
    tags: [sour, classic]
    lines:
      - 1.5-2 part bourbon
      - 0.75 part lemon juice
      - 0.5 part rich demerara syrup
      - 0.5 part egg white (optional)
    notes: dry shake, then shake with ice
    made: {last: 2026-07-18, times: 12}
```

Rules:

- `format` is the schema version; imports of unsupported versions are rejected (FR-DAT-4).
- Ingredient entries: `name` required; `base` (default `false`) marks a base spirit; `stock`
  is `in` | `low` | `out` (default `out`).
- An ingredient line is `<amount> <unit> <ingredient name>`, optionally suffixed
  ` (optional)`. Amount is a decimal number or a range `a-b`; unit is one of
  `part ml oz dash barspoon drop piece` and is stored as entered. The ` (optional)` suffix
  is reserved — ingredient names cannot end with it.
- `made` holds the made-history: `last` is an ISO date string, `times` a count. Absent =
  never made.
- Every recipe line and tag reference must resolve to the vocabularies; names are unique
  within their kind (FR-DAT-4 validation).
- Value rules (FR-DAT-4): names are non-empty, single-line, without surrounding
  whitespace; amounts are positive with range ends in order; `part_ml` is positive;
  `times` is at least 1; a recipe's tag list has no repeats.
- The app writes a canonical form: fixed key order, fixed indentation, no comments. Comments
  are legal in imported files but are not preserved once the app rewrites the store —
  the round-trip guarantee (FR-DAT-5) covers content, not comments.
- Unit and stock tokens are declared as fields on their enums, never derived from Dart
  identifier spellings, so renaming a member cannot change the format.
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

## Project layout

One folder per layer under `lib/` — `domain/` (pure Dart entities and computations), `data/`
(storage interface and YAML file adapter), `state/` (Riverpod providers), `ui/` (screens and
widgets) — each exposing a barrel file over its `src/` internals. `test/` mirrors `lib/`.
The full structure and the boundary rules are in [components.md](components.md).

## Platform facts

- Store file and rotated backups live in the app-private documents directory; export goes
  through the Android share sheet, import through the system file picker (FR-DAT-1/3).
- Android Auto Backup stays enabled: the store and its backups (kilobytes, far under the
  25 MB quota) ride the phone's normal Google backup, so device loss or reset does not mean
  data loss. Manual export remains the explicit, user-controlled off-device copy.
- Application ID: `dev.salveron.cocktails` (permanent once installed).
- Minimum Android version: Flutter's current default (minSdk 21+); no device features used
  beyond file storage and sharing.
- UI language is English; no i18n framework in the pilot.

## Build & distribution

- Release APK built locally and sideloaded (USB or file share); no store presence in the pilot.
- The APK is signed with a locally kept keystore; the keystore and its credentials are backed
  up outside the repo — losing it means reinstalling instead of updating in place.
- A Play Store track remains possible later without rework (new listing, same codebase).

## Repository, CI & testing

- The repo lives on GitHub (private); GitHub Actions runs the format check, `flutter analyze`,
  and the test suite on every push. APKs are built and signed locally, not in CI.
- Unit tests (pure Dart, no device) are the backbone and cover the domain layer: availability
  computation, filtering/grouping, the optimizer, import validation, and the YAML codec's
  lossless round-trip (FR-DAT-5 is a test, not a hope).
- The storage adapter is integration-tested against temp files (atomic write, backup
  rotation, corrupt-file recovery).
- Widget tests cover the critical flows only (recipe form, stock toggle, import
  confirmation); everything else is verified manually on the device.

## Decision records

- [01 — Technology stack](adr/01-technology-stack.md) — Flutter (Dart), Android pilot target
- [02 — Persistence and export format](adr/02-persistence-and-export-format.md) — in-memory
  model, single YAML store file identical to the export format
- [03 — App structure and state management](adr/03-app-structure-and-state.md) — three
  layers, Riverpod
- [04 — Module boundaries and public surface](adr/04-module-boundaries.md) — layer barrels
  over `src/`, boundaries enforced by a test, declared wire tokens
