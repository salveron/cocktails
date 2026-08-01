# Roadmap — pilot

Implementation milestones in dependency order, one commit each. Scope and acceptance
criteria live in [requirements.md](requirements.md), the design in
[architecture.md](architecture.md); milestones reference both instead of restating them.
Development-machine setup is out of scope — every milestone is repo content only.

**Conventions:** One milestone = one commit with tests. Green on `flutter analyze`, test suite.
Domain: pure Dart + unit tests. Widget tests per [strategy](architecture.md#testing).

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
- [x] **M9 App shell** — navigation between placeholder screens, theme, empty states.

## Phase 1 — Inventory & vocabularies

First usable slice; recipes reference both vocabularies, so this precedes Phase 2.

- [x] **M10 Inventory screen** — ingredient list, name search, single-tap stock toggle
      (FR-INV-1/2); stock-toggle widget test.
- [x] **M10a Base spirit on the line** — base-ness moved from the ingredient to the recipe
      line ([ADR 06](adr/06-base-spirit-on-the-line.md)): one `LineMark?` per line, so base
      and optional cannot combine (FR-REC-8), a ` (base)` suffix in the line grammar, and the
      requirement edits it forced (FR-VOC-2 retired, FR-DIS-4, FR-DAT-1).
- [x] **M11 Ingredient management** — add, rename with propagation, reference-blocked
      delete (FR-VOC-1) on the inventory screen, through the two shared
      [vocabulary dialogs](ui-design.md#vocabulary-editing) M12 reuses.
- [x] **M11a Tag colour** — a tag carries a colour from a closed palette
      ([ADR 07](adr/07-tag-colour.md)): `TagColor` with declared tokens, `Tag.color` defaulting
      to neutral and surviving a rename, and the tag entry becoming a mapping like the
      ingredient entry (FR-VOC-3). Shape only — the picker is M12's.
- [x] **M11b Ingredient tags** — the second tag vocabulary, decided before any screen was built
      on the first ([ADR 07](adr/07-tag-colour.md), amended): `recipe_tags` and `ingredient_tags`
      as peer sections behind `Model.recipeTags`/`ingredientTags`, `Ingredient.tags`, a colour
      now required on every tag (`neutral` dropped), per-vocabulary rename propagation and
      delete blocking (FR-VOC-3/4, FR-INV-3). Shape only — both screens are M12's and M12a's.
- [x] **M12 Tag management** — both vocabularies behind Settings, a tab each: add, rename with
      propagation, reference-blocked delete (FR-VOC-1), and the colour, picked in the same
      dialog as the name on create and on edit alike (FR-VOC-3). Extracts the vocabulary list
      the inventory screen already was, so all three lists are one widget, and lands the
      token → swatch map in `palette.dart` beside the stock colours it now shares a shape with.
- [x] **M12a Ingredient tags on the inventory screen** — a borderless colour dot per tag after
      the ingredient's name, and a filter-chip row under the search that doubles as the legend
      for those dots: picking narrows to the bottles wearing every picked tag, combining with
      the name search (FR-INV-3). Tags are settled in the entry dialog beside the name, on the
      add and the edit alike, so `VocabularyList` gains the one filter slot the recipe list
      (M18) will use next.

## Phase 2 — Recipes

- [x] **M13 Recipe list & view** — read-only: the recipe list joins the shared searchable
      list (FR-DIS-2), each recipe a card expanding in place from name + tag dots +
      ingredient summary to the full view — chips, the lines as the file writes them,
      notes, made-history. No pushed view: the view is the expanded card.
- [x] **M14 Recipe form** — create, edit, delete via the shared line parser and tag picker,
      per-line base and optional marks (FR-REC-1..5/8); recipe-form widget test.
- [x] **M15 Made it** — the action closing the expanded card: the history it stamps, the Undo that
      stamp leaves behind, and the long-press reset (FR-REC-6, amended for both ways back). One
      domain writer, `withRecipeHistory`, serves the stamp, the undo and the reset alike.
- [x] **M16 Availability** — `availabilityOf` over required lines only and the `availabilityProvider`
      derived from it, the Ready/Low/Missing chip beside each row's ⋮, and a stock dot on every open
      line that is low or out (FR-DIS-1). FR-REC-2 gains the rule the verdict rests on — a recipe
      carries at least one line that is not optional — enforced by `validateRecipe`, so the form and
      an imported file refuse it alike.
- [x] **M16a Names ignore case, entry made forgiving** — quality of life across the recipe form and
      the domain under it: names compare through one fold, so "gin" typed against "Gin" is that
      bottle and no vocabulary can hold both ([ADR 08](adr/08-names-ignore-case.md)); the line
      grammar takes an omitted unit as `part` and a plural one as itself (FR-REC-2), while the
      writer still emits the full singular form; the form keeps one empty line rather than two,
      opens notes one line tall, and the theme dims every hint so a placeholder never reads as
      content.
- [x] **M17 Scaling & unit display** — `displayRecipeLine` over a line, a factor and the
      settings: every amount multiplies, both ends of a range together, and a part-based one
      converts at `part_ml` where the reading asks for ml (FR-REC-7; display half of FR-SET-1).
      Behind the recipe card's ⋮, one dialog settles both for that card alone and for as long
      as it stays open — the name row says "(×2, ml)", each line's measure turns italic, and
      the recipe, the file and the global setting stand untouched. `formatRecipeLine` splits
      into the two halves both paths now compose, so ×1 in parts is the canonical line again.

- [x] **M17a Sorting** — every list reads in more than one order (FR-DIS-8): the recipes by
      availability, the inventory by stock, both tag vocabularies by colour, each against the
      A→Z that is also every order's tie-break. `VocabularyList` takes them as a label → rank
      map, first the one the list opens in, and picking the one in force turns the whole list
      round — so "missing first" and Z→A need no chips of their own. One icon beside the search
      opens the chips and shuts them again; the order it settled stands either way. A list is
      re-placed only where the rows on show change or another order is picked, so a bottle never
      moves under the tap emptying it. Screen state, like the filters — nothing reaches the file.

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
