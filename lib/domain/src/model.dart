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

  const Ingredient(this.name, {this.stock = StockLevel.out});

  Ingredient copyWith({String? name, StockLevel? stock}) =>
      Ingredient(name ?? this.name, stock: stock ?? this.stock);

  @override
  bool operator ==(Object other) =>
      other is Ingredient && other.name == name && other.stock == stock;

  @override
  int get hashCode => Object.hash(name, stock);

  @override
  String toString() => 'Ingredient($name, stock: ${stock.token})';
}

final class Tag {
  final String name;

  const Tag(this.name);

  @override
  bool operator ==(Object other) => other is Tag && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Tag($name)';
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
  final List<Tag> tags;
  final List<Recipe> recipes;

  Model({
    this.settings = const Settings(),
    List<Ingredient> ingredients = const [],
    List<Tag> tags = const [],
    List<Recipe> recipes = const [],
  }) : ingredients = List.unmodifiable(ingredients),
       tags = List.unmodifiable(tags),
       recipes = List.unmodifiable(recipes) {
    _requireUniqueNames(
      'ingredient',
      this.ingredients.map((i) => i.name).toList(),
    );
    _requireUniqueNames('tag', this.tags.map((t) => t.name).toList());
    _requireUniqueNames('recipe', this.recipes.map((r) => r.name).toList());
  }

  Model copyWith({
    Settings? settings,
    List<Ingredient>? ingredients,
    List<Tag>? tags,
    List<Recipe>? recipes,
  }) => Model(
    settings: settings ?? this.settings,
    ingredients: ingredients ?? this.ingredients,
    tags: tags ?? this.tags,
    recipes: recipes ?? this.recipes,
  );

  Ingredient? ingredientNamed(String name) => _ingredientsByName[name];

  Recipe? recipeNamed(String name) => _recipesByName[name];

  bool hasTag(String name) => _tagNames.contains(name);

  /// Built on first lookup and kept, which is what makes repeated reference
  /// questions O(1) at NFR-2 scale. Safe behind an immutable face: the lists
  /// they index can never change.
  late final Map<String, Ingredient> _ingredientsByName = {
    for (final ingredient in ingredients) ingredient.name: ingredient,
  };
  late final Map<String, Recipe> _recipesByName = {
    for (final recipe in recipes) recipe.name: recipe,
  };
  late final Set<String> _tagNames = {for (final tag in tags) tag.name};

  @override
  bool operator ==(Object other) =>
      other is Model &&
      other.settings == settings &&
      listEquals(other.ingredients, ingredients) &&
      listEquals(other.tags, tags) &&
      listEquals(other.recipes, recipes);

  @override
  int get hashCode => Object.hash(
    settings,
    Object.hashAll(ingredients),
    Object.hashAll(tags),
    Object.hashAll(recipes),
  );

  @override
  String toString() =>
      'Model(${ingredients.length} ingredients, ${tags.length} tags, '
      '${recipes.length} recipes)';
}

void _requireUniqueNames(String kind, List<String> names) {
  final duplicates = duplicateNameIndexes(names);
  if (duplicates.isNotEmpty) {
    throw ArgumentError('Duplicate $kind name: "${names[duplicates.first]}"');
  }
}
