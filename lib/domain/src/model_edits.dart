/// Every model edit as a pure derivation returning a new [Model]
/// (docs/components.md#editing-the-model), kept out of model.dart so that file
/// stays the home of shape and invariants. An edit naming an entry that is not
/// there returns the model unchanged; one that collides with an existing name
/// throws [ArgumentError] from the [Model] constructor.
library;

import 'model.dart';

extension ModelEdits on Model {
  Model withSettings(Settings settings) => copyWith(settings: settings);

  /// Adds [ingredient], or replaces the entry of its name where it stands.
  Model withIngredient(Ingredient ingredient) =>
      copyWith(ingredients: _upserted(ingredients, ingredient, (i) => i.name));

  Model withoutIngredient(String name) =>
      copyWith(ingredients: _without(ingredients, name, (i) => i.name));

  Model withStock(String ingredient, StockLevel stock) {
    final entry = ingredientNamed(ingredient);
    return entry == null ? this : withIngredient(entry.copyWith(stock: stock));
  }

  /// Sets which ingredient-tag names [ingredient] carries, replacing whatever
  /// it carried before (FR-VOC-4) — the vocabulary itself is edited through
  /// [withIngredientTag].
  Model withIngredientTags(String ingredient, List<String> tags) {
    final entry = ingredientNamed(ingredient);
    return entry == null ? this : withIngredient(entry.copyWith(tags: tags));
  }

  /// Renames the entry and rewrites every recipe line that referenced it —
  /// a name is the only reference there is (FR-VOC-1).
  Model withIngredientRenamed(String from, String to) {
    if (ingredientNamed(from) == null) return this;
    return copyWith(
      ingredients: [
        for (final ingredient in ingredients)
          ingredient.name == from ? ingredient.copyWith(name: to) : ingredient,
      ],
      recipes: [
        for (final recipe in recipes) _withLinesRenamed(recipe, from, to),
      ],
    );
  }

  Model withRecipeTag(Tag tag) =>
      copyWith(recipeTags: _upserted(recipeTags, tag, _tagName));

  Model withoutRecipeTag(String name) =>
      copyWith(recipeTags: _without(recipeTags, name, _tagName));

  /// Renames the entry and rewrites every recipe that carried the tag.
  Model withRecipeTagRenamed(String from, String to) {
    if (!hasRecipeTag(from)) return this;
    return copyWith(
      recipeTags: _renamedTag(recipeTags, from, to),
      recipes: [
        for (final recipe in recipes)
          switch (_tagsRenamed(recipe.tags, from, to)) {
            null => recipe,
            final tags => recipe.copyWith(tags: tags),
          },
      ],
    );
  }

  Model withIngredientTag(Tag tag) =>
      copyWith(ingredientTags: _upserted(ingredientTags, tag, _tagName));

  Model withoutIngredientTag(String name) =>
      copyWith(ingredientTags: _without(ingredientTags, name, _tagName));

  /// Renames the entry and rewrites every ingredient that carried the tag.
  Model withIngredientTagRenamed(String from, String to) {
    if (!hasIngredientTag(from)) return this;
    return copyWith(
      ingredientTags: _renamedTag(ingredientTags, from, to),
      ingredients: [
        for (final ingredient in ingredients)
          switch (_tagsRenamed(ingredient.tags, from, to)) {
            null => ingredient,
            final tags => ingredient.copyWith(tags: tags),
          },
      ],
    );
  }

  /// Adds [recipe], or replaces the one of its name where it stands.
  Model withRecipe(Recipe recipe) =>
      copyWith(recipes: _upserted(recipes, recipe, (r) => r.name));

  Model withoutRecipe(String name) =>
      copyWith(recipes: _without(recipes, name, (r) => r.name));

  /// Stamps the recipe as made on [today] and counts it (FR-REC-6). The clock
  /// is a parameter — the domain reads no ambient time.
  Model withRecipeMade(String name, DateTime today) {
    final recipe = recipeNamed(name);
    if (recipe == null) return this;
    final made = recipe.made;
    return withRecipe(
      recipe.copyWith(
        made: MadeHistory(today, made == null ? 1 : made.times + 1),
      ),
    );
  }

  /// Names of the recipes standing in the way of deleting the ingredient, in
  /// model order; empty when it is free to go (FR-VOC-1). Optional lines count
  /// — they reference the vocabulary just as required ones do.
  List<String> recipesUsingIngredient(String name) => [
    for (final recipe in recipes)
      if (recipe.lines.any((line) => line.ingredient == name)) recipe.name,
  ];

  /// [recipesUsingIngredient] for recipe tags.
  List<String> recipesUsingTag(String name) => [
    for (final recipe in recipes)
      if (recipe.tags.contains(name)) recipe.name,
  ];

  /// [recipesUsingIngredient] for ingredient tags. A tag is blocked by
  /// references from its own vocabulary's side only.
  List<String> ingredientsUsingTag(String name) => [
    for (final ingredient in ingredients)
      if (ingredient.tags.contains(name)) ingredient.name,
  ];
}

String _tagName(Tag tag) => tag.name;

/// The vocabulary with the entry named [from] renamed to [to] — through
/// [Tag.copyWith], so the colour comes along; building a fresh [Tag] here
/// would drop it.
List<Tag> _renamedTag(List<Tag> tags, String from, String to) => [
  for (final tag in tags) tag.name == from ? tag.copyWith(name: to) : tag,
];

/// [item] in place of the entry sharing its name, appended when there is none.
List<T> _upserted<T>(List<T> items, T item, String Function(T) nameOf) {
  final name = nameOf(item);
  final index = items.indexWhere((entry) => nameOf(entry) == name);
  return index < 0 ? [...items, item] : ([...items]..[index] = item);
}

List<T> _without<T>(List<T> items, String name, String Function(T) nameOf) => [
  for (final item in items)
    if (nameOf(item) != name) item,
];

/// The recipe with its references rewritten, or the very same recipe when it
/// held none — an untouched recipe is not worth rebuilding.
Recipe _withLinesRenamed(Recipe recipe, String from, String to) =>
    recipe.lines.any((line) => line.ingredient == from)
    ? recipe.copyWith(
        lines: [
          for (final line in recipe.lines)
            line.ingredient == from ? line.copyWith(ingredient: to) : line,
        ],
      )
    : recipe;

/// [tags] with [from] rewritten to [to], or null when it held no [from] — the
/// caller then keeps the entry it has rather than rebuilding it. One home for
/// rewriting tag references, whichever vocabulary is being renamed.
List<String>? _tagsRenamed(List<String> tags, String from, String to) =>
    tags.contains(from)
    ? [for (final tag in tags) tag == from ? to : tag]
    : null;
