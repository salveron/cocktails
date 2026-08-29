/// The collection root: every vocabulary and every entry, and the memoised
/// lookups a name resolves through. Shapes and defaults follow the data
/// format in docs/architecture.md; value validation (malformed amounts,
/// referential integrity) is collection_validation.dart's rule set, not
/// enforced here.
library;

import '../names.dart';
import 'ingredient.dart';
import 'recipe.dart';
import 'tag.dart';
import 'unit.dart';
import 'unit_sizes.dart';

final class Collection {
  final UnitSizes unitSizes;

  /// Units vocabulary; used for files naming none (ADR-09).
  final List<Unit> units;
  final List<Ingredient> ingredients;

  /// Two tag vocabularies, peers of one shape; names unique within each (ADR-07).
  final List<Tag> ingredientTags;
  final List<Tag> recipeTags;
  final List<Recipe> recipes;

  Collection({
    this.unitSizes = const UnitSizes(),
    List<Unit> units = defaultUnits,
    List<Ingredient> ingredients = const [],
    List<Tag> ingredientTags = const [],
    List<Tag> recipeTags = const [],
    List<Recipe> recipes = const [],
  }) : units = List.unmodifiable(units),
       ingredients = List.unmodifiable(ingredients),
       ingredientTags = List.unmodifiable(ingredientTags),
       recipeTags = List.unmodifiable(recipeTags),
       recipes = List.unmodifiable(recipes) {
    _requireUniqueNames('unit', this.units.spellings);
    _requireUniqueNames('ingredient', [
      for (final ingredient in this.ingredients) ...ingredient.spellings,
    ]);
    _requireUniqueNames(
      'ingredient tag',
      this.ingredientTags.map((t) => t.name).toList(),
    );
    _requireUniqueNames(
      'recipe tag',
      this.recipeTags.map((t) => t.name).toList(),
    );
    _requireUniqueNames('recipe', this.recipes.map((r) => r.name).toList());
  }

  Collection copyWith({
    UnitSizes? unitSizes,
    List<Unit>? units,
    List<Ingredient>? ingredients,
    List<Tag>? ingredientTags,
    List<Tag>? recipeTags,
    List<Recipe>? recipes,
  }) => Collection(
    unitSizes: unitSizes ?? this.unitSizes,
    units: units ?? this.units,
    ingredients: ingredients ?? this.ingredients,
    ingredientTags: ingredientTags ?? this.ingredientTags,
    recipeTags: recipeTags ?? this.recipeTags,
    recipes: recipes ?? this.recipes,
  );

  /// The entry [name] names, any case, any spelling (ADR-08, ADR-10).
  Ingredient? ingredientNamed(String name) => _ingredientsByName[nameKey(name)];

  /// [name] under the ingredient's own spelling — what a reference is stored as
  /// and an offering reads in. A name outside the vocabulary stands as it came.
  String spellingOf(String name) => ingredientNamed(name)?.name ?? name;

  Recipe? recipeNamed(String name) => _recipesByName[nameKey(name)];

  List<Tag> tagsOf(TagKind kind) => switch (kind) {
    TagKind.recipe => recipeTags,
    TagKind.ingredient => ingredientTags,
  };

  bool hasTag(TagKind kind, String name) =>
      tagsOf(kind).any((tag) => tag.name.sameName(name));

  /// Memoized: keyed by fold and every alias for O(1) lookups (ADR-10).
  late final Map<String, Ingredient> _ingredientsByName = {
    for (final ingredient in ingredients)
      for (final spelling in ingredient.spellings)
        nameKey(spelling): ingredient,
  };
  late final Map<String, Recipe> _recipesByName = {
    for (final recipe in recipes) nameKey(recipe.name): recipe,
  };

  /// Recipe names as validation expects; memoized and unmodifiable.
  late final Set<String> recipeNames = Set.unmodifiable({
    for (final recipe in recipes) recipe.name,
  });

  /// All spellings the vocabulary answers to, except [except] (ADR-10).
  Set<String> ingredientSpellings({String? except}) => {
    for (final ingredient in ingredients)
      if (isOtherName(ingredient.name, except)) ...ingredient.spellings,
  };

  /// Unit spellings; used by reference rules.
  late final Set<String> unitSpellings = Set.unmodifiable(units.spellings);

  Set<String> tagNames(TagKind kind) => _tagNames[kind]!;

  /// Tag names keyed by kind.
  late final Map<TagKind, Set<String>> _tagNames = {
    for (final kind in TagKind.values)
      kind: Set.unmodifiable({for (final tag in tagsOf(kind)) tag.name}),
  };

  @override
  bool operator ==(Object other) =>
      other is Collection &&
      other.unitSizes == unitSizes &&
      listEquals(other.units, units) &&
      listEquals(other.ingredients, ingredients) &&
      listEquals(other.ingredientTags, ingredientTags) &&
      listEquals(other.recipeTags, recipeTags) &&
      listEquals(other.recipes, recipes);

  @override
  int get hashCode => Object.hash(
    unitSizes,
    Object.hashAll(units),
    Object.hashAll(ingredients),
    Object.hashAll(ingredientTags),
    Object.hashAll(recipeTags),
    Object.hashAll(recipes),
  );

  @override
  String toString() =>
      'Collection(${ingredients.length} ingredients, '
      '${ingredientTags.length} ingredient tags, '
      '${recipeTags.length} recipe tags, '
      '${recipes.length} recipes)';
}

void _requireUniqueNames(String kind, List<String> names) {
  final duplicates = duplicateNameIndexes(names);
  if (duplicates.isNotEmpty) {
    throw ArgumentError(duplicateNameMessage(kind, names[duplicates.first]));
  }
}
