/// Every model edit as a pure derivation returning a new [Model]
/// (docs/components.md#editing-the-model), kept out of model.dart so that file
/// stays the home of shape and invariants. An edit naming an entry that is not
/// there returns the model unchanged; one that collides with an existing name
/// throws [ArgumentError] from the [Model] constructor.
library;

import 'helpers.dart';
import 'model.dart';

/// One row of the units screen on its way back: the entry as it now reads and
/// the name it had, null where it is new (docs/ui-design.md#units).
typedef UnitEdit = ({Unit unit, String? was});

extension ModelEdits on Model {
  Model withSettings(Settings settings) => copyWith(settings: settings);

  /// The whole unit vocabulary at once — every rename rewriting the lines
  /// measured in it, so two units can trade names in one edit and neither
  /// collides with the other on the way (ADR 09).
  Model withUnits(List<UnitEdit> edits) {
    final renamed = <String, String>{};
    for (final (:unit, :was) in edits) {
      // Compared exactly: a recapitalisation is the same unit under a new
      // spelling, and the lines take it too (ADR 08).
      if (was != null && was != unit.name) renamed[nameKey(was)] = unit.name;
    }
    final units = [for (final edit in edits) edit.unit];
    return renamed.isEmpty
        ? copyWith(units: units)
        : copyWith(
            units: units,
            recipes: [
              for (final recipe in recipes) _withUnitsRenamed(recipe, renamed),
            ],
          );
  }

  /// Every recipe line under the bottle's own name — where an alias or another
  /// case becomes the entry it means, and where an unknown name stays (ADR 10).
  Model withCanonicalIngredientNames() {
    final canonical = <Recipe>[];
    var moved = false;
    for (final recipe in recipes) {
      final lines = _canonicalLines(this, recipe.lines);
      moved |= lines != null;
      canonical.add(lines == null ? recipe : recipe.copyWith(lines: lines));
    }
    return moved ? copyWith(recipes: canonical) : this;
  }

  /// Adds [ingredient], or replaces the entry of its name — or the one named
  /// [replacing], every recipe line that named it following (FR-VOC-1). The
  /// whole entry settles at once, since a bottle renamed as its aliases change
  /// has no valid model to stop at halfway (ADR 10). The name it replaces is
  /// compared exactly, as [withUnits] compares its own.
  Model withIngredient(Ingredient ingredient, {String? replacing}) {
    final from = replacing ?? ingredient.name;
    return copyWith(
      ingredients: _upserted(ingredients, ingredient, (i) => i.name, at: from),
      recipes: from == ingredient.name
          ? recipes
          : [
              for (final recipe in recipes)
                _withLinesRenamed(recipe, from, ingredient.name),
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

  /// Renames the entry and rewrites every entry that wore the tag — the
  /// recipes for a recipe tag, the ingredients for an ingredient tag. A
  /// vocabulary is only ever worn on its own side (FR-VOC-4).
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

  /// Adds [recipe], or replaces the one of its name where it stands.
  Model withRecipe(Recipe recipe) =>
      copyWith(recipes: _upserted(recipes, recipe, (r) => r.name));

  Model withoutRecipe(String name) =>
      copyWith(recipes: _without(recipes, name, (r) => r.name));

  /// Stamps the recipe as made on [today] and counts it (FR-REC-6). The clock
  /// is a parameter — the domain reads no ambient time.
  Model withRecipeMade(String name, DateTime today) {
    final made = recipeNamed(name)?.made;
    return withRecipeHistory(
      name,
      MadeHistory(today, made == null ? 1 : made.times + 1),
    );
  }

  /// The one writer of a made-history: [made] as given, null for never made.
  /// Taking a stamp back is putting the history that preceded it back, so
  /// undo and reset are this one derivation twice (FR-REC-6).
  Model withRecipeHistory(String name, MadeHistory? made) {
    final recipe = recipeNamed(name);
    return recipe == null ? this : withRecipe(recipe.stamped(made));
  }

  /// Names of the recipes standing in the way of deleting the ingredient, in
  /// model order; empty when it is free to go (FR-VOC-1). Optional lines count,
  /// and so does one naming the bottle by an alias — both ends resolving
  /// through the one index (ADR 10).
  List<String> recipesUsingIngredient(String name) {
    final wanted = ingredientNamed(name)?.name ?? name;
    return [
      for (final recipe in recipes)
        if (recipe.lines.any((line) => _resolved(this, line).sameName(wanted)))
          recipe.name,
    ];
  }

  /// [recipesUsingIngredient] for a unit: what stands in the way of deleting
  /// it, since a line measured in a unit references it as it does a bottle.
  List<String> recipesUsingUnit(String name) => [
    for (final recipe in recipes)
      if (recipe.lines.any((line) => line.unit.sameName(name))) recipe.name,
  ];

  /// [recipesUsingIngredient] for a tag: the recipes wearing a recipe tag, the
  /// ingredients wearing an ingredient tag. A tag is blocked by references
  /// from its own vocabulary's side only.
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

/// The bottle [line] means, under its own name; as typed where there is none.
String _resolved(Model model, RecipeLine line) =>
    model.ingredientNamed(line.ingredient)?.name ?? line.ingredient;

/// [lines] resolved, or null where each already stood under its own name.
List<RecipeLine>? _canonicalLines(Model model, List<RecipeLine> lines) {
  final canonical = <RecipeLine>[];
  var moved = false;
  for (final line in lines) {
    final name = _resolved(model, line);
    moved |= name != line.ingredient;
    canonical.add(line.copyWith(ingredient: name));
  }
  return moved ? canonical : null;
}

/// The recipe with its measures rewritten under [renamed], or the very same
/// recipe where none of them moved — [_withLinesRenamed] for units.
Recipe _withUnitsRenamed(Recipe recipe, Map<String, String> renamed) =>
    recipe.lines.any((line) => renamed.containsKey(nameKey(line.unit)))
    ? recipe.copyWith(
        lines: [
          for (final line in recipe.lines)
            line.copyWith(unit: renamed[nameKey(line.unit)] ?? line.unit),
        ],
      )
    : recipe;

/// The vocabulary with the entry named [from] renamed to [to] — through
/// [Tag.copyWith], so the colour comes along; building a fresh [Tag] here
/// would drop it.
List<Tag> _renamedTag(List<Tag> tags, String from, String to) => [
  for (final tag in tags)
    tag.name.sameName(from) ? tag.copyWith(name: to) : tag,
];

/// [item] in place of the entry named [at], else of its own name, else added.
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

/// The recipe with its references rewritten, or the very same recipe when it
/// held none — an untouched recipe is not worth rebuilding.
Recipe _withLinesRenamed(Recipe recipe, String from, String to) =>
    recipe.lines.any((line) => line.ingredient.sameName(from))
    ? recipe.copyWith(
        lines: [
          for (final line in recipe.lines)
            line.ingredient.sameName(from)
                ? line.copyWith(ingredient: to)
                : line,
        ],
      )
    : recipe;

/// [tags] with [from] rewritten to [to], or null when it held no [from] — the
/// caller then keeps the entry it has rather than rebuilding it. One home for
/// rewriting tag references, whichever vocabulary is being renamed.
List<String>? _tagsRenamed(List<String> tags, String from, String to) =>
    tags.any((tag) => tag.sameName(from))
    ? [for (final tag in tags) tag.sameName(from) ? to : tag]
    : null;
