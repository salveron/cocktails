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

## Phase 3 — Discovery

- [x] **M17a Sorting** — every list reads in more than one order (FR-DIS-8): the recipes by
      availability, the inventory by stock, both tag vocabularies by colour, each against the
      A→Z that is also every order's tie-break. `VocabularyList` takes them as a label → rank
      map, first the one the list opens in, and picking the one in force turns the whole list
      round — so "missing first" and Z→A need no chips of their own. One icon beside the search
      opens the chips and shuts them again; the order it settled stands either way. A list is
      re-placed only where the rows on show change or another order is picked, so a bottle never
      moves under the tap emptying it. Screen state, like the filters — nothing reaches the file.
- [x] **M17b Unit vocabulary** — units move out of the code and into the file
      ([ADR 09](adr/09-units-are-a-vocabulary.md)): a `units:` section seeded with the seven the app
      shipped, `Unit` an entry carrying a plural, `RecipeLine.unit` a name resolved against it as an
      ingredient name is, and `part`/`ml` fixed members the ratio and the display toggle stay
      anchored to (FR-VOC-5). The grammar takes the vocabulary — it decides what counts as a unit —
      and writes the plural for any amount but exactly 1, so `2 dash` normalises to `2 dashes` where
      it once went the other way. `withUnits` takes the vocabulary whole, propagating renames into
      every line. Shape only — the screen is M17c's.
- [x] **M17c Units screen** — Settings → Units: the rows edited in place, one Save for the screen and
      a discard prompt behind it, an empty bottom row that grows, deletion refused while a line uses
      the unit, `part` and `ml` locked (FR-VOC-5, [ui-design.md](ui-design.md#units)). The rows are
      judged by `validateModel` itself, so the screen refuses exactly what an import would, and
      `setUnits` carries the lot — renames included — to the disk in one write.
- [x] **M17d Ingredient aliases** — a bottle answers to more than one name
      ([ADR 10](adr/10-ingredient-aliases.md), FR-VOC-6): `Ingredient.aliases` behind one
      comma-separated field in the entry dialog, resolved wherever a name resolves — the recipe
      form, the inventory search, a hand-edited file — and always stored under the bottle's own
      name. Uniqueness widens to every spelling, `ingredientNamed` indexes them all, and
      `withCanonicalIngredientNames` is the one derivation putting a line under the bottle it
      names, so the codec and `upsertRecipe` share it and the form resolves nothing itself.
- [x] **M18 Filters** — the recipe list narrows the way the inventory does: a scrolling chip row of
      recipe tags under the search, keeping what wears every one picked and combining with the query
      (FR-DIS-3). The row two screens now share is `tagFilter`, which also reads the picks against the
      live vocabulary, so a tag renamed or deleted elsewhere stops narrowing on both. Ingredients are
      reached through the search rather than filtered: a recipe answers to every spelling of every
      bottle it is built from, aliases included (FR-DIS-2 widened, ADR 10) — hence "answers to" where
      a list says nothing matches. Availability is dropped as a filter, its order (FR-DIS-8) being
      what puts the makeable first; a grammar for compound queries is out of pilot scope.
- [x] **M18a Ingredient substitutions** — a line offers alternatives, and any one of them on hand
      makes it ([ADR 11](adr/11-substitutions-on-the-line.md), FR-REC-9): `RecipeLine.ingredients`
      is a never-empty list with no singular accessor, so the nine readers each decide what a group
      means rather than quietly taking the first. The grammar splits the tail on `/`, spaced or not,
      after the unit and after the mark — so one amount, one unit and one mark govern the group and
      no reading depends on the bar; `/` joins the mark suffixes barred from every ingredient
      spelling, since `sweet / dry vermouth` would otherwise have two readings. `stockOfLine` takes
      the best of a group and is the one home the verdict and the card both read, so a card can dim
      what the bar lacks — but only while it holds something, leaving an all-short group undimmed
      under the dot that already says so. Cards read "or" where the file reads `/`; the form keeps
      the separator, being where a line is re-edited. `displayRecipeLine` becomes `displayMeasure`,
      the body it returned having transformed nothing.
- [x] **M19 Base spirit narrows** — the browsing FR-DIS-4 asked to be grouped becomes a filter
      instead ([ADR 12](adr/12-base-spirit-narrows.md)): base is a predicate, not a placement, so
      ADR 11's deferred question dissolves — a marked group answers under every bottle it names,
      where a section could have filed its recipe under only one. Grouping is refused for what it
      would cost: a second list layout over search, tags, six orders and per-card expansion, and
      availability — the order the list opens in — demoted to *within* a section. `discovery.dart`
      lands `basesOf`, `baseSpirits` and `marksBase`; `groupByBaseSpirit` is never written. One
      chip leads the filter row, reading `Base: Any` / `Base: Gin` / `Base: None` and opening the
      spirits the collection is actually built on — `tagFilter` takes it as a leading filter, so
      the two narrowings share one scroller and one no-match message, and a vocabulary with no tags
      still gets the chip. It wears `neutralSwatch`, the one scheme-derived ground in `palette.dart`,
      since a bottle's name is neither a tag nor a signal. A pick gone stale stops narrowing rather
      than emptying the list, as a tag pick does.
- [x] **M20 Random pick** — one suggestion of what to make now (FR-DIS-5): a dice above the add
      button, drawing a recipe the bar can make from whatever the list is showing. The draw is the
      *list's*, not the screen's, so every narrowing already holds and the search never has to leave
      `VocabularyList` — the hoist [components.md](components.md) predicted this milestone would
      force turned out unnecessary. `canMake` lands in `availability.dart` as the one reading of
      what the bar can manage (low counts, unjudged does not), which the optimizer will ask too;
      `randomCanMake` draws over candidates handed to it rather than over the model, and skips the
      recipe already standing so a second roll always moves. The pick opens alone — every other card
      shuts, a roll being one answer rather than a pile — and the list scrolls to it by index on
      `scrollable_positioned_list` ([ADR 13](adr/13-lists-scroll-by-index.md)), waiting on the
      measurement the draw's own reshuffle forces, since a row already in view is reached in pixels
      rather than by index and would otherwise be aimed at where it stood. Once it lands, the card
      washes from `secondaryContainer` back to rest — colour alone, since a row changing height
      would fire that same measurement — because a list that stopped moving has not yet said what it
      stopped *for*. The first dependency taken for ergonomics rather than structure: confined to
      `vocabulary_list.dart`, pinned exactly against its own dormancy, with the float-to-front
      fallback recorded so a dead package is a costed edit rather than a redesign. Nothing makeable
      says so instead of doing nothing. The dice itself is Font Awesome's pair
      ([ADR 14](adr/14-the-dice-comes-off-font-awesome.md)), the shipped font carrying only single
      dice that read as domino tiles at button size; `ListDraw` carries the glyph as a widget, so
      the font is named on the recipes screen and nowhere else.
- [x] **M21 Optimizer domain** — combination search and ranking (FR-DIS-6): `purchasesWithin` over
      `Purchase`, the basket of bottles and the recipes it unlocks. ADR 11's flagged consequence
      turns out to reshape the search rather than adjust it — a missing recipe's gap is not one set
      of bottles but a *choice* between several, any one alternative closing its line, so the ways
      of making it are the cross product over the lines it is short of. The bottles worth weighing
      are exactly those gaps', which is what keeps a pool of out-of-stock bottles from being every
      bottle. What [architecture.md](architecture.md#domain-computations) described — sets collected
      per recipe — would also have missed the combined buy, two unrelated single-bottle gaps being
      no recipe's own set; that line is rewritten. A basket has to beat each of its own smaller
      selves or it is one of them carrying a passenger, which subsumes the zero-yield rule rather
      than sitting beside it. The performance test is the milestone's other half and earned its
      keep: the first working version took 6.8s at NFR-2 scale, and the profile said the search was
      43ms while *naming* thirty-five thousand baskets was the rest — hence
      [ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md), the best few of each size, and
      ~140ms. `Model.bottleNamed` lands as the one home for "this name, under the entry's own",
      which `baseSpiritNamed` and two copies in `model_edits.dart` were each spelling separately.
- [x] **M22a Restocking widens the search** — what counts as short becomes the reader's to set
      ([ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md), FR-DIS-6/7 rewritten):
      `purchasesWithin` takes `restocking`, off leaving M21's answer exactly as it stood, on taking
      a line short of *full* stock — so the bottles running low join the pool and the goal becomes
      ready rather than merely makeable. Widening the pool alone would not have done it: a low
      bottle unlocks nothing under `canMake`, a recipe standing at Low being already can-make, so
      every basket holding one would have been dropped as a passenger by ADR 15's rule. It is the
      *goal* that had to move. One flag, one place — the test in `_gapsOf` — since the whole search
      below it already read "short" rather than "out"; `canMake` itself does not move, the traffic
      light and the random pick going on as they were. FR-DIS-7 stops asking for a restock list of
      its own: being shoppable is how a low bottle is reminded of. M21's tests stand as the
      flag-off case, and the performance test now times both readings over the one collection —
      58ms plain against 100ms restocking, the pool being bounded by the gaps' own bottles rather
      than by the shelf.
- [ ] **M22 Optimizer screen** — budget selector, ranked combinations (FR-DIS-6/7).

## Phase 4 — Settings & data exchange

- [ ] **M23 Settings screen** — part-to-ml ratio editor and display toggle (FR-SET-1).
- [ ] **M24 Export** — share a copy of the store file via the share sheet (FR-DAT-1).
- [ ] **M25 Import** — file picker, validation report, confirmation with automatic
      pre-import export, atomic replace (FR-DAT-3/4); confirmation-flow widget test.

## Phase 5 — Release

- [ ] **M26 Release packaging** — signing configuration (keystore outside the repo),
      Android Auto Backup enabled, launcher icon and label, version 1.0.0.
