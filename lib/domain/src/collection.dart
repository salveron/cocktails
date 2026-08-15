/// Domain entities and the collection root. Shapes, defaults, and name
/// uniqueness follow the data format in docs/architecture.md. Value validation
/// (malformed amounts, referential integrity) is validation.dart's rule set,
/// not enforced here.
library;

import 'names.dart';

enum StockLevel {
  in_('in'),
  low('low'),
  out('out');

  final String token;
  const StockLevel(this.token);

  /// Next step in a bottle's lifecycle (FR-INV-2).
  /// Declaration order is the life; wire tokens are independent.
  StockLevel get next => values[(index + 1) % values.length];

  static StockLevel? fromToken(String text) =>
      enumFromToken(values, text, (v) => v.token);
}

/// The fixed units (FR-VOC-5): no rename, no delete, and the only ones a
/// measure converts between — `Bar.display` names the one they all read in
/// ([ADR 17](../../../docs/adr/17-the-fixed-units-interconvert.md)).
enum FixedUnit {
  part(partUnit),
  ml(mlUnit),
  oz(ozUnit);

  final String token;
  const FixedUnit(this.token);

  static FixedUnit? fromToken(String text) =>
      enumFromToken(values, text, (v) => v.token);

  /// The fixed unit [name] spells, or null where it is one of the reader's own.
  static FixedUnit? named(String name) {
    for (final unit in values) {
      if (unit.token.sameName(name)) return unit;
    }
    return null;
  }
}

/// A recipe line's mark: base spirit or optional (ADR-06).
/// One field ensures a line cannot be both.
enum LineMark {
  base('base'),
  optional('optional');

  final String token;
  const LineMark(this.token);

  static LineMark? fromToken(String text) =>
      enumFromToken(values, text, (v) => v.token);
}

/// Tag color palette; green/amber/red reserved by stock and availability (ADR-07).
/// Every tag has a color; declaration order is the picker's order.
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
      enumFromToken(values, text, (v) => v.token);
}

/// Linear token lookup, shared by the enums above and by the bar's own
/// (shelf.dart). Public in src/, not exported (ADR-04).
T? enumFromToken<T extends Enum>(
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

  /// Other spellings a bottle answers to (FR-VOC-6, ADR-10): for finding, not showing.
  final List<String> aliases;

  /// Names from the ingredient-tag vocabulary (FR-VOC-4), optional.
  final List<String> tags;

  Ingredient(
    this.name, {
    this.stock = StockLevel.out,
    List<String> aliases = const [],
    List<String> tags = const [],
  }) : aliases = List.unmodifiable(aliases),
       tags = List.unmodifiable(tags);

  /// Every spelling: name first, then aliases; unique namespace (ADR-10).
  List<String> get spellings => [name, ...aliases];

  Ingredient copyWith({
    String? name,
    StockLevel? stock,
    List<String>? aliases,
    List<String>? tags,
  }) => Ingredient(
    name ?? this.name,
    stock: stock ?? this.stock,
    aliases: aliases ?? this.aliases,
    tags: tags ?? this.tags,
  );

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.name == name &&
      other.stock == stock &&
      listEquals(other.aliases, aliases) &&
      listEquals(other.tags, tags);

  @override
  int get hashCode =>
      Object.hash(name, stock, Object.hashAll(aliases), Object.hashAll(tags));

  @override
  String toString() =>
      'Ingredient($name, stock: ${stock.token}'
      '${aliases.isEmpty ? '' : ', aliases: $aliases'}'
      '${tags.isEmpty ? '' : ', tags: $tags'})';
}

/// Which vocabulary a tag belongs to; peers of one shape (ADR-07).
enum TagKind { recipe, ingredient }

/// A tag in either vocabulary; color is required (ADR-07).
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

/// A single value or a range (FR-REC-2).
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

/// One measure a line can be written in (ADR-09).
/// [plural] empty means plural reads the same as name.
final class Unit {
  final String name;
  final String plural;

  const Unit(this.name, {this.plural = ''});

  /// The plural as it reads; name itself where none was written.
  String get pluralName => plural.isEmpty ? name : plural;

  /// How [amount] is spelled: singular for one, plural otherwise.
  String spelling(Amount amount) =>
      amount == const Amount(1) ? name : pluralName;

  /// Whether [token] is one of its spellings, any case (ADR-08).
  bool answersTo(String token) =>
      name.sameName(token) || pluralName.sameName(token);

  @override
  bool operator ==(Object other) =>
      other is Unit && other.name == name && other.plural == plural;

  @override
  int get hashCode => Object.hash(name, plural);

  @override
  String toString() =>
      'Unit($name${plural.isEmpty ? '' : ', plural: $plural'})';
}

/// Default units; also used when a file names none.
const defaultUnits = [
  Unit(partUnit, plural: 'parts'),
  Unit(mlUnit),
  Unit(ozUnit),
  Unit('dash', plural: 'dashes'),
  Unit('barspoon', plural: 'barspoons'),
  Unit('drop', plural: 'drops'),
  Unit('piece', plural: 'pieces'),
];

/// The names [FixedUnit] is anchored to: an omitted unit is a part (FR-REC-2),
/// and the ratios convert between the three (FR-SET-1).
const partUnit = 'part';
const mlUnit = 'ml';
const ozUnit = 'oz';

bool isReservedUnit(String name) => FixedUnit.named(name) != null;

extension UnitLookup on List<Unit> {
  /// The unit [token] names; exact spellings answer first.
  Unit? unitNamed(String token) {
    for (final spelling in [
      token,
      if (token.endsWith('s')) token.substring(0, token.length - 1),
      if (token.endsWith('es')) token.substring(0, token.length - 2),
    ]) {
      for (final unit in this) {
        if (unit.answersTo(spelling)) return unit;
      }
    }
    return null;
  }

  /// Every spelling the vocabulary answers to, in order.
  List<String> get spellings => [
    for (final unit in this) ...[
      unit.name,
      if (!unit.pluralName.sameName(unit.name)) unit.pluralName,
    ],
  ];
}

/// What separates a line's alternatives, in the grammar and in the file
/// (ADR-11); barred from ingredient spellings so the split stays unambiguous.
const alternativeSeparator = '/';

/// A line names unit and ingredients by name, resolved against vocabularies
/// (ADR-09). More than one name is a substitution group: any one of them on
/// hand makes the line (ADR-11). Never empty — the grammar is the only maker
/// of lines and it refuses one naming nothing; no assert, since a const
/// constructor cannot evaluate one.
final class RecipeLine {
  final Amount amount;
  final String unit;
  final List<String> ingredients;
  final LineMark? mark;

  const RecipeLine(this.amount, this.unit, this.ingredients, {this.mark});

  bool get isBase => mark == LineMark.base;

  bool get isOptional => mark == LineMark.optional;

  RecipeLine copyWith({
    Amount? amount,
    String? unit,
    List<String>? ingredients,
  }) => RecipeLine(
    amount ?? this.amount,
    unit ?? this.unit,
    ingredients ?? this.ingredients,
    mark: mark,
  );

  /// Only way to change/clear the mark (copyWith uses null for "keep").
  RecipeLine marked(LineMark? mark) =>
      RecipeLine(amount, unit, ingredients, mark: mark);

  @override
  bool operator ==(Object other) =>
      other is RecipeLine &&
      other.amount == amount &&
      other.unit == unit &&
      listEquals(other.ingredients, ingredients) &&
      other.mark == mark;

  @override
  int get hashCode =>
      Object.hash(amount, unit, Object.hashAll(ingredients), mark);

  @override
  String toString() {
    final mark = this.mark;
    return 'RecipeLine($amount $unit ${ingredients.join(' $alternativeSeparator ')}'
        '${mark == null ? '' : ', ${mark.token}'})';
  }
}

/// What a part and an ounce are worth (FR-SET-1) — the owner's, where the unit
/// they read in is the reader's and lives on the bar (ADR 21). Sizes are held in
/// ml because ml is the anchor — it needs none of its own — so the ratios
/// between any two are derived rather than stored (ADR 17).
final class Settings {
  final double partMl;
  final double ozMl;

  const Settings({this.partMl = 30, this.ozMl = 29.5735});

  /// How many ml one [unit] is.
  double mlPer(FixedUnit unit) => switch (unit) {
    FixedUnit.part => partMl,
    FixedUnit.ml => 1,
    FixedUnit.oz => ozMl,
  };

  /// How many [to] one [from] is — the amounts screen's rows and a converted
  /// measure alike.
  double ratio(FixedUnit from, FixedUnit to) => mlPer(from) / mlPer(to);

  /// These settings with one [from] made worth [n] of [to] — [ratio] written
  /// back. [to]'s size is what moves, so redefining the part leaves the ounce
  /// where it stood; where [to] is ml it has no size of its own, and [from]'s
  /// moves instead.
  Settings withRatio(FixedUnit from, FixedUnit to, double n) =>
      to == FixedUnit.ml ? _sized(from, n) : _sized(to, mlPer(from) / n);

  /// ml is the anchor — its size is 1 by definition, so there is none to set.
  Settings _sized(FixedUnit unit, double ml) => switch (unit) {
    FixedUnit.part => copyWith(partMl: ml),
    FixedUnit.ml => this,
    FixedUnit.oz => copyWith(ozMl: ml),
  };

  Settings copyWith({double? partMl, double? ozMl}) =>
      Settings(partMl: partMl ?? this.partMl, ozMl: ozMl ?? this.ozMl);

  @override
  bool operator ==(Object other) =>
      other is Settings && other.partMl == partMl && other.ozMl == ozMl;

  @override
  int get hashCode => Object.hash(partMl, ozMl);

  @override
  String toString() => 'Settings($partMl ml/part, $ozMl ml/oz)';
}

final class Recipe {
  final String name;
  final List<String> tags;
  final List<RecipeLine> lines;
  final String notes;

  Recipe(
    this.name, {
    List<String> tags = const [],
    List<RecipeLine> lines = const [],
    this.notes = '',
  }) : tags = List.unmodifiable(tags),
       lines = List.unmodifiable(lines);

  Recipe copyWith({
    String? name,
    List<String>? tags,
    List<RecipeLine>? lines,
    String? notes,
  }) => Recipe(
    name ?? this.name,
    tags: tags ?? this.tags,
    lines: lines ?? this.lines,
    notes: notes ?? this.notes,
  );

  @override
  bool operator ==(Object other) =>
      other is Recipe &&
      other.name == name &&
      listEquals(other.tags, tags) &&
      listEquals(other.lines, lines) &&
      other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(name, Object.hashAll(tags), Object.hashAll(lines), notes);

  @override
  String toString() => 'Recipe($name)';
}

final class Collection {
  final Settings settings;

  /// Units vocabulary; used for files naming none (ADR-09).
  final List<Unit> units;
  final List<Ingredient> ingredients;

  /// Two tag vocabularies, peers of one shape; names unique within each (ADR-07).
  final List<Tag> recipeTags;
  final List<Tag> ingredientTags;
  final List<Recipe> recipes;

  Collection({
    this.settings = const Settings(),
    List<Unit> units = defaultUnits,
    List<Ingredient> ingredients = const [],
    List<Tag> recipeTags = const [],
    List<Tag> ingredientTags = const [],
    List<Recipe> recipes = const [],
  }) : units = List.unmodifiable(units),
       ingredients = List.unmodifiable(ingredients),
       recipeTags = List.unmodifiable(recipeTags),
       ingredientTags = List.unmodifiable(ingredientTags),
       recipes = List.unmodifiable(recipes) {
    _requireUniqueNames('unit', this.units.spellings);
    _requireUniqueNames('ingredient', [
      for (final ingredient in this.ingredients) ...ingredient.spellings,
    ]);
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

  Collection copyWith({
    Settings? settings,
    List<Unit>? units,
    List<Ingredient>? ingredients,
    List<Tag>? recipeTags,
    List<Tag>? ingredientTags,
    List<Recipe>? recipes,
  }) => Collection(
    settings: settings ?? this.settings,
    units: units ?? this.units,
    ingredients: ingredients ?? this.ingredients,
    recipeTags: recipeTags ?? this.recipeTags,
    ingredientTags: ingredientTags ?? this.ingredientTags,
    recipes: recipes ?? this.recipes,
  );

  /// The entry [name] names, any case, any spelling (ADR-08, ADR-10).
  Ingredient? ingredientNamed(String name) => _ingredientsByName[nameKey(name)];

  /// [name] under the bottle's own spelling — what a reference is stored as and
  /// an offering reads in. A name outside the vocabulary stands as it came.
  String bottleNamed(String name) => ingredientNamed(name)?.name ?? name;

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
      if (except == null || !ingredient.name.sameName(except))
        ...ingredient.spellings,
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
      other.settings == settings &&
      listEquals(other.units, units) &&
      listEquals(other.ingredients, ingredients) &&
      listEquals(other.recipeTags, recipeTags) &&
      listEquals(other.ingredientTags, ingredientTags) &&
      listEquals(other.recipes, recipes);

  @override
  int get hashCode => Object.hash(
    settings,
    Object.hashAll(units),
    Object.hashAll(ingredients),
    Object.hashAll(recipeTags),
    Object.hashAll(ingredientTags),
    Object.hashAll(recipes),
  );

  @override
  String toString() =>
      'Collection(${ingredients.length} ingredients, '
      '${recipeTags.length} recipe tags, '
      '${ingredientTags.length} ingredient tags, '
      '${recipes.length} recipes)';
}

/// The four kinds a collection is summed up by, recipes first: a reader tells
/// one collection from another by what it makes long before by the vocabulary
/// serving it. One home for the kinds, their order and what each is called, so
/// a bar card and an import review read alike.
enum Holding {
  recipe('recipe'),
  ingredient('ingredient'),
  tag('tag'),
  unit('unit');

  /// What a bar's summary is written under (ADR 21). Declared rather than the
  /// identifier, so renaming a kind cannot quietly rewrite the index's format —
  /// and independent of [noun], which is the reader's word and free to change.
  final String token;
  const Holding(this.token);

  String get noun => name;
}

/// How many of each [Holding], which is all a bar list may know of a bar that
/// is not on show ([ADR 20](../../../docs/adr/20-the-app-holds-many-bars.md)) —
/// four numbers rather than a second collection.
Map<Holding, int> holdingsOf(Collection collection) => {
  Holding.recipe: collection.recipes.length,
  Holding.ingredient: collection.ingredients.length,
  // The one kind spanning two vocabularies, counted as the reader meets it:
  // one word for both, as `tags_screen.dart` lists them (ADR 07).
  Holding.tag: collection.recipeTags.length + collection.ingredientTags.length,
  Holding.unit: collection.units.length,
};

/// Tags [worn] names, in [vocabulary] order.
List<Tag> wornInOrder(List<Tag> vocabulary, Iterable<String> worn) {
  final names = nameKeys(worn);
  return [
    for (final tag in vocabulary)
      if (names.contains(nameKey(tag.name))) tag,
  ];
}

void _requireUniqueNames(String kind, List<String> names) {
  final duplicates = duplicateNameIndexes(names);
  if (duplicates.isNotEmpty) {
    throw ArgumentError('Duplicate $kind name: "${names[duplicates.first]}"');
  }
}
