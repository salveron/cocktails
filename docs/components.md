# Components

Module-level design: structure, layers, interfaces, data flows. System: [architecture.md](architecture.md); boundaries: [ADR 04](adr/04-module-boundaries.md); screens: [ui-design.md](ui-design.md).

## Module map

Each layer is a folder with a barrel file. **The barrel is the entire public surface**; 
everything else under `src/`.

```
lib/
  main.dart                    # ProviderScope, store and channel overrides, CocktailsApp
  domain/
    domain.dart                # barrel — the only domain import other layers use
    src/
      shelf.dart               # Shelf, the root above Collection (ADR 20), and the bar it
                               #   holds: Bar, BarMode, Transport, BarSource, Offer,
                               #   BarPayload. Bar.summarised and Bar.refreshedAt are the
                               #   only writers of what a bar holds and when it changed.
                               #   enumFromToken, the token lookup it shares
                               #   with collection.dart, is layer-private like names.dart
      shelf_edits.dart         # extension ShelfEdits on Shelf — pure derivations,
                               #   the guest-bar refusal among them (ADR 23)
      collection.dart          # entities, Collection — one bar's contents — name lookups,
                               #   wornInOrder, the unit vocabulary and its lookup (ADR 09)
      collection_edits.dart    # extension CollectionEdits on Collection — pure derivations
      line_format.dart         # compact-line grammar
      validation.dart          # ValidationIssue + rule set, otherNames
      availability.dart        # Availability, availabilityOf, canMake, stockOfLine, stockOf
      scaling.dart             # ×N scaling, part↔ml display
      discovery.dart           # basesOf, baseSpirits, marksBase, randomCanMake
      optimizer.dart           # Purchase, purchasesWithin — what to buy next
      names.dart               # not exported: nameKey, nameKeys, sameName,
                               #   compareNames, repeatsName, duplicateNameIndexes,
                               #   listEquals
  data/
    data.dart                  # barrel — the store, the channels, the codec, their results
    src/
      sourced_issue.dart       # SourcedIssue — shared by the store and the codec
      bar_store.dart           # the storage interface and its outcome types
      bar_channel.dart         # the sharing seam: fetch, offer, withdraw, find (ADR 22)
      file_channel.dart        # FR-BAR-7 — the picker's text, decoded
      lan_channel.dart         # FR-BAR-8 — DNS-SD registration and browse, HTTP both ways
      yaml_codec.dart          # decode/encode of a bar and of the index, version gate
      yaml_reader.dart         # YAML tree → collection parts, with source spans
      yaml_writer.dart         # canonical emitter
      file_bar_store.dart      # one file per bar, the index, atomic write, rotation
      memory_bar_store.dart    # in-memory double for state and widget tests
  state/
    state.dart                 # barrel — every provider over the shelf
    src/
      shelf_controller.dart    # the one writable provider (ADR 23)
      bar_writer.dart          # the write surface, handed out for an owned bar only
      seams.dart               # store, clock, share sheet, picker — one provider each
                               #   (ADR 18); the clock so the domain needs none
      channels.dart            # the transports resolved, the refreshes in flight and
                               #   what they failed with, the offers standing (ADR 22)
      derived.dart             # read-only over the shelf: the open bar's collection and
                               #   record, every record on it, availability, the optimizer
  ui/                          # no barrel — leaves, imported directly; design in ui-design.md
    app.dart                   # MaterialApp and the shell: app bar, gear, the stack, and
                               #   the trail a jump leaves for back to undo (ADR 19)
    destinations.dart          # what destinations a bar offers and how one screen asks
                               #   another to reveal a named row — the same subject, so one
                               #   file (ADR 19). The one provider outside the state layer
    theme.dart                 # the seed colour, the two schemes, `dimmedInk` — the one
                               #   dim, worn by a hint and by an ingredient the bar lacks
    palette.dart               # the fixed hues — the tag palette, and the one traffic
                               #   light worn by stock, by availability and by whose bar
                               #   it is (`barModeColors`) — beside `neutralSwatch`, the
                               #   ground a chip meaning nothing by its colour stands on
                               #   (ADR 12), which is off scheme roles for that reason
    screens/                   # one file per destination, plus settings, tags, units,
                               #   amounts, recipe form, bars — the list that is also
                               #   home wherever none is open — and the owner's view of
                               #   what a bar is shared by, that last shaped by
                               #   ui-design.md once it is settled. settings_screen holds
                               #   both halves of the data exchange (ADR 18) and, on a
                               #   guest bar, the refresh that stands in its import's
                               #   place; bar_form_screen is where a file picked at either
                               #   end is read and agreed to, founding and importing being
                               #   one form reached two ways
    widgets/                   # empty_state, search_field,
                               #   telling — how the app says what it could not do: the
                               #     load and refresh banners over every destination, the
                               #     one wording of what a refresh came to, and the
                               #     snackbar a refused action speaks through
                               #   arriving_bar — one file arriving, read the same way
                               #     wherever it was picked: the pick, the counts, the
                               #     refusal, and the pull a guest bar's lists answer
                               #   color_chip — the pill, chip, dot, the run of dots a name
                               #     or a basket's recipe wears, the dotted name itself, and
                               #     `chipRadius`, the corner a chip and its ink round to
                               #   tag_choices — the row tags are picked from
                               #   vocabulary_list — the searchable list all four screens are:
                               #     the orders it reads in, the spellings it searches by, the
                               #     tag filter three screens narrow by (the shopping one
                               #     taking the row without the list), the draw one of them
                               #     offers over the rows on show, the row another destination
                               #     asks it to reveal (ADR 19), the bulleted runs a card body
                               #     names things in, the row itself and the margin it is
                               #     inset by — the lists' own by default, overridden by a
                               #     form that pads its page already — byName, Set.toggle,
                               #     and counted — how many of a thing there are, in words.
                               #     The one file that knows a list scrolls (ADR 13)
                               #   vocabulary_dialogs — entry (name, aliases, colour, tags),
                               #     a bare name where only that is asked for, delete,
                               #     discard, plus VocabularyEntry and the one reading of
                               #     issue paths into fields every form shares
                               #   editor_form — the pushed editor both forms wear: the
                               #     Save/discard frame and the self-growing row list
test/                          # mirrors lib/, plus test/architecture_test.dart
```

`domain/src/names.dart` holds the name rules shared between domain files (layer-private, not 
exported) — `nameKey`/`sameName` among them, the one fold behind every name comparison 
([ADR 08](adr/08-names-ignore-case.md)).

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
- Layer's surface is exactly its barrel: no `src/` dependencies across layers. `ui/` exception 
  (no barrel; `main.dart` imports leaves).
- Within layer: `src/` files import by relative path.
- Barrel re-exports own layer only (no sibling re-export).

`test/architecture_test.dart` enforces via `import`/`export` directives (pure functions, 
exercised on constructed inputs and real tree). It also pins the dependency list in 
[architecture.md](architecture.md#technology-stack) to `pubspec.yaml`, so a package taken without 
a written reason fails the suite, and it keeps `ui/` off `shelfProvider.notifier` — the write 
surface is `barWriterProvider`'s, which does not exist for a guest bar 
([ADR 23](adr/23-nothing-writes-a-guest-bar.md)).

## Domain contracts

Pure Dart, no I/O, no clock, no randomness taken from ambient state — anything time- or
chance-dependent is passed in, which is what keeps the layer unit-testable, a refresh time included.

### The shelf and the bar

`Shelf` is the root ([ADR 20](adr/20-the-app-holds-many-bars.md)): every bar the device holds, which 
one is open, and that one's collection. `Collection` keeps its whole shape — it is one bar's 
contents, and the level above it is added rather than folded in.

```dart
enum BarMode { owner('owner'), guest('guest'); … }
enum Transport { file('file'), lan('lan'), cloud('cloud'); … }              // FR-BAR-7/8/9
typedef Offer = ({Transport via, List<String> guests});   // empty where a way cannot name them
typedef BarPayload = ({String name, FixedUnit display, Collection collection});  // what a file holds

final class BarSource {          // where a guest bar refreshes from (FR-BAR-5)
  final Transport via;
  final String at;               // the transport's own address; opaque above data/
  final String from;             // what to call it where a source is read
}

final class Bar {
  final String id;               // minted on this device, never written to a bar's file;
                                 //   opaque, so compared exactly — ADR 08's fold is a rule
                                 //   for names, and two ids differing in case are two bars
  final String name;             // a label: two bars may carry one (FR-BAR-1)
  final BarMode mode;
  final FixedUnit display;       // the reader's pick, outliving every refresh (FR-SET-1)
  final List<Offer> offers;      // an owner's, one per way it is shared (FR-BAR-6)
  final BarSource? source;       // a guest's, with…
  final DateTime? refreshed;     // …when that source last answered
  bool get isOwned;
}

final class Shelf {
  final List<Bar> bars;
  final String? openId;          // null where no bar is open — first run, or the last deleted
  final Collection collection;        // the open bar's, and the only one resident
  Bar? get open;
  Bar? barWithId(String id);
}

extension ShelfEdits on Shelf {         // shelf_edits.dart, as CollectionEdits is collection_edits.dart
  Shelf withCollection(Collection collection);      // throws on a guest bar (ADR 23)
  Shelf withBar(Bar bar);                      // add or replace by id — rename, offers, source
  Shelf withoutBar(String id);                 // FR-BAR-2; a deleted open bar leaves openId null
  Shelf opening(String id, Collection collection);  // the switch: record and bytes at once
  Shelf refreshedWith(String id, BarPayload payload, DateTime at);   // FR-BAR-5, guest only
}
```

`Shelf`'s constructor throws `ArgumentError` on a broken shelf, the programmer contract `Collection`'s own 
constructor already keeps: ids unique, `openId` naming a bar that exists, and the mode deciding which 
half of a record a bar may carry — a guest carries the source it refreshes from and offers nothing, 
being no device's to give away twice, while an owner carries neither source nor refresh time and 
offers a bar once per transport. That coherence sits on `Shelf` rather than on `Bar` for the reason 
`Ingredient` has no invariants and `Collection` has them all: `validateShelf` takes bars already 
built, so a rule `Bar`'s constructor kept would be one an untrusted index could never be *reported* 
on — it would crash on the way in instead. `collection` is an empty `Collection` while no bar 
is open, and no screen can read it then — the shell offers no destination without a bar 
([architecture.md](architecture.md#bars)).

`Offer` is a record, and a record compares its fields with `==` — so `Bar` compares the guest lists 
inside its offers itself, two offers built apart being equal in every part but list identity.

**One collection is resident**, which is what makes FR-BAR-1's "nothing crosses" a fact rather than a 
rule: there is no second `Collection` for a search, a draw or a jump to reach into. It also leaves 
`Collection`'s memoised lookups exactly as they were — built for the bar on show and thrown away with it, 
so tens of bars cost one bar's worth of index.

`refreshedWith` takes the name and the time as well as the collection, a refresh replacing all three 
([architecture.md](architecture.md#domain-computations)); it moves `collection` only where the 
refreshed bar is the one open, so refreshing another is a record edit here and a file write in the 
store. It never touches `display` — the payload's own is read only where a bar is established.

### Entities and the collection root

`Ingredient`, `Tag`, `Amount`, `RecipeLine`, `Settings`, `Recipe`, `Collection` are 
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
  the readings `Bar.display` chooses among, since they are the same three. `Settings` holds 
  each one's size in ml (`partMl`, `ozMl`, ml being the anchor at 1), so `ratio` derives any pair 
  rather than storing it, and `withRatio` writes one back — moving the trailing unit's size, so 
  redefining the part leaves the ounce where it stood. The pick itself is not there: the sizes are 
  the owner's and travel with the collection, the pick is the reader's and stays with the bar 
  ([ADR 21](adr/21-the-file-carries-one-bar.md)). Both a converted measure and the 
  [amounts screen](ui-design.md#amounts) read the relation there rather than dividing themselves:

```dart
final class Unit {
  final String name;
  final String plural;        // empty where the plural reads like the name
  String get pluralName;      // the plural as it reads
  String spelling(Amount amount);   // singular for exactly one, plural otherwise
  bool answersTo(String token);     // either spelling, folded (ADR 08)
}
const defaultUnits = [Unit(partUnit, plural: 'parts'), Unit(mlUnit), …];
const partUnit = 'part', mlUnit = 'ml', ozUnit = 'oz';   // what FixedUnit is anchored to
bool isReservedUnit(String name);                // FixedUnit.named, so the three have one home

extension UnitLookup on List<Unit> {
  Unit? unitNamed(String token);   // either spelling, or an unwritten plural ("2 cups")
  List<String> get spellings;      // what uniqueness and reference rules ask for
}
```

- **Wire tokens are declared, not inferred.** Enum on-disk spelling is a field, never Dart identifier:

```dart
enum StockLevel { in_('in'), low('low'), out('out'); … }   // token differs from the identifier
enum FixedUnit { part('part'), ml('ml'), oz('oz'); … }   // ADR 17: also the reserved units
enum LineMark { base('base'), optional('optional'); … }    // ADR 06
enum TagColor { teal('teal'), … slate('slate'); … }        // ADR 07, open to new members
```

`BarMode` and `Transport` are declared the same way, the index being a file like any other 
([architecture.md](architecture.md#data-format)).

`RecipeLine.mark` holds that one `LineMark?`, so a base line can never also be optional
(FR-REC-8); `isBase` and `isOptional` are getters over it, and `marked(LineMark?)` is what
sets and clears it — `copyWith` cannot, since null is its "keep what you have".

**A line names one or more ingredients** ([ADR 11](adr/11-substitutions-on-the-line.md)).
`RecipeLine.ingredients` is a never-empty `List<String>` with no singular accessor, so every reader
decides for itself what a group means rather than quietly taking the first. It is the one entity
list left unwrapped: `List.unmodifiable` would cost the `const` constructor the grammar leans on.

`Collection` answers reference questions directly, so no consumer builds its own name index:

```dart
Ingredient? ingredientNamed(String name);
String spellingOf(String name);      // that entry's own spelling; unknown names stand
Recipe? recipeNamed(String name);
List<Tag> tagsOf(TagKind kind);
bool hasTag(TagKind kind, String name);

Set<String> get recipeNames;          // the sets every validate… call asks for
Set<String> get unitSpellings;
Set<String> tagNames(TagKind kind);
Set<String> ingredientSpellings({String? except});   // names and aliases, ADR 10
```

These are backed by a `late final` map built on first use. `Collection` stays immutable and the
memoisation is invisible; a lookup is O(1) after the first call, which is what the recipe list,
availability, and the optimizer all need at NFR-2 scale. The name sets are memoised on the same
terms, so a form judging a name on every keystroke builds one once instead of one per frame.
`ingredientSpellings` is the exception, built per call: every caller leaves an entry out of it —
the one being edited, which must collide with neither its own name nor its own aliases.

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
so `collection.dart` holds shape and invariants:

```dart
Collection withSettings(Settings settings);
typedef UnitEdit = ({Unit unit, String? was});        // the row and the name it came from
Collection withUnits(List<UnitEdit> edits);                // the whole vocabulary, renames propagated
Collection withCanonicalIngredientNames();                 // every line under its ingredient's own name
Collection withIngredient(Ingredient ingredient, {String? replacing});   // add, replace, rename
Collection withoutIngredient(String name);
Collection withStock(String ingredient, StockLevel stock);
Collection withTag(TagKind kind, Tag tag);                 // add or replace in that vocabulary
Collection withTagRenamed(TagKind kind, String from, String to);   // rewrites every entry wearing it
Collection withoutTag(TagKind kind, String name);
Collection withRecipe(Recipe recipe);                      // add or replace by name
Collection withoutRecipe(String name);

List<String> recipesUsingIngredient(String name);     // FR-VOC-1 delete blocking
List<String> recipesUsingUnit(String name);
List<String> usersOfTag(TagKind kind, String name);
```

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

`copyWith` on multi-field values (`Settings`, `Ingredient`, `Tag`, `RecipeLine`, `Recipe`, `Collection`, 
`Bar`); rename and stock built from it. `Amount` is rebuilt whole. One nullable field needs its own 
hatch, since null is `copyWith`'s "keep what you have": `RecipeLine.marked` clears the mark.

Rebuilding `Collection` on every edit is deliberate (a bar's scale: few thousand pointer writes; keeps all 
immutable, derived provider invalidation trivial). `Shelf` above it rebuilds on the same terms and 
costs less — a list of records tens long, and the same `Collection` pointer carried across.

### Line grammar

One implementation, two entry points (form gets non-throwing feedback; codec uses exceptions):

```dart
typedef ParsedLine = ({RecipeLine? line, String? problem});

ParsedLine tryParseRecipeLine(String text, List<Unit> units);   // never throws — form, codec
RecipeLine parseRecipeLine(String text, List<Unit> units);      // throws — built on tryParse
String formatRecipeLine(RecipeLine line, List<Unit> units);     // canonical form
String lineMarkSuffix(LineMark? mark);        // ' (base)' / ' (optional)' / '' — cards too
String formatAmount(Amount amount);
String formatNumber(double value);            // canonical number text — amounts, part_ml
```

Grammar in [architecture.md](architecture.md#data-format). This file enforces syntax; value rules in validation. Both halves take the vocabulary (ADR 09): it decides what counts as a unit and how an amount is spelled, and the line stores the unit's own name whichever spelling was typed. The unit is optional and may be plural on the way in; `formatRecipeLine` writes the canonical form for the file and the form alike. Alternatives split on `/` ([ADR 11](adr/11-substitutions-on-the-line.md)), lexically and after the mark, so the group is never resolved here. `formatMeasure` stays public in `src/` and out of the barrel — the display transform builds its measure from that same piece rather than a second spelling of it; the body is private, since a card writes its own from `ingredients` and `lineMarkSuffix`, in prose rather than in the file's separator.

### Validation

Contract and rationale: [ADR 05](adr/05-validation-contract.md).

```dart
enum ValidationIssueKind {
  emptyName, whitespaceInName, lineBreakInName, commaInAlias, duplicateName,
  reservedSuffix, separatorInName,                     // grammar's own text, ADR 06/11
  unitSizeNotPositive,                                 // part_ml, oz_ml — ADR 17
  missingUnit, unknownUnit, unknownIngredient, unknownTag,
  duplicateTag, duplicateAlternative,                  // ADR 11
  amountNotPositive, rangeOutOfOrder, noRequiredLine,
  unsupportedFormat, malformedLine, malformedValue,    // raised by the codec
}

final class ValidationIssue {
  final List<Object> path;         // data-format keys and indexes, e.g. ['recipes', 0, 'lines', 2]
  final ValidationIssueKind kind;  // the rule that failed
  final String message;            // ready to display, names the offending value
  String get location;             // 'recipes[0].lines[2]'
}

List<ValidationIssue> validateCollection({settings, units, ingredients, ingredientTags,
    recipeTags, recipes});
List<ValidationIssue> validateRecipe(Recipe recipe,
    {required Set<String> knownIngredients, required Set<String> knownTags,
     required Set<String> knownUnits, Set<String> otherRecipeNames});
List<ValidationIssue> validateIngredient(Ingredient ingredient,
    {required Set<String> knownIngredientTags, Set<String> otherIngredientNames});
List<ValidationIssue> validateTag(Tag tag, {Set<String> otherTagNames});
List<ValidationIssue> validateShelf({required List<Bar> bars, String? openId});
Set<String> otherNames(Set<String> names, String? except);   // the other…Names argument, folded
```

Empty result = valid. Issues collected in one pass (no fail-fast), top-to-bottom like file 
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
`randomCanMake` takes `Random` for testability.

```dart
const scaleFactors = [1, 2, 3, 4];                    // what a recipe view offers (FR-REC-7)
String displayMeasure(RecipeLine line, Settings settings, List<Unit> units,
    {required FixedUnit display, int scale = 1});

Set<String> basesOf(Recipe recipe);                   // discovery.dart — FR-DIS-4, ADR 12
List<String> baseSpirits(Collection collection);
bool marksBase(Recipe recipe, String? spirit);        // null asks for the unmarked

bool canMake(Availability? availability);             // availability.dart — low counts
Recipe? randomCanMake(Iterable<Recipe> candidates, Map<String, Availability> availability,
    Random random, {String? besides});                // discovery.dart — FR-DIS-5

const budgets = [1, 2, 3];                            // what the optimizer offers (FR-DIS-6)
final class Purchase { List<String> ingredients; List<String> unlocks; }   // both A→Z
List<Purchase> purchasesWithin(Collection collection, int budget,               // FR-DIS-6
    {int most = 25, bool restocking = false});                        // FR-DIS-7, ADR 16
```

`canMake` is the one reading of what the bar can manage now — low still being something on hand, and a
recipe the pass has yet to judge reading as missing, the rank the list's order already gives it.
The optimizer (FR-DIS-6) asks the same question, so it asks it here. `randomCanMake` draws over
*candidates handed to it* rather than over the collection: the caller is the list, and what it hands
over has already been narrowed, which is how "respecting active filters" costs nothing. `besides`
is the recipe already standing — skipped while another can be made, so a second roll always moves,
and compared by name fold like every name (ADR 08).

Base spirit is a predicate, not a placement ([ADR 12](adr/12-base-spirit-narrows.md)): `basesOf` 
takes every alternative of every base line, so a marked group answers under each ingredient it names, 
and `baseSpirits` folds those into what the filter offers — resolved through `Collection.spellingOf` 
*before* being weighed for repetition, so two spellings of one ingredient are one spirit; A→Z. 
`spellingOf` is also how a screen holding a pick reads it against a changed vocabulary, so an 
ingredient merely recased goes on narrowing; it is the one home for "this name, under the entry's own", 
which the optimizer, `withCanonicalIngredientNames` and delete blocking all ask for too. Comparison 
runs through `names.dart`, which stays unexported — no screen folds a name itself.

`purchasesWithin` answers FR-DIS-6 ([ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md)); 
the algorithm is in [architecture.md](architecture.md#domain-computations). It returns the best 
`most` baskets *of each size*, not the best `most` overall, so a one-ingredient win is never crowded 
out by the three-ingredient baskets that almost always unlock more — which is what will let the screen 
ask for one size at a time off a single search.

`restocking` is what "short" means ([ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md), 
FR-DIS-7): off, a line standing at out; on, a line short of full stock, so the ingredients running low 
join the pool and the goal becomes ready rather than merely makeable. Decided in one place — the 
whole search below reads "short", never "out" — which is why it costs the algorithm nothing. 
`canMake` does not move: the traffic light, the recipe order and the random pick all go on reading 
low as makeable, and it is the optimizer's own goal that shifts.

One search at `budgets.last` answers every smaller budget as well: what it holds at a size or under 
*is* that budget's own answer. A wider budget widens the pool, but only with ingredients no recipe is 
short of on their own — they close nothing alone, so a basket carrying one is dropped as a passenger 
whatever the budget was. That is what lets the screen search once and read a size off the result 
([ui-design.md](ui-design.md#shopping-screen)); it is pinned by test rather than asserted here.

`displayMeasure` is how a card reads a line's amounts (FR-REC-7, FR-SET-1). The measure is the only 
half that transforms, so it is the only half returned — and marking it as the card's own rather than 
the recipe's is what the split was for. The card writes the body itself, one alternative at a time 
(ADR 11). `display` is a parameter beside the sizes rather than a field inside them, since the two 
belong to different owners on a guest bar (ADR 21) — which is also what a card reading in another 
unit passes (FR-REC-7), the bar's pick standing where it is. A line converts only where 
`FixedUnit.named` answers for its unit, and only into the one `display` names: the two sizes give 
the factor, and everything else prints as entered (ADR 17).

## Data contracts

Data layer owns: YAML, files, atomicity, backups, and what crosses to another device.

```dart
typedef Records = ({List<Bar> bars, String? openId});   // the index, with no collection in it
String newBarId();                                     // six hex characters, minted per device
bool isStorableBarId(String id);                       // may it name a file — an index is untrusted

abstract interface class BarStore {
  Future<LoadOutcome<Records>> loadShelf();
  Future<LoadOutcome<BarPayload>> loadBar(String id);   // one bar, or why it could not be read
  Future<void> saveShelf(Records records);
  Future<void> saveBar(Bar bar, Collection collection);      // one file — the name and pick ride along
  Future<void> removeBar(String id);                    // its file and its backups (FR-BAR-2)
  Future<String> exportSnapshot(Bar bar, Collection collection, {ExportPurpose purpose});
}
```

The interface names no file and answers an export with an opaque location, which is the whole of 
[storage isolation](architecture.md#storage-isolation). `loadShelf` and `loadBar` are separate 
because the bar list must open without reading a collection (NFR-2), and `saveBar` takes the record 
beside the collection because the file carries the bar's name and reading unit as well as its 
contents ([ADR 21](adr/21-the-file-carries-one-bar.md)). Both answer the sealed trio the store has 
always answered with, now over what was asked for: `Loaded<T>`, `Empty`, `Corrupt<T>` with its 
recovery. Name and reading unit therefore stand in two files at once, and the index is the 
authority: `loadBar`'s copy of them is read only where a bar is being established or a lost index 
rebuilt, and every `saveBar` writes the record's own back.

`exportSnapshot` takes the collection rather than copying the store file: a session started from 
`Corrupt` runs on a recovered backup, and the copy must be the collection on screen, not the file 
that failed to decode ([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)). Byte-identical 
to that bar's store file regardless, the emitter being canonical.

`ExportPurpose` is why a copy is written, not where it goes: `share` is FR-DAT-1's, `beforeImport` 
and `beforeDelete` the nets FR-DAT-3 and FR-BAR-2 ask for. The store maps each to its own file 
([platform facts](architecture.md#platform-facts)), so no one act can cost a reader the copy another 
just staged — and no caller learns a name.

Ids are minted in the data layer rather than the domain, which stays pure of ambient chance, and are 
reached by the state layer through the barrel. `isStorableBarId` stands beside `newBarId` because an 
id is also a file name: minted ones are always safe, but the index is a file like any other and one 
carrying `../secrets` has to be refused rather than resolved. The store gates on it before it 
resolves a path, and answers `Corrupt` rather than reaching outside `bars/`.

Import is `YamlCodec.decode` + `saveBar`, not a store method. Separate so confirmation and 
pre-import export can slot between (FR-DAT-3), and so a refresh reaches the same decode by another 
road (FR-BAR-5).

`SourcedIssue` is own module (`Corrupt`, `Rejected` and `Refused` all carry it). Putting elsewhere 
creates cross-layer coupling [ADR 02](adr/02-persistence-and-export-format.md) avoids.

`decode` pipeline (each stage feeds issue list):
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
   answer a `BarPayload`: the collection, the file's `name`, and the `display` read out of 
   `settings`. Who keeps which of the three is the caller's, and it is where an import and a refresh 
   differ (ADR 21). A format-1 file carries no name and its `made:` was dropped at step 3.

Step 5 is **only** place data-format keys bind to source positions (domain has no YAML knowledge). 
`decodeShelf`/`encodeShelf` are the same two halves over the index, judged by `validateShelf` and 
written by the same emitter — one canonical form, two documents.

`FileBarStore` writes via temp + rename, rotates that file's own backups, and serialises every call 
through one queue (overlapping saves collapse). One queue rather than one per bar: two bars are 
never written in the same breath, and a single order is what makes a refresh landing behind an edit 
predictable. An unreadable bar falls back to its newest decodable backup and answers `Corrupt` with 
issues and recovery; the bars beside it are not touched, and a lost index is rebuilt from the bar 
files. Load never throws (damaged file = FR-DAT-4 failure). Constructor takes directory (platform 
path resolved at composition root `main.dart`), keeps adapter testable. File names, backup depth: 
[platform facts](architecture.md#platform-facts). `MemoryBarStore` for tests.

### The sharing seam

One interface per side, so a way that cannot do something does not carry a method for it 
([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)):

```dart
sealed class FetchOutcome {}
final class Fetched extends FetchOutcome { final BarPayload payload; }
final class Refused extends FetchOutcome { final List<SourcedIssue> issues; }   // FR-DAT-4
final class Unreachable extends FetchOutcome { final UnreachableReason why; }   // FR-BAR-5

abstract interface class BarChannel {         // every transport answers this much
  Transport get transport;
  Future<FetchOutcome?> fetch(BarSource source);        // the add, and every refresh after
}
```

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
answers. The file channel implements `BarChannel` alone: its `fetch` is the picker's text decoded, 
so a refresh is the reader handing over a newer file and there is nothing to offer or withdraw 
(FR-BAR-7). No cloud channel exists yet and the registry has no entry for that transport, which is 
how FR-BAR-9 waits without blocking anything.

## State contracts

`barStoreProvider` overridden in `main.dart` with the file store, tests with the memory one 
(device-free seam). `channelsProvider` is the same seam for the transports — `Map<Transport, 
BarChannel>`, composed from the seams beside it rather than overridden at the composition root, the 
file channel needing only `filePickerProvider` and no platform fact `main.dart` holds. A test 
replaces the map wholesale with fakes, or overrides the picker to exercise the real channel; either 
way nothing above it learns what a network is (ADR 22). A transport absent from the map has no 
adapter in this build, which is what a `refresh` meets as `Unreachable`. `clockProvider` is the 
state layer's one clock, stamping when a 
refresh landed (FR-BAR-5) and existing so that the domain needs none of its own. 
`sharerProvider` is the one file naming `share_plus`: it takes the opaque location `export()` 
answered with and hands it to the system's sheet, so a widget test overrides it with a recorder and 
no screen learns what a share is made of 
([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)).

`filePickerProvider` is its mirror and the one file naming `file_selector`: `Future<String?>` — the 
picked document's *text*, null where the reader picked nothing. Text rather than the `XFile` ADR 18 
made the currency, for the same reason the sharer takes a location: the platform type crosses the 
edge inside the provider body, so a widget test hands the flow a string and no file is needed to 
exercise it. No type filter, YAML having no MIME type Android's table knows — a filter would grey out 
the file the reader came for, and FR-DAT-4's decode is the judge either way.

The bytes→text step is `pickedText`, named rather than inlined because it is the one rule the seam 
carries and overriding the provider with a plain string never reaches it: `XFile.readAsString` 
ignores its own `encoding` for the bytes-backed file Android answers with, which cost the diacritics 
of every name on the way in ([architecture.md](architecture.md#platform-facts)). Its test builds the 
`XFile` the way the plugin does, so the shape the bug lived in is the shape under test.

```dart
typedef ImportReview = ({BarPayload? bar, List<String> issues});   // never both

ImportReview review(String text);        // pure: decode, described, nothing touched
Future<String> export();                           // the open bar's copy (FR-DAT-1)
Future<void> replaceOpen(String name, BarPayload bar);      // the copy, then the replace (FR-DAT-3)
Future<void> setDisplay(FixedUnit display);        // the reader's, guest bar included
Future<void> openBar(String id);                   // FR-BAR-1, the switch
Future<void> addOwnedBar(String name, {BarPayload? from});  // FR-BAR-2, empty or from a file
Future<void> renameBar(String id, String name);    // FR-BAR-2/3, any bar: the name is the reader's
Future<void> removeBar(String id);                 // FR-BAR-2, after its own export
Future<void> addGuestBar(String name, BarSource source, BarPayload bar);   // FR-BAR-3/7/8/9
Future<void> refresh(String barId);                // FR-BAR-5; never awaited by a screen
```

All of them take **one call site each**, which is why they sit here rather than on the writer — see
[ADR 23](adr/23-nothing-writes-a-guest-bar.md), where the count is the whole argument. `export`
and `setDisplay` work on a guest bar (FR-DAT-1, FR-BAR-3), and so does `renameBar`: what a bar is
called on this device is the reader's, on someone else's bar as on their own, and a refresh cannot
reach it ([ADR 21](adr/21-the-file-carries-one-bar.md)). `replaceOpen` refuses a guest bar, FR-DAT-3
importing "into an owned bar" and FR-BAR-7 giving the same file its other road.

**One picked file can become three things**, and the two that found a bar share `_found` — the bar's
file before the index naming it, then the shelf opened onto it. All three take the name from the
caller and never off the payload: the file's `name:` is a starting value the screen puts in a field,
and what the reader leaves there is what the bar is called (ADR 21). `addOwnedBar`'s `from` is
FR-BAR-2's "created from a file": the contents and the reading unit arrive and no source is kept, so
nothing about such a bar refreshes. `addGuestBar` keeps the source, which is what a refresh asks
again. `fileSource` is `channels.dart`'s republication of `FileBarChannel.source`, so a screen
founding a guest bar from a pick names a transport and never builds an address (ADR 22) — `ui/` may
not import `data/` at all.

**What a bar holds rides on its record**, so listing bars reads the index and nothing else (ADR 20)
and no second `Collection` ever reaches `ui/`. `Bar.holds` is `holdingsOf(Collection)` in the domain,
keyed by the `Holding` enum that is also the one home for the four kinds, their order and their nouns
(an arriving file's cards name the same four); `Bar.updated` dates the change beside it. Both are written
by `Bar.summarised` and — for a guest's refresh — `Bar.refreshedAt`, and by nothing else, which is
what keeps the count from falling a step behind the contents: every route a collection takes ends in
one of them, `ShelfEdits.withCollection` included.

`Bar.holds` is null only on a record no summary has reached — an index written before they existed.
`ShelfController.build()` repairs those, reading each such bar once under the startup spinner and
writing the index back; the open bar is counted from the collection the load already brought up, so
it costs no read of its own. A bar whose file cannot be read at all stays null and the card says so,
where a file that never landed counts as the empty collection opening it would give. Counting is not
editing: the repair writes no `updated`, a stamp invented there dating an edit nobody made.

`review` is deliberately pure so the confirmation and the pre-import copy slot after it, and it is 
the controller's rather than the screen's because `ui/` never imports `data/`. `_described` is the 
one rendering of a `SourcedIssue`, shared with the startup banner and with a channel's refusal, so a 
file that fails at load, one that fails at import and a fetch that fails on arrival are worded 
alike. It answers a whole `BarPayload`, which is what lets one picked file take any road FR-BAR-7 and 
FR-DAT-3 offer — replacing an owned bar, founding one, or founding a guest bar — each caller saying 
what becomes of its three parts.

`ShelfController.build()` performs the startup load and is the only writable provider: it reads the 
index, opens the bar it names, and reports what failed — a `Corrupt` bar starts on its recovered 
backup, and issues reach the UI through `loadIssuesProvider` as `"line N: message"` strings 
(FR-DAT-4; `SourcedIssue` is data-layer). Those issues are the *last* load's, startup or crossing 
alike, so a bar opened onto a torn file says so where the banner already speaks. That provider is 
**ordinary state the load writes**, a `Notifier` beside the controller rather than a field read off 
it: a field would only ever be right while every write set it before the shelf moved, and no write 
site can be made to keep an invariant the type does not. An index naming no open bar, or naming one 
it does not hold, still opens on whatever it does hold. **No index at all is 
a first run and founds a bar; an index listing none is a reader who deleted their last, and the bar 
list meets them** — the store tells the two apart, and `Empty` versus `Loaded` with no bars is where.

One private path serves every write, `_publish`: publish, then persist only what moved. A collection 
is written **only where the bar under it stayed put**, which is what tells an edit from a crossing — 
a crossing brings its collection up from disk, and writing that back would rotate the backups of a 
bar nobody touched. The index is written only where a record moved or the open bar changed, so a 
stock tap rotates no backup of `shelf.yaml` and a unit pick none of a bar's file. One rule covers all 
seven writes. The platform seams sit in `seams.dart` beside it, one provider each 
([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)).

**The write surface is separate from the controller** ([ADR 23](adr/23-nothing-writes-a-guest-bar.md)): 
`barWriterProvider` answers a `BarWriter?` — every collection mutation, and null on a guest bar, so 
the null a screen may get back is the same fact that hides the control (FR-BAR-4) and nothing has to 
remember a rule. **Built:** a screen reads it once in `build` and passes the non-null writer down to 
whatever it hands a control, so the control and the write are the same decision rather than two that 
could disagree — and there is no `!` left in `ui/` to be wrong about it. `setUnits` is the one mutation on it taking a whole vocabulary rather than an entry: 
the units screen edits every row at once, and a rename among them must reach the recipe lines in the 
same edit ([ui-design.md](ui-design.md#units)).

Each mutation is one line over a `CollectionEdits` derivation. All run through a single private path: 
await the startup load, derive, publish, save the open bar. The three `upsert…`s with `replacing` 
compose several derivations (whole form/dialog reaches disk as one collection, the rename it leaves 
behind included). `upsertRecipe` ends on `withCanonicalIngredientNames`, so a line typed in any 
spelling — another case, an alias — lands under the ingredient it names, the ingredients that same edit adds 
included (ADR 08, ADR 10); the recipe form therefore stores what it was given rather than resolving 
names itself. Awaiting the load makes edits during startup land on the loaded bar rather than 
replace it. An edit that leaves the collection unchanged is not saved (no backup waste). UI never 
constructs a `Collection`, never holds a `BarStore`, and never reaches the notifier 
([ADR 03](adr/03-app-structure-and-state.md), ADR 23).

Everything else is derived, read-only:

`collectionProvider` — the open bar's collection, and the shape every screen already reads. It is derived 
from `shelfProvider` rather than owned, which is what kept the whole presentation layer still while 
the root moved above it. It answers a `Collection`, never an `AsyncValue` of one: **the startup load 
is met in exactly one place**, the shell ([ui-design.md](ui-design.md#app-shell)), which draws no 
screen until it has answered — so a screen reading this provider cannot exist early enough to see a 
wait, and reading it before the shelf has landed throws rather than standing in with an empty 
collection nobody wrote. `availabilityProvider` and `purchasesProvider` read it plainly for the same 
reason. `openBarProvider` answers the record beside it — name, mode, reading unit, source, last 
refresh — and `barsProvider` every record on the shelf, which is all the bar list reads. 
`openBarProvider` answering null once the shelf has loaded is what puts the bar list on screen as 
home ([ui-design.md](ui-design.md#bars)).

`availabilityProvider` — `Map<String, Availability>` by recipe name, `availabilityOf` over every 
recipe on each collection change; empty until the load lands. One pass serves the list's chips and, later, 
the availability filter, the random pick and the optimizer. Per-line marks read `stockOfLine` 
directly (the map answers per recipe, the card asks per line), and `stockOf` per ingredient beneath it — 
so a card dims the alternatives it lacks against the same rule the verdict was reached by (ADR 11).

Filter, search and order are presentation: widget state where the list is drawn, never persisted and 
never a provider — nothing collection-derived reads them, so there is nothing to invalidate. A consumer 
outside the screen is what would hoist them, and the random pick (FR-DIS-5) turned out not to be 
one: the draw is made *by* the list, over the rows it is already showing, so the search never had to 
leave `VocabularyList` and no narrowing had to be named twice. What a screen supplies is the draw 
itself; what it gets back is a name.

`destinationsOf(BarMode)` sits beside it in `ui/destinations.dart` and answers what the bottom bar 
offers: three on an owned bar, the two that read on a guest (FR-BAR-4). It lives there rather than in 
the state layer because `Destination` is the shell's own enum and `state/` never imports `ui/`. **The 
shell indexes the stack and the bar by position in that list**, never by `Destination.index` — the two 
agree only while every bar offers every destination, and a guest offers two.

`revealProvider` is the one provider outside this layer, and the fourth kind of state in the app: not 
collection, not derived, not screen-local, but one screen's request of another 
([ADR 19](adr/19-a-destination-sends-the-reader-to-another.md)). It lives in `ui/destinations.dart` 
beside the enum it names, since what destinations exist and how one is asked for are the same 
subject, and `state/` has no business knowing either. A `Reveal?` — a destination and a name — 
nullable and one-shot: the shell listens only to switch, the serving screen clears it. Clearing it 
inside that listener is safe because Riverpod copies its listener list before dispatch, so the shell 
still hears the request it is being cleared out of; the shell ignoring a null one is what makes the 
order between them not matter. What the bar on show changes here is only how many destinations there 
are (FR-BAR-4): the shell indexes its stack by position in the list that bar offers, never by the 
enum's own index, which is the one place a variable destination list is felt.

`purchasesProvider` — `List<Purchase>` keyed on what counts as short (ADR 16), searched once at 
`budgets.last` so the screen reads one size off the one answer. `autoDispose`, and watched only 
while the shopping screen is the destination on show: the shell tells each destination whether it 
is (`ShoppingScreen.showing`), since `IndexedStack` keeps them alive and a stock tap on the 
ingredients screen would otherwise fire a search nobody is reading. The answer is let go with the screen and 
made afresh on return — the search costs ~100ms at NFR-2 scale, which is a moment on arriving at a 
screen and a stutter on every tap of another. On a guest bar the destination is absent, so nothing 
watches it at all (FR-BAR-4).

### Work in flight

Refreshing and sharing are the app's first work outliving the gesture that started it, and the 
**fifth kind of state**: not collection, not derived, not screen-local, not one screen's request of 
another, but a job the reader may walk away from. Both live in `channels.dart`.

`refreshesProvider` — `Map<String, RefreshState>` by bar id: `Reaching`, or what it last failed with 
and when, until it is `told`, which is what dismissing the banner and reporting it in a snackbar 
both come to — `RefreshRefused` carrying issues already described (`ui/` never meets a `SourcedIssue`) 
and `RefreshUnreachable` the closed reason it words itself (FR-BAR-5). A bar with no entry has 
nothing out and nothing to be met. No screen awaits a refresh, which is what NFR-2's *a refresh never holds up the 
bar on show* comes to in practice: the reader goes on reading and editing while one is out, and the 
screens are told only through this map. A late answer is dropped where its bar is gone or a newer 
ask has been made (each carries a token, only the newest lands); a guest bar's collection has no 
other writer, so there is nothing else for one to lose.

`sharingProvider` keeps the offers standing in step with the shelf — starting an adapter's 
advertisement when a bar gains an offer, stopping it when the bar loses one or goes, running nothing 
when the shelf offers nothing (NFR-5). Its value is an effect rather than a reading, so the app 
watches it rather than a screen.

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
   `ShelfController.build()` reads the index and opens the bar it names → `Loaded` seeds state, 
   `Corrupt` seeds that bar's recovered backup + surfaces issues, no index at all runs the format-1 
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
   `VocabularyList` for one build → the list clears its search and order, goes home, then scrolls to 
   the row and washes it (ADR 13, ADR 19).
7. **Switching bars** (FR-BAR-1): a card's **Open bar** calls `openBar(id)` → the controller loads 
   that bar and publishes record and collection together, so no frame pairs one bar's record with 
   another's recipes, and the index alone is written → the shell's subtree is keyed by the open bar, 
   so every screen is built anew and no narrowing, open card or jump trail survives the crossing → 
   the screen pops to the root, landing the reader in the bar rather than back on the gear. The bar
   already loaded has nothing to read again, so it asks `Reveals.land` for the recipes instead and
   pops to the same place (ADR 19).
8. **Adding a guest bar** (FR-BAR-3): a source — picked, or found nearby — reaches `channel.fetch` 
   → `Fetched` becomes a bar with a minted id, the name the reader left in the form, the payload's 
   display, and the source kept for next time; `Refused` reads as an import's issues do, 
   `Unreachable` says which of the three. The form picks and `review`s the file itself, so the 
   reader sees the counts before choosing a road, and only the chosen road reaches the controller.
9. **Refreshing** (FR-BAR-5): `refresh(id)` marks the bar reaching and is never awaited by a screen 
   → the fetch runs off the gesture → `refreshedWith` replaces collection and time, never the name 
   or the reading unit the reader picked (ADR 21); the bar on show is written by `_publish` as any 
   edit is, and any other bar's file by `refresh` itself, only one collection ever being resident 
   (ADR 20) → a failure leaves the bar as it stood, held in `refreshesProvider` to be met. Each ask 
   carries a token: an answer arriving behind a newer ask, or for a bar deleted meanwhile, is 
   dropped whole rather than landing on top of it. The gesture is `VocabularyList.onRefresh`, 
   non-null only on a guest bar (`refreshOf`), and the answer is met by the `RefreshFailure` banner 
   over the destinations — the pull awaits the fetch only to retract its own spinner, which is not a 
   screen holding up the bar on show. Settings' **Refresh** row asks the same way from behind that 
   banner, so it reads the answer itself (`Refreshes.standing`), says it in a snackbar and marks it 
   `told` — one answer, one telling, whichever of the two the reader met.
10. **Sharing** (FR-BAR-6): an offer on a bar's record starts the adapter and removing it stops the 
    adapter; `sharingProvider` is the one place the two are kept in step, so nothing is announced 
    that the shelf does not say is shared (NFR-5).
11. **Deleting a bar** (FR-BAR-2): confirmed, exported under `beforeDelete` — owned bars only, a 
    guest's contents being its owner's (FR-BAR-3) — then the record, then the file and its backups, 
    in that order, since a record outliving its file is a bar that opens onto nothing. A deleted open 
    bar leaves the shelf with none open, and the bar list becomes home under the reader.

The controller is the UI's only route to the data layer; screens never hold a `BarStore`, a 
`BarChannel` or a `YamlCodec`.

## Testing

- **Domain**: unit tests, no device. Pure functions; clock/randomness passed in. `Shelf`'s 
  invariants and its refusal to edit a guest bar's collection (ADR 23) are unit tests like any other.
- **Data**: codec unit-tested (round-trip FR-DAT-5, broken-file decode with line numbers, a 
  format-1 file read and written back as 2). `FileBarStore` integration-tested (atomic write, 
  backups, recovery, and one bar's save leaving every other bar's bytes byte-for-byte as they were). 
  Channels are tested against a fake for the seam and, for the LAN one, its own loopback server.
- **State**: controller tests vs `MemoryBarStore` and fake channels; a mutation updates state and 
  reaches the store, a refresh lands or is dropped as stale, a guest bar hands out no writer.
- **UI**: widget tests for critical flows. The file transport is composed from `filePickerProvider`, 
  so a widget test drives the *real* channel by overriding the picker alone — a pull answered with a 
  file, a damaged one, or nothing — and reaches `Unreachable` by seeding a bar sourced `cloud`, 
  which this build has no adapter for. `test/ui/harness.dart` over the store and channel 
  overrides.
- **Boundaries**: `test/architecture_test.dart` enforces imports, the dependency list, and the one 
  route to a write.

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
each, not a copy each — `tokenVocabulary` and `valueEquality` in `test/domain/collection_test.dart`, 
`vocabulary` in `collection_edits_test.dart`, `barStoreContract` in `test/data/`. Every case in such a 
table carries a `reason` naming it, so a failure says which one.
