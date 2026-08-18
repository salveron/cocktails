/// Collection edits as pure derivations; kept separate so collection.dart
/// holds shape only. Edits naming absent entries return the collection
/// unchanged; collisions throw ArgumentError.
library;

import 'names.dart';
import 'collection.dart';
import 'list_edits.dart';

/// Unit edit result: current state and prior name (null if new).
typedef UnitEdit = ({Unit unit, String? was});

extension CollectionEdits on Collection {
  Collection withSettings(Settings settings) => copyWith(settings: settings);

  /// Whole unit vocabulary at once; renames rewrite lines measured in them (ADR-09).
  Collection withUnits(List<UnitEdit> edits) {
    final renamed = <String, String>{};
    for (final (:unit, :was) in edits) {
      // Exact comparison: recapitalization is same unit, lines follow (ADR-08).
      if (was != null && was != unit.name) renamed[nameKey(was)] = unit.name;
    }
    final units = [for (final edit in edits) edit.unit];
    return renamed.isEmpty
        ? copyWith(units: units)
        : copyWith(
            units: units,
            recipes: [
              for (final recipe in recipes)
                _withLines(
                  recipe,
                  (line) => line.copyWith(
                    unit: renamed[nameKey(line.unit)] ?? line.unit,
                  ),
                ),
            ],
          );
  }

  /// Every recipe line under ingredient's own name; aliases/cases resolve
  /// (ADR-10).
  Collection withCanonicalIngredientNames() {
    final canonical = <Recipe>[];
    var moved = false;
    for (final recipe in recipes) {
      final resolved = _withLines(
        recipe,
        (line) => line.copyWith(
          ingredients: [for (final name in line.ingredients) spellingOf(name)],
        ),
      );
      moved |= !identical(resolved, recipe);
      canonical.add(resolved);
    }
    return moved ? copyWith(recipes: canonical) : this;
  }

  /// Adds or replaces ingredient; every line that named it follows (FR-VOC-1, ADR-10).
  Collection withIngredient(Ingredient ingredient, {String? replacing}) {
    final from = replacing ?? ingredient.name;
    return copyWith(
      ingredients: upserted(ingredients, ingredient, [
        (e) => e.name.sameName(from),
        (e) => e.name.sameName(ingredient.name),
      ]),
      recipes: from == ingredient.name
          ? recipes
          : [
              for (final recipe in recipes)
                _withLines(
                  recipe,
                  (line) => line.copyWith(
                    ingredients: [
                      for (final name in line.ingredients)
                        name.sameName(from) ? ingredient.name : name,
                    ],
                  ),
                ),
            ],
    );
  }

  Collection withoutIngredient(String name) =>
      copyWith(ingredients: without(ingredients, (i) => i.name.sameName(name)));

  Collection withStock(String ingredient, StockLevel stock) {
    final entry = ingredientNamed(ingredient);
    return entry == null ? this : withIngredient(entry.copyWith(stock: stock));
  }

  /// Adds [tag] to [kind]'s vocabulary, or replaces the entry of its name.
  Collection withTag(TagKind kind, Tag tag) => _withTags(
    kind,
    upserted(tagsOf(kind), tag, [(t) => t.name.sameName(tag.name)]),
  );

  Collection withoutTag(TagKind kind, String name) =>
      _withTags(kind, without(tagsOf(kind), (t) => t.name.sameName(name)));

  /// Renames tag and rewrites all entries wearing it; on their own side only (FR-VOC-4).
  Collection withTagRenamed(TagKind kind, String from, String to) {
    if (!hasTag(kind, from)) return this;
    final renamed = _withTags(kind, _renamedTag(tagsOf(kind), from, to));
    return switch (kind) {
      TagKind.recipe => renamed.copyWith(
        recipes: [
          for (final recipe in recipes)
            switch (_tagsRenamed(recipe.tags, from, to)) {
              null => recipe,
              final tags => recipe.copyWith(tags: tags),
            },
        ],
      ),
      TagKind.ingredient => renamed.copyWith(
        ingredients: [
          for (final ingredient in ingredients)
            switch (_tagsRenamed(ingredient.tags, from, to)) {
              null => ingredient,
              final tags => ingredient.copyWith(tags: tags),
            },
        ],
      ),
    };
  }

  Collection _withTags(TagKind kind, List<Tag> tags) => switch (kind) {
    TagKind.recipe => copyWith(recipeTags: tags),
    TagKind.ingredient => copyWith(ingredientTags: tags),
  };

  /// Adds or replaces recipe by name.
  Collection withRecipe(Recipe recipe) => copyWith(
    recipes: upserted(recipes, recipe, [(r) => r.name.sameName(recipe.name)]),
  );

  Collection withoutRecipe(String name) =>
      copyWith(recipes: without(recipes, (r) => r.name.sameName(name)));

  /// Recipe names blocking ingredient deletion, in collection order
  /// (FR-VOC-1, ADR-10). Spellings on both sides: an alias references its
  /// entry as surely as the canonical name does.
  List<String> recipesUsingIngredient(String name) => _referencing(
    recipes,
    (r) => r.name,
    (r) => [
      for (final line in r.lines)
        for (final n in line.ingredients) spellingOf(n),
    ],
    spellingOf(name),
  );

  /// Recipe names blocking unit deletion (measured-in reference).
  List<String> recipesUsingUnit(String name) => _referencing(
    recipes,
    (r) => r.name,
    (r) => [for (final line in r.lines) line.unit],
    name,
  );

  /// Users of a tag; blocked by own vocabulary's side only.
  List<String> usersOfTag(TagKind kind, String name) => switch (kind) {
    TagKind.recipe => _referencing(recipes, (r) => r.name, (r) => r.tags, name),
    TagKind.ingredient => _referencing(
      ingredients,
      (i) => i.name,
      (i) => i.tags,
      name,
    ),
  };
}

/// Names of [items] that reference [name] among the spellings [refsOf] them
/// gives back — the one walk `recipesUsingIngredient`, `recipesUsingUnit` and
/// `usersOfTag` all are, case and spelling folded (ADR-08).
List<String> _referencing<T>(
  List<T> items,
  String Function(T) nameOf,
  Iterable<String> Function(T) refsOf,
  String name,
) => [
  for (final item in items)
    if (refsOf(item).any((ref) => ref.sameName(name))) nameOf(item),
];

/// [recipe] with every line put through [rewrite] — the recipe itself where
/// none moved, so an edit reaching no line rebuilds nothing and callers can
/// tell by identity.
Recipe _withLines(Recipe recipe, RecipeLine Function(RecipeLine line) rewrite) {
  final lines = <RecipeLine>[];
  var moved = false;
  for (final line in recipe.lines) {
    final rewritten = rewrite(line);
    moved |= rewritten != line;
    lines.add(rewritten);
  }
  return moved ? recipe.copyWith(lines: lines) : recipe;
}

/// Tags with [from] renamed to [to]; via copyWith to preserve color.
List<Tag> _renamedTag(List<Tag> tags, String from, String to) => [
  for (final tag in tags)
    tag.name.sameName(from) ? tag.copyWith(name: to) : tag,
];

/// Tags with [from] rewritten to [to]; null if none matched.
List<String>? _tagsRenamed(List<String> tags, String from, String to) =>
    tags.any((tag) => tag.sameName(from))
    ? [for (final tag in tags) tag.sameName(from) ? to : tag]
    : null;
