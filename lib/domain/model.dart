/// Domain entities and the model root. Shapes, defaults, and name-uniqueness
/// rules follow the data format in docs/architecture.md. Value validation
/// (malformed amounts, referential integrity) is M5's rule set, not enforced
/// here.
library;

enum StockLevel { inStock, lowStock, outOfStock }

enum Unit { part, ml, oz, dash, barspoon, drop, piece }

enum DisplayUnit { part, ml }

final class Ingredient {
  final String name;
  final bool isBase;
  final StockLevel stock;

  const Ingredient(
    this.name, {
    this.isBase = false,
    this.stock = StockLevel.outOfStock,
  });

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.name == name &&
      other.isBase == isBase &&
      other.stock == stock;

  @override
  int get hashCode => Object.hash(name, isBase, stock);

  @override
  String toString() => 'Ingredient($name, base: $isBase, stock: ${stock.name})';
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
  final bool isOptional;

  const RecipeLine(
    this.amount,
    this.unit,
    this.ingredient, {
    this.isOptional = false,
  });

  @override
  bool operator ==(Object other) =>
      other is RecipeLine &&
      other.amount == amount &&
      other.unit == unit &&
      other.ingredient == ingredient &&
      other.isOptional == isOptional;

  @override
  int get hashCode => Object.hash(amount, unit, ingredient, isOptional);

  @override
  String toString() =>
      'RecipeLine($amount ${unit.name} $ingredient'
      '${isOptional ? ', optional' : ''})';
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

  @override
  bool operator ==(Object other) =>
      other is Settings && other.partMl == partMl && other.display == display;

  @override
  int get hashCode => Object.hash(partMl, display);

  @override
  String toString() => 'Settings($partMl ml/part, display: ${display.name})';
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

  @override
  bool operator ==(Object other) =>
      other is Recipe &&
      other.name == name &&
      _listEquals(other.tags, tags) &&
      _listEquals(other.lines, lines) &&
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
    _requireUniqueNames('ingredient', this.ingredients.map((i) => i.name));
    _requireUniqueNames('tag', this.tags.map((t) => t.name));
    _requireUniqueNames('recipe', this.recipes.map((r) => r.name));
  }

  @override
  bool operator ==(Object other) =>
      other is Model &&
      other.settings == settings &&
      _listEquals(other.ingredients, ingredients) &&
      _listEquals(other.tags, tags) &&
      _listEquals(other.recipes, recipes);

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

void _requireUniqueNames(String kind, Iterable<String> names) {
  final seen = <String>{};
  for (final name in names) {
    if (!seen.add(name)) {
      throw ArgumentError('Duplicate $kind name: "$name"');
    }
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
