# Components

Module-level design: structure, layers, interfaces, data flows. System: [architecture.md](architecture.md); boundaries: [ADR 04](adr/04-module-boundaries.md); screens: [ui-design.md](ui-design.md).

## Module map

Each layer is a folder with a barrel file. **The barrel is the entire public surface**; 
everything else under `src/`.

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

`domain/src/names.dart` holds the one fold behind every name comparison 
([ADR 08](adr/08-names-ignore-case.md)) — `nameKey`, `nameKeys`, `sameName`, `compareNames` — 
exported, so a list that sorts or a chip that narrows reads the rule rather than restating it.

## Boundary rules

Three visibility levels:

| Marking | Scope | Use for |
|---|---|---|
| `_name` | the file | helpers used in one file |
| public in `src/`, not exported | the layer | logic shared between files of one layer |
| exported from the barrel | the app | the layer's contract with other layers |

Dependencies point inward (`ui → state → data → domain`):

- `domain/**`: no other layer, no Flutter/io/ui imports. Plain Dart, testable without device.
- `data/**`: imports `domain/domain.dart` only.
- `state/**`: imports `domain/domain.dart`, `data/data.dart`.
- `ui/**`: imports `domain/domain.dart`, `state/state.dart`; never `data/`.
- **A layer another layer imports has a barrel**, which is exactly its surface: no `src/`
  dependencies across layers. `ui/` needs none, since only `main.dart` imports it, and directly.
- Within layer: `src/` files import by relative path.
- Barrel re-exports own layer only (no sibling re-export).
- Within `ui/` ([ADR 25](adr/25-the-ui-groups-by-subject.md)): only `app.dart` and files under 
  `screens/` import `screens/`; every file directly under `screens/` is named `*_screen.dart`; 
  nothing sits loose under `widgets/` — every file sorts into one of its groups; every intra-`ui` 
  import is relative, never `package:cocktails/ui/…`.
- Within `domain/src/` ([ADR 26](adr/26-the-domain-groups-by-responsibility.md)): every file is
  loose or sits in `collection/`, `shopping/`, or `shelf/`; a folder never imports one later in its
  own chain — `shelf/ → shopping/ → collection/ → loose`.

`test/architecture_test.dart` enforces via `import`/`export` directives (pure functions, 
exercised on constructed inputs and real tree). It also pins the dependency list in 
[architecture.md](architecture.md#technology-stack) to `pubspec.yaml`, so a package taken without 
a written reason fails the suite, and it reads two names in `ui/` source: `editCollection`, since 
the write surface is `barWriterProvider`'s and does not exist for a guest bar 
([ADR 23](adr/23-nothing-writes-a-guest-bar.md)), and `toLowerCase`/`toUpperCase`, since the fold 
behind a name comparison is `nameKey`'s ([ADR 08](adr/08-names-ignore-case.md)). Outside `ui/` the 
fold rule does not apply — `file_bar_store` folds a bar's name into a file basename, which is a slug 
rather than a comparison. Across the whole of `lib/` it reads one more: a type named `Memory…`, 
`Fake…`, `Mock…` or `Stub…` is a test double, and a double lives in `test/support/` rather than in 
what ships. The four `ui/`-only rules above are the same suite's, over the real tree and over 
constructed fake inputs alike.

## Domain contracts

Pure Dart, no I/O, no clock, no randomness taken from ambient state — anything time- or
chance-dependent is passed in, which is what keeps the layer unit-testable, a refresh time included.

### The shelf and the bar

`Shelf` is the root ([ADR 20](adr/20-the-app-holds-many-bars.md)): every bar the device holds, which 
one is open, and that one's collection. `Collection` keeps its whole shape — it is one bar's 
contents, and the level above it is added rather than folded in.

`Bar` carries the fields a mode splits in two: `shopping` and `offers` are an owner's, `source` and 
`refreshed` a guest's (FR-SET-2, ADR 21, ADR 24), the two shared fields being `name` (a label, not 
an identity — FR-BAR-1) and the reader's own `display` (FR-SET-1). `id` is opaque and minted 
on-device, compared exactly rather than folded, so two ids differing in case are two bars. 
`ShelfEdits` (`shelf_edits.dart`, as `CollectionEdits` is `collection_edits.dart`) is `Shelf`'s own 
set of pure derivations — adding, replacing or removing a bar by id, opening one, and 
`refreshedWith` for a guest's incoming payload.

`Shelf`'s constructor throws `ArgumentError` on a broken shelf, the programmer contract `Collection`'s own 
constructor already keeps: ids unique, `openId` naming a bar that exists, and the mode deciding which 
half of a record a bar may carry. That coherence sits on `Shelf` rather than on `Bar` for the reason 
`Ingredient` has no invariants and `Collection` has them all: `validateShelf` takes bars already 
built, so a rule `Bar`'s constructor kept would be one an untrusted index could never be *reported* 
on — it would crash on the way in instead. `collection` is an empty `Collection` while no bar 
is open, and no screen can read it then — the shell offers no destination without a bar 
([architecture.md](architecture.md#bars)). `Offer` is a record, comparing its fields with `==`, so 
`Bar` compares the guest lists inside its offers itself, two offers built apart being equal in every 
part but list identity.

**One collection is resident**, which is what makes FR-BAR-1's "nothing crosses" a fact rather than a 
rule: there is no second `Collection` for a search, a draw or a jump to reach into, and 
`Collection`'s memoised lookups stay built for the bar on show and thrown away with it, so tens of 
bars cost one bar's worth of index.

`refreshedWith` takes the name and the time as well as the collection, a refresh replacing all three 
([architecture.md](architecture.md#domain-computations)); it moves `collection` only where the 
refreshed bar is the one open, so refreshing another is a record edit here and a file write in the 
store. It never touches `display` — the payload's own is read only where a bar is established.

### Entities and the collection root

`Ingredient`, `Tag`, `Amount`, `RecipeLine`, `UnitSizes`, `Recipe`, `Collection` are 
immutable `final class` values with structural equality. Collections wrapped `List.unmodifiable` 
— lists not `const`-constructible.

Two identity conventions:

- **Vocabulary entries are entities; references are names.** `Collection.ingredients` holds 
  `Ingredient` values; `RecipeLine.ingredients`, `Recipe.tags`, `Ingredient.tags` hold `String` names. 
  No surrogate IDs — rename is a mutation rewriting references ([architecture.md](architecture.md#system-overview)).
- **One name however it is capitalised** ([ADR 08](adr/08-names-ignore-case.md)). Every comparison — 
  uniqueness, lookup, reference resolution, delete blocking, rename — goes through `nameKey`; the 
  spelling stored is the spelling shown. Lookup maps are keyed by the fold, so resolution stays O(1).
- **An ingredient answers to more than one name** ([ADR 10](adr/10-ingredient-aliases.md)). 
  `Ingredient.aliases` holds them and `Ingredient.spellings` is the name and the aliases together — 
  one namespace, unique under the fold, indexed by `ingredientNamed` so no caller learns an alias 
  exists. A reference is stored under the entry's own name, `withCanonicalIngredientNames` being the 
  one derivation that puts it there, wherever the line came from.
- **Two tag vocabularies are peers.** `Collection.recipeTags` and `Collection.ingredientTags` are separate 
  `Tag` lists, unique within each ([ADR 07](adr/07-tag-colour.md)). A `Tag` carries no scope: 
  `TagKind` names the side, and every tag operation takes one rather than existing twice under two 
  names — which is also what keeps the UI from re-deriving the distinction to abstract over it.
- **A unit is an entry, not an enum** ([ADR 09](adr/09-units-are-a-vocabulary.md)). `Collection.units`
  is the vocabulary, `RecipeLine.unit` a name into it, and the three the app leans on are `FixedUnit` 
  ([ADR 17](adr/17-the-fixed-units-interconvert.md)) — one enum for the units no one may rename and 
  the readings `Bar.display` chooses among, since they are the same three. `UnitSizes` holds 
  each one's size in ml (`partMl`, `ozMl`, ml being the anchor at 1), so `ratio` derives any pair 
  rather than storing it, and `withRatio` writes one back — moving the trailing unit's size, so 
  redefining the part leaves the ounce where it stood. The pick itself is not there: the sizes are 
  the owner's and travel with the collection, the pick is the reader's and stays with the bar 
  ([ADR 21](adr/21-the-file-carries-one-bar.md)). Both a converted measure and the 
  [amounts screen](ui-design.md#amounts) read the relation there rather than dividing themselves.

Enum on-disk spelling is declared as a field, never inferred from the Dart identifier — 
`StockLevel`, `FixedUnit` (also the reserved units, ADR 17), `LineMark` (ADR 06), `TagColor` 
(ADR 07, open to new members), `BarMode` and `Transport` all name their own wire token this way, the 
index being a file like any other ([architecture.md](architecture.md#data-format)).

`RecipeLine.mark` holds that one `LineMark?`, so a base line can never also be optional
(FR-REC-8); `isBase` and `isOptional` are getters over it, and `marked(LineMark?)` is what
sets and clears it — `copyWith` cannot, since null is its "keep what you have".

**A line names one or more ingredients** ([ADR 11](adr/11-substitutions-on-the-line.md)).
`RecipeLine.ingredients` is a never-empty `List<String>` with no singular accessor, so every reader
decides for itself what a group means rather than quietly taking the first. It is the one entity
list left unwrapped: `List.unmodifiable` would cost the `const` constructor the grammar leans on.

`Collection` answers reference questions directly — lookup by name, tag membership, and the name 
sets every `validate…` call asks for — so no consumer builds its own index. These are backed by a 
`late final` map built on first use. `Collection` stays immutable and the memoisation is invisible; 
a lookup is O(1) after the first call, which is what the recipe list, availability, and the 
optimizer all need at NFR-2 scale. The name sets are memoised on the same terms, so a form judging a 
name on every keystroke builds one once instead of one per frame. `ingredientSpellings` is the 
exception, built per call: every caller leaves an entry out of it — the one being edited, which must 
collide with neither its own name nor its own aliases.

### Two contracts, one rule set

Name uniqueness checked in two places:

- `Collection` constructor throws `ArgumentError` on duplicate (programmer contract: existing Collection 
  is well-formed). `Shelf`'s does the same for its own invariants.
- `validateCollection` returns issues, never throws (data contract: untrusted input reported, not crashed). 
  Works on loose parts before Collection construction. `validateShelf` is its counterpart over the index's 
  parts, reusing the same kinds — an id twice over is a `duplicateName`, an unreadable token a 
  `malformedValue`.

Both use single `duplicateNameIndexes` in `names.dart`.

### Editing the collection

Every edit is a pure derivation returning a new `Collection`, in `extension CollectionEdits on Collection` 
so `collection.dart` holds shape and invariants — one method per vocabulary entry (add/replace/rename/
remove for ingredients, tags and recipes), `withUnits` for the vocabulary whole, and 
`recipesUsingIngredient`/`recipesUsingUnit`/`usersOfTag` for delete blocking (FR-VOC-1).

`withUnits` takes the vocabulary whole because the units screen edits it whole: a row carries the
name it came from, so a rename rewrites every line measured in it and two units can trade names in
one edit. Compared exactly, not folded — a recapitalisation is the same unit under a new spelling,
and the lines take it too (ADR 08).

`withIngredient` takes its `replacing` for the same reason, one step down: the entry dialog settles
name, aliases and tags together, and a rename that also lets an alias go — or takes the old name on
as one — has no valid collection to stop at halfway (ADR 10). A `replacing` naming no entry falls back to
the entry's own name, so a stale name still cannot crash.

A tag edit touches only its own side: renaming a recipe tag never reads an ingredient, and
`usersOfTag` blocks deletion from its own side only. One name may stand in both vocabularies and
mean two different things, so the `kind` is what tells them apart, never the name.

Three rules: edit for missing entry returns unchanged (stale name can't crash). Collision with 
existing name throws `ArgumentError` (programmer contract). Removal never cascades (caller asks 
`recipesUsing…` first for blocking message).

`copyWith` on multi-field values (`UnitSizes`, `Ingredient`, `Tag`, `RecipeLine`, `Recipe`, `Collection`, 
`Bar`); rename and stock built from it. `Amount` is rebuilt whole. One nullable field needs its own 
hatch, since null is `copyWith`'s "keep what you have": `RecipeLine.marked` clears the mark.

Rebuilding `Collection` on every edit is deliberate (a bar's scale: few thousand pointer writes; keeps all 
immutable, derived provider invalidation trivial). `Shelf` above it rebuilds on the same terms and 
costs less — a list of records tens long, and the same `Collection` pointer carried across.

### Line grammar

One implementation, two entry points (form gets non-throwing feedback via `tryParseRecipeLine`; 
codec uses the throwing `parseRecipeLine` built on it), plus `formatRecipeLine` for the canonical 
form and `lineMarkSuffix` for the mark a card writes in prose.

Grammar in [architecture.md](architecture.md#data-format). This file enforces syntax; value rules in collection_validation.dart. Both halves take the vocabulary (ADR 09): it decides what counts as a unit and how an amount is spelled, and the line stores the unit's own name whichever spelling was typed. The unit is optional and may be plural on the way in; `formatRecipeLine` writes the canonical form for the file and the form alike. Alternatives split on `/` ([ADR 11](adr/11-substitutions-on-the-line.md)), lexically and after the mark, so the group is never resolved here. `amountText` stays public in `src/` and out of the barrel — the display transform builds its measure from that same piece rather than a second spelling of it.

### Validation

Contract and rationale: [ADR 05](adr/05-validation-contract.md). `ValidationIssueKind` names each 
rule that can fail (grammar's own — ADR 06/11, unit sizes — ADR 17, and the codec's own shape 
errors among them); `ValidationIssue` carries the `kind`, a data-format `path` and a ready-to-display 
`message`. `validateCollection`, `validateRecipe`, `validateIngredient`, `validateTag` and 
`validateShelf` all answer a `List<ValidationIssue>`, empty meaning valid.

Issues collected in one pass (no fail-fast), top-to-bottom like file 
(settings, units, ingredients, tags, recipes, within each by index). Lets codec render as-is. 
`ValidationIssue` has value equality.

`path` uses **data-format key names** (`part_ml`, `ingredient_tags`), not Dart names. Seam lets 
codec attach YAML line numbers, form attach field focus, without domain knowing either. 
Behaviour switches on `kind`; `message` is display-only.

`validateCollection`: whole-file entry point for import, and for what a refresh brings (FR-BAR-5) — one 
judgement, so a file and a fetch are refused on the same terms and worded alike. Others check the 
single entry a form edits — the ingredient, the tag, the recipe — in one call: paths relative, empty 
for name. `other…Names` holds every *other* entry's name — every *spelling* for the ingredient 
vocabulary, whose namespace holds aliases too (ADR 10) — so a rename never collides with itself. All 
four run same rules, same code.

### Computations

All pure functions of `Collection`. Algorithms in [architecture.md](architecture.md#domain-computations). 
`randomCanMake` takes `Random` for testability; `basesOf`/`baseSpirits` read the base-spirit 
predicate (ADR 12); `purchasesWithin` is the optimizer, `keptPerSize` and `budgets` shaping how much 
of each size it keeps (FR-DIS-6, ADR 15); `scaledAmountText` is the card's own ×N and unit 
conversion.

`canMake` is the one reading of what the bar can manage now — low still counts, unjudged reads as
missing. The optimizer (FR-DIS-6) asks the same question, so it asks it here. `randomCanMake` draws
over *candidates handed to it* rather than over the collection, so "respecting active filters" costs
the caller nothing; `besides` is the recipe already standing, skipped while another can be made, so
a second roll always moves and is compared by name fold like every name (ADR 08).

Base spirit is a predicate, not a placement ([ADR 12](adr/12-base-spirit-narrows.md)): `basesOf` 
takes every alternative of every base line, so a marked group answers under each ingredient it names; 
`baseSpirits` folds those into the filter's offer through `Collection.spellingOf` *before* weighing 
repetition, so two spellings of one ingredient are one spirit, A→Z. `spellingOf` is the one home for 
"this name, under the entry's own", which the optimizer, `withCanonicalIngredientNames` and delete 
blocking all ask for too — comparison running through `names.dart`, which every layer reads, so no 
screen folds a name itself.

`purchasesWithin` answers FR-DIS-6 ([ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md)); 
the algorithm is in [architecture.md](architecture.md#domain-computations). It keeps the best 
`keptPerSize` baskets *of each size*, not overall, so a one-ingredient win is never crowded out by 
the three-ingredient baskets that almost always unlock more. `restocking` is what "short" means 
([ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md), FR-DIS-7) — out only, or anything short 
of full stock — decided once in `isShortLine` (ingredient_stock.dart), the same reading 
`availabilityOf` judges "missing" by; `canMake` itself never moves, only the optimizer's own goal.
One search at `budgets.last` answers every smaller budget too: a wider budget only adds ingredients 
no recipe is short of alone, so they close nothing and are dropped as passengers, which is what lets 
the screen search once and read a size off the result ([ui-design.md](ui-design.md#shopping-screen)).

`scaledAmountText` is how a card reads a line's amounts (FR-REC-7, FR-SET-1) — the measure is the 
only half that transforms, so it is the only half returned, one alternative at a time (ADR 11). 
`display` sits beside the sizes rather than inside them, since the two belong to different owners on 
a guest bar (ADR 21); a line converts only where `FixedUnit.named` answers for its unit and only 
into the one `display` names, the two sizes giving the factor and everything else printing as 
entered (ADR 17).

## Data contracts

Data layer owns: YAML, files, atomicity, backups, and what crosses to another device.

`ShelfIndex` is the index's own shape (`bars`, `openId`), with no collection in it. `BarStore` is 
the storage interface: `loadShelf`/`loadBar` separate reads, `saveShelf`/`saveBar`/`removeBar` 
writes, and `exportSnapshot` for a copy. Every one of them answers `Outcome<T>` — `Ok`, `Empty` (a 
load's own "nothing stored yet"), `Rejected` (FR-DAT-4, carrying issues and what could be recovered) 
or `Unreachable` (a fetch's own).

`Outcome<T>` is one shape, three readings: a load reaches every case, `YamlCodec.decode` answers 
only `Ok`/`Rejected` (never having a backup or a "nothing stored" of its own), and `BarChannel.fetch` 
every case but `Empty` (a fetch has nothing to say "nothing stored yet" of). One shape means a 
decode's `Ok`/`Rejected` needs no conversion at all where a load or a fetch reads it straight through; 
only attaching a load's `recovered` remains hand-written.

The interface names no file and answers an export with an opaque location, which is the whole of 
[storage isolation](architecture.md#storage-isolation). `loadShelf` and `loadBar` are separate 
because the bar list must open without reading a collection (NFR-2), and `saveBar` takes the record 
beside the collection because the file carries the bar's name and reading unit as well as its 
contents ([ADR 21](adr/21-the-file-carries-one-bar.md)). Name and reading unit therefore stand in 
two files at once, and the index is the authority: `loadBar`'s copy of them is read only where a bar 
is being established or a lost index rebuilt, and every `saveBar` writes the record's own back.

`exportSnapshot` takes the collection rather than copying the store file: a session started from 
`Rejected` runs on a recovered backup, and the copy must be the collection on screen, not the file 
that failed to decode ([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)). Byte-identical 
to that bar's store file regardless, the emitter being canonical.

`ExportPurpose` is why a copy is written, not where it goes: `share` is FR-DAT-1's, `beforeImport` 
and `beforeDelete` the nets FR-DAT-3 and FR-BAR-2 ask for. The store maps each to its own file 
([platform facts](architecture.md#platform-facts)), so no one act can cost a reader the copy another 
just staged — and no caller learns a name.

`newBarId` mints six hex characters per device, in the data layer rather than the domain, which 
stays pure of ambient chance; `isStorableBarId` stands beside it because an id is also a file name — 
minted ones are always safe, but the index is a file like any other and one carrying `../secrets` is 
refused (`Rejected`) rather than resolved outside `bars/`.

Import is `YamlCodec.decode` + `saveBar`, not a store method, so confirmation and a pre-import export 
can slot between (FR-DAT-3) and a refresh can reach the same decode by another road (FR-BAR-5). 
`SourcedIssue` and `Outcome` share a module for the same reason: every `Rejected` carries the one, 
and both the store and the codec answer the other, so keeping them apart would be the cross-layer 
coupling [ADR 02](adr/02-persistence-and-export-format.md) avoids.

`decode` pipeline (each stage feeds one issue list):
1. Parse YAML, retain node spans.
2. Gate on `format`; 1 and 2 pass, anything else is rejected 
   ([architecture.md](architecture.md#data-format)).
3. Read tree to collection parts; shape errors reported against offending node; compact lines through 
   `tryParseRecipeLine` (problem → issue at line path). `units` is read first — the lines are 
   parsed against it, and an absent section is the shipped vocabulary (ADR 09).
4. Run `validateCollection` on parts (referential, value rules) only if step 3 clean (broken shape 
   never cascades to spurious reference errors).
5. Resolve `ValidationIssue.path` against parse tree for line numbers.
6. Build `Collection` (cannot throw; duplicates ruled out), then `withCanonicalIngredientNames` — a
   hand-edited line naming an ingredient by an alias is held under the ingredient's own name (ADR 10) — and 
   answer a `BarContent`: the collection, the file's `name`, and the `display` read out of 
   `settings`. Who keeps which of the three is the caller's, and it is where an import and a refresh 
   differ (ADR 21). A format-1 file carries no name and its `made:` was dropped at step 3.

Step 5 is **only** place data-format keys bind to source positions (domain has no YAML knowledge). 
`decodeShelf`/`encodeShelf` are the same two halves over the index, judged by `validateShelf` and 
written by the same emitter — one canonical form, two documents.

`FileBarStore` writes via temp + rename, rotates that file's own backups, and serialises every call 
through one queue (overlapping saves collapse). One queue rather than one per bar: two bars are 
never written in the same breath, and a single order is what makes a refresh landing behind an edit 
predictable. An unreadable bar falls back to its newest decodable backup and answers `Rejected` with 
issues and recovery; the bars beside it are not touched, and a lost index is rebuilt from the bar 
files. Load never throws (damaged file = FR-DAT-4 failure). Constructor takes directory (platform 
path resolved at composition root `main.dart`), keeps adapter testable. File names, backup depth: 
[platform facts](architecture.md#platform-facts). `MemoryBarStore` (`test/support/`) for tests.

### The sharing seam

One interface per side, so a way that cannot do something does not carry a method for it 
([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)). `BarChannel` is what every transport answers: 
its own `transport`, and `fetch(BarSource)` for the add and every refresh after.

`fetch` answers in the same `Outcome<T>` a load and a decode do — `Ok`, `Rejected` (FR-DAT-4) or 
`Unreachable` (FR-BAR-5), never `Empty`, which only a load has a "nothing stored" of its own to mean.

The endings ([architecture.md](architecture.md#sharing)) are values a caller must handle rather than 
an exception it may forget, and a null one is *no fetch happened*: the file transport's picker 
dismissed, which is neither a refusal nor a source gone silent. `UnreachableReason` is closed, so an 
adapter maps its own errors onto it and the wording stays the UI's — and it sits in the domain 
beside `Transport`, `ui/` being what words it and reading no further down than there. `BarSource` is 
minted by the side that knows the transport, so nothing above `data/` ever builds an address; the 
file transport has none to build, and `FileBarChannel.source` is the one empty address every 
file-sourced bar keeps.

The owner's side — `BarOfferings` (offer/withdraw, FR-BAR-6) and `BarFinder` (`nearby`, FR-BAR-8) — 
lands with the LAN channel that first implements them, along with the `Found` entry a browse 
answers. `BarOfferings` takes and drops one bar by id, and the adapter behind it owns everything that 
comes up with an offer and goes down with the last — one server and one service instance per device, 
never per bar ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)). It is handed *the bytes of a bar 
id* rather than a `BarStore`: an offered bar is usually not the one on show and only one collection 
is resident (ADR 20), so the composition root supplies a function over a load and the canonical 
emitter — the seam `filePickerProvider` already is, and what keeps a test free of a socket. 
`BarFinder.nearby` answers `Found` entries — the source to keep and what to call it — and is asked 
only while a reader is looking. The file channel implements `BarChannel` alone: its `fetch` is the picker's text decoded, 
so a refresh is the reader handing over a newer file and there is nothing to offer or withdraw 
(FR-BAR-7). No cloud channel exists yet and the registry has no entry for that transport, which is 
how FR-BAR-9 waits without blocking anything.

## State contracts

`barStoreProvider` and `channelsProvider` are the device-free seams (ADR 22): `main.dart` overrides 
the store with the file adapter, tests with `MemoryBarStore` or a map of fakes. A transport absent 
from the map has no adapter in this build, which is what a `refresh` meets as `Unreachable`. 
`clockProvider` stamps when a refresh landed (FR-BAR-5) so the domain needs no clock of its own.

`sharerProvider` and `filePickerProvider` are the two seams crossing the platform edge 
([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)): a share takes the opaque location 
`export()` answered with, and a pick answers `Future<String?>` — text, not the platform's `XFile`, 
so a widget test hands the flow a string and no file is needed to exercise it. No type filter: 
YAML has no MIME type Android's table knows, and FR-DAT-4's decode is the judge either way. The 
bytes-to-text step decodes UTF-8 itself rather than trusting `XFile.readAsString`, which drops the 
encoding it is asked for on the bytes-backed file Android answers with and cost the diacritics of 
every name on the way in ([architecture.md](architecture.md#platform-facts)).

`export`, `setDisplay` and `renameBar` all work on a guest bar (FR-DAT-1, FR-BAR-3, ADR 21) — what a 
bar is called or read in is the reader's, on someone else's bar as on their own — while 
`replaceOpen` refuses one, FR-DAT-3's import running only into an owned bar. `addOwnedBar`'s 
optional `from` is a file with no source kept, so nothing about such a bar refreshes; `addGuestBar` 
keeps the source, which is what a refresh asks again (`fileSource` republishing 
`FileBarChannel.source` so `ui/` never builds an address itself, ADR 22). All of the controller's 
mutating methods take one call site each, which is why they sit here rather than on the writer 
(ADR 23).

`ShelfController.build()` is the only writable provider: it performs the startup load, opens the 
bar the index names, and reports what failed — a `Rejected` bar starts on its recovered backup, and 
issues reach the UI through `loadIssuesProvider` as `"line N: message"` strings (FR-DAT-4). An index 
naming no open bar, or naming one it does not hold, still opens on whatever it does hold; no index 
at all is a first run and founds a bar, while an index listing none is a reader who deleted their 
last — the store's `Empty` versus an `Ok` with no bars is where that distinction lives. Every 
mutation runs the same path: await the startup load, derive through a `CollectionEdits` method, 
publish, and save only what moved — a collection only where the bar under it stayed put (an edit, 
not a crossing), the index only where a record moved or the open bar changed. An edit that leaves 
the collection unchanged is not saved. `review(text)` is a pure decode used by both import and the 
picked-file flow, so the confirmation and the pre-import copy can slot after it without `ui/` 
touching `data/` itself.

**The write surface is separate from the controller** ([ADR 23](adr/23-nothing-writes-a-guest-bar.md)): 
`barWriterProvider` answers a `BarWriter?`, null on a guest bar, so the null a screen may get back 
is the same fact that hides the control (FR-BAR-4). A screen reads it once in `build` and passes the 
non-null writer down to whatever it hands a control, so the control and the write are the same 
decision — there is no `!` left in `ui/` to be wrong about it. UI never constructs a `Collection`, 
never holds a `BarStore`, and never reaches the notifier directly 
([ADR 03](adr/03-app-structure-and-state.md), ADR 23).

**What a bar holds rides on its record** (ADR 20): `Bar.summary`/`Bar.updated` are written only by 
crossing a collection through `ShelfEdits.withCollection`, so listing bars reads the index and no 
second `Collection` ever reaches `ui/`. A record from before summaries existed reads `summary` as 
null; the controller repairs it once under the startup spinner rather than backdating an `updated` 
nobody wrote.

Everything else is derived and read-only. `collectionProvider` answers a `Collection`, never an 
`AsyncValue` of one — the startup load is met in exactly one place, the shell 
([ui-design.md](ui-design.md#app-shell)), which draws no screen until it has answered, so reading 
this provider before the shelf has landed throws rather than standing in with an empty collection 
nobody wrote; `availabilityProvider` and `purchasesProvider` lean on the same guarantee. 
`openBarProvider` answers the open bar's record and `barsProvider` every record on the shelf, the 
former answering null once the shelf has loaded being what puts the bar list on screen as home 
([ui-design.md](ui-design.md#bars)). `availabilityProvider` is one `availabilityOf` pass per 
collection change, read directly by line (`stockOfLine`) as well as by recipe, so a card dims the 
alternatives it lacks against the same rule the verdict was reached by (ADR 11). 
`recipeTagsProvider`/`ingredientTagsProvider` sort each vocabulary once per change rather than per 
build (ADR 08). Filter, search and order stay in screen-local widget state rather than a provider: 
nothing collection-derived reads them, and the random pick (FR-DIS-5) turned out not to need one 
either — the draw is made *by* the list, over the rows it is already showing.

`purchasesProvider` keys on a `ShoppingQuery` (what counts as short — ADR 16 — and the tags the 
search is aimed at, empty while the chips sift — ADR 24); the rest of what the optimizer is asked 
comes off the bar's own `ShoppingSettings` (FR-SET-2), so a setting change re-keys nothing and 
simply recomputes. Searched once at `budgets.last` so the screen reads one size off the one answer. 
`autoDispose`, and watched only while the shopping screen is the destination on show, since 
`IndexedStack` keeps every screen alive and a stock tap elsewhere would otherwise fire a search 
nobody is reading; the answer is remade on return rather than kept, the search costing about 100ms 
at NFR-2 scale.

`revealProvider` is the fourth kind of state, one screen's request of another 
([ADR 19](adr/19-a-destination-sends-the-reader-to-another.md)): a nullable, one-shot `Reveal?` — a 
destination and a name — that the shell watches only to switch, the serving screen clearing it on 
arrival. Clearing it inside that listener is safe because Riverpod copies its listener list before 
dispatch, so the shell still hears the request it is being cleared out of. `destinationsOf(BarMode)` 
(`ui/destinations.dart`) answers what the bottom bar offers — three on an owned bar, two on a guest 
(FR-BAR-4) — and the shell indexes its stack by position in that list, never by `Destination`'s own 
index, which is the one place a variable destination list is felt.

### Work in flight

Refreshing and sharing are the app's first work outliving the gesture that started it, and the 
**fifth kind of state**: not collection, not derived, not screen-local, not one screen's request of 
another, but a job the reader may walk away from. A refresh in flight lives in
`refreshes.dart`; the transports one is resolved through, in `channels.dart`.

An offer is the same kind of work from the owner's side, and splits where a refresh does not: the 
**offer** is the reader's intent and rides on `Bar.offers` into the index, where the **announcement** 
is a socket and a service registration living no longer than the app. So what is announced right now 
— and what an announcement failed with — is state beside the refreshes in flight, and a bar carrying 
an offer is announced again at startup rather than quietly un-offering itself.

`refreshesProvider` — `Map<String, RefreshState>` by bar id: `Reaching`, or what it last failed with 
and when, until it is `told`, which is what dismissing the banner and reporting it in a snackbar 
both come to — `RefreshRefused` carrying issues already described (`ui/` never meets a `SourcedIssue`) 
and `RefreshUnreachable` the closed reason it words itself (FR-BAR-5). A bar with no entry has 
nothing out and nothing to be met. No screen awaits a refresh, which is what NFR-2's *a refresh never holds up the 
bar on show* comes to in practice: the reader goes on reading and editing while one is out, and the 
screens are told only through this map. A late answer is dropped where its bar is gone or a newer 
ask has been made (each carries a token, only the newest lands); a guest bar's collection has no 
other writer, so there is nothing else for one to lose.

Performance facts (no over-engineering):
- Every mutation replaces the whole `Collection` → all collection-derived recompute. Hundreds of recipes: 
  availability pass < 1ms; incremental unneeded (NFR-2).
- Optimizer is the sole expensive computation, and the sole reason a screen is told whether it is on 
  show. Runs on the main thread: it is spent on arriving, on moving the budget and on flipping the 
  switch — all moments a reader has just acted — where an isolate would buy the time back at the 
  price of copying the collection and a spinner on every edit.
- Opening a bar and landing a refresh both cost one decode, the same work startup has always done on 
  the main thread. Reaching the source does not: it is async I/O and yields. Should a decode ever be 
  measured to jank the bar on show, the way out is an isolate around that one call, and nothing 
  above the store would move.

## Data flows

1. **Startup**: `main` overrides `barStoreProvider` → 
   `ShelfController.build()` reads the index and opens the bar it names → `Ok` seeds state, 
   `Rejected` seeds that bar's recovered backup + surfaces issues, no index at all runs the format-1 
   migration ([architecture.md](architecture.md#storage-isolation)) or mints one empty owned bar.
2. **Edit**: widget takes `barWriterProvider` and calls `setStock(…)` → `CollectionEdits` returns a new 
   `Collection` → `withCollection` publishes it → UI rebuilds → the open bar's file is enqueued.
3. **Recipe form**: `tryParseRecipeLine` on each field (live feedback) → `validateRecipe` on 
   save (`lines[i]` paths map to fields; else snackbar) → recipe + new ingredients + rename name 
   reach `upsertRecipe` as one edit (ui-design.md#recipe-form).
4. **Export** (FR-DAT-1): `export()` hands the bar on screen and its collection to `exportSnapshot` 
   and returns the location; the screen passes that to `sharerProvider` and says nothing unless it 
   throws. A guest bar exports exactly as an owned one does (FR-BAR-4).
5. **Import** (FR-DAT-3/4): `filePickerProvider` answers with a document's text → `review` decodes 
   it → the pushed `BarFormScreen.importing` shows the issues, or what the file holds and the two 
   roads open to it (FR-BAR-7) → `replaceOpen` keeps the `beforeImport` copy, publishes, saves; 
   `addGuestBar` mints an id and writes a new bar instead → the screen leaves for the collection, 
   Replace alone saying what it did (ui-design.md#data). It is the same screen `BarFormScreen.founding` 
   builds: one file, one form, the entry deciding only whether the owner's road founds a bar or 
   replaces the open one.
6. **Reaching a row** (FR-DIS-9): a name tapped on one destination resolves to the entry's own 
   (`spellingOf`) and reaches `revealProvider.ask` → the shell switches and records what it left → 
   the serving screen clears the request, its own picks and the open cards, and hands the name to 
   `EntryCardList` for one build → the list clears its search and order, goes home, then scrolls to 
   the row and washes it (ADR 13, ADR 19).
7. **Switching bars** (FR-BAR-1): a card's **Open bar** calls `openBar(id)` → the controller loads 
   that bar and publishes record and collection together, so no frame pairs one bar's record with 
   another's recipes, and the index alone is written → the shell's subtree is keyed by the open bar, 
   so every screen is built anew and no narrowing, open card or jump trail survives the crossing → 
   the screen pops to the root, landing the reader in the bar rather than back on the gear. The bar
   already loaded has nothing to read again, so it asks `Reveals.land` for the recipes instead and
   pops to the same place (ADR 19).
8. **Adding a guest bar** (FR-BAR-3): a source — picked, or found nearby — reaches `channel.fetch` 
   → `Ok` becomes a bar with a minted id, the name the reader left in the form, the payload's 
   display, and the source kept for next time; `Rejected` reads as an import's issues do, 
   `Unreachable` says which of the three. The form picks and `review`s the file itself, so the 
   reader sees the counts before choosing a road, and only the chosen road reaches the controller.
9. **Refreshing** (FR-BAR-5): `refresh(id)` marks the bar reaching and is never awaited by a screen 
   → the fetch runs off the gesture → `refreshedWith` replaces collection and time, never the name 
   or the reading unit the reader picked (ADR 21); the bar on show is written the same way any edit 
   is, and any other bar's file by `refresh` itself, only one collection ever being resident 
   (ADR 20) → a failure leaves the bar as it stood, held in `refreshesProvider` to be met. Each ask 
   carries a token: an answer arriving behind a newer ask, or for a bar deleted meanwhile, is 
   dropped whole rather than landing on top of it. The gesture is `EntryCardList.onRefresh`, 
   non-null only on a guest bar (`refreshOf`), and the answer is met by the `RefreshFailure` banner 
   over the destinations — the pull awaits the fetch only to retract its own spinner, which is not a 
   screen holding up the bar on show. Settings' **Refresh** row asks the same way from behind that 
   banner, so it reads the answer itself (`Refreshes.standing`), says it in a snackbar and marks it 
   `told` — one answer, one telling, whichever of the two the reader met.
10. **Deleting a bar** (FR-BAR-2): confirmed, exported under `beforeDelete` — owned bars only, a 
    guest's contents being its owner's (FR-BAR-3) — then the record, then the file and its backups, 
    in that order, since a record outliving its file is a bar that opens onto nothing. A deleted open 
    bar leaves the shelf with none open, and the bar list becomes home under the reader.

The controller is the UI's only route to the data layer; screens never hold a `BarStore`, a 
`BarChannel` or a `YamlCodec`.

## Testing

### Where a test lives

`test/` mirrors `lib/` one file to one file: `lib/domain/src/shelf/bar.dart` is tested by 
`test/domain/shelf/bar_test.dart` and by nothing else, and that file tests nothing but what 
`bar.dart` owns. A test file is named for the source file whose behaviour it holds to account, 
even where it drives that behaviour through the layer's barrel — `yaml_writer_test.dart` and 
`yaml_bar_reader_test.dart` both call `YamlCodec`, because the barrel is the layer's only surface 
([ADR 04](adr/04-module-boundaries.md)), but each is named for the file that owns what it checks. 
Every file under a `test/` subfolder ends `_test.dart`.

Two kinds of file are not a mirror of anything, and only those sit at the root of `test/`: 
`architecture_test.dart`, which reads the whole tree, and `support_test.dart`, which holds the 
support below to account. A file exercised only through its callers earns no test file of its own —
true of a handful of domain/data helpers (`list_edits.dart`, `yaml_primitives.dart`) and, more often,
of a small `ui/` widget or dialog whose whole behaviour is driven by the screen test that composes
it (`dialog_frame.dart`, `field_issues.dart`, `empty_state.dart`, most of `cards/`, `chips/` and
`forms/` alike).

**A plugin has no implementation under `flutter test`**, so what only a device can answer is not a 
test here at all: `lan_discovery.dart` is exercised by hand against a target and its findings are 
written to [platform facts](architecture.md#platform-facts) rather than held by a suite 
([ADR 27](adr/27-nearby-comes-off-bonsoir.md)). Everything above it takes the seam instead, which is 
what keeps the rest of the LAN transport testable without one.

### Support

Code under `test/` that is not itself a test is **support**, and that is the only word for it: no 
harnesses, kits, fixtures or toolkits as separate categories. It lives in `test/support/`, one file 
per layer — `domain_test_support.dart`, `data_test_support.dart`, `state_test_support.dart` — with 
`memory_bar_store.dart` for what more than one layer reads, the double named in its own file rather 
than a generic one. `ui/` is the one exception: fixtures, harness and finders change for three 
different reasons, so `ui_fixtures.dart`, `ui_harness.dart` and `ui_finders.dart` stand apart — what 
one test file alone reads still goes home to it rather than joining any of the three. Names that say 
what a helper *asserts* rather than what kind of helper it is stay as they are: `barStoreContract`, 
`tokenVocabulary`, `valueEquality`.

What one test file alone reads stays in that file; what a second file reaches for moves to support. 
That is the whole of the rule, and it is why no test file imports another.

### Per layer

- **Domain**: unit tests, no device. Pure functions; clock/randomness passed in. `Shelf`'s 
  invariants and its refusal to edit a guest bar's collection (ADR 23) are unit tests like any other.
- **Data**: codec unit-tested (round-trip FR-DAT-5, broken-file decode with line numbers, a 
  format-1 file read and written back as 2). `FileBarStore` integration-tested (atomic write, 
  backups, recovery, and one bar's save leaving every other bar's bytes byte-for-byte as they were). 
  Channels are tested against a fake for the seam.
- **State**: controller tests vs `MemoryBarStore` and fake channels; a mutation updates state and 
  reaches the store, a refresh lands or is dropped as stale, a guest bar hands out no writer.
- **UI**: widget tests for critical flows. The file transport is composed from `filePickerProvider`, 
  so a widget test drives the *real* channel by overriding the picker alone — a pull answered with a 
  file, a damaged one, or nothing — and reaches `Unreachable` by seeding a bar sourced `cloud`, 
  which this build has no adapter for. `ui_harness.dart` stands the store and channel overrides up. 
  **What a guest bar refuses is tested on each screen it reaches, in that screen's own file**:
  `bar_writer_test.dart`'s one fact and `guestListOffersNoWrite`'s (the add button and a row's menu,
  shared by every list screen a guest can only read), each screen's reading of it still that
  screen's.
- **Boundaries**: `test/architecture_test.dart` enforces imports, the dependency list, the one 
  route to a write, the one fold behind a name, and that no double ships.

### What earns a test

A test earns its place if it can fail for a reason a reader would care about, and nothing else 
fails for that reason first.

Write one for a requirement or ADR rule; for a boundary the code cannot express — a refusal, an 
ordering, an invariant, an edge (none, one, many, absent); and for a defect that reached the branch 
once. Don't for what the type system, the analyzer or a constructor already refuses; for a 
framework's own contract; or for a second sample of a rule already proven over a table — that case 
joins the table.

One rule, one test: where a fact is pinned in two places a change has to visit both, and the second 
one drifts. A rule holding over several types or vocabularies gets one parametrised body run over 
each, not a copy each — `tokenVocabulary` and `valueEquality` in `support/domain_test_support.dart`, 
`barStoreContract` in `support/data_test_support.dart`, `vocabulary` in `collection_edits_test.dart`. 
Every case in such a table carries a `reason` naming it, so a failure says which one.
