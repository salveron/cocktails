# Roadmap

Milestones in dependency order. Scope: [requirements.md](requirements.md); design: [architecture.md](architecture.md), [components.md](components.md), [ui-design.md](ui-design.md); rationale: [ADRs](adr/). Phases 0–6: single bar; Phases 7–8 and 11–12: FR-BAR-1..9; Phases 9–10 carry no new requirement.

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

## Phase 1 — Ingredients & vocabularies

- [x] **M10** — Ingredients screen. Delivers: ingredient list, search, stock toggle (FR-ING-1/2). Depends: M9.
- [x] **M10a** — Base spirit on line. Delivers: [ADR 06](adr/06-base-spirit-on-the-line.md), LineMark per line, (base)/(optional) exclusive (FR-REC-8). Depends: M10.
- [x] **M11** — Ingredient management. Delivers: add, rename, delete with reference blocking (FR-VOC-1). Depends: M10.
- [x] **M11a** — Tag colour. Delivers: [ADR 07](adr/07-tag-colour.md), colour on Tag, required on all tags (FR-VOC-3). Depends: M11.
- [x] **M11b** — Ingredient tags. Delivers: recipe_tags and ingredient_tags as peers, per-vocabulary propagation (FR-VOC-3/4, FR-ING-3). Depends: M11a.
- [x] **M12** — Tag management. Delivers: add, rename, delete on both vocabularies in Settings; colour picker (FR-VOC-1/3). Depends: M11b.
- [x] **M12a** — Ingredient tags on the ingredients screen. Delivers: colour dot per tag, filter-chip row combines with search (FR-ING-3). Depends: M12.

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

- [x] **M26** — Basket card re-reads. Delivers: title `Shopping Cart #N`, ingredients subtitle, body as BulletRuns, ranked by count (FR-DIS-6). Depends: M25a.
- [x] **M27** — Baskets narrow to category. Delivers: tagFilter row, basket answers tags of recipes unlocked (FR-DIS-10). Depends: M26.
- [x] **M28** — Destination sends reader to another. Delivers: [ADR 19](adr/19-a-destination-sends-the-reader-to-another.md), destinations.dart, revealProvider, back undoes (FR-DIS-9). Depends: M27.

## Phase 6 — Cleanup & release

- [x] **M28a** — Made it comes out. Delivers: Remove FR-REC-6 history, reader ignores made: key, format 1 backward compatible. Depends: M28.
- [x] **M28b** — Test suite reads once. Delivers: Remove duplication, tokenVocabulary/valueEquality table, document rules in [components.md](components.md#what-earns-a-test). Depends: M28a.
- [x] **M28c** — Type takes noun. Delivers: Model→Collection rename, collection.dart, CollectionEdits, amend [ADR 20](adr/20-the-app-holds-many-bars.md). Depends: M28b.
- [x] **M29** — Build takes identity. Delivers: release keystore, Auto Backup declared, launcher icon local_bar, version 1.0.0+1. Depends: M28c.

## Phase 7 — The app holds many bars

**Pilot boundary.** Phases 0–6 are a complete product — one bar, kept and read and shared as a
file. What follows is the next claim rather than the same one continued.

- [x] **M30** — Shelf domain. Delivers: [ADR 20](adr/20-the-app-holds-many-bars.md), Bar, BarMode, Transport, BarSource, Offer, BarContent, Shelf, ShelfEdits, validateShelf, guest refusal [ADR 23](adr/23-nothing-writes-a-guest-bar.md). Depends: M29.
- [x] **M31** — One file per bar. Delivers: [ADR 21](adr/21-the-file-carries-one-bar.md), BarStore, shelf.yaml, bars/<id>.yaml, atomic write, rotation, format 2 lands whole, cocktails.yaml migration. Depends: M30.
- [x] **M32** — Shelf in state. Delivers: ShelfController, collectionProvider derived, openBarProvider, barWriterProvider (null for guest), export/import on open bar only, amend [ADR 23](adr/23-nothing-writes-a-guest-bar.md). Depends: M31.
- [x] **M33** — Bars screen. Delivers: [ui-design.md](ui-design.md#bars), Switch bar in gear, openBar/addOwnedBar/renameBar/removeBar, card expands, summaryOf/Holding enum, loadIssues (FR-BAR-1/2). Depends: M32.
- [x] **M33a** — Load answers once. Delivers: collectionProvider as plain Provider, spinner moved to _Home, no AsyncData wrapper, loadIssuesProvider as Notifier, Bar.copyWith narrowed, widget test harness updated. Depends: M33.
- [x] **M33b** — The bar list says more, and says it at once. Delivers: `Bar.updated`/`Bar.summary` on
  the record and the card's dated subtitle, Rename/Delete behind the row's ⋮; amends
  [ADR 19](adr/19-a-destination-sends-the-reader-to-another.md),
  [ADR 20](adr/20-the-app-holds-many-bars.md), [ADR 21](adr/21-the-file-carries-one-bar.md). Depends: M33a.
- [x] **M34** — Guest bar is read-only. Delivers: every write control gated on `barWriterProvider`
  being null, the optimizer destination absent on a guest, export still working (FR-DAT-1). Depends: M33a.

## Phase 8 — A bar travels by file

- [x] **M35** — Sharing seam. Delivers: [ADR 22](adr/22-a-bar-travels-behind-one-seam.md), BarChannel, FetchOutcome, channelsProvider, refreshesProvider, file channel first (FR-BAR-7). Depends: M34.
- [x] **M36** — One file, two destinations. Delivers: `BarFormScreen`, one form for founding and
  importing; `addOwnedBar` (FR-BAR-2), swipe-to-refresh on a guest bar (FR-BAR-5). Depends: M35.
- [x] **M36a** — A guest bar is the reader's to name. Delivers: `renameBar` on a guest bar, the import
  review folded into `BarFormScreen`, Import becoming Refresh on a guest (FR-BAR-5); amends
  [ADR 21](adr/21-the-file-carries-one-bar.md), [ADR 23](adr/23-nothing-writes-a-guest-bar.md). Depends: M36.
- [x] **M36b** — One word per thing. Delivers: Inventory renamed Ingredients throughout, requirements
  included (FR-ING-1/2/3); a bar card dated Updated/Refreshed rather than Loaded (ADR 20). Depends: M36a.
- [x] **M36c** — The optimizer is asked, and a guest may look. Delivers: a Shopping settings screen
  over `Bar.shopping` (ADR 21), aim/sift chips ([ADR 24](adr/24-the-tags-may-aim-the-optimizer.md),
  FR-SET-2, FR-DIS-10); a guest bar reads tags, units and amounts read-only (FR-BAR-4). Depends: M36b.

## Phase 9 — The code says what it means

No behaviour changes here but the first, which is a bug fix. The phase pays down what Phases 7 and 8
left: one idea implemented four times, names that stopped meaning one thing, and four files past the
size a reader holds. It stands before the LAN because the second `BarChannel` would otherwise copy
what M36f settles.

- [x] **M36d** — The name rule reaches the surface. Delivers: `nameKey` and its kin exported so a tag
  chip folds a name the same way everywhere ([ADR 08](adr/08-names-ignore-case.md)), retiring three
  private folds (amends [ADR 04](adr/04-module-boundaries.md)). Depends: M36c.
- [x] **M36e** — Dead weight goes. Delivers: `MemoryBarStore` out of the shipped binary into
  `test/support/`, and an `architecture_test` rule that no double ships. Depends: M36d.
- [x] **M36f** — One home per algorithm: domain and data. Delivers: the bar coherence rules, the
  `Outcome<T>` hierarchy and the token-carrying enums' `Tokened` each stated once instead of
  several times. Depends: M36e.
- [x] **M36g** — One home per algorithm: UI. Delivers: `ExpandingRow`, `Segments<T>`, `DialogFrame`
  and `RevealServing` each replacing several hand-rolled copies across screens. Depends: M36f.
- [x] **M36h** — One owner per value. Delivers: settings and screens reading a single live watch
  instead of a mirrored copy resynced by `ref.listen`, so a moved default and a ticking clock each
  take hold from one place. Depends: M36g.
- [x] **M36i** — One word per thing. Delivers: `VocabularyList`/`VocabularyRow` → `EntryCardList`/
  `EntryCard`, `BarPayload` → `BarContent`, `Shopping` → `ShoppingSettings`, and a run of smaller
  renames converging one concept on one name apiece. Depends: M36h.
- [x] **M36j** — Files find their size, one home per role. Delivers: `lib/ui` regrouped into
  `screens/` and `widgets/{cards,chips,dialogs,forms,lists,notices}`
  ([ADR 25](adr/25-the-ui-groups-by-subject.md)), every file over 600 lines split by subject within
  it. Depends: M36i.
- [x] **M36k** — The tests mirror the code. Delivers: `test/` holding one file per `lib/` file, named
  for it ([rule and its two exemptions](components.md#where-a-test-lives)); yaml's one 1,609-line
  file split among the four files that own its behaviour; test support folded into five files.
  Depends: M36j.

## Phase 10 — Every file names what it is responsible for

Phase 9 asked whether a file was too big and whether a word meant one thing. It never asked what a
file is *responsible for*, which is why `collection.dart` holds eight subjects, `availability.dart`
mixes recipe availability with ingredient stock, and the shelf imports the optimizer for a value on
`Bar`. One behaviour change only: `Bar.shopping` takes the mode rule every other mode-specific field
already keeps. It stands before the LAN so the second `BarChannel` lands in a domain that has been
asked the question.

- [x] **M37** — Dead weight and misfiled declarations. Delivers: `newBarId`'s unused `Random`
  parameter gone; `data.dart` newly hiding `isStorableBarId`; `refreshes.dart` split into
  `channels.dart` and itself. Depends: M36k.
- [x] **M38** — One home per algorithm: domain and data. Delivers: the shelf's and the collection's
  duplicate-name rules, `ShelfController`'s `Outcome` reads, and the yaml readers' "must be a
  mapping" guard each stated once; `ShoppingSettings`'s wire tokens declared beside their fields.
  Depends: M37.
- [x] **M39** — One home per algorithm: UI. Delivers: one write-gate idiom across three screens, two
  missing `mounted` guards fixed, `ToggleMembership`/`AmountView`/`say` each moved to the file that
  owns the concern. Depends: M38.
- [x] **M40** — The domain finds its shape. Delivers: 13 `domain/src/` files become 25 across
  `collection/`, `shopping/` and `shelf/` in a one-way chain
  ([ADR 26](adr/26-the-domain-groups-by-responsibility.md)); `Bar.shopping` becomes nullable and
  owner-only, the one behaviour change (amends [ADR 21](adr/21-the-file-carries-one-bar.md),
  [ADR 24](adr/24-the-tags-may-aim-the-optimizer.md)). Depends: M39.
- [x] **M41** — The tests find their level. Delivers: `barChannelContract`, a 3-way split of
  `ui_test_support.dart`, and `architecture_test.dart`'s sanity checks collapsed onto one table;
  `expectIssue`/`copyWithContract` reached into the domain suites; eleven `List.unmodifiable`
  contract checks removed and `list_controls.dart` gained its first test file. Depends: M40.
- [x] **M42** — The docs say less, and mean it. Delivers: an anchor-resolution check in
  `architecture_test.dart` landed first over all 126 links; [components.md](components.md) 1022 →
  688 lines, its signature fences gone; this roadmap's own history compacted from M33b on (319 →
  170); [ADR 20](adr/20-the-app-holds-many-bars.md), [ADR 21](adr/21-the-file-carries-one-bar.md)
  freed of reversed alternatives and amendment narration, [ADR 02](adr/02-persistence-and-export-format.md)
  marked superseded by them; [ui-design.md](ui-design.md) trimmed of its screen-content walks and
  its Vocabulary editing section pointed at the widgets' own dartdoc. Depends: M41.

## Phase 11 — A bar travels over the LAN

The first thing in the app to open a socket and the first to announce anything about itself, so it
lands bottom-up: the package proven on a device before a server rests on it, the server before
anything announces it, and the owner's side before the guest's — FR-BAR-6 having had nothing to
offer or withdraw while a file was the only way a bar travelled.

- [x] **M43** — Nearby is proven, and confined. Delivers: a DNS-SD package under the
  [ADR 13](adr/13-lists-scroll-by-index.md) bar — one file, the way out written down — the pick and
  its pinning ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)), a register-and-browse round trip
  proven on the device, and the permissions it actually asks for
  ([platform facts](architecture.md#platform-facts)). Depends: M42.
- [x] **M44** — The device answers on a socket. Delivers: one `dart:io` `HttpServer` on an ephemeral
  port, the offered list and one unguessable path per bar, 404 for everything else; the bytes read
  through the store, so a served copy is the bar's own export
  ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)). Depends: M43.
- [x] **M45** — An offer announces, a withdrawal silences. Delivers: `BarOfferings` on the
  [sharing seam](components.md#the-sharing-seam), one service instance per device, up with the first
  offer and down with the last (FR-BAR-6, NFR-5). Depends: M44.
- [x] **M46** — The offer is the reader's to make. Delivers: `offering`/`withdrawing` on
  `ShelfEdits`, the owner-only write of `Bar.offers`, and what is announced now held beside the
  refreshes in flight ([work in flight](components.md#work-in-flight)); shape only, the screen being
  M47's (FR-BAR-6). Depends: M45.
- [ ] **M47** — Settings opens on Sharing. Delivers: the room a bar is shared from
  ([ui-design.md](ui-design.md#sharing)), read from either side — an owner's ways out, a guest's way
  in (FR-BAR-6/7). Depends: M46.
- [ ] **M48** — Any bar is shared from the list. Delivers: the bars card's ⋮ reaching that same room
  for a bar not in hand, and the card marking one that is shared
  ([ui-design.md](ui-design.md#bars), FR-BAR-6). Depends: M47.
- [ ] **M49** — A guest refreshes over the LAN. Delivers: the LAN channel's `fetch` — the instance
  resolved afresh every ask — and the three unreachable readings mapped onto where the ask stopped
  (FR-BAR-5/8, [ADR 22](adr/22-a-bar-travels-behind-one-seam.md)); `barChannelContract` run over it.
  Depends: M48.
- [ ] **M50** — A guest finds one nearby. Delivers: `BarFinder` and the `Found` entry
  ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)), **Find nearby** beside **From import**
  ([ui-design.md](ui-design.md#new-bar)), bars grouped under the device offering them and told apart
  by id (FR-BAR-1/8). Depends: M49.
- [ ] **M51** — A guest bar refreshes from wherever the reader points it. Delivers: `resourced` on
  `ShelfEdits` and the Sharing room's guest row becoming changeable, so a bar added from a file
  refreshes from a device found nearby and back again (FR-BAR-5). Depends: M50.

## Phase 12 — A bar travels over the cloud

- [ ] **M52** — Cloud adapter. Delivers: FR-BAR-9, backend chosen via [ADR 22](adr/22-a-bar-travels-behind-one-seam.md), one identity (NFR-3), guests named, refresh from anywhere. Depends: M51.
