# Roadmap — pilot

Implementation milestones in dependency order, one commit each. Scope and acceptance
criteria live in [requirements.md](requirements.md), the design in
[architecture.md](architecture.md); milestones reference both instead of restating them.
Development-machine setup is out of scope — every milestone is repo content only.

**Conventions:** One milestone = one commit with tests. `flutter analyze` and test suite green at every step. Domain as pure Dart + unit tests; widget tests per [strategy](architecture.md#testing).

## Phase 0 — Foundation

Horizontal groundwork every feature depends on; strictly ordered.

- [x] **M1 Scaffold** — Flutter project, Android target, application ID, `flutter_lints`,
      `.gitignore`, directories per the [project layout](architecture.md#project-layout).
- [x] **M2 CI** — GitHub Actions workflow: format check, `flutter analyze`, tests on push.
- [x] **M3 Domain model** — entities (ingredient, tag, recipe, settings) and the model
      root with unique-name invariants.
- [x] **M4 Line parser/formatter** — the compact-line grammar with round-trip tests; the
      single shared home later used by the codec (M6) and the recipe form (M14).
- [x] **M5 Model validation** — referential integrity, duplicate names, malformed values:
      the rule set behind FR-DAT-4 and the recipe form.
- [x] **M5a Domain packaging** — the [module boundaries](components.md#boundary-rules) and the
      [validation contract](adr/05-validation-contract.md) before anything depends on them:
      domain files under `src/` behind a barrel, shared internals in `helpers.dart`, declared
      wire tokens on the enums, `tryParseRecipeLine`, `ValidationIssueKind` and value equality
      on `ValidationIssue`, one validation entry point per editable entity, and the
      architecture test. The only behaviour change: `validateModel` reports issues in the
      documented order.
- [x] **M6 YAML codec** — parse + validate with line-position errors, canonical emitter,
      format-version gate, lossless round-trip test. (FR-DAT-2/4/5 core)
- [x] **M7 Storage adapter** — storage interface + file adapter: load at start, atomic
      save, backup rotation, corrupt/missing-file handling; temp-dir integration tests.
- [x] **M7a Model edit API** — [`ModelEdits`](components.md#editing-the-model): `copyWith` on
      the entities, pure edit derivations including rename propagation and "made it", memoised
      name lookups, and the reference queries behind FR-VOC-1 delete blocking.
- [x] **M8 State wiring** — Riverpod model provider, mutations persisting through M7,
      startup load.
- [ ] **M9 App shell** — navigation between placeholder screens, theme, empty states.

## Phase 1 — Inventory & vocabularies

First usable slice; recipes reference both vocabularies, so this precedes Phase 2.

- [ ] **M10 Inventory screen** — ingredient list, name search, single-tap stock toggle
      (FR-INV-1/2); stock-toggle widget test.
- [ ] **M11 Ingredient management** — add, rename with propagation, reference-blocked
      delete, base-spirit flag (FR-VOC-1/2).
- [ ] **M12 Tag management** — add, rename with propagation, reference-blocked delete
      (FR-VOC-1).

## Phase 2 — Recipes

- [ ] **M13 Recipe list & view** — read-only: list with name search (FR-DIS-2); view with
      lines, tags, notes, made-history.
- [ ] **M14 Recipe form** — create, edit, delete via the shared line parser and tag picker
      (FR-REC-1..5); recipe-form widget test.
- [ ] **M15 Made it** — the action and its stamped display (FR-REC-6).
- [ ] **M16 Availability** — domain computation, derived provider, list badges, per-line
      low/out marks (FR-DIS-1).
- [ ] **M17 Scaling & unit display** — ×2/3/4 scaling and part↔ml display conversion in
      the recipe view (FR-REC-7; display half of FR-SET-1).

## Phase 3 — Discovery

- [ ] **M18 Filters** — by tags, ingredients, availability; combinable (FR-DIS-3).
- [ ] **M19 Base-spirit grouping** — grouped browsing with ungrouped tail section
      (FR-DIS-4).
- [ ] **M20 Random pick** — one can-make suggestion respecting active filters (FR-DIS-5).
- [ ] **M21 Optimizer domain** — combination search and ranking (FR-DIS-6) with a
      performance test at NFR-2 scale.
- [ ] **M22 Optimizer screen** — budget selector, ranked combinations, running-low restock
      reminders (FR-DIS-6/7).

## Phase 4 — Settings & data exchange

- [ ] **M23 Settings screen** — part-to-ml ratio editor and display toggle (FR-SET-1).
- [ ] **M24 Export** — share a copy of the store file via the share sheet (FR-DAT-1).
- [ ] **M25 Import** — file picker, validation report, confirmation with automatic
      pre-import export, atomic replace (FR-DAT-3/4); confirmation-flow widget test.

## Phase 5 — Release

- [ ] **M26 Release packaging** — signing configuration (keystore outside the repo),
      Android Auto Backup enabled, launcher icon and label, version 1.0.0.

## Ordering facts

- **Phase 0:** strictly sequential. Later phases: ordered by value.
- **Hard dependencies:** M16 before M18/M20/M21 (consume availability); M21 before M22.
- **Shape milestones:** M5a blocks M6; M7a blocks M8 and editing screens (M10–12, M14–15).
- **Data exchange:** M24–25 depend only on Phase 0; can move ahead if loading migrated data early.
