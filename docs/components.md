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
      model.dart               # entities, Model root, name lookups, wornInOrder
      model_edits.dart         # extension ModelEdits on Model — pure derivations
      line_format.dart         # compact-line grammar
      validation.dart          # ValidationIssue + rule set
      availability.dart        # M16
      scaling.dart             # M17 — ×N scaling, part↔ml display
      discovery.dart           # M13/M18/M19/M20 — search, filter, group, random
      optimizer.dart           # M21
      helpers.dart             # not exported: duplicateNameIndexes, listEquals
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
      derived.dart             # availability, visible recipes, grouping, optimizer
      filters.dart             # filter and search UI state
  ui/                          # no barrel — leaves, imported directly; design in ui-design.md
    app.dart                   # MaterialApp and the shell: destinations, app bar, gear
    theme.dart                 # the seed colour and the two schemes
    palette.dart               # the fixed hues: stock signals and the tag palette
    screens/                   # one file per destination, plus settings, tags, recipe form
    widgets/                   # empty_state, model_view, search_field, startup_issues,
                               #   color_chip — the pill, chip, dot and dotted name
                               #   tag_choices — the row tags are picked from
                               #   vocabulary_list — the searchable list all four screens are,
                               #     plus byName and Set.toggle
                               #   vocabulary_dialogs — entry (name, colour, tags), delete,
                               #     plus fieldError, the rule the recipe form shares
test/                          # mirrors lib/, plus test/architecture_test.dart
```

`domain/src/helpers.dart` holds logic shared between domain files (layer-private, not exported). Contains `duplicateNameIndexes` and `listEquals`.

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
  `Ingredient` values; `RecipeLine.ingredient`, `Recipe.tags`, `Ingredient.tags` hold `String` names. 
  No surrogate IDs — rename is a mutation rewriting references ([architecture.md](architecture.md#system-overview)).
- **Two tag vocabularies are peers.** `Model.recipeTags` and `Model.ingredientTags` are separate 
  `Tag` lists, unique within each ([ADR 07](adr/07-tag-colour.md)). A `Tag` carries no scope: 
  `TagKind` names the side, and every tag operation takes one rather than existing twice under two 
  names — which is also what keeps the UI from re-deriving the distinction to abstract over it.
- **Wire tokens are declared, not inferred.** Enum on-disk spelling is a field, never Dart identifier:

```dart
enum Unit {
  part('part'), ml('ml'), oz('oz'), dash('dash'),
  barspoon('barspoon'), drop('drop'), piece('piece');
  final String token;
  const Unit(this.token);
  static Unit? fromToken(String text);
}
enum StockLevel { in_('in'), low('low'), out('out'); … }   // token differs from the identifier
enum DisplayUnit { part('part'), ml('ml'); … }
enum LineMark { base('base'), optional('optional'); … }    // ADR 06
enum TagColor { teal('teal'), … slate('slate'); … }        // ADR 07, open to new members
```

`RecipeLine.mark` holds that one `LineMark?`, so a base line can never also be optional
(FR-REC-8); `isBase` and `isOptional` are getters over it, and `marked(LineMark?)` is what
sets and clears it — `copyWith` cannot, since null is its "keep what you have".

`Model` answers reference questions directly, so no consumer builds its own name index:

```dart
Ingredient? ingredientNamed(String name);
Recipe? recipeNamed(String name);
List<Tag> tagsOf(TagKind kind);
bool hasTag(TagKind kind, String name);

Set<String> get ingredientNames;      // the sets every validate… call asks for
Set<String> get recipeNames;
Set<String> tagNames(TagKind kind);
```

These are backed by a `late final` map built on first use. `Model` stays immutable and the
memoisation is invisible; a lookup is O(1) after the first call, which is what the recipe list,
availability, and the optimizer all need at NFR-2 scale. The name sets are memoised on the same
terms, so a form judging a name on every keystroke builds one once instead of one per frame.

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
Model withIngredient(Ingredient ingredient);          // add, or replace the entry of that name
Model withIngredientRenamed(String from, String to);  // rewrites every referencing recipe line
Model withoutIngredient(String name);
Model withStock(String ingredient, StockLevel stock);
Model withTag(TagKind kind, Tag tag);                 // add or replace in that vocabulary
Model withTagRenamed(TagKind kind, String from, String to);   // rewrites every entry wearing it
Model withoutTag(TagKind kind, String name);
Model withRecipe(Recipe recipe);                      // add or replace by name
Model withoutRecipe(String name);
Model withRecipeMade(String name, DateTime today);    // the clock is a parameter (FR-REC-6)

List<String> recipesUsingIngredient(String name);     // FR-VOC-1 delete blocking
List<String> usersOfTag(TagKind kind, String name);
```

A tag edit touches only its own side: renaming a recipe tag never reads an ingredient, and
`usersOfTag` blocks deletion from its own side only. One name may stand in both vocabularies and
mean two different things, so the `kind` is what tells them apart, never the name.

Three rules: edit for missing entry returns unchanged (stale name can't crash). Collision with 
existing name throws `ArgumentError` (programmer contract). Removal never cascades (caller asks 
`recipesUsing…` first for blocking message).

`copyWith` on multi-field values (`Settings`, `Ingredient`, `Tag`, `RecipeLine`, `Recipe`, `Model`); 
rename/stock/made built from it. `Amount`, `MadeHistory` rebuilt whole. Two unreachable fields have 
own methods: `RecipeLine.marked` clears mark; `Recipe.copyWith` can't clear `made` (never unmade, 
FR-REC-6).

Rebuilding `Model` on every edit is deliberate (pilot scale: few thousand pointer writes; keeps all 
immutable, derived provider invalidation trivial).

### Line grammar

One implementation, two entry points (form gets non-throwing feedback; codec uses exceptions):

```dart
typedef ParsedLine = ({RecipeLine? line, String? problem});

ParsedLine tryParseRecipeLine(String text);   // never throws — recipe form (M14), codec (M6)
RecipeLine parseRecipeLine(String text);      // throws FormatException — built on tryParse
String formatRecipeLine(RecipeLine line);     // canonical form
String formatAmount(Amount amount);
String formatNumber(double value);            // canonical number text — amounts, part_ml
```

Grammar in [architecture.md](architecture.md#data-format). This file enforces syntax; value rules in validation.

### Validation

Contract and rationale: [ADR 05](adr/05-validation-contract.md).

```dart
enum ValidationIssueKind {
  emptyName, whitespaceInName, lineBreakInName, duplicateName, reservedSuffix,
  partMlNotPositive, unknownIngredient, unknownTag, duplicateTag,
  amountNotPositive, rangeOutOfOrder, timesBelowOne,
  unsupportedFormat, malformedLine, malformedValue,    // raised by the codec (M6)
}

final class ValidationIssue {
  final List<Object> path;         // data-format keys and indexes, e.g. ['recipes', 0, 'lines', 2]
  final ValidationIssueKind kind;  // the rule that failed
  final String message;            // ready to display, names the offending value
  String get location;             // 'recipes[0].lines[2]'
}

List<ValidationIssue> validateModel({settings, ingredients, ingredientTags, recipeTags, recipes});
List<ValidationIssue> validateRecipe(Recipe recipe,
    {required Set<String> knownIngredients, required Set<String> knownTags,
     Set<String> otherRecipeNames});
List<ValidationIssue> validateIngredient(Ingredient ingredient,
    {required Set<String> knownIngredientTags, Set<String> otherIngredientNames});
List<ValidationIssue> validateTag(Tag tag, {Set<String> otherTagNames});
```

Empty result = valid. Issues collected in one pass (no fail-fast), top-to-bottom like file 
(settings, ingredients, tags, recipes, within each by index). Lets codec render as-is (M6). 
`ValidationIssue` has value equality.

`path` uses **data-format key names** (`part_ml`, `made.times`), not Dart names. Seam lets 
codec attach YAML line numbers, form attach field focus, without domain knowing either. 
Behaviour switches on `kind`; `message` is display-only.

`validateModel`: whole-file entry point for import (M6). Others check single entry a form edits 
(M11/M12/M14) in one call: paths relative, empty for name. `other…Names` holds every *other* 
entry's name (rename never collides with itself). All four run same rules, same code.

### Computations

Named now; implemented in milestones. All pure functions of `Model`. Algorithms in 
[architecture.md](architecture.md#domain-computations). `groupByBaseSpirit` reads base-marked lines, 
keys ungrouped tail with `null`. `randomCanMake` takes `Random` for testability.

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
   `tryParseRecipeLine` (problem → issue at line path).
4. Run `validateModel` on parts (referential, value rules) only if step 3 clean (broken shape 
   never cascades to spurious reference errors).
5. Resolve `ValidationIssue.path` against parse tree for line numbers.
6. Build `Model` (cannot throw; duplicates ruled out).

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

Each mutation is one line over `ModelEdits` derivation. All run through single private path: await 
startup load, derive, publish, save. The three `upsert…`s with `replacing` compose several derivations 
(whole form/dialog reaches disk as one model, the rename it leaves behind included). Awaiting load makes edits during startup land on 
loaded model, not replace. Edit that leaves model unchanged is not saved (no backup waste). UI never 
constructs `Model` or touches `ModelStore` ([ADR 03](adr/03-app-structure-and-state.md)).

Everything else is derived, read-only:

Filter state is presentation, never persisted; own provider so filter change invalidates only visible 
list, not model-derived.

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
