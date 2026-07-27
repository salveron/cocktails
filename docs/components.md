# Components

Module-level design for the pilot: the folder structure, what each layer exposes, the
interfaces between them, and how data flows across them. The system-level design is in
[architecture.md](architecture.md); rationale for the boundaries is in
[ADR 04](adr/04-module-boundaries.md). Signatures marked with a milestone
([roadmap.md](roadmap.md)) do not exist yet — they are named here so the layers that consume
them can be designed against a fixed shape.

## Module map

Each layer is a folder with a barrel file. **The barrel is the layer's entire public
surface**; everything else lives under `src/` and is invisible to the rest of the app.

```
lib/
  main.dart                    # ProviderScope, store override, CocktailsApp
  domain/
    domain.dart                # barrel — the only domain import other layers use
    src/
      model.dart               # entities, Model root, name lookups
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
      model_controller.dart    # M8 — the one writable provider
      derived.dart             # availability, visible recipes, grouping, optimizer
      filters.dart             # filter and search UI state
  ui/
    app.dart, theme.dart       # M9
    screens/, widgets/         # no barrel — leaves, imported directly
test/                          # mirrors lib/, plus test/architecture_test.dart
```

`domain/src/helpers.dart` holds logic shared between domain files (layer-private, not exported). Contains `duplicateNameIndexes` and `listEquals`.

## Boundary rules

Three levels of visibility, used deliberately:

| Marking | Scope | Use for |
|---|---|---|
| `_name` | the file | helpers used in one file |
| public in `src/`, not exported | the layer | logic shared between files of one layer |
| exported from the barrel | the app | the layer's contract with other layers |

Dependencies point strictly inward — `ui → state → data → domain` — with these rules:

- `domain/**` imports no other layer, and nothing from `package:flutter/*`, `dart:io`, or
  `dart:ui`. It is plain Dart, testable with no device.
- `data/**` imports `domain/domain.dart` only.
- `state/**` imports `domain/domain.dart` and `data/data.dart`.
- `ui/**` imports `domain/domain.dart` and `state/state.dart`; never `data/`.
- A layer's public surface is exactly its barrel: no file depends on another layer's `src/`,
  nor on any other file of that layer. `ui/` is the exception that needs no barrel — nothing
  depends on it, so `main.dart` imports its leaves directly.
- Within a layer, `src/` files import each other by relative path.
- A barrel re-exports only its own layer. Re-exporting a sibling layer — even one this layer
  may legally import — would publish that layer's surface to everyone downstream and open a
  transitive route around the rules above.

`test/architecture_test.dart` (M5a) reads the `import` and `export` directives under `lib/`
and fails on any violation, so the rules are enforced by the suite rather than by review
habit. It needs no package beyond `dart:io` and the existing test harness. Its rules are pure
functions over a (path, directives) pair, exercised against constructed inputs as well as the
real tree, so the suite cannot pass vacuously.

## Domain contracts

Pure Dart, no I/O, no clock, no randomness taken from ambient state — anything time- or
chance-dependent is passed in, which is what keeps the layer unit-testable.

### Entities and the model root

`Ingredient`, `Tag`, `Amount`, `RecipeLine`, `MadeHistory`, `Settings`, `Recipe` and `Model`
are immutable `final class` values with structural equality. Collections are copied and
wrapped with `List.unmodifiable` on construction.

Two identity conventions hold throughout and explain the shape of the model:

- **Vocabulary entries are entities; references are names.** `Model.ingredients` holds
  `Ingredient` values with their stock and base flag; `RecipeLine.ingredient` and
  `Recipe.tags` hold plain `String` names. There are no surrogate IDs — a rename is a model
  mutation that rewrites every reference ([architecture.md](architecture.md#system-overview)).
- **Wire tokens are declared, not inferred.** The on-disk spelling of an enum is a field on
  the enum, never its Dart identifier, so renaming a member cannot silently change the file
  format:

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
```

`Model` answers reference questions directly, so no consumer builds its own name index:

```dart
Ingredient? ingredientNamed(String name);
Recipe? recipeNamed(String name);
bool hasTag(String name);
```

These are backed by a `late final` map built on first use. `Model` stays immutable and the
memoisation is invisible; a lookup is O(1) after the first call, which is what the recipe list,
availability, and the optimizer all need at NFR-2 scale.

### Two contracts, one rule set

Name uniqueness is checked in two places on purpose, and the distinction is worth stating
because it explains why `validateModel` takes model *parts* rather than a `Model`:

- `Model`'s constructor throws `ArgumentError` on a duplicate name. This is the **programmer**
  contract — a `Model` that exists is well-formed, so no consumer re-checks.
- `validateModel` returns issues and never throws. This is the **data** contract for untrusted
  input (imported files, form entry), which must be *reported*, not crashed on. It therefore
  works on the loose parts, before a `Model` could be constructed.

Both sit on the single `duplicateNameIndexes` implementation in `helpers.dart`.

### Editing the model

Every edit is a pure derivation returning a new `Model`, gathered in
`extension ModelEdits on Model` so `model.dart` stays the home of shape and invariants:

```dart
Model withSettings(Settings settings);
Model withIngredient(Ingredient ingredient);          // add, or replace the entry of that name
Model withIngredientRenamed(String from, String to);  // rewrites every referencing recipe line
Model withoutIngredient(String name);
Model withStock(String ingredient, StockLevel stock);
Model withTag(Tag tag);
Model withTagRenamed(String from, String to);         // rewrites every referencing recipe
Model withoutTag(String name);
Model withRecipe(Recipe recipe);                      // add or replace by name
Model withoutRecipe(String name);
Model withRecipeMade(String name, DateTime today);    // the clock is a parameter (FR-REC-6)

List<String> recipesUsingIngredient(String name);     // FR-VOC-1 delete blocking
List<String> recipesUsingTag(String name);
```

Three rules hold across the API. An edit naming an entry that is not there returns the model
unchanged, so a screen holding a stale name cannot crash the app. An edit that would collide
with an existing name throws `ArgumentError` from the `Model` constructor — the programmer
contract above, which the caller keeps by validating first. And removal never cascades: the
delete methods do not enforce FR-VOC-1's reference block themselves, because the caller asks
`recipesUsing…` first and needs the referencing names for the blocking message anyway.

`copyWith` goes on the values with more than one independently editable field — `Settings`,
`Ingredient`, `RecipeLine`, `Recipe`, `Model` — and is what the rename, stock and made edits
are built from; `Tag`, `Amount` and `MadeHistory` are rebuilt whole. `Recipe.copyWith` cannot
clear `made`: the pilot stamps a recipe as made and never unmakes it (FR-REC-6).

Rebuilding the whole `Model` on every edit is deliberate: at pilot scale the copy is a few
thousand pointer writes, and it keeps every value immutable and every derived provider's
invalidation trivially correct.

### Line grammar

One implementation, two entry points — so the recipe form gets non-throwing feedback and the
codec keeps the exception path it already uses:

```dart
typedef ParsedLine = ({RecipeLine? line, String? problem});

ParsedLine tryParseRecipeLine(String text);   // never throws — recipe form (M14), codec (M6)
RecipeLine parseRecipeLine(String text);      // throws FormatException — built on tryParse
String formatRecipeLine(RecipeLine line);     // canonical form
String formatAmount(Amount amount);
String formatNumber(double value);            // canonical number text — amounts, part_ml
```

The grammar itself is specified in [architecture.md](architecture.md#data-format). This file
enforces syntax only; value rules live in validation.

### Validation

The contract and its rationale are [ADR 05](adr/05-validation-contract.md).

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

List<ValidationIssue> validateModel({settings, ingredients, tags, recipes});
List<ValidationIssue> validateRecipe(Recipe recipe,
    {required Set<String> knownIngredients, required Set<String> knownTags,
     Set<String> otherRecipeNames});
List<ValidationIssue> validateIngredient(Ingredient ingredient,
    {Set<String> otherIngredientNames});
List<ValidationIssue> validateTag(Tag tag, {Set<String> otherTagNames});
```

An empty result means valid; every issue is collected in one pass, never fail-fast, so the
report reads top-to-bottom like the file: settings, then each vocabulary, then recipes in
order, and within each of those by entry index — every rule for one entry is applied before
the next entry, so a later pass never emits behind an earlier one. That is what lets the codec
render the list as it stands (M6). `ValidationIssue` carries value equality.

`path` uses the **data-format key names** (`part_ml`, `made.times`), not Dart field names.
This is the seam that lets the codec attach YAML line numbers and the recipe form attach field
focus, without the domain knowing about either. Behaviour switches on `kind`; `message` is for
display only, because matching on its text would make the wording API.

`validateModel` is the whole-file entry point for import (M6). The other three each check the
single entry a form is editing (M11/M12/M14) in one call: their paths are relative to that
entry and empty for its name, and `other…Names` holds every *other* entry's name, so a rename
never collides with itself. All four run the same rules over the same code.

### Computations

Named now, implemented in their milestones. All are pure functions of a `Model`:

```dart
enum Availability { makeable, makeableLow, missing }                    // FR-DIS-1
Availability availabilityOf(Recipe recipe, Model model);                // M16
Map<String, Availability> availabilityByRecipe(Model model);            // M16, single pass

Amount scaleAmount(Amount amount, int factor);                          // M17, FR-REC-7
String displayAmount(RecipeLine line, Settings settings, int factor);   // M17, FR-SET-1

List<Recipe> searchRecipes(Model model, String query);                  // M13, FR-DIS-2
List<Recipe> applyFilters(Model model, RecipeFilter filter,
                          Map<String, Availability> availability);      // M18, FR-DIS-3
Map<String?, List<Recipe>> groupByBaseSpirit(Model model,
                          List<Recipe> recipes);                        // M19, FR-DIS-4
Recipe? randomCanMake(List<Recipe> candidates, Random random);          // M20, FR-DIS-5

List<PurchaseOption> optimize(Model model, {required int budget});      // M21, FR-DIS-6
List<Ingredient> runningLow(Model model);                               // M22, FR-DIS-7
```

Availability is computed over required lines only; the algorithms are specified in
[architecture.md](architecture.md#domain-computations). `groupByBaseSpirit` keys the ungrouped
tail section with `null`. `randomCanMake` takes its `Random` so the pick is testable.

## Data contracts

The data layer owns everything the domain must not know: YAML, files, atomicity, backups.

```dart
abstract interface class ModelStore {
  Future<LoadOutcome> load();
  Future<void> save(Model model);
  Future<String> exportSnapshot();   // opaque location handed to the share sheet (M24)
}

sealed class LoadOutcome {}
final class Loaded  extends LoadOutcome { final Model model; }
final class Empty   extends LoadOutcome {}                  // no store file yet — first run
final class Corrupt extends LoadOutcome {
  final List<SourcedIssue> issues;
  final Model? recoveredFromBackup;
}
```

`exportSnapshot` returns a location rather than the file itself so that the store, not the UI,
decides what a shareable copy is. The UI passes it to the platform share API and never
learns it is a path ([architecture.md](architecture.md#storage-isolation)).

Import is not a store method: it is `YamlCodec.decode` followed by `save`. Keeping them
separate is what lets FR-DAT-3 slot the confirmation and the automatic pre-import export
between the two.

```dart
final class YamlCodec {
  static const int formatVersion = 1;
  String encode(Model model);        // canonical: fixed key order, fixed indent, no comments
  DecodeResult decode(String yaml);  // never throws
}

sealed class DecodeResult {}
final class Decoded  extends DecodeResult { final Model model; }
final class Rejected extends DecodeResult { final List<SourcedIssue> issues; }

final class SourcedIssue {
  final ValidationIssue issue;
  final int? line;                   // 1-based YAML line, null when unresolvable
}
```

`SourcedIssue` is its own module because both `Corrupt` and `Rejected` carry it: putting it in
`model_store.dart` would make the codec depend on the storage module to name its own result,
and putting it in `yaml_codec.dart` would make the storage interface depend on the concrete
YAML module — the coupling [ADR 02](adr/02-persistence-and-export-format.md) isolates against.

`decode` runs one pipeline, each stage feeding the same issue list:

1. Parse the YAML, retaining node spans.
2. Gate on `format` — an unsupported version is rejected here and nothing else runs.
3. Read the tree into model parts, reporting shape errors (wrong type, missing `name`) against
   the offending node; compact lines go through `tryParseRecipeLine`, whose `problem` string
   becomes an issue at that line's path.
4. Run `validateModel` on the parts for referential integrity and value rules — only when
   step 3 reported nothing, so a broken shape never cascades into spurious reference errors
   (a rejected `ingredients` section must not flag every recipe line as unknown).
5. Resolve each `ValidationIssue.path` against the parsed node tree to attach a line number.
6. Build the `Model` — it cannot throw, because step 4 already ruled out duplicates.

Step 5 is the **only** place data-format keys bind to source positions, which is why the domain
needs no notion of YAML and the codec needs no second copy of the rules.

`FileModelStore` writes to a temp file and renames, rotates a small set of backups, and
serialises every call through one queue so overlapping saves collapse to the latest model — the
single-writer discipline of [ADR 02](adr/02-persistence-and-export-format.md). A load whose
file is unreadable falls back to the newest backup that decodes, returning `Corrupt` with both
the issues and whatever was recovered; a load never throws, so a damaged file is reported like
any other FR-DAT-4 failure. It takes its directory as a constructor argument — the platform
path is resolved at the composition root (`main.dart`), which is what keeps the adapter
testable against a temp directory. File names and backup depth are
[platform facts](architecture.md#platform-facts). `MemoryModelStore` implements the same
interface for tests.

## State contracts

```dart
final modelStoreProvider = Provider<ModelStore>((ref) => throw UnimplementedError());
final modelProvider = AsyncNotifierProvider<ModelController, Model>(ModelController.new);
```

`modelStoreProvider` is overridden in `main.dart` with the file store and in tests with the
memory store — the seam that keeps state and widget tests device-free.
`ModelController.build()` performs the startup load and is the only writable provider.

Each mutation is one controller method that calls a `ModelEdits` operation, sets state, and
enqueues a save; the UI never constructs a `Model` and never touches `ModelStore`
([ADR 03](adr/03-app-structure-and-state.md)). Everything else is derived and read-only:

| Provider | Depends on | Milestone |
|---|---|---|
| `availabilityProvider` | model | M16 |
| `filterProvider` | UI state only — search text, tags, ingredients, availability | M13/M18 |
| `visibleRecipesProvider` | model, filter, availability | M13/M18 |
| `groupedRecipesProvider` | visible recipes | M19 |
| `optimizerProvider.family(budget)` | model, availability | M21 |
| `restockProvider` | model | M22 |

Filter state is presentation state and is never persisted; it lives in its own provider so a
filter change does not invalidate anything model-derived beyond the visible list.

Two performance facts, recorded so later milestones do not over-engineer:

- Every mutation replaces the whole `Model`, so every model-derived provider recomputes. At
  several hundred recipes an availability pass is well under a millisecond; incremental
  recomputation is not needed and should not be added (NFR-2).
- The optimizer is the one expensive computation. Its provider is watched only by the
  optimizer screen, so it never runs while the user is anywhere else.

## Data flows

1. **Startup** — `main` overrides `modelStoreProvider` with file store → `ModelController.build()` loads → `Loaded` seeds state, `Empty` seeds empty model, `Corrupt` seeds recovered model and surfaces issues.
2. **Edit** — widget calls `modelProvider.notifier.setStock(name, level)` → `ModelEdits` returns new `Model` → state updates, UI rebuilds from derived providers → save enqueued in background.
3. **Recipe form** (M14) — `tryParseRecipeLine` on each field for live feedback → `validateRecipe` on save, issue paths map to fields → clean recipe reaches `notifier.upsertRecipe`.
4. **Export** (FR-DAT-1) — `notifier.export()` returns location for share sheet; store file is the export.
5. **Import** (FR-DAT-3/4) — `YamlCodec.decode` validates → `Rejected` shows issues ("line N: message"), `Decoded` confirms and atomically saves.

Controller is the UI's only route to data layer; screens never hold `ModelStore` or `YamlCodec`.

## Testing

- **Domain** — unit tests, no device. Pure functions; clock and randomness passed in.
- **Data** — codec unit-tested (round-trip FR-DAT-5, broken-file decode with line numbers). `FileModelStore` integration-tested (atomic write, backups, recovery).
- **State** — controller tests against `MemoryModelStore`; mutation updates state and reaches store.
- **UI** — widget tests for critical flows with store provider overridden.
- **Boundaries** — `test/architecture_test.dart` enforces import rules.
