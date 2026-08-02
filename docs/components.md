# Components

Module-level design: folder structure, layer surfaces, interfaces, data flows. System-level design 
in [architecture.md](architecture.md); boundaries in [ADR 04](adr/04-module-boundaries.md); screens 
in [ui-design.md](ui-design.md). Milestone signatures don't exist yet ([roadmap.md](roadmap.md)) 
— named here so consumers design against fixed shapes.

## Module map

Each layer is a folder with a barrel file. **The barrel is the entire public surface**; 
everything else under `src/`.

```
lib/
  main.dart                    # ProviderScope, store override, CocktailsApp
  domain/
    domain.dart                # barrel — the only domain import other layers use
    src/
      model.dart               # entities, Model root, name lookups, wornInOrder,
                               #   the unit vocabulary and its lookup (ADR 09)
      model_edits.dart         # extension ModelEdits on Model — pure derivations
      line_format.dart         # compact-line grammar
      validation.dart          # ValidationIssue + rule set, otherNames
      availability.dart        # Availability, availabilityOf, stockOfLine, stockOf
      scaling.dart             # ×N scaling, part↔ml display
      discovery.dart           # basesOf, baseSpirits, marksBase; M20 — random
      optimizer.dart           # M21
      helpers.dart             # not exported: nameKey, sameName, repeatsName,
                               #   duplicateNameIndexes, listEquals
  data/
    data.dart                  # barrel — the store, the codec, and their result types
    src/
      sourced_issue.dart       # SourcedIssue — shared by the store and the codec
      model_store.dart         # the storage interface and its outcome types
      yaml_codec.dart          # decode/encode, format-version gate
      yaml_reader.dart         # YAML tree → model parts, with source spans
      yaml_writer.dart         # canonical emitter
      file_model_store.dart    # atomic write, backup rotation
      memory_model_store.dart  # in-memory double for state and widget tests
  state/
    state.dart                 # barrel — every provider
    src/
      model_controller.dart    # the one writable provider
      derived.dart             # availabilityProvider; visible recipes, optimizer
  ui/                          # no barrel — leaves, imported directly; design in ui-design.md
    app.dart                   # MaterialApp and the shell: destinations, app bar, gear
    theme.dart                 # the seed colour, the two schemes, `dimmedInk` — the one
                               #   dim, worn by a hint and by a bottle the bar lacks
    palette.dart               # the fixed hues — stock signals and the tag palette —
                               #   and `neutralSwatch`, the ground a chip meaning
                               #   nothing by its colour stands on (ADR 12)
    screens/                   # one file per destination, plus settings, tags, units,
                               #   recipe form
    widgets/                   # empty_state, model_view, search_field, startup_issues,
                               #   color_chip — the pill, chip, dot and dotted name,
                               #     plus `chipRadius`, the corner a chip and the ink
                               #     under it both round to
                               #   tag_choices — the row tags are picked from
                               #   vocabulary_list — the searchable list all four screens are,
                               #     plus the orders it reads in, the spellings it searches
                               #     by, the tag filter two of them narrow by, byName
                               #     and Set.toggle
                               #   vocabulary_dialogs — entry (name, aliases, colour, tags),
                               #     delete, discard, plus VocabularyEntry and the one
                               #     reading of issue paths into fields every form shares
                               #   editor_form — the pushed editor both forms wear: the
                               #     Save/discard frame and the self-growing row list
test/                          # mirrors lib/, plus test/architecture_test.dart
```

`domain/src/helpers.dart` holds logic shared between domain files (layer-private, not exported). Contains `nameKey`/`sameName` — the one fold behind every name comparison ([ADR 08](adr/08-names-ignore-case.md)) — plus `duplicateNameIndexes` and `listEquals`.

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

`test/architecture_test.dart` (M5a) enforces via `import`/`export` directives (pure functions, 
exercised on constructed inputs and real tree).

## Domain contracts

Pure Dart, no I/O, no clock, no randomness taken from ambient state — anything time- or
chance-dependent is passed in, which is what keeps the layer unit-testable.

### Entities and the model root

`Ingredient`, `Tag`, `Amount`, `RecipeLine`, `MadeHistory`, `Settings`, `Recipe`, `Model` are 
immutable `final class` values with structural equality. Collections wrapped `List.unmodifiable` 
— lists not `const`-constructible.

Two identity conventions:

- **Vocabulary entries are entities; references are names.** `Model.ingredients` holds 
  `Ingredient` values; `RecipeLine.ingredients`, `Recipe.tags`, `Ingredient.tags` hold `String` names. 
  No surrogate IDs — rename is a mutation rewriting references ([architecture.md](architecture.md#system-overview)).
- **One name however it is capitalised** ([ADR 08](adr/08-names-ignore-case.md)). Every comparison — 
  uniqueness, lookup, reference resolution, delete blocking, rename — goes through `nameKey`; the 
  spelling stored is the spelling shown. Lookup maps are keyed by the fold, so resolution stays O(1).
- **A bottle answers to more than one name** ([ADR 10](adr/10-ingredient-aliases.md)). 
  `Ingredient.aliases` holds them and `Ingredient.spellings` is the name and the aliases together — 
  one namespace, unique under the fold, indexed by `ingredientNamed` so no caller learns an alias 
  exists. A reference is stored under the entry's own name, `withCanonicalIngredientNames` being the 
  one derivation that puts it there, wherever the line came from.
- **Two tag vocabularies are peers.** `Model.recipeTags` and `Model.ingredientTags` are separate 
  `Tag` lists, unique within each ([ADR 07](adr/07-tag-colour.md)). A `Tag` carries no scope: 
  `TagKind` names the side, and every tag operation takes one rather than existing twice under two 
  names — which is also what keeps the UI from re-deriving the distinction to abstract over it.
- **A unit is an entry, not an enum** ([ADR 09](adr/09-units-are-a-vocabulary.md)). `Model.units`
  is the vocabulary, `RecipeLine.unit` a name into it, and the two the app leans on are constants:

```dart
final class Unit {
  final String name;
  final String plural;        // empty where the plural reads like the name
  String get pluralName;      // the plural as it reads
  String spelling(Amount amount);   // singular for exactly one, plural otherwise
  bool answersTo(String token);     // either spelling, folded (ADR 08)
}
const defaultUnits = [Unit(partUnit, plural: 'parts'), Unit(mlUnit), …];
const partUnit = 'part', mlUnit = 'ml';          // FR-REC-2, FR-SET-1 anchor here
const reservedUnits = [partUnit, mlUnit];        // neither renameable nor deletable

extension UnitLookup on List<Unit> {
  Unit? unitNamed(String token);   // either spelling, or an unwritten plural ("2 cups")
  List<String> get spellings;      // what uniqueness and reference rules ask for
}
```

- **Wire tokens are declared, not inferred.** Enum on-disk spelling is a field, never Dart identifier:

```dart
enum StockLevel { in_('in'), low('low'), out('out'); … }   // token differs from the identifier
enum DisplayUnit { part('part'), ml('ml'); … }
enum LineMark { base('base'), optional('optional'); … }    // ADR 06
enum TagColor { teal('teal'), … slate('slate'); … }        // ADR 07, open to new members
```

`RecipeLine.mark` holds that one `LineMark?`, so a base line can never also be optional
(FR-REC-8); `isBase` and `isOptional` are getters over it, and `marked(LineMark?)` is what
sets and clears it — `copyWith` cannot, since null is its "keep what you have".

**A line names one or more bottles** ([ADR 11](adr/11-substitutions-on-the-line.md)).
`RecipeLine.ingredients` is a never-empty `List<String>` with no singular accessor, so every reader
decides for itself what a group means rather than quietly taking the first. It is the one entity
list left unwrapped: `List.unmodifiable` would cost the `const` constructor the grammar leans on.

`Model` answers reference questions directly, so no consumer builds its own name index:

```dart
Ingredient? ingredientNamed(String name);
Recipe? recipeNamed(String name);
List<Tag> tagsOf(TagKind kind);
bool hasTag(TagKind kind, String name);

Set<String> get recipeNames;          // the sets every validate… call asks for
Set<String> get unitSpellings;
Set<String> tagNames(TagKind kind);
Set<String> ingredientSpellings({String? except});   // names and aliases, ADR 10
```

These are backed by a `late final` map built on first use. `Model` stays immutable and the
memoisation is invisible; a lookup is O(1) after the first call, which is what the recipe list,
availability, and the optimizer all need at NFR-2 scale. The name sets are memoised on the same
terms, so a form judging a name on every keystroke builds one once instead of one per frame.
`ingredientSpellings` is the exception, built per call: every caller leaves an entry out of it —
the one being edited, which must collide with neither its own name nor its own aliases.

### Two contracts, one rule set

Name uniqueness checked in two places:

- `Model` constructor throws `ArgumentError` on duplicate (programmer contract: existing Model 
  is well-formed).
- `validateModel` returns issues, never throws (data contract: untrusted input reported, not crashed). 
  Works on loose parts before Model construction.

Both use single `duplicateNameIndexes` in `helpers.dart`.

### Editing the model

Every edit is a pure derivation returning a new `Model`, in `extension ModelEdits on Model` 
so `model.dart` holds shape and invariants:

```dart
Model withSettings(Settings settings);
typedef UnitEdit = ({Unit unit, String? was});        // the row and the name it came from
Model withUnits(List<UnitEdit> edits);                // the whole vocabulary, renames propagated
Model withCanonicalIngredientNames();                 // every line under its bottle's own name
Model withIngredient(Ingredient ingredient, {String? replacing});   // add, replace, rename
Model withoutIngredient(String name);
Model withStock(String ingredient, StockLevel stock);
Model withTag(TagKind kind, Tag tag);                 // add or replace in that vocabulary
Model withTagRenamed(TagKind kind, String from, String to);   // rewrites every entry wearing it
Model withoutTag(TagKind kind, String name);
Model withRecipe(Recipe recipe);                      // add or replace by name
Model withoutRecipe(String name);
Model withRecipeMade(String name, DateTime today);    // the clock is a parameter (FR-REC-6)
Model withRecipeHistory(String name, MadeHistory? made);      // the one writer; null = never made

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
as one — has no valid model to stop at halfway (ADR 10). A `replacing` naming no entry falls back to
the entry's own name, so a stale name still cannot crash.

A tag edit touches only its own side: renaming a recipe tag never reads an ingredient, and
`usersOfTag` blocks deletion from its own side only. One name may stand in both vocabularies and
mean two different things, so the `kind` is what tells them apart, never the name.

Three rules: edit for missing entry returns unchanged (stale name can't crash). Collision with 
existing name throws `ArgumentError` (programmer contract). Removal never cascades (caller asks 
`recipesUsing…` first for blocking message).

`withRecipeMade` is `withRecipeHistory` with the next count worked out; taking a stamp back is
putting the history that preceded it back, so undo and reset are that same derivation (FR-REC-6).

`copyWith` on multi-field values (`Settings`, `Ingredient`, `Tag`, `RecipeLine`, `Recipe`, `Model`); 
rename/stock/made built from it. `Amount`, `MadeHistory` rebuilt whole. Two nullable fields need 
their own hatch, since null is `copyWith`'s "keep what you have": `RecipeLine.marked` clears the 
mark, `Recipe.stamped` clears the history.

Rebuilding `Model` on every edit is deliberate (pilot scale: few thousand pointer writes; keeps all 
immutable, derived provider invalidation trivial).

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
  partMlNotPositive, missingUnit, unknownUnit, unknownIngredient, unknownTag,
  duplicateTag, duplicateAlternative,                  // ADR 11
  amountNotPositive, rangeOutOfOrder, noRequiredLine, timesBelowOne,
  unsupportedFormat, malformedLine, malformedValue,    // raised by the codec (M6)
}

final class ValidationIssue {
  final List<Object> path;         // data-format keys and indexes, e.g. ['recipes', 0, 'lines', 2]
  final ValidationIssueKind kind;  // the rule that failed
  final String message;            // ready to display, names the offending value
  String get location;             // 'recipes[0].lines[2]'
}

List<ValidationIssue> validateModel({settings, units, ingredients, ingredientTags,
    recipeTags, recipes});
List<ValidationIssue> validateRecipe(Recipe recipe,
    {required Set<String> knownIngredients, required Set<String> knownTags,
     required Set<String> knownUnits, Set<String> otherRecipeNames});
List<ValidationIssue> validateIngredient(Ingredient ingredient,
    {required Set<String> knownIngredientTags, Set<String> otherIngredientNames});
List<ValidationIssue> validateTag(Tag tag, {Set<String> otherTagNames});
Set<String> otherNames(Set<String> names, String? except);   // the other…Names argument, folded
```

Empty result = valid. Issues collected in one pass (no fail-fast), top-to-bottom like file 
(settings, ingredients, tags, recipes, within each by index). Lets codec render as-is (M6). 
`ValidationIssue` has value equality.

`path` uses **data-format key names** (`part_ml`, `made.times`), not Dart names. Seam lets 
codec attach YAML line numbers, form attach field focus, without domain knowing either. 
Behaviour switches on `kind`; `message` is display-only.

`validateModel`: whole-file entry point for import (M6). Others check single entry a form edits 
(M11/M12/M14) in one call: paths relative, empty for name. `other…Names` holds every *other* 
entry's name — every *spelling* for the ingredient vocabulary, whose namespace holds aliases too 
(ADR 10) — so a rename never collides with itself. All four run same rules, same code.

### Computations

Named now; implemented in milestones. All pure functions of `Model`. Algorithms in 
[architecture.md](architecture.md#domain-computations). `randomCanMake` takes `Random` for testability.

```dart
const scaleFactors = [1, 2, 3, 4];                    // what a recipe view offers (FR-REC-7)
String displayMeasure(RecipeLine line, Settings settings, List<Unit> units, {int scale = 1});

Set<String> basesOf(Recipe recipe);                   // discovery.dart — FR-DIS-4, ADR 12
List<String> baseSpirits(Model model);
String baseSpiritNamed(Model model, String spirit);   // the spelling the offering uses
bool marksBase(Recipe recipe, String? spirit);        // null asks for the unmarked
```

Base spirit is a predicate, not a placement ([ADR 12](adr/12-base-spirit-narrows.md)): `basesOf` 
takes every alternative of every base line, so a marked group answers under each bottle it names, 
and `baseSpirits` folds those into what the filter offers — resolved through `baseSpiritNamed` 
*before* being weighed for repetition, so two spellings of one bottle are one spirit; A→Z. 
`baseSpiritNamed` is also how a screen holding a pick reads it against a changed vocabulary, so a 
bottle merely recased goes on narrowing. Comparison runs through `helpers.dart`, which stays 
unexported — no screen folds a name itself.

`displayMeasure` is how a card reads a line's amounts (FR-REC-7, FR-SET-1). The measure is the only 
half that transforms, so it is the only half returned — and marking it as the card's own rather than 
the recipe's is what the split was for. The card writes the body itself, one alternative at a time 
(ADR 11). A caller wanting a unit the settings do not hold passes `settings.copyWith(display: …)` — 
the reading is the settings that card is under, not a second notion of one.

(See components.md line-by-line for signatures — formatted for readability in source)

## Data contracts

Data layer owns: YAML, files, atomicity, backups.

`exportSnapshot` returns location (not file) so store decides what's shareable. UI passes to 
platform share API, never learns it's a path ([architecture.md](architecture.md#storage-isolation)).

Import is `YamlCodec.decode` + `save`, not a store method. Separate so confirmation and 
pre-import export can slot between (FR-DAT-3).

`SourcedIssue` is own module (both `Corrupt` and `Rejected` carry it). Putting elsewhere creates 
cross-layer coupling [ADR 02](adr/02-persistence-and-export-format.md) avoids.

`decode` pipeline (each stage feeds issue list):
1. Parse YAML, retain node spans.
2. Gate on `format`; unsupported version rejected.
3. Read tree to model parts; shape errors reported against offending node; compact lines through 
   `tryParseRecipeLine` (problem → issue at line path). `units` is read first — the lines are 
   parsed against it, and an absent section is the shipped vocabulary (ADR 09).
4. Run `validateModel` on parts (referential, value rules) only if step 3 clean (broken shape 
   never cascades to spurious reference errors).
5. Resolve `ValidationIssue.path` against parse tree for line numbers.
6. Build `Model` (cannot throw; duplicates ruled out), then `withCanonicalIngredientNames` — a
   hand-edited line naming a bottle by an alias is held under the bottle's own name (ADR 10).

Step 5 is **only** place data-format keys bind to source positions (domain has no YAML knowledge).

`FileModelStore` writes via temp + rename, rotates backups, serialises calls through queue 
(overlapping saves collapse). Unreadable load falls back to newest decodable backup, returns 
`Corrupt` with issues and recovery. Load never throws (damaged file = FR-DAT-4 failure). 
Constructor takes directory (platform path resolved at composition root `main.dart`), keeps 
adapter testable. File names, backup depth: [platform facts](architecture.md#platform-facts). 
`MemoryModelStore` for tests.

## State contracts

`modelStoreProvider` overridden in `main.dart` with file store, tests with memory store (device-free 
seam). `clockProvider` is seam for made-it date (FR-REC-6) (state layer only reads clock; domain stays 
pure).

`ModelController.build()` performs startup load, only writable provider. `Corrupt` load starts on 
recovered backup (empty if nothing decoded); issues reach UI via `startupIssuesProvider` as 
`"line N: message"` strings (FR-DAT-4; SourcedIssue is data-layer).

`setUnits` is the one mutation taking a whole vocabulary rather than an entry: the units screen
edits every row at once, and a rename among them must reach the recipe lines in the same edit
([ui-design.md](ui-design.md#units)).

Each mutation is one line over `ModelEdits` derivation. All run through single private path: await 
startup load, derive, publish, save. The three `upsert…`s with `replacing` compose several derivations 
(whole form/dialog reaches disk as one model, the rename it leaves behind included). `upsertRecipe` 
ends on `withCanonicalIngredientNames`, so a line typed in any spelling — another case, an alias — 
lands under the bottle it names, the bottles that same edit adds included (ADR 08, ADR 10); the 
recipe form therefore stores what it was given rather than resolving names itself. Awaiting load makes edits during startup land on 
loaded model, not replace. Edit that leaves model unchanged is not saved (no backup waste). UI never 
constructs `Model` or touches `ModelStore` ([ADR 03](adr/03-app-structure-and-state.md)).

Everything else is derived, read-only:

`availabilityProvider` — `Map<String, Availability>` by recipe name, `availabilityOf` over every 
recipe on each model change; empty until the load lands. One pass serves the list's chips and, later, 
the availability filter, the random pick and the optimizer. Per-line marks read `stockOfLine` 
directly (the map answers per recipe, the card asks per line), and `stockOf` per bottle beneath it — 
so a card dims the alternatives it lacks against the same rule the verdict was reached by (ADR 11).

Filter, search and order are presentation: widget state where the list is drawn, never persisted and 
never a provider — nothing model-derived reads them, so there is nothing to invalidate. A consumer 
outside the screen (M20's random pick, FR-DIS-5) is what would hoist them.

Performance facts (no over-engineering):
- Every mutation replaces whole `Model` → all model-derived recompute. Hundreds of recipes: availability 
  pass < 1ms; incremental unneeded (NFR-2).
- Optimizer is sole expensive computation. Watched only by optimizer screen (never runs elsewhere).

## Data flows

1. **Startup**: `main` overrides `modelStoreProvider` with file store → `ModelController.build()` 
   loads → `Loaded` seeds state, `Empty` seeds empty, `Corrupt` seeds recovered + surfaces issues.
2. **Edit**: widget calls `modelProvider.notifier.setStock(…)` → `ModelEdits` returns new `Model` 
   → state updates, UI rebuilds → save enqueued.
3. **Recipe form** (M14): `tryParseRecipeLine` on each field (live feedback) → `validateRecipe` on 
   save (`lines[i]` paths map to fields; else snackbar) → recipe + new ingredients + rename name 
   reach `notifier.upsertRecipe` as one edit (ui-design.md#recipe-form).
4. **Export** (FR-DAT-1): `notifier.export()` (M24) returns location for share sheet; store file is export.
5. **Import** (FR-DAT-3/4): `YamlCodec.decode` validates → `Rejected` shows issues, `Decoded` confirms 
   and atomically saves.

Controller is UI's only route to data layer; screens never hold `ModelStore` or `YamlCodec`.

## Testing

- **Domain**: unit tests, no device. Pure functions; clock/randomness passed in.
- **Data**: codec unit-tested (round-trip FR-DAT-5, broken-file decode with line numbers). 
  `FileModelStore` integration-tested (atomic write, backups, recovery).
- **State**: controller tests vs `MemoryModelStore`; mutation updates state, reaches store.
- **UI**: widget tests for critical flows. `test/ui/harness.dart` over store override.
- **Boundaries**: `test/architecture_test.dart` enforces imports.
