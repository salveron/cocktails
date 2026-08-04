/// Model edits as pure derivations; kept separate so model.dart holds shape only.
/// Edits naming absent entries return unchanged model; collisions throw ArgumentError.
library;

import 'helpers.dart';
import 'model.dart';

/// Unit edit result: current state and prior name (null if new).
typedef UnitEdit = ({Unit unit, String? was});

extension ModelEdits on Model {
  Model withSettings(Settings settings) => copyWith(settings: settings);

  /// Whole unit vocabulary at once; renames rewrite lines measured in them (ADR-09).
  Model withUnits(List<UnitEdit> edits) {
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

  /// Every recipe line under bottle's own name; aliases/cases resolve (ADR-10).
  Model withCanonicalIngredientNames() {
    final canonical = <Recipe>[];
    var moved = false;
    for (final recipe in recipes) {
      final resolved = _withLines(
        recipe,
        (line) => line.copyWith(
          ingredients: [for (final name in line.ingredients) bottleNamed(name)],
        ),
      );
      moved |= !identical(resolved, recipe);
      canonical.add(resolved);
    }
    return moved ? copyWith(recipes: canonical) : this;
  }

  /// Adds or replaces ingredient; every line that named it follows (FR-VOC-1, ADR-10).
  Model withIngredient(Ingredient ingredient, {String? replacing}) {
    final from = replacing ?? ingredient.name;
    return copyWith(
      ingredients: _upserted(ingredients, ingredient, (i) => i.name, at: from),
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

  Model withoutIngredient(String name) =>
      copyWith(ingredients: _without(ingredients, name, (i) => i.name));

  Model withStock(String ingredient, StockLevel stock) {
    final entry = ingredientNamed(ingredient);
    return entry == null ? this : withIngredient(entry.copyWith(stock: stock));
  }

  /// Adds [tag] to [kind]'s vocabulary, or replaces the entry of its name.
  Model withTag(TagKind kind, Tag tag) =>
      _withTags(kind, _upserted(tagsOf(kind), tag, _tagName));

  Model withoutTag(TagKind kind, String name) =>
      _withTags(kind, _without(tagsOf(kind), name, _tagName));

  /// Renames tag and rewrites all entries wearing it; on their own side only (FR-VOC-4).
  Model withTagRenamed(TagKind kind, String from, String to) {
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

  Model _withTags(TagKind kind, List<Tag> tags) => switch (kind) {
    TagKind.recipe => copyWith(recipeTags: tags),
    TagKind.ingredient => copyWith(ingredientTags: tags),
  };

  /// Adds or replaces recipe by name.
  Model withRecipe(Recipe recipe) =>
      copyWith(recipes: _upserted(recipes, recipe, (r) => r.name));

  Model withoutRecipe(String name) =>
      copyWith(recipes: _without(recipes, name, (r) => r.name));

  /// Stamps recipe as made on [today] and counts it (FR-REC-6).
  Model withRecipeMade(String name, DateTime today) {
    final made = recipeNamed(name)?.made;
    return withRecipeHistory(
      name,
      MadeHistory(today, made == null ? 1 : made.times + 1),
    );
  }

  /// Only writer of made-history; null for never made (FR-REC-6).
  Model withRecipeHistory(String name, MadeHistory? made) {
    final recipe = recipeNamed(name);
    return recipe == null ? this : withRecipe(recipe.stamped(made));
  }

  /// Recipe names blocking ingredient deletion, in model order (FR-VOC-1, ADR-10).
  List<String> recipesUsingIngredient(String name) {
    final wanted = bottleNamed(name);
    return [
      for (final recipe in recipes)
        if (recipe.lines.any(
          (line) => line.ingredients.any(
            (name) => bottleNamed(name).sameName(wanted),
          ),
        ))
          recipe.name,
    ];
  }

  /// Recipe names blocking unit deletion (measured-in reference).
  List<String> recipesUsingUnit(String name) => [
    for (final recipe in recipes)
      if (recipe.lines.any((line) => line.unit.sameName(name))) recipe.name,
  ];

  /// Users of a tag; blocked by own vocabulary's side only.
  List<String> usersOfTag(TagKind kind, String name) => switch (kind) {
    TagKind.recipe => [
      for (final recipe in recipes)
        if (recipe.tags.any((tag) => tag.sameName(name))) recipe.name,
    ],
    TagKind.ingredient => [
      for (final ingredient in ingredients)
        if (ingredient.tags.any((tag) => tag.sameName(name))) ingredient.name,
    ],
  };
}

String _tagName(Tag tag) => tag.name;

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

/// [item] replacing entry named [at], else its own name, else added.
List<T> _upserted<T>(
  List<T> items,
  T item,
  String Function(T) nameOf, {
  String? at,
}) {
  for (final name in [?at, nameOf(item)]) {
    final index = items.indexWhere((entry) => nameOf(entry).sameName(name));
    if (index >= 0) return [...items]..[index] = item;
  }
  return [...items, item];
}

List<T> _without<T>(List<T> items, String name, String Function(T) nameOf) => [
  for (final item in items)
    if (!nameOf(item).sameName(name)) item,
];

/// Tags with [from] rewritten to [to]; null if none matched.
List<String>? _tagsRenamed(List<String> tags, String from, String to) =>
    tags.any((tag) => tag.sameName(from))
    ? [for (final tag in tags) tag.sameName(from) ? to : tag]
    : null;
