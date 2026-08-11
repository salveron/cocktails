# Roadmap

Milestones in dependency order, one commit + tests each. Scope in [requirements.md](requirements.md); 
design in [architecture.md](architecture.md), [components.md](components.md) and 
[ui-design.md](ui-design.md), rationale in the [ADRs](adr/). An entry says what a milestone did and 
where the fact now lives — it is a record of the order the work went in, not a second home for any 
of it. Domain: unit tests; UI: widget tests per strategy. Phases 0–6 are the pilot — one collection, 
one reader, nothing leaving the device but a file; Phase 7 onward is what FR-BAR-1..9 asks for.

## Phase 0 — Foundation

Horizontal groundwork every feature depends on; strictly ordered.

- [x] **M1 Scaffold** — Flutter project, Android target, application ID, `flutter_lints`,
      `.gitignore`, directories per the [module map](components.md#module-map).
- [x] **M2 CI** — GitHub Actions workflow: format check, `flutter analyze`, tests on push.
- [x] **M3 Domain model** — entities (ingredient, tag, recipe, settings) and the collection
      root with unique-name invariants.
- [x] **M4 Line parser/formatter** — the compact-line grammar with round-trip tests; the
      single shared home later used by the codec (M6) and the recipe form (M14).
- [x] **M5 Collection validation** — referential integrity, duplicate names, malformed values:
      the rule set behind FR-DAT-4 and the recipe form.
- [x] **M5a Domain packaging** — [module boundaries](components.md#boundary-rules), 
      [validation contract](adr/05-validation-contract.md), barrel + `src/` internals, 
      `names.dart`, wire tokens on enums, architecture test, validation order documented.
- [x] **M6 YAML codec** — parse + validate with line-position errors, canonical emitter,
      format-version gate, lossless round-trip test. (FR-DAT-2/4/5 core)
- [x] **M7 Storage adapter** — storage interface + file adapter: load at start, atomic
      save, backup rotation, corrupt/missing-file handling; temp-dir integration tests.
- [x] **M7a Collection edit API** — [`CollectionEdits`](components.md#editing-the-collection): `copyWith`, 
      pure derivations (rename, "made it"), memoised lookups, FR-VOC-1 delete blocking.
- [x] **M8 State wiring** — Riverpod collection provider, mutations persisting through M7,
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
      as peer sections behind `Collection.recipeTags`/`ingredientTags`, `Ingredient.tags`, a colour
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
      `part`/`ml` locked (FR-VOC-5). Validated by `validateCollection` (import rules match). 
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
      performance test. `Collection.bottleNamed` unified lookup.
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
      `XFile`. `sharerProvider` is seam. MIME: `text/plain`. `exportSnapshot` takes collection 
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

## Phase 6 — Cleanup & release

What ships as 1.0.0 should carry nothing the product no longer claims.

- [x] **M28a Made it comes out** — FR-REC-6 is retired, so the feature left rather than hid: the
      made row and its button, the history text, the Undo and the long-press reset, `MadeHistory`,
      `Recipe.made` and `stamped`, `withRecipeMade` and `withRecipeHistory`, `timesBelowOne`, and
      the `made:` the writer emitted. The reader goes on accepting that key and ignoring it,
      whatever it holds — the rule format 1 keeps for good
      ([ADR 21](adr/21-the-file-carries-one-bar.md)) — so a collection already on a device loses its
      stamps and nothing else, and the version waits for the bump that has something to add (M31).
      `clockProvider` went with it, the app having nothing left to ask the time of until a refresh
      does (M36). The test harness reads an open card off the row's own body, the button having been
      what said so before.
- [x] **M28b The test suite reads once** — the suite was sound but said some things twice, so the
      copies went and the rules they proved stayed. Four enum-token groups became one
      `tokenVocabulary` body run over each, and the eight equality pairs one `valueEquality` table;
      every `copyWith` case now names its field in a `reason`, so a broken `==` says which one it
      stopped reading rather than printing two objects to be compared by eye. A matching table for
      `copyWith` was tried and dropped: each case has to spell both sides out whatever wraps it, so
      the wrapper bought a test name six times over and cost a layer of parens at every case.
      `validation_test`'s trailing `issue kinds` group went — every kind it asserted now sits with
      the test already owning that rule's path and message. `screens_test.dart` moved to
      `screens/settings_screen_test.dart`, the name the other six screens use, and a docstring
      stranded on the wrong declaration went back to `scale`. What earns a test at all is written
      down for the first time, in [components.md](components.md#what-earns-a-test). The shared
      `VocabularyList` keeps being proven through the screens that draw it rather than on its own:
      its mechanics read differently per screen, and moving them off would leave a mis-wired list
      with nothing watching. The suite came out 19 lines shorter — the point was one home per rule,
      not fewer lines, and the parametrised bodies cost about what the copies did.
- [x] **M28c The type takes the noun the documents use** — `Model` became `Collection`, which is what
      every document already called it: [requirements](requirements.md)' glossary defines a bar as
      "one collection", and [components.md](components.md#the-shelf-and-the-bar)'s signatures were
      written `Model collection` — `BarPayload`, `withCollection`, `opening`, `offer` — before a line
      of Phase 7 existed. Read down the tiers, `Shelf`, `Bar`, `Model`, `Recipe` named three things
      in a bar and one thing in an architecture. Carried with it: `collection.dart`,
      `collection_edits.dart` and `CollectionEdits`, `validateCollection`, `collectionProvider`,
      `CollectionView`, `Loaded.collection`, the `architecture_test` paths naming the file, and every
      fixture. `helpers.dart` became `names.dart`, which is all it ever held. Left alone on purpose:
      `ModelStore`, `ModelController` and `ModelParts`, which M31 and M32 replace outright with
      `BarStore`, `ShelfController` and `BarPayload` — renaming them here would be a second edit to
      lines already scheduled for deletion, and the two milestones of `ModelStore` holding a
      `Collection` are the price. One collision surfaced and was worth having: `optimizer_test`'s
      builder was `model` where its locals were already `collection`, so it became `collectionOf`,
      the name the store test had reached for independently. Reverses
      [ADR 20](adr/20-the-app-holds-many-bars.md), amended in place rather than superseded: cost was
      the whole of its argument, the cost only grew from here, and nothing had been built on it.
- [ ] **M29 Release packaging** — signing configuration (keystore outside the repo),
      Android Auto Backup enabled, launcher icon and label, version 1.0.0.

## Phase 7 — The app holds many bars

The root moves above `Collection` and every layer follows it up. Nothing travels between devices yet: a
guest bar is built as a shape here and gets its first source in Phase 8.

- [ ] **M30 Shelf domain** — [ADR 20](adr/20-the-app-holds-many-bars.md): `Bar`, `BarMode`,
      `Transport`, `BarSource`, `Offer`, `BarPayload`, and `Shelf` over them, keeping the
      constructor contract `Collection`'s own already does — ids unique, `openId` naming a bar that
      exists, a guest carrying a source and an owner none. `ShelfEdits` beside `CollectionEdits`, with
      `withCollection` refusing a guest bar ([ADR 23](adr/23-nothing-writes-a-guest-bar.md)), and
      `validateShelf` reading the index's parts through the kinds that already exist. Shape only —
      nothing above the domain knows yet.
- [ ] **M31 One file per bar** — `BarStore` replaces `ModelStore`: `shelf.yaml` and `bars/<id>.yaml`,
      atomic writes and rotation per bar, `removeBar`, and `beforeDelete` joining `ExportPurpose`.
      Format 2 lands whole ([ADR 21](adr/21-the-file-carries-one-bar.md)) — `name:` at the top,
      format 1 read and written back as 2 — and the device's own `cocktails.yaml` migrates through
      that same one route to become the first owned bar, its old files left standing as the net
      ([architecture.md](architecture.md#storage-isolation)). Pinned by integration test: one bar's
      save leaves every other bar's bytes exactly as they were.
- [ ] **M32 The shelf in state** — `ShelfController` replaces `ModelController` and `collectionProvider`
      becomes derived rather than owned, which is what keeps the whole presentation layer still
      while the root moves above it ([components.md](components.md#state-contracts)).
      `openBarProvider` answers the record, `barWriterProvider` the writes — null on a guest bar,
      the same null that will hide a control (ADR 23). Export and import become the open bar's
      (FR-DAT-1/3), every other bar untouched. `test/architecture_test.dart` gains the rule keeping
      `ui/` off the notifier.
- [ ] **M33 The bars screen** — [ui-design.md](ui-design.md#bars): the gear's **Switch bar…**, one
      card a bar, tapped to switch and popped on the way, with rename and delete behind its ⋮ —
      delete confirmed and exported first (FR-BAR-2). An empty shelf is the one time this screen is
      home, offering the two ways to a first bar. The app bar reads "Home bar's Recipes", and the
      shell's subtree is keyed by the open bar, so a crossing takes every search, pick, open card
      and jump trail with it (FR-BAR-1).
- [ ] **M34 A guest bar is read-only** — FR-BAR-3/4 built as shape, before any channel can make one:
      two destinations rather than three, the optimizer absent rather than empty (FR-DIS-6/7/10
      unreachable, so nothing watches `purchasesProvider` at all), and no form, dialog, toggle or
      vocabulary edit offered — refusing nothing, because nothing is on offer. Export still works
      (FR-DAT-1), and Amounts becomes the unit pick alone, the two ml sizes being the owner's and
      arriving with the collection (FR-SET-1).

## Phase 8 — A bar travels by file

- [ ] **M35 The sharing seam** — [ADR 22](adr/22-a-bar-travels-behind-one-seam.md): `BarChannel` and
      the value a fetch answers with — what arrived, what failed the import's own judgement, or that
      the source could not be reached and which of the three. `channelsProvider` resolves the
      transports at the composition root, and the file channel is the first, honestly one method
      wide. `refreshesProvider` lands beside it: the app's first work outliving the gesture that
      started it ([components.md](components.md#work-in-flight)), token and all, so a stale answer
      is dropped rather than landed. No screen yet.
- [ ] **M36 One file, two destinations** — FR-BAR-7: `review` answers a whole `BarPayload`, so one
      picked file either replaces the open owned bar or founds a guest one, the reader choosing
      ([ui-design.md](ui-design.md#data)). Refreshing is being handed a newer file — the swipe down
      on a guest bar's lists (FR-BAR-5) opens the picker, and what comes back is judged as an import
      is before it replaces anything. `clockProvider` returns to stamp when the source answered.
      `RefreshIndicator` meets `ScrollablePositionedList` here
      ([ADR 13](adr/13-lists-scroll-by-index.md)): prove the two sit together before the gesture is
      built on them, and write the way out if they do not.

## Phase 9 — A bar travels over the LAN

- [ ] **M37 An owner offers a bar nearby** — FR-BAR-8, the owner's half: the DNS-SD package chosen
      between `bonsoir` and `nsd`, taken under the ADR 13 bar and named in
      [architecture.md](architecture.md#technology-stack) in this same change, since the test pins
      that list to `pubspec.yaml`. Then the `dart:io` server on an unguessable path, and the
      internet permission — the app's first manifest entry of its own. `sharingProvider` keeps the
      advertisement in step with the shelf, so a device sharing nothing announces nothing (NFR-5),
      and the offer and its withdrawal read on the bar's own card (FR-BAR-6). Integration-tested
      against its own loopback server.
- [ ] **M38 A guest finds one** — FR-BAR-8, the guest's half: browsing the service type as a list
      that fills while devices answer, adding what it finds, and refreshing by GET on the swipe M36
      already built. Two bars of one name are two service instances, told apart by the discriminator
      off the owner's bar id (FR-BAR-1). A source withdrawn, off the network, or with no network at
      all leaves the bar readable as it stood and says which of the three it was (FR-BAR-5).

## Phase 10 — A bar travels over the cloud

- [ ] **M39 The cloud adapter** — FR-BAR-9, with the backend picked when this milestone comes up
      rather than ahead of it: [ADR 22](adr/22-a-bar-travels-behind-one-seam.md) carries the
      options, what each costs this project and a recommendation, and is amended with the choice
      before any code is written. The one identity in the product (NFR-3), the guests an owner names,
      and a refresh from anywhere. The seam and the shape of an offer already stand, so what this
      adds is one adapter and one sign-in.
