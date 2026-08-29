/// One drink: its tags, its lines, its notes.
library;

import '../names.dart';
import 'recipe_line.dart';

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
