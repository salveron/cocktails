/// One bottle the bar may hold, its stock and its own spellings (FR-VOC-6).
library;

import '../names.dart';
import '../tokens.dart';

enum StockLevel implements Tokened {
  in_('in'),
  low('low'),
  out('out');

  @override
  final String token;
  const StockLevel(this.token);

  /// Next step in an ingredient's lifecycle (FR-ING-2).
  /// Declaration order is the life; wire tokens are independent.
  StockLevel get next => values[(index + 1) % values.length];

  static StockLevel? fromToken(String text) => enumFromToken(values, text);
}

final class Ingredient {
  final String name;
  final StockLevel stock;

  /// Other spellings an ingredient answers to (FR-VOC-6, ADR-10): for finding,
  /// not showing.
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
