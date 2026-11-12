# Components

Module-level design: structure, layers, interfaces, data flows. System: [architecture.md](architecture.md); boundaries: [ADR 04](adr/04-module-boundaries.md); screens: [ui-design.md](ui-design.md).

## Module map

Each layer is a folder with a barrel file. **The barrel is the entire public surface**; everything else lives under `src/`.

```
lib/
  main.dart                    # composition root — ProviderScope, store and channel overrides
  domain/
    domain.dart                # barrel — the only domain import other layers use
    src/                       # loose, collection/, shopping/, shelf/, one-way chain (ADR 26)
      names.dart               # the name fold every comparison goes through (ADR 08)
      tokens.dart              # the enum-to-wire-token contract every token-carrying enum backs
      issues.dart              # ValidationIssue and the rule-checking primitives it shares
      list_edits.dart          # generic list edits collection and shelf derivations share
      collection/              # what one bar contains, and every question asked of it
        collection.dart        # the root: vocabularies, recipes, memoised lookups
        amount.dart            # a measured quantity
        unit.dart               # the units vocabulary and the three fixed readings
        unit_sizes.dart        # a part and an ounce in ml (ADR 17, ADR 21)
        ingredient.dart        # an ingredient: stock, aliases, tags
        ingredient_stock.dart  # what a line's stock reads as, for the optimizer (ADR 16)
        tag.dart               # a labelled colour, and the order it wears in
        recipe.dart            # a recipe: tags, lines, notes
        recipe_line.dart       # the compact-line grammar
        recipe_availability.dart # whether a recipe can be made
        recipe_discovery.dart  # base spirit and the random pick
        amount_scaling.dart    # ×N scaling and part↔ml display
        collection_edits.dart  # pure derivations over Collection
        collection_validation.dart # the collection's own rule set
      shopping/                # what the optimizer is asked, and what it answers
        shopping_settings.dart # how the optimizer is asked (FR-SET-2)
        optimizer.dart         # what to buy next
      shelf/                   # how the device holds many bars, and shares them
        bar.dart               # one bar's record and its summary
        shelf.dart             # the root above Collection (ADR 20), and its two rules
        sharing.dart           # the ways a bar can travel, and where a guest reads from
        shelf_edits.dart       # pure derivations over Shelf, the guest-bar refusal among them (ADR 23)
        shelf_validation.dart  # the shelf's own rule set
  data/
    data.dart                  # barrel — the store, the channels, the codec, their results
    src/
      sourced_issue.dart       # a load/decode/fetch's shared result shape
      bar_store.dart           # the storage interface and the shelf index
      bar_channel.dart         # the sharing seam every transport answers (ADR 22)
      file_bar_channel.dart    # the file transport: the picker's text, decoded (FR-BAR-7)
      lan_discovery.dart       # the one file naming a DNS-SD package (ADR 27)
      lan_bar_server.dart      # the offered list, and each offered bar's bytes (ADR 22)
      lan_bar_channel.dart     # the LAN's owner half: offer announces, withdrawal silences
      yaml_codec.dart          # decode/encode of a bar and of the index, version gate
      yaml_bar_reader.dart     # YAML tree → a bar's own file parts
      yaml_shelf_reader.dart   # YAML tree → the shelf index's parts
      yaml_primitives.dart     # the generic reads and checks both readers share
      yaml_writer.dart         # canonical emitter
      file_bar_store.dart      # one file per bar, the index, atomic write, rotation
  state/
    state.dart                 # barrel — every provider over the shelf
    src/
      shelf_controller.dart    # the one writable provider (ADR 23)
      bar_writer.dart          # the write surface, handed out for an owned bar only
      seams.dart               # store, clock, share sheet, picker, random — one provider each
      channels.dart            # which transport has an adapter in this build (ADR 22)
      refreshes.dart           # the refreshes in flight and what they failed with (FR-BAR-5)
      sharing.dart             # the offers in flight and what an announcement failed with (FR-BAR-6)
      derived.dart             # everything read-only: collection, availability, the optimizer
  ui/                          # no barrel — leaves, imported directly; design in ui-design.md
    app.dart, destinations.dart, theme.dart, palette.dart, wording.dart, toggling.dart   # the
                               #   shell, the nav model and each subject read by more than one
                               #   of screens/ and widgets/ (ADR 25)
    screens/                  # route destinations, one per file, all *_screen.dart (ADR 25)
    widgets/                  # everything else, grouped by subject, never by feature (ADR 25)
      cards/                  # a list's rows and a recipe's own card
      chips/                  # colour read as a pill, a dot, or a picked-tag row
      dialogs/                # the one AlertDialog shape and every dialog built on it
      forms/                  # the editor frame, its fields, and the ValidationIssue path reading
      lists/                  # the searchable list and its chrome
      notices/                # empty states, failure banners, the snackbar every message reaches through
test/                          # one file per lib/ file, named for it (see Testing)
  architecture_test.dart       # the whole tree: imports, dependency list, ui/ and domain/ layout, doc anchors
  support_test.dart            # holds the support below to account
  support/                     # everything under test/ that is not itself a test —
                               #   memory_bar_store.dart for what several layers read,
                               #   then one file per layer: {domain,data,state}_test_support.dart,
                               #   ui/ split three ways: ui_fixtures, ui_harness, ui_finders
```

`domain/src/names.dart` holds the one fold behind every name comparison ([ADR 08](adr/08-names-ignore-case.md)): `nameKey`, `nameKeys`, `sameName`, `compareNames`. Exported, lists and chips reuse the rule rather than restate it.

## Boundary rules

Three visibility levels:

| Marking | Scope | Use for |
|---|---|---|
| `_name` | the file | helpers used in one file |
| public in `src/`, not exported | the layer | logic shared between files of one layer |
| exported from the barrel | the app | the layer's contract with other layers |

Dependencies point inward (`ui → state → data → domain`):

- `domain/**`: no other layer, no Flutter/io/ui imports; testable without a device.
- `data/**`: imports `domain/domain.dart` only.
- `state/**`: imports `domain/domain.dart`, `data/data.dart`.
- `ui/**`: imports `domain/domain.dart`, `state/state.dart`; never `data/`.
- **A layer another layer imports has a barrel**, its exact surface: no cross-layer `src/` imports. `ui/` needs none; only `main.dart` imports it, directly.
- Within a layer, `src/` files import by relative path; a barrel re-exports its own layer only.
- Within `ui/` ([ADR 25](adr/25-the-ui-groups-by-subject.md)): only `app.dart` and `screens/` files import `screens/`; files directly under `screens/` are `*_screen.dart`; nothing sits loose under `widgets/`; intra-`ui` imports are relative, never `package:cocktails/ui/…`.
- Within `domain/src/` ([ADR 26](adr/26-the-domain-groups-by-responsibility.md)): files are loose or in `collection/`, `shopping/` or `shelf/`; no folder imports a later one in `shelf/ → shopping/ → collection/ → loose`.

`test/architecture_test.dart` enforces these through `import`/`export` directives, on the real tree and constructed fakes. It pins the dependency list in [architecture.md](architecture.md#technology-stack) to `pubspec.yaml`, so a package taken without a written reason fails the suite. In `ui/` it reads `editCollection` (the write surface is `barWriterProvider`'s and absent for a guest bar: [ADR 23](adr/23-nothing-writes-a-guest-bar.md)) and `toLowerCase`/`toUpperCase` (the fold is `nameKey`'s: [ADR 08](adr/08-names-ignore-case.md)). Outside `ui/` the fold rule does not apply: `file_bar_store` slugs a name into a basename. Across `lib/`, a type named `Memory…`, `Fake…`, `Mock…` or `Stub…` is a test double and must live in `test/support/`.

## Domain contracts

Pure Dart: no I/O, clock or ambient randomness. Time- and chance-dependent values are passed in, a refresh time included.

### The shelf and the bar

`Shelf` is the root ([ADR 20](adr/20-the-app-holds-many-bars.md)): every bar the device holds, the open bar's id, and its collection. `Collection` keeps its shape; the level above is added, not folded in.

`Bar` splits by mode: `shopping` is an owner's; `source` and `refreshed` are a guest's (FR-SET-2, ADR 21, ADR 24). Shared fields are `name` (a label, not an identity: FR-BAR-1), `display` (FR-SET-1) and `offers` (FR-BAR-6). `contentWith` puts a record's name and unit over a collection, so an export and a LAN copy are one document. `id` is opaque and compared exactly: ids differing in case are two bars. `ShelfEdits` (`shelf_edits.dart`, as `CollectionEdits` is `collection_edits.dart`) holds `Shelf`'s pure derivations: add, replace, remove, open, offer, withdraw, and `refreshedWith` for a guest's payload.

`Shelf`'s constructor throws `ArgumentError` on a broken shelf, as `Collection`'s does: ids unique, owned names unique under the fold (FR-BAR-1), `openId` naming a bar, and the mode fixing which half of a record a bar carries. The invariants sit on `Shelf`, not `Bar`, because `validateShelf` takes built bars and a `Bar` constructor rule would crash on an untrusted index instead of reporting it. `collection` is empty while no bar is open; no screen reads it ([architecture.md](architecture.md#bars)). `Bar` compares the guest lists inside each `Offer` itself, as a record's `==` compares lists by identity.

**One collection is resident** (FR-BAR-1's "nothing crosses", as a fact): no second `Collection` exists to search, draw or jump into. Its memoised lookups go with the bar on show, so tens of bars cost one bar's index.

`refreshedWith` replaces collection and time together ([architecture.md](architecture.md#domain-computations)). It moves `collection` only for the open bar; refreshing another is a record edit here and a file write in the store. It never touches `name` or `display`, which come from the payload only when a bar is established.

### Entities and the collection root

`Ingredient`, `Tag`, `Amount`, `RecipeLine`, `UnitSizes`, `Recipe` and `Collection` are immutable `final class` values with structural equality. Their lists are `List.unmodifiable`, as lists are not `const`-constructible.

Identity conventions:

- **Vocabulary entries are entities; references are names.** `Collection.ingredients` holds `Ingredient` values; `RecipeLine.ingredients`, `Recipe.tags` and `Ingredient.tags` hold `String` names. No surrogate IDs: rename rewrites references ([architecture.md](architecture.md#system-overview)).
- **One name however it is capitalised** ([ADR 08](adr/08-names-ignore-case.md)). Every comparison (uniqueness, lookup, reference resolution, delete blocking, rename) goes through `nameKey`. The stored spelling is the one shown.
- **An ingredient answers to more than one name** ([ADR 10](adr/10-ingredient-aliases.md)). `Ingredient.aliases` holds them; `Ingredient.spellings` is name and aliases together, one namespace unique under the fold, indexed by `ingredientNamed` so no caller learns an alias exists. References are stored under the entry's own name, which only `withCanonicalIngredientNames` derives.
- **Two tag vocabularies are peers.** `Collection.recipeTags` and `Collection.ingredientTags` are separate `Tag` lists, unique within each ([ADR 07](adr/07-tag-colour.md)). `TagKind` names the side, and every tag operation takes one, so the UI never re-derives it.
- **A unit is an entry, not an enum** ([ADR 09](adr/09-units-are-a-vocabulary.md)). `Collection.units` is the vocabulary; `RecipeLine.unit` names into it. `FixedUnit` ([ADR 17](adr/17-the-fixed-units-interconvert.md)) holds the units no one may rename, which are also the readings `Bar.display` chooses among. `UnitSizes` holds each one's ml size (`partMl`, `ozMl`; ml is the anchor at 1). `ratio` derives any pair; `withRatio` writes one back, moving the trailing unit's size, so redefining the part keeps the ounce. Sizes belong to the owner and travel with the collection; the pick belongs to the reader and stays with the bar ([ADR 21](adr/21-the-file-carries-one-bar.md)). The [amounts screen](ui-design.md#amounts) and converted measures read this relation, not their own division.

Enum on-disk spelling is a declared field, never inferred from the Dart identifier: `StockLevel`, `FixedUnit` (also the reserved units, ADR 17), `LineMark` (ADR 06), `TagColor` (ADR 07, open to new members), `BarMode` and `Transport` each name their own wire token, since the index is a file too ([architecture.md](architecture.md#data-format)).

`RecipeLine.mark` holds one `LineMark?`, so a base line cannot also be optional (FR-REC-8). `isBase` and `isOptional` read it; `marked(LineMark?)` sets and clears it.

**A line names one or more ingredients** ([ADR 11](adr/11-substitutions-on-the-line.md)). `RecipeLine.ingredients` is a never-empty `List<String>` with no singular accessor, so each reader decides what a group means. It is the one entity list left unwrapped, since wrapping would cost the grammar's `const` constructor.

`Collection` answers reference questions itself (lookup by name, tag membership, the name sets every `validate…` call asks for), so no consumer builds an index. Lookups are a `late final` map built on first use: invisible to callers and O(1) after, as the recipe list, availability and optimizer need at NFR-2 scale. Name sets are memoised likewise. `ingredientSpellings` is built per call, leaving out the entry being edited, which must collide with neither its name nor its aliases.

### Two contracts, one rule set

Name uniqueness is checked in two places:

- `Collection`'s constructor throws `ArgumentError` on a duplicate: a programmer contract, as an existing Collection is well-formed. `Shelf`'s does the same for its invariants.
- `validateCollection` returns issues and never throws, since untrusted input is reported, not crashed. It runs on loose parts before construction. `validateShelf` is its index counterpart with the same kinds: a duplicate id or owned name is `duplicateName`, an unreadable token `malformedValue`.

Both use the single `duplicateNameIndexes` in `names.dart`.

### Editing the collection

Each edit is a pure derivation returning a new `Collection`, in `extension CollectionEdits on Collection`, so `collection.dart` keeps only shape and invariants. One method per vocabulary entry (add, replace, rename, remove for ingredients, tags and recipes); `withUnits` for the whole unit vocabulary; `recipesUsingIngredient`, `recipesUsingUnit` and `usersOfTag` for delete blocking (FR-VOC-1).

`withUnits` takes the whole vocabulary because the units screen edits it whole: each row carries its origin name, so a rename rewrites its lines and two units can trade names in one edit. Units compare exactly: a recapitalisation rewrites the lines too (ADR 08).

`withIngredient` takes `replacing` for the same reason: the entry dialog settles name, aliases and tags together, and a rename that drops or adopts an alias has no valid intermediate collection (ADR 10). A `replacing` naming no entry falls back to the entry's own name.

A tag edit touches only its own side: renaming a recipe tag never reads an ingredient, and `usersOfTag` blocks deletion from its side alone. `kind`, never the name, tells the two vocabularies apart.

Three rules: an edit for a missing entry returns unchanged (a stale name cannot crash); a name collision throws `ArgumentError` (programmer contract); removal never cascades, so the caller asks `recipesUsing…` first for the blocking message.

`copyWith` exists on multi-field values (`UnitSizes`, `Ingredient`, `Tag`, `RecipeLine`, `Recipe`, `Collection`, `Bar`); rename and stock are built on it; `Amount` is rebuilt whole. Null means "keep" to `copyWith`, so the one nullable field needing a hatch is `RecipeLine.marked`, which clears the mark.

Rebuilding `Collection` on every edit is deliberate: at a bar's scale it is a few thousand pointer writes, and immutability keeps derived-provider invalidation trivial. `Shelf` rebuilds the same way at lower cost: tens of records, the same `Collection` pointer carried across.

### Line grammar

One implementation, two entry points: `tryParseRecipeLine` gives the form non-throwing feedback; the codec uses `parseRecipeLine`, which throws, built on it. `formatRecipeLine` writes the canonical form; `lineMarkSuffix` writes the mark a card shows in prose.

Grammar: [architecture.md](architecture.md#data-format). This file enforces syntax; value rules live in collection_validation.dart. Both halves take the vocabulary (ADR 09), which decides what counts as a unit and how an amount is spelled. The line stores the unit's own name whichever spelling was typed; the unit is optional and may be plural on input. Alternatives split on `/` ([ADR 11](adr/11-substitutions-on-the-line.md)), lexically and after the mark, so the group is never resolved here. `amountText` stays in `src/`: the display transform builds its measure from that same piece.

### Validation

Contract and rationale: [ADR 05](adr/05-validation-contract.md). `ValidationIssueKind` names each failable rule: grammar's (ADR 06/11), unit sizes (ADR 17), and the codec's shape errors. `ValidationIssue` carries `kind`, a data-format `path` and a display-ready `message`. `validateCollection`, `validateRecipe`, `validateIngredient`, `validateTag`, `validateBarName` and `validateShelf` each return a `List<ValidationIssue>`; empty means valid.

Issues are collected in one pass, with no fail-fast, in file order (settings, units, ingredients, tags, recipes; by index within each), so the codec renders them as-is. `ValidationIssue` has value equality.

`path` uses **data-format key names** (`part_ml`, `ingredient_tags`), not Dart names, so the codec and a form can attach line numbers and focus without the domain knowing either. Behaviour switches on `kind`; `message` is display-only.

`validateCollection` is the whole-file entry, for import and for refresh (FR-BAR-5), so a file and a fetch are refused alike. The others check the one entry a form edits, with relative paths and an empty path for name. `other…Names` holds every *other* entry's name, and every *spelling* for ingredients (ADR 10), so a rename never collides with itself. All run the same rules and code.

### Computations

All pure functions of `Collection`; algorithms in [architecture.md](architecture.md#domain-computations). `randomCanMake` takes `Random` for testability. `basesOf` and `baseSpirits` read the base-spirit predicate (ADR 12). `purchasesWithin` is the optimizer; `keptPerSize` and `budgets` shape what it keeps per size (FR-DIS-6, ADR 15). `scaledAmountText` is the card's ×N and unit conversion.

`canMake` is the one reading of what the bar can manage now: low still counts; unjudged reads as missing. The optimizer asks the same question. `randomCanMake` draws over *candidates handed to it*, so "respecting active filters" costs the caller nothing. `besides` is the recipe already standing, skipped while another can be made, so a re-roll always moves; it is compared by name fold (ADR 08).

Base spirit is a predicate, not a placement ([ADR 12](adr/12-base-spirit-narrows.md)). `basesOf` takes every alternative of every base line, so a marked group answers under each ingredient it names. `baseSpirits` folds those through `Collection.spellingOf` *before* weighing repetition, so two spellings of one ingredient are one spirit, listed A→Z. `spellingOf` is the single home for "this name, under the entry's own", which the optimizer, `withCanonicalIngredientNames` and delete blocking also use.

`purchasesWithin` answers FR-DIS-6 ([ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md)); algorithm in [architecture.md](architecture.md#domain-computations). It keeps the best `keptPerSize` baskets *of each size*, so a one-ingredient win is never crowded out by the larger baskets that almost always unlock more. `restocking` defines "short" ([ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md), FR-DIS-7) as out only, or anything short of full stock; `isShortLine` (ingredient_stock.dart) decides it, the reading `availabilityOf` also judges "missing" by. `canMake` never moves; only the optimizer's goal does. One search at `budgets.last` answers every smaller budget, since a wider budget adds only ingredients no recipe is short of alone, which drop out as passengers. The screen reads a size off that one result ([ui-design.md](ui-design.md#shopping-screen)).

`scaledAmountText` is how a card reads amounts (FR-REC-7, FR-SET-1). Only the measure transforms, so only it is returned, one alternative at a time (ADR 11). `display` sits beside the sizes, not inside them, as the two belong to different owners on a guest bar (ADR 21). A line converts only where `FixedUnit.named` knows its unit and only into the unit `display` names; the sizes give the factor, and everything else prints as entered (ADR 17).

## Data contracts

Data layer owns: YAML, files, atomicity, backups, and what crosses to another device.

`ShelfIndex` (`bars`, `openId`) holds no collection. `BarStore` is the storage interface: `loadShelf` and `loadBar` read; `saveShelf`, `saveBar` and `removeBar` write; `exportSnapshot` copies. Each answers `Outcome<T>`: `Ok`; `Empty` (a load's "nothing stored yet"); `Rejected` (FR-DAT-4: issues and what could be recovered); or `Unreachable` (a fetch's).

`Outcome<T>` is one shape with three readings: a load reaches every case; `YamlCodec.decode` answers only `Ok` and `Rejected`; `BarChannel.fetch` answers all but `Empty`. A decode's result passes straight through a load or fetch; only a load's `recovered` is attached by hand.

The interface names no file and answers an export with an opaque location ([storage isolation](architecture.md#storage-isolation)). `loadShelf` and `loadBar` are separate so the bar list opens without reading a collection (NFR-2). `saveBar` takes the record beside the collection, as the file carries name and reading unit too ([ADR 21](adr/21-the-file-carries-one-bar.md)). The index is the authority: `loadBar`'s copy is read only when establishing a bar or rebuilding a lost index, and each `saveBar` writes the record's own back.

`exportSnapshot` takes the collection, not the store file: a session started from `Rejected` runs on a recovered backup, and the copy must match what is on screen ([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)). It is byte-identical to the store file regardless (canonical emitter).

`ExportPurpose` says why a copy is written, not where: `share` (FR-DAT-1), `beforeImport` and `beforeDelete` (the nets FR-DAT-3 and FR-BAR-2 ask for). Each maps to its own file ([platform facts](architecture.md#platform-facts)), so no act costs a reader the copy another just staged.

`newBarId` mints six hex characters per device in the data layer, keeping the domain free of ambient chance. `isStorableBarId` guards each id as a file name: `../secrets` is refused (`Rejected`), never resolved outside `bars/`.

Import is `YamlCodec.decode` + `saveBar`, not a store method, so confirmation and a pre-import export fit between (FR-DAT-3); a refresh reaches the same decode (FR-BAR-5). `SourcedIssue` and `Outcome` share a module, since every `Rejected` carries the one and the store and codec both answer the other. Splitting them would be the cross-layer coupling [ADR 02](adr/02-persistence-and-export-format.md) avoids.

`decode` pipeline (each stage feeds one issue list):
1. Parse YAML, retaining node spans.
2. Gate on `format`: 1 and 2 pass; anything else is rejected ([architecture.md](architecture.md#data-format)).
3. Read the tree into collection parts; shape errors name the offending node. Compact lines go through `tryParseRecipeLine` (problem → issue at line path). `units` is read first, since lines parse against it; an absent section means the shipped vocabulary (ADR 09).
4. Run `validateCollection` only if step 3 is clean, so broken shape cannot cascade into spurious reference errors.
5. Resolve `ValidationIssue.path` against the parse tree for line numbers.
6. Build `Collection` (cannot throw; duplicates ruled out), then `withCanonicalIngredientNames`, which holds an alias-named line under the ingredient's own name (ADR 10). Answer a `BarContent`: collection, file `name`, and `display` from `settings`. The caller keeps which of the three; an import and a refresh differ here (ADR 21). A format-1 file has no name; its `made:` was dropped at step 3.

Step 5 is **the only** place data-format keys bind to source positions. `decodeShelf` and `encodeShelf` are the same two halves over the index, judged by `validateShelf` and written by the same emitter: one canonical form, two documents.

`FileBarStore` writes via temp + rename, rotates each bar's own backups, and serialises every call through one queue (overlapping saves collapse). One queue, not one per bar: no two bars are written together, and a refresh behind an edit lands predictably. An unreadable bar falls back to its newest decodable backup and answers `Rejected`; neighbouring bars are untouched, and a lost index is rebuilt from the bar files. Load never throws (a damaged file is an FR-DAT-4 failure). The constructor takes a directory resolved at the composition root `main.dart`, keeping the adapter testable. File names and backup depth: [platform facts](architecture.md#platform-facts).

### The sharing seam

One interface per side, so a way that cannot do something has no method for it ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)). `BarChannel` is what every transport answers: its own `transport`, and `fetch(BarSource)` for the add and every refresh. `fetch` answers `Ok`, `Rejected` (FR-DAT-4) or `Unreachable` (FR-BAR-5), never `Empty`, which only a load can mean.

The endings ([architecture.md](architecture.md#sharing)) are values a caller must handle. A null means *no fetch happened* (the picker was dismissed): neither a refusal nor a silent source. `UnreachableReason` is closed, so adapters map their own errors onto it and the wording stays in the UI, which reads it from the domain beside `Transport`. `BarSource` is minted by the transport's side, so nothing above `data/` builds an address; `FileBarChannel.source` is the one empty address a file-sourced bar keeps.

`LanBarChannel` answers both halves: one device is one server and one announcement. Its `fetch` owns nothing. It resolves the instance afresh, reads what the device offers through `readOfferings` (the one document a stranger writes, gated on its own `lan_format` and answered whole or not at all), and takes bytes from the path that list names. Where the ask stopped picks the unreachable reading ([architecture.md](architecture.md#sharing)). `channelsProvider` and `offeringsProvider` name that one adapter.

The sharing side is `BarOfferings` (offer and withdraw, FR-BAR-6), serving guest and owned bars alike. `LanBarChannel` is the first and so far only transport to answer it; a file is handed over, not offered, so nothing follows it to withdraw.

- `BarOfferings` takes and drops one bar by id, and owns what comes up with the first offer and goes down with the last: one server and one service instance per device, never per bar ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)). Both are held as the futures that raise them, so concurrent offers raise one of each.
- The announcement crosses the platform behind `LanAnnouncer`, so the lifecycle is tested against a real loopback server with only the announcing stood in for.
- `BarFinder` (`nearby`, FR-BAR-8) and the `Found` entry a browse answers land with the guest's half. A browse runs only while a reader is looking; `nearbyProvider` is how a screen asks.
- `BarOfferings` is handed *the bytes of a bar id*, not a `BarStore`, since an offered bar is usually not the one on show (ADR 20). The composition root supplies `exportOf`: the bar's collection under the record's own name and unit, through the canonical emitter. It is named, not inlined, so it is provable without a socket. Name and unit come from the record, not the bar file's header, since a rename or unit pick moves the index and no bar file.
- The announced name is a supplier, read at each announcement, so a rename takes effect without rebuilding a live adapter ([ADR 28](adr/28-the-device-is-named-by-its-reader.md)).
- The file channel implements `BarChannel` alone: its `fetch` is the picker's text decoded, so a refresh is the reader handing over a newer file (FR-BAR-7). `Transport.cloud` has no channel, so the registry has no entry for it.

## State contracts

`barStoreProvider` and `channelsProvider` are the device-free seams (ADR 22). `main.dart` overrides the store with the file adapter; tests use `MemoryBarStore` or fakes. A transport absent from the map has no adapter in this build: `refresh` meets it as `Unreachable`. `clockProvider` stamps refreshes (FR-BAR-5), so the domain needs no clock. `ShelfController.reach` is the add's own fetch, answering an `Arrival`: a review to agree to or refuse, or the reason nothing came, worded in `ui/`.

`platformNameProvider` is overridden at the composition root from `platformDeviceName()`. `deviceNameProvider` is the one place the reader's name and the phone's are weighed against each other ([ADR 28](adr/28-the-device-is-named-by-its-reader.md)).

`sharerProvider` and `filePickerProvider` are the seams at the platform edge ([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)). A share takes the opaque location `export(id)` answered with. A pick answers `Future<String?>` (text, not `XFile`), so widget tests need no file. There is no type filter: YAML has no MIME type Android's table knows, and the decode judges either way (FR-DAT-4). The bytes-to-text step decodes UTF-8 itself: `XFile.readAsString` drops the requested encoding on Android's bytes-backed files, losing every name's diacritics ([architecture.md](architecture.md#platform-facts)).

`export`, `setDisplay`, `renameBar`, `offerBar` and `withdrawBar` work on a guest bar too (FR-DAT-1, FR-BAR-3, FR-BAR-6, ADR 21): a guest bar is named, read in and shared by its reader. `replaceOpen` refuses a guest bar, since FR-DAT-3's import runs only into an owned bar. `export` takes any bar id. `renameBar` re-announces every way the bar is offered, so offering again is how a way is renamed. `addOwnedBar`'s optional `from` is a file with no kept source, so it never refreshes. `addGuestBar` keeps the source for refresh; `fileSource` republishes `FileBarChannel.source` so `ui/` builds no address (ADR 22). Each mutating method has one call site, which is why they live here and not on the writer (ADR 23).

`ShelfController.build()` is the only writable provider. It runs the startup load and opens the bar the index names. A `Rejected` bar starts on its recovered backup; issues reach the UI through `loadIssuesProvider` as `"line N: message"` strings (FR-DAT-4). An index naming no open bar, or one not held, still opens on what is held. No index is a first run and founds a bar; an index listing none means the reader deleted their last (the store's `Empty` versus an `Ok` with no bars). Each mutation awaits the startup load, derives through a `CollectionEdits` method, publishes, then saves only what moved: the collection only where the bar under it stayed put, the index only where a record or the open bar changed. An unchanged collection is not saved. `review(text)` is a pure decode shared by import and the picked-file flow, so confirmation slots in without `ui/` touching `data/`.

**The write surface is separate from the controller** ([ADR 23](adr/23-nothing-writes-a-guest-bar.md)). `barWriterProvider` answers a `BarWriter?`, null on a guest bar, so its null is the same fact that hides the control (FR-BAR-4). A screen reads it once in `build` and passes the non-null writer to whatever it hands a control, so control and write are one decision, and `ui/` has no `!` to get wrong. UI never constructs a `Collection`, holds a `BarStore`, `BarChannel` or `YamlCodec`, or reaches the notifier ([ADR 03](adr/03-app-structure-and-state.md), ADR 23).

**What a bar holds rides on its record** (ADR 20). `Bar.summary` and `Bar.updated` are written only through `ShelfEdits.withCollection`, so listing bars reads the index and no second `Collection` reaches `ui/`. A record predating summaries reads `summary` as null; the controller repairs it once under the startup spinner, without backdating `updated`.

Everything else is derived and read-only. `collectionProvider` answers a `Collection`, never an `AsyncValue`. The shell ([ui-design.md](ui-design.md#app-shell)) is the one place the startup load is met: it draws no screen until it has answered, so reading this provider earlier throws. `availabilityProvider` and `purchasesProvider` rely on the same guarantee. `openBarProvider` answers the open bar's record, null once the shelf has loaded, which is what makes the bar list home ([ui-design.md](ui-design.md#bars)); `barsProvider` answers every record. `availabilityProvider` is one `availabilityOf` pass per collection change, read per line (`stockOfLine`) as well as per recipe, so cards dim by the rule behind the verdict (ADR 11). `recipeTagsProvider` and `ingredientTagsProvider` sort each vocabulary once per change (ADR 08). Filter, search and order stay in screen-local state, since nothing collection-derived reads them. The random pick (FR-DIS-5) needs no provider: the list draws over the rows it shows.

`purchasesProvider` keys on a `ShoppingQuery`: what counts as short (ADR 16), and the tags the search aims at, empty while the chips sift (ADR 24). The rest of the optimizer's input comes from the bar's `ShoppingSettings` (FR-SET-2), so a setting change recomputes without re-keying. It is `autoDispose` and watched only while the shopping screen is on show, since `IndexedStack` keeps every screen alive and a stock tap elsewhere would fire a search nobody reads. It is remade on return, not kept; the search costs about 100ms at NFR-2 scale.

`revealProvider` is the fourth kind of state: one screen's request of another ([ADR 19](adr/19-a-destination-sends-the-reader-to-another.md)). It is a nullable, one-shot `Reveal?` (a destination and a name) that the shell watches only to switch; the serving screen clears it on arrival, which is safe because Riverpod copies its listener list before dispatch. `destinationsOf(BarMode)` (`ui/destinations.dart`) gives three destinations on an owned bar and two on a guest (FR-BAR-4). The shell indexes its stack by position in that list, never by `Destination`'s own index.

### Work in flight

Refreshing and sharing are the app's first work outliving the gesture that started it: the **fifth kind of state**, a job the reader may walk away from. In-flight refreshes live in `refreshes.dart`, resolved through `channels.dart`.

An offer splits where a refresh does not. The **offer** is the reader's intent and rides on `Bar.offers` into the index; the **announcement** is a socket and service registration, living no longer than the app, so what is announced now is state beside the refreshes.

`refreshesProvider` is a `Map<String, RefreshState>` by bar id: `Reaching`, or what the last ask failed with and when, until `told`. Dismissing the banner and reporting it in a snackbar both mark it `told`. Failures are `RefreshRefused` (carrying the issues already described; `ui/` never meets a `SourcedIssue`) or `RefreshUnreachable` (carrying the closed reason it words itself, FR-BAR-5). No entry means nothing out. No screen awaits a refresh: under NFR-2, *a refresh never holds up the bar on show*, and screens learn only through this map. Each ask carries a token; a late answer is dropped if its bar is gone or a newer ask was made. A guest collection has no other writer, so a late answer loses nothing.

Sharing lasts as long as the app: the startup load empties every bar's offers, so nothing is announced on the way in and no switch claims a network the process is no longer on.

`sharingProvider` is a `Map<String, SharingState>` by bar id, the owner's side of the same shape: `Announcing` while an offer goes up, `Silencing` while a withdrawal comes down, and `SharingFailed` (what stopped it, and when) until `told`. **The record moves first and the network second**, so an offer that could not be announced still stands on the bar. A transport with no adapter in this build reads as a refused announcement, since nothing reaches the network either way. Offering a way already offered, or withdrawing one never offered, tells the device nothing.

Performance facts (no over-engineering):
- Every mutation replaces the whole `Collection`, so collection-derived values recompute. With hundreds of recipes the availability pass takes < 1ms; incremental updates are unneeded (NFR-2).
- The optimizer is the sole expensive computation and the sole reason a screen is told whether it is on show. It runs on the main thread: arrival, budget moves and switch flips are moments a reader has just acted, and an isolate would cost copying the collection and a spinner on every edit.
- Opening a bar and landing a refresh each cost one decode, the work startup already does on the main thread. Reaching the source is async I/O and yields. If a decode is measured to jank the bar on show, the fix is an isolate around that one call; nothing above the store moves.

## Data flows

1. **Startup**: `main` overrides `barStoreProvider` → `ShelfController.build()` reads the index and opens the bar it names → `Ok` seeds state; `Rejected` seeds that bar's recovered backup and surfaces issues; no index runs the format-1 migration ([architecture.md](architecture.md#storage-isolation)) or mints one empty owned bar.
2. **Edit**: widget takes `barWriterProvider` and calls `setStock(…)` → `CollectionEdits` returns a new `Collection` → `withCollection` publishes it → UI rebuilds → the open bar's file is enqueued.
3. **Recipe form**: `tryParseRecipeLine` per field (live feedback) → `validateRecipe` on save (`lines[i]` paths map to fields; else snackbar) → recipe, new ingredients and rename reach `upsertRecipe` as one edit (ui-design.md#recipe-form).
4. **Export** (FR-DAT-1): `export(id)` hands the bar and its collection to `exportSnapshot` and returns the location; the Share room passes it to `sharerProvider` and says nothing unless that throws. A guest bar exports as an owned one does (FR-BAR-4).
5. **Import** (FR-DAT-3/4): `BarFormScreen.importing` opens with nothing in hand. `filePickerProvider` yields a document's text, which `review` decodes; a bar picked nearby is fetched by `reach` and reviewed the same way. The form shows issues, or what arrived and the two roads (FR-BAR-7/8). `replaceOpen` keeps the `beforeImport` copy, publishes and saves; `addGuestBar` writes a new bar instead. The screen then leaves for the collection; only Replace says what it did (ui-design.md#data). `BarFormScreen.founding` is the same screen: the entry decides only whether the owner's road founds a bar or replaces the open one, and whether a bar of nothing may be saved.
6. **Reaching a row** (FR-DIS-9): a name tapped on one destination resolves to the entry's own (`spellingOf`) and reaches `revealProvider.ask` → the shell switches and records what it left → the serving screen clears the request, its picks and open cards, and hands the name to `EntryCardList` for one build → the list clears search and order, goes home, scrolls to the row and washes it (ADR 13, ADR 19).
7. **Switching bars** (FR-BAR-1): `openBar(id)` publishes record and collection together, so no frame pairs one bar's record with another's recipes; only the index is written → the shell rebuilds every screen under the open bar, so no narrowing, open card or jump trail survives → the screen pops to the root. A bar already loaded asks `Reveals.land` for the recipes instead and pops to the same place (ADR 19).
8. **Adding a guest bar** (FR-BAR-3): a picked or nearby source reaches `channel.fetch`. `Ok` becomes a bar with a minted id, the name typed in the form, the payload's display, and the source kept for next time. `Rejected` reads as an import's issues; `Unreachable` says which of the three. The form `review`s the file itself, so counts show before a road is chosen; only the chosen road reaches the controller.
9. **Refreshing** (FR-BAR-5): `refresh(id)` marks the bar reaching. The fetch runs off the gesture; `refreshedWith` replaces collection and time, never the name or reading unit the reader picked (ADR 21). The bar on show is written like any edit; another bar's file is written by `refresh` itself (ADR 20). A failure leaves the bar as it stood, held in `refreshesProvider`. The gesture is `EntryCardList.onRefresh` (non-null only on a guest bar, `refreshOf`); the `RefreshFailure` banner over the destinations meets the answer. The pull awaits the fetch only to retract its spinner. Settings' **Refresh** row reads the answer itself (`Refreshes.standing`), tells it in a snackbar and marks it `told`: one answer, one telling.
10. **Deleting a bar** (FR-BAR-2): confirmed, exported under `beforeDelete` (owned bars only; a guest's contents belong to its owner, FR-BAR-3), then the record, then the file and its backups, in that order, since a record outliving its file opens onto nothing. Deleting the open bar leaves none open, and the bar list becomes home.

## Testing

### Where a test lives

`test/` mirrors `lib/` one file to one file: `lib/domain/src/shelf/bar.dart` is tested by `test/domain/shelf/bar_test.dart` and by nothing else, which tests only what `bar.dart` owns. A test file is named for the source file whose behaviour it holds to account, even when it drives that through the barrel: `yaml_writer_test.dart` and `yaml_bar_reader_test.dart` both call `YamlCodec` through its barrel ([ADR 04](adr/04-module-boundaries.md)) but are named for the file each checks. Every file under a `test/` subfolder ends `_test.dart`.

Only `architecture_test.dart` (the whole tree) and `support_test.dart` (the support) sit at the root of `test/` unmirrored. A file exercised only through its callers earns no test file: a handful of domain/data helpers (`list_edits.dart`, `yaml_primitives.dart`), and more often a small `ui/` widget or dialog whose behaviour the composing screen test drives (`dialog_frame.dart`, `field_issues.dart`, `empty_state.dart`, most of `cards/`, `chips/` and `forms/`).

**A plugin has no implementation under `flutter test`**, so what only a device can answer is not a test here. `lan_discovery.dart` is checked by hand against a target, and its findings are written to [platform facts](architecture.md#platform-facts) ([ADR 27](adr/27-nearby-comes-off-bonsoir.md)). Everything above it takes the seam, keeping the rest of the LAN transport testable.

### Support

Code under `test/` that is not a test is **support**, the only word for it. It lives in `test/support/`, one file per layer (`domain_test_support.dart`, `data_test_support.dart`, `state_test_support.dart`), plus `memory_bar_store.dart` for what more than one layer reads, the double named in its own file. `ui/` is the exception: fixtures, harness and finders change for three different reasons, so `ui_fixtures.dart`, `ui_harness.dart` and `ui_finders.dart` stand apart. Names saying what a helper *asserts*, not what kind it is, stay: `barStoreContract`, `tokenVocabulary`, `valueEquality`.

What one test file alone reads stays in it; what a second reaches for moves to support, so no test file imports another.

### Per layer

- **Domain**: unit tests, no device; clock and randomness passed in. `Shelf`'s invariants and its refusal to edit a guest collection (ADR 23) are unit tests like any other.
- **Data**: codec unit-tested (round-trip FR-DAT-5, broken-file decode with line numbers, a format-1 file read and written back as 2). `FileBarStore` integration-tested: atomic write, backups, recovery, and one bar's save leaving every other bar's bytes unchanged. Channels are tested against a fake.
- **State**: controller tests against `MemoryBarStore` and fake channels: a mutation updates state and reaches the store; a refresh lands or is dropped as stale; a guest bar hands out no writer.
- **UI**: widget tests for critical flows. The file transport composes from `filePickerProvider`, so a test drives the *real* channel by overriding the picker alone: a file pulled, a damaged one, or nothing. `Unreachable` is reached by seeding a bar sourced `cloud`, which has no adapter in this build. `ui_harness.dart` stands up the overrides. **What a guest bar refuses is tested on each screen it reaches, in that screen's own file**: `bar_writer_test.dart` holds the one fact, `guestListOffersNoWrite` the shared one (the add button and a row's menu, for every list screen a guest can only read).
- **Boundaries**: the rules under Boundary rules, enforced by `test/architecture_test.dart`.

### What earns a test

A test earns its place if it can fail for a reason a reader would care about, and nothing else fails for that reason first.

Write one for a requirement or ADR rule; for a boundary the code cannot express (a refusal, an ordering, an invariant, an edge: none, one, many, absent); and for a defect that reached the branch once. Don't for what the type system, the analyzer or a constructor already refuses; for a framework's own contract; or for a second sample of a rule already proven over a table: that case joins the table.

One rule, one test: where a fact is pinned in two places, a change must visit both, and the second drifts. A rule over several types or vocabularies gets one parametrised body run over each, not a copy each: `tokenVocabulary` and `valueEquality` in `support/domain_test_support.dart`, `barStoreContract` in `support/data_test_support.dart`, `vocabulary` in `collection_edits_test.dart`. Each case in such a table carries a `reason` naming it, so a failure says which.
