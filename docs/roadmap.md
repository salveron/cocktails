# Roadmap — pilot

Milestones in dependency order, one commit + tests each. Scope in [requirements.md](requirements.md); 
design in [architecture.md](architecture.md), [components.md](components.md) and 
[ui-design.md](ui-design.md), rationale in the [ADRs](adr/). An entry says what a milestone did and 
where the fact now lives — it is a record of the order the work went in, not a second home for any 
of it. Domain: unit tests; UI: widget tests per strategy.

## Phase 0 — Foundation

Horizontal groundwork every feature depends on; strictly ordered.

- [x] **M1 Scaffold** — Flutter project, Android target, application ID, `flutter_lints`,
      `.gitignore`, directories per the [module map](components.md#module-map).
- [x] **M2 CI** — GitHub Actions workflow: format check, `flutter analyze`, tests on push.
- [x] **M3 Domain model** — entities (ingredient, tag, recipe, settings) and the model
      root with unique-name invariants.
- [x] **M4 Line parser/formatter** — the compact-line grammar with round-trip tests; the
      single shared home later used by the codec (M6) and the recipe form (M14).
- [x] **M5 Model validation** — referential integrity, duplicate names, malformed values:
      the rule set behind FR-DAT-4 and the recipe form.
- [x] **M5a Domain packaging** — [module boundaries](components.md#boundary-rules), 
      [validation contract](adr/05-validation-contract.md), barrel + `src/` internals, 
      `helpers.dart`, wire tokens on enums, architecture test, validation order documented.
- [x] **M6 YAML codec** — parse + validate with line-position errors, canonical emitter,
      format-version gate, lossless round-trip test. (FR-DAT-2/4/5 core)
- [x] **M7 Storage adapter** — storage interface + file adapter: load at start, atomic
      save, backup rotation, corrupt/missing-file handling; temp-dir integration tests.
- [x] **M7a Model edit API** — [`ModelEdits`](components.md#editing-the-model): `copyWith`, 
      pure derivations (rename, "made it"), memoised lookups, FR-VOC-1 delete blocking.
- [x] **M8 State wiring** — Riverpod model provider, mutations persisting through M7,
      startup load.
- [x] **M9 App shell** — navigation between placeholder screens, theme, empty states.

## Phase 1 — Inventory & vocabularies

First usable slice; recipes reference both vocabularies, so this precedes Phase 2.

- [x] **M10 Inventory screen** — ingredient list, name search, single-tap stock toggle
      (FR-INV-1/2); stock-toggle widget test.
- [x] **M10a Base spirit on the line** — [ADR 06](adr/06-base-spirit-on-the-line.md): one 
      `LineMark?` per line (base and optional mutually exclusive, FR-REC-8), ` (base)` suffix, 
      FR-VOC-2 retired, FR-DIS-4, FR-DAT-1.
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
- [x] **M16a Names ignore case, entry made forgiving** — [ADR 08](adr/08-names-ignore-case.md): 
      folded comparison (no duplicate "gin"/"Gin"), grammar takes omitted unit as `part`, 
      plural accepted, form keeps one empty line, notes open one line, dimmed hints.
- [x] **M17 Scaling & unit display** — `displayRecipeLine`: amounts multiply (range ends together), 
      part converts at `part_ml` (FR-REC-7, FR-SET-1). Dialog per card only; recipe/file/settings 
      unchanged. Name row shows "(×2, ml)", measures italic. `formatRecipeLine` canonical form.

## Phase 3 — Discovery

- [x] **M17a Sorting** — multiple orders per list (FR-DIS-8): recipes by availability, 
      inventory by stock, tags by colour; A→Z tie-break. `VocabularyList` label → rank map; 
      picking current reverses. Icon toggles chip row. Screen state only (not persisted).
- [x] **M17b Unit vocabulary** — [ADR 09](adr/09-units-are-a-vocabulary.md): `units:` section 
      with plural per entry, `RecipeLine.unit` resolved as name, `part`/`ml` fixed (FR-VOC-5). 
      Grammar respects vocabulary; plural for amounts ≠ 1. `withUnits` propagates renames. Shape only.
- [x] **M17c Units screen** — Settings → Units: edit in place, one Save, delete blocked while used, 
      `part`/`ml` locked (FR-VOC-5). Validated by `validateModel` (import rules match). 
      `setUnits` whole vocabulary, renames included, one write.
- [x] **M17d Ingredient aliases** — [ADR 10](adr/10-ingredient-aliases.md), FR-VOC-6: 
      `Ingredient.aliases`, comma-separated, resolved form/search/file, stored under entry's name. 
      Uniqueness: all spellings. `ingredientNamed` indexes all; `withCanonicalIngredientNames` 
      resolves (codec, `upsertRecipe` share it).
- [x] **M18 Filters** — recipe list chip row (FR-DIS-3): tag filter like inventory. `tagFilter` 
      shared, reads live vocabulary (renames/deletes update). Ingredients via search not filter 
      (recipe answers to bottle spellings, FR-DIS-2); availability via order not filter (FR-DIS-8).
- [x] **M18a Ingredient substitutions** — [ADR 11](adr/11-substitutions-on-the-line.md), FR-REC-9: 
      `RecipeLine.ingredients` never-empty list (no singular). Grammar splits on `/` after unit/mark; 
      one amount/unit/mark govern group. `stockOfLine` reads best; card dims what lacks while holding 
      one. Cards read "or", file reads `/`, form keeps separator. `displayMeasure` replaces split body.
- [x] **M19 Base spirit narrows** — [ADR 12](adr/12-base-spirit-narrows.md): filter not grouping 
      (base predicate, not placement; ADR 11 dissolves). `discovery.dart`: `basesOf`, `baseSpirits`, 
      `marksBase`. Chip reads `Base: Any`/`Gin`/`None`; leads filter row with `tagFilter`. 
      `neutralSwatch` for non-signal meaning. Stale pick stops narrowing.
- [x] **M20 Random pick** — one draw of makeable recipe (FR-DIS-5): dice button, draws from 
      list on show. `canMake` lands in `availability.dart` (low counts). `randomCanMake` over 
      candidates, skips current. `scrollable_positioned_list` by index [ADR 13](adr/13-lists-scroll-by-index.md). 
      Card washes (colour alone). Dice is Font Awesome pair [ADR 14](adr/14-the-dice-comes-off-font-awesome.md). 
      Empty case: "nothing makeable" message.
- [x] **M21 Optimizer domain** — [ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md), FR-DIS-6: 
      `purchasesWithin`, `Purchase` (bottles + unlocked recipes). Gap = choice among alternatives 
      (ADR 11), cross product over short lines. Best few of each size, the cost pinned by a 
      performance test. `Model.bottleNamed` unified lookup.
- [x] **M21a Restocking widens the search** — [ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md), 
      FR-DIS-7: `restocking` flag. Off: out only; on: short of full stock (low joins pool, goal = ready). 
      One flag, one place (`_gapsOf`). `canMake` unchanged.
- [x] **M22 Optimizer screen** — budget selector, ranked baskets (FR-DIS-6/7, [ui-design.md](ui-design.md#shopping-screen)). 
      Budget picks exactly N (ADR 15 shelf-per-size). One search at max budget, read size off answer. 
      Card reused (title, bottles, count). Stock dots. Empty states. `autoDispose` and a screen told 
      whether it is on show, so the one costly search runs for no one else. `Wrap` for wrap at narrow 
      widths (tested 320/360).

## Phase 4 — Settings & data exchange

- [x] **M23 The fixed units interconvert** — [ADR 17](adr/17-the-fixed-units-interconvert.md), FR-SET-1: 
      `oz` joins `part`/`ml` as reserved. `FixedUnit` for both reserved names and `display` choice. 
      `Settings` holds ml per unit (`oz_ml` new). Ratio derived. Format stays `1`. Shape only.
- [x] **M23a Amounts screen** — Settings screen (FR-SET-1, [ui-design.md](ui-design.md#amounts)): 
      global unit picked, two ratios. Ml never leads (0.0333 problem); each row leads with unit it sizes. 
      First row = part worth, second = ounce (redefine part, ounce stays). Pick rewrites readings, not 
      sizes. `Settings.ratio`/`withRatio`. Validation: ratio > 0. "Scale" menu heading.
- [x] **M24 Export** — system share sheet (FR-DAT-1, [ui-design.md](ui-design.md#data), 
      [ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)). `share_plus`/`file_selector` via 
      `XFile`. `sharerProvider` is seam. MIME: `text/plain`. `exportSnapshot` takes model 
      (Corrupt-safe). On Settings list. `_Entry` two constructors (action vs travel).
- [x] **M25 Import** — [ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md), FR-DAT-3/4: 
      `filePickerProvider`, no type filter, answers with text. Screen shows file contents, Replace button 
      or issues. Counts = identity (no filename). Safety copy: `cocktails-before-import.yaml` 
      (`ExportPurpose`). `review` pure. Replace leaves for collection.
- [x] **M25a The counts open, and the diacritics survive** — UTF-8 fix: `XFile.readAsString` 
      drops encoding; `pickedText` decodes bytes (test via plugin-built `XFile`). 
      [architecture.md](architecture.md#platform-facts) recorded. Counts open per kind; tapped card 
      shows all names (nothing cut, full list). Kinds named/ordered per managing screen; tag vocabs 
      share count, own runs ([ADR 07](adr/07-tag-colour.md)). Accept on app bar.

## Phase 5 — The basket, and reaching across screens

- [x] **M26 The basket card re-reads** — [ui-design.md](ui-design.md#shopping-screen): title 
      `Shopping Cart #N`, bottles in subtitle (clipped closed), body becomes `BulletRuns` (import 
      review idiom). `BulletRuns` in `vocabulary_list.dart`. Count trails in neutral (no chip). 
      Ranked by count. Open card remembered by bottles. UI only.
- [x] **M27 The baskets narrow to a category** — FR-DIS-10, [ui-design.md](ui-design.md#shopping-screen): 
      `tagFilter` row under controls. Basket answers to tags of recipes it unlocks. Ranked among 
      size (`#1, #4, #7`). Empty state names picks as cause. Open basket marks answered recipes 
      with picked tags. `TagDots` (from `DottedName`). UI only; search not re-run per pick.
- [x] **M28 A destination sends the reader to another** — FR-DIS-9, [ADR 19](adr/19-a-destination-sends-the-reader-to-another.md): 
      basket's recipes → Recipes; basket's/line's bottles → Inventory. `lib/ui/destinations.dart` 
      holds enum + `revealProvider` (destination + name). Gesture: plain tap (reaches name most 
      common). No arrow (slot used for tags/stock dots). Line reaches per bottle (ADR 11). Back 
      undoes jumps one at a time. `VocabularyList` reveal + draw same frame [ADR 13](adr/13-lists-scroll-by-index.md).

## Phase 6 — Release

- [ ] **M29 Release packaging** — signing configuration (keystore outside the repo),
      Android Auto Backup enabled, launcher icon and label, version 1.0.0.
