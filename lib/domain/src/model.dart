/// Domain entities and the model root. Shapes, defaults, and name-uniqueness
/// rules follow the data format in docs/architecture.md. Value validation
/// (malformed amounts, referential integrity) is validation.dart's rule set,
/// not enforced here.
library;

import 'helpers.dart';

enum StockLevel {
  in_('in'),
  low('low'),
  out('out');

  final String token;
  const StockLevel(this.token);

  /// The next step in a bottle's life — full, running low, empty, bought
  /// again — and so what one tap on the inventory list does (FR-INV-2).
  /// Declaration order is that life; the wire tokens above are independent
  /// of it.
  StockLevel get next => values[(index + 1) % values.length];

  static StockLevel? fromToken(String text) =>
      _fromToken(values, text, (v) => v.token);
}

enum Unit {
  part('part'),
  ml('ml'),
  oz('oz'),
  dash('dash'),
  barspoon('barspoon'),
  drop('drop'),
  piece('piece');

  final String token;
  const Unit(this.token);

  static Unit? fromToken(String text) =>
      _fromToken(values, text, (v) => v.token);
}

enum DisplayUnit {
  part('part'),
  ml('ml');

  final String token;
  const DisplayUnit(this.token);

  static DisplayUnit? fromToken(String text) =>
      _fromToken(values, text, (v) => v.token);
}

/// What a recipe makes of one of its lines — its base spirit, or a line it can
/// go without (docs/adr/06-base-spirit-on-the-line.md). One field, so a base
/// line can never also be optional.
enum LineMark {
  base('base'),
  optional('optional');

  final String token;
  const LineMark(this.token);

  static LineMark? fromToken(String text) =>
      _fromToken(values, text, (v) => v.token);
}

/// The palette a tag's colour comes from (docs/adr/07-tag-colour.md). Green,
/// amber and red are absent by design: stock and availability already spend
/// them on meaning. Every tag has one — there is no unpainted member, so a
/// colour on screen is always a choice someone made. Declaration order is the
/// order the picker offers, and the set is open to new members. What each
/// token looks like is the UI's to say.
enum TagColor {
  teal('teal'),
  indigo('indigo'),
  plum('plum'),
  rose('rose'),
  sand('sand'),
  slate('slate');

  final String token;
  const TagColor(this.token);

  static TagColor? fromToken(String text) =>
      _fromToken(values, text, (v) => v.token);
}

/// Linear token lookup shared by the enums above.
T? _fromToken<T extends Enum>(
  List<T> values,
  String text,
  String Function(T) token,
) {
  for (final value in values) {
    if (token(value) == text) return value;
  }
  return null;
}

final class Ingredient {
  final String name;
  final StockLevel stock;

  /// Names from the ingredient-tag vocabulary, as [Recipe.tags] holds names
  /// from the recipe one (FR-VOC-4). Optional: most bottles carry none.
  final List<String> tags;

  Ingredient(
    this.name, {
    this.stock = StockLevel.out,
    List<String> tags = const [],
  }) : tags = List.unmodifiable(tags);

  Ingredient copyWith({String? name, StockLevel? stock, List<String>? tags}) =>
      Ingredient(
        name ?? this.name,
        stock: stock ?? this.stock,
        tags: tags ?? this.tags,
      );

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.name == name &&
      other.stock == stock &&
      listEquals(other.tags, tags);

  @override
  int get hashCode => Object.hash(name, stock, Object.hashAll(tags));

  @override
  String toString() =>
      'Ingredient($name, stock: ${stock.token}'
      '${tags.isEmpty ? '' : ', tags: $tags'})';
}

/// One label in either vocabulary — they differ in what they name, not in what
/// they are (docs/adr/07-tag-colour.md). The colour is required: an unpainted
/// tag is not a thing the app can hold.
final class Tag {
  final String name;
  final TagColor color;

  const Tag(this.name, {required this.color});

  Tag copyWith({String? name, TagColor? color}) =>
      Tag(name ?? this.name, color: color ?? this.color);

  @override
  bool operator ==(Object other) =>
      other is Tag && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hash(name, color);

  @override
  String toString() => 'Tag($name, color: ${color.token})';
}

/// A single value when [min] == [max], a range otherwise (FR-REC-2).
final class Amount {
  final double min;
  final double max;

  const Amount(double value) : this.range(value, value);

  const Amount.range(this.min, this.max);

  bool get isRange => min != max;

  @override
  bool operator ==(Object other) =>
      other is Amount && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => isRange ? 'Amount($min-$max)' : 'Amount($min)';
}

final class RecipeLine {
  final Amount amount;
  final Unit unit;
  final String ingredient;
  final LineMark? mark;

  const RecipeLine(this.amount, this.unit, this.ingredient, {this.mark});

  bool get isBase => mark == LineMark.base;

  bool get isOptional => mark == LineMark.optional;

  RecipeLine copyWith({Amount? amount, Unit? unit, String? ingredient}) =>
      RecipeLine(
        amount ?? this.amount,
        unit ?? this.unit,
        ingredient ?? this.ingredient,
        mark: mark,
      );

  /// The only way to change the mark, and the only one that can clear it —
  /// `copyWith` cannot, since null is its "keep what you have".
  RecipeLine marked(LineMark? mark) =>
      RecipeLine(amount, unit, ingredient, mark: mark);

  @override
  bool operator ==(Object other) =>
      other is RecipeLine &&
      other.amount == amount &&
      other.unit == unit &&
      other.ingredient == ingredient &&
      other.mark == mark;

  @override
  int get hashCode => Object.hash(amount, unit, ingredient, mark);

  @override
  String toString() {
    final mark = this.mark;
    return 'RecipeLine($amount ${unit.token} $ingredient'
        '${mark == null ? '' : ', ${mark.token}'})';
  }
}

/// Made-history stamps a date (FR-REC-6): [last] keeps no time of day.
final class MadeHistory {
  final DateTime last;
  final int times;

  MadeHistory(DateTime last, this.times)
    : last = DateTime(last.year, last.month, last.day);

  @override
  bool operator ==(Object other) =>
      other is MadeHistory && other.last == last && other.times == times;

  @override
  int get hashCode => Object.hash(last, times);

  @override
  String toString() => 'MadeHistory(last: $last, times: $times)';
}

final class Settings {
  final double partMl;
  final DisplayUnit display;

  const Settings({this.partMl = 30, this.display = DisplayUnit.part});

  Settings copyWith({double? partMl, DisplayUnit? display}) =>
      Settings(partMl: partMl ?? this.partMl, display: display ?? this.display);

  @override
  bool operator ==(Object other) =>
      other is Settings && other.partMl == partMl && other.display == display;

  @override
  int get hashCode => Object.hash(partMl, display);

  @override
  String toString() => 'Settings($partMl ml/part, display: ${display.token})';
}

final class Recipe {
  final String name;
  final List<String> tags;
  final List<RecipeLine> lines;
  final String notes;
  final MadeHistory? made;

  Recipe(
    this.name, {
    List<String> tags = const [],
    List<RecipeLine> lines = const [],
    this.notes = '',
    this.made,
  }) : tags = List.unmodifiable(tags),
       lines = List.unmodifiable(lines);

  /// [made] only ever grows: the pilot stamps a recipe as made (FR-REC-6) and
  /// never unmakes it, so a null argument keeps the current history.
  Recipe copyWith({
    String? name,
    List<String>? tags,
    List<RecipeLine>? lines,
    String? notes,
    MadeHistory? made,
  }) => Recipe(
    name ?? this.name,
    tags: tags ?? this.tags,
    lines: lines ?? this.lines,
    notes: notes ?? this.notes,
    made: made ?? this.made,
  );

  @override
  bool operator ==(Object other) =>
      other is Recipe &&
      other.name == name &&
      listEquals(other.tags, tags) &&
      listEquals(other.lines, lines) &&
      other.notes == notes &&
      other.made == made;

  @override
  int get hashCode => Object.hash(
    name,
    Object.hashAll(tags),
    Object.hashAll(lines),
    notes,
    made,
  );

  @override
  String toString() => 'Recipe($name)';
}

final class Model {
  final Settings settings;
  final List<Ingredient> ingredients;

  /// The two tag vocabularies (docs/adr/07-tag-colour.md). Peers of one shape,
  /// each unique within itself — the same name may stand in both and mean two
  /// different things.
  final List<Tag> recipeTags;
  final List<Tag> ingredientTags;
  final List<Recipe> recipes;

  Model({
    this.settings = const Settings(),
    List<Ingredient> ingredients = const [],
    List<Tag> recipeTags = const [],
    List<Tag> ingredientTags = const [],
    List<Recipe> recipes = const [],
  }) : ingredients = List.unmodifiable(ingredients),
       recipeTags = List.unmodifiable(recipeTags),
       ingredientTags = List.unmodifiable(ingredientTags),
       recipes = List.unmodifiable(recipes) {
    _requireUniqueNames(
      'ingredient',
      this.ingredients.map((i) => i.name).toList(),
    );
    _requireUniqueNames(
      'recipe tag',
      this.recipeTags.map((t) => t.name).toList(),
    );
    _requireUniqueNames(
      'ingredient tag',
      this.ingredientTags.map((t) => t.name).toList(),
    );
    _requireUniqueNames('recipe', this.recipes.map((r) => r.name).toList());
  }

  Model copyWith({
    Settings? settings,
    List<Ingredient>? ingredients,
    List<Tag>? recipeTags,
    List<Tag>? ingredientTags,
    List<Recipe>? recipes,
  }) => Model(
    settings: settings ?? this.settings,
    ingredients: ingredients ?? this.ingredients,
    recipeTags: recipeTags ?? this.recipeTags,
    ingredientTags: ingredientTags ?? this.ingredientTags,
    recipes: recipes ?? this.recipes,
  );

  Ingredient? ingredientNamed(String name) => _ingredientsByName[name];

  Recipe? recipeNamed(String name) => _recipesByName[name];

  bool hasRecipeTag(String name) => _recipeTagNames.contains(name);

  bool hasIngredientTag(String name) => _ingredientTagNames.contains(name);

  /// Built on first lookup and kept, which is what makes repeated reference
  /// questions O(1) at NFR-2 scale. Safe behind an immutable face: the lists
  /// they index can never change.
  late final Map<String, Ingredient> _ingredientsByName = {
    for (final ingredient in ingredients) ingredient.name: ingredient,
  };
  late final Map<String, Recipe> _recipesByName = {
    for (final recipe in recipes) recipe.name: recipe,
  };
  late final Set<String> _recipeTagNames = {
    for (final tag in recipeTags) tag.name,
  };
  late final Set<String> _ingredientTagNames = {
    for (final tag in ingredientTags) tag.name,
  };

  @override
  bool operator ==(Object other) =>
      other is Model &&
      other.settings == settings &&
      listEquals(other.ingredients, ingredients) &&
      listEquals(other.recipeTags, recipeTags) &&
      listEquals(other.ingredientTags, ingredientTags) &&
      listEquals(other.recipes, recipes);

  @override
  int get hashCode => Object.hash(
    settings,
    Object.hashAll(ingredients),
    Object.hashAll(recipeTags),
    Object.hashAll(ingredientTags),
    Object.hashAll(recipes),
  );

  @override
  String toString() =>
      'Model(${ingredients.length} ingredients, ${recipeTags.length} recipe '
      'tags, ${ingredientTags.length} ingredient tags, '
      '${recipes.length} recipes)';
}

void _requireUniqueNames(String kind, List<String> names) {
  final duplicates = duplicateNameIndexes(names);
  if (duplicates.isNotEmpty) {
    throw ArgumentError('Duplicate $kind name: "${names[duplicates.first]}"');
  }
}
