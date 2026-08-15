# Roadmap

Milestones in dependency order. Scope: [requirements.md](requirements.md); design: [architecture.md](architecture.md), [components.md](components.md), [ui-design.md](ui-design.md); rationale: [ADRs](adr/). Phases 0–6: single bar; Phase 7+: FR-BAR-1..9.

## Phase 0 — Foundation

- [x] **M1** — Scaffold. Delivers: Flutter project, Android, application ID, directories per [module map](components.md#module-map).
- [x] **M2** — CI. Delivers: GitHub Actions workflow (format, analyze, test).
- [x] **M3** — Domain model. Delivers: Ingredient, Tag, Recipe, Settings, Collection root with invariants.
- [x] **M4** — Line parser/formatter. Delivers: compact-line grammar, round-trip tests. Used by M6, M14.
- [x] **M5** — Collection validation. Delivers: referential integrity, duplicate names, malformed values (FR-DAT-4).
- [x] **M5a** — Domain packaging. Delivers: [module boundaries](components.md#boundary-rules), [validation contract](adr/05-validation-contract.md), barrel, tokens on enums. Depends: M5.
- [x] **M6** — YAML codec. Delivers: parse, validate with line positions, canonical emit, format gate, round-trip (FR-DAT-2/4/5). Depends: M4, M5.
- [x] **M7** — Storage adapter. Delivers: storage interface, file adapter, atomic save, backups, recovery. Depends: M6.
- [x] **M7a** — Collection edit API. Delivers: [CollectionEdits](components.md#editing-the-collection), pure derivations, memoised lookups (FR-VOC-1). Depends: M3.
- [x] **M8** — State wiring. Delivers: Riverpod collection provider, mutations persist, startup load. Depends: M7, M7a.
- [x] **M9** — App shell. Delivers: navigation, theme, empty states. Depends: M8.

## Phase 1 — Inventory & vocabularies

- [x] **M10** — Inventory screen. Delivers: ingredient list, search, stock toggle (FR-INV-1/2). Depends: M9.
- [x] **M10a** — Base spirit on line. Delivers: [ADR 06](adr/06-base-spirit-on-the-line.md), LineMark per line, (base)/(optional) exclusive (FR-REC-8). Depends: M10.
- [x] **M11** — Ingredient management. Delivers: add, rename, delete with reference blocking (FR-VOC-1). Depends: M10.
- [x] **M11a** — Tag colour. Delivers: [ADR 07](adr/07-tag-colour.md), colour on Tag, required on all tags (FR-VOC-3). Depends: M11.
- [x] **M11b** — Ingredient tags. Delivers: recipe_tags and ingredient_tags as peers, per-vocabulary propagation (FR-VOC-3/4, FR-INV-3). Depends: M11a.
- [x] **M12** — Tag management. Delivers: add, rename, delete on both vocabularies in Settings; colour picker (FR-VOC-1/3). Depends: M11b.
- [x] **M12a** — Ingredient tags on inventory. Delivers: colour dot per tag, filter-chip row combines with search (FR-INV-3). Depends: M12.

## Phase 2 — Recipes

- [x] **M13** — Recipe list & view. Delivers: read-only cards expand in place, chips, lines, notes (FR-DIS-2). Depends: M12a.
- [x] **M14** — Recipe form. Delivers: create, edit, delete with line parser and tag picker (FR-REC-1..5/8). Depends: M13.
- [x] **M15** — Made it. Delivers: history stamp, Undo, long-press reset (FR-REC-6). Depends: M14.
- [x] **M16** — Availability. Delivers: availabilityOf, chip (Ready/Low/Missing), stock dots on low/out lines (FR-DIS-1, FR-REC-2). Depends: M15.
- [x] **M16a** — Names ignore case. Delivers: [ADR 08](adr/08-names-ignore-case.md), folded comparison, part default, plural accepted. Depends: M16.
- [x] **M17** — Scaling & unit display. Delivers: displayRecipeLine scales ×2–4, part↔ml conversion, formatRecipeLine canonical (FR-REC-7, FR-SET-1). Depends: M16a.

## Phase 3 — Discovery

- [x] **M17a** — Sorting. Delivers: multiple orders per list, A→Z tie-break (FR-DIS-8). Depends: M17.
- [x] **M17b** — Unit vocabulary. Delivers: [ADR 09](adr/09-units-are-a-vocabulary.md), units section, part/ml fixed (FR-VOC-5). Depends: M17a.
- [x] **M17c** — Units screen. Delivers: Settings → Units, edit in place, delete blocked while used, part/ml locked (FR-VOC-5). Depends: M17b.
- [x] **M17d** — Ingredient aliases. Delivers: [ADR 10](adr/10-ingredient-aliases.md), aliases on Ingredient, resolved everywhere (FR-VOC-6). Depends: M17c.
- [x] **M18** — Filters. Delivers: recipe list chip row, tag filter (FR-DIS-3). Depends: M17d.
- [x] **M18a** — Ingredient substitutions. Delivers: [ADR 11](adr/11-substitutions-on-the-line.md), alternatives on line split by / (FR-REC-9). Depends: M18.
- [x] **M19** — Base spirit narrows. Delivers: [ADR 12](adr/12-base-spirit-narrows.md), base filter predicate, baseSpirits chip (FR-DIS-4). Depends: M18a.
- [x] **M20** — Random pick. Delivers: dice button, randomCanMake over candidates (FR-DIS-5), [ADR 13](adr/13-lists-scroll-by-index.md), [ADR 14](adr/14-the-dice-comes-off-font-awesome.md). Depends: M19.
- [x] **M21** — Optimizer domain. Delivers: [ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md), purchasesWithin, Purchase (FR-DIS-6). Depends: M20.
- [x] **M21a** — Restocking widens search. Delivers: [ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md), restocking flag (FR-DIS-7). Depends: M21.
- [x] **M22** — Optimizer screen. Delivers: budget selector, ranked baskets (FR-DIS-6/7), autoDispose when off-screen. Depends: M21a.

## Phase 4 — Settings & data exchange

- [x] **M23** — Fixed units interconvert. Delivers: [ADR 17](adr/17-the-fixed-units-interconvert.md), oz joins part/ml as reserved, FixedUnit, Settings.oz_ml (FR-SET-1). Depends: M22.
- [x] **M23a** — Amounts screen. Delivers: Settings screen, global unit pick, two ratios, Settings.ratio/withRatio (FR-SET-1). Depends: M23.
- [x] **M24** — Export. Delivers: [ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md), system share sheet, share_plus, exportSnapshot, ExportPurpose (FR-DAT-1). Depends: M23a.
- [x] **M25** — Import. Delivers: [ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md), filePickerProvider, review pure, Replace button, safety copy, counts=identity (FR-DAT-3/4). Depends: M24.
- [x] **M25a** — Counts open, diacritics survive. Delivers: UTF-8 fix via pickedText, counts per kind, full list on tap (FR-DAT-4). Depends: M25.

## Phase 5 — The basket, and reaching across screens

- [x] **M26** — Basket card re-reads. Delivers: title `Shopping Cart #N`, bottles subtitle, body as BulletRuns, ranked by count (FR-DIS-6). Depends: M25a.
- [x] **M27** — Baskets narrow to category. Delivers: tagFilter row, basket answers tags of recipes unlocked (FR-DIS-10). Depends: M26.
- [x] **M28** — Destination sends reader to another. Delivers: [ADR 19](adr/19-a-destination-sends-the-reader-to-another.md), destinations.dart, revealProvider, back undoes (FR-DIS-9). Depends: M27.

## Phase 6 — Cleanup & release

- [x] **M28a** — Made it comes out. Delivers: Remove FR-REC-6 history, reader ignores made: key, format 1 backward compatible. Depends: M28.
- [x] **M28b** — Test suite reads once. Delivers: Remove duplication, tokenVocabulary/valueEquality table, document rules in [components.md](components.md#what-earns-a-test). Depends: M28a.
- [x] **M28c** — Type takes noun. Delivers: Model→Collection rename, collection.dart, CollectionEdits, amend [ADR 20](adr/20-the-app-holds-many-bars.md). Depends: M28b.
- [x] **M29** — Build takes identity. Delivers: release keystore, Auto Backup declared, launcher icon local_bar, version 1.0.0+1. Depends: M28c.

## Phase 7 — The app holds many bars

- [x] **M30** — Shelf domain. Delivers: [ADR 20](adr/20-the-app-holds-many-bars.md), Bar, BarMode, Transport, BarSource, Offer, BarPayload, Shelf, ShelfEdits, validateShelf, guest refusal [ADR 23](adr/23-nothing-writes-a-guest-bar.md). Depends: M29.
- [x] **M31** — One file per bar. Delivers: [ADR 21](adr/21-the-file-carries-one-bar.md), BarStore, shelf.yaml, bars/<id>.yaml, atomic write, rotation, format 2 lands whole, cocktails.yaml migration. Depends: M30.
- [x] **M32** — Shelf in state. Delivers: ShelfController, collectionProvider derived, openBarProvider, barWriterProvider (null for guest), export/import on open bar only, amend [ADR 23](adr/23-nothing-writes-a-guest-bar.md). Depends: M31.
- [x] **M33** — Bars screen. Delivers: [ui-design.md](ui-design.md#bars), Switch bar in gear, openBar/addOwnedBar/renameBar/removeBar, card expands, holdingsOf/Holding enum, loadIssues (FR-BAR-1/2). Depends: M32.
- [x] **M33a** — Load answers once. Delivers: collectionProvider as plain Provider, spinner moved to _Home, no AsyncData wrapper, loadIssuesProvider as Notifier, Bar.copyWith narrowed, widget test harness updated. Depends: M33.
- [x] **M33b** — The bar list says more, and says it at once. Delivers: `Bar.updated` and `Bar.holds`
  on the record with `Bar.summarised` their one writer, both optional keys on the index and neither
  in a bar's file; the startup pass that counts a shelf written before summaries existed; the card
  subtitle (Loaded · Updated/Synced, coarse, silent where undated); the owner/guest chip off scheme
  roles (`barModeColors`); Rename and Delete behind the row's ⋮ with Rename absent on a guest bar;
  Open bar offered on every bar, a landing rather than a jump on the one already loaded
  (`Reveals.land`, nullable `Reveal.name`); `clockProvider`; `holdingsOfBar` and the card's
  `FutureBuilder` gone. Amends [ADR 19](adr/19-a-destination-sends-the-reader-to-another.md),
  [ADR 20](adr/20-the-app-holds-many-bars.md) — which had refused the index summary — and
  [ADR 21](adr/21-the-file-carries-one-bar.md). Depends: M33a.
- [x] **M34** — Guest bar is read-only. Delivers: `destinationsOf(BarMode)` with the shell indexing
  by offered position rather than by the enum; the optimizer absent on a guest rather than empty;
  every write control built from `barWriterProvider` being null, so no add button, no ⋮ on an
  inventory row, no Edit/Delete on a recipe, and no stock rotation — Scale & convert, the dice, the
  narrowings and the jumps all surviving; `RowMenu` drawing nothing when empty; Settings' Tags,
  Units and Import dimmed and leading nowhere while Amounts, Export and Change bar stay live;
  Amounts offering a guest the pick alone; export working on a guest (FR-DAT-1); no `!` on the
  writer left in `ui/`. Also: Change bar moved last and de-ellipsised, every Settings caption cut to
  one line, "Yours" → "Owned", Open bar filled tonal and right-aligned, and the second person gone
  from the UI's copy. Depends: M33a.

## Phase 8 — A bar travels by file

- [x] **M35** — Sharing seam. Delivers: [ADR 22](adr/22-a-bar-travels-behind-one-seam.md), BarChannel, FetchOutcome, channelsProvider, refreshesProvider, file channel first (FR-BAR-7). Depends: M34.
- [ ] **M36** — One file, two destinations. Delivers: review, BarPayload, replace owned or found guest (FR-BAR-7), refresh by picker (FR-BAR-5). Depends: M35.

## Phase 9 — A bar travels over the LAN

- [ ] **M37** — Owner offers bar nearby. Delivers: FR-BAR-8, DNS-SD package, dart:io server, internet permission, sharingProvider, [ADR 22](adr/22-a-bar-travels-behind-one-seam.md). Depends: M36.
- [ ] **M38** — Guest finds one. Delivers: FR-BAR-8, browse service type, GET refresh, two instances discriminated by bar id (FR-BAR-1/5). Depends: M37.

## Phase 10 — A bar travels over the cloud

- [ ] **M39** — Cloud adapter. Delivers: FR-BAR-9, backend chosen via [ADR 22](adr/22-a-bar-travels-behind-one-seam.md), one identity (NFR-3), guests named, refresh from anywhere. Depends: M38.
