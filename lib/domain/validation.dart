/// Model validation behind FR-DAT-4 and the recipe form: referential
/// integrity, duplicate names, and the value rules of the data format in
/// docs/architecture.md. Takes model parts instead of a [Model] so duplicate
/// names are reported rather than thrown; issue paths mirror the data-format
/// keys, ready for mapping to YAML positions (codec) or form fields.
library;

import 'line_format.dart';
import 'model.dart';

/// One violation: [path] locates it in data-format keys and indexes,
/// [message] names the offending value.
final class ValidationIssue {
  final List<Object> path;
  final String message;

  ValidationIssue(List<Object> path, this.message)
    : path = List.unmodifiable(path);

  /// [path] in dotted-and-indexed form, e.g. `recipes[0].lines[2]`.
  String get location {
    final buffer = StringBuffer();
    for (final segment in path) {
      if (segment is int) {
        buffer.write('[$segment]');
      } else {
        if (buffer.isNotEmpty) {
          buffer.write('.');
        }
        buffer.write(segment);
      }
    }
    return buffer.toString();
  }

  @override
  String toString() => '$location: $message';
}

/// Checks the parts of a would-be [Model]; an empty result means valid.
List<ValidationIssue> validateModel({
  Settings settings = const Settings(),
  List<Ingredient> ingredients = const [],
  List<Tag> tags = const [],
  List<Recipe> recipes = const [],
}) {
  final issues = <ValidationIssue>[];
  if (settings.partMl <= 0) {
    issues.add(
      ValidationIssue([
        'settings',
        'part_ml',
      ], 'part_ml must be positive: ${settings.partMl}'),
    );
  }
  final ingredientNames = ingredients.map((i) => i.name).toList();
  _checkNames(issues, 'ingredients', 'ingredient', ingredientNames);
  _checkNames(issues, 'tags', 'tag', tags.map((t) => t.name).toList());
  _checkNames(issues, 'recipes', 'recipe', recipes.map((r) => r.name).toList());
  for (var i = 0; i < ingredients.length; i++) {
    if (ingredients[i].name.endsWith(optionalSuffix)) {
      issues.add(
        ValidationIssue(
          ['ingredients', i],
          'Ingredient name ends with the reserved "$optionalSuffix" suffix: '
          '"${ingredients[i].name}"',
        ),
      );
    }
  }
  final knownIngredients = ingredientNames.toSet();
  final knownTags = tags.map((t) => t.name).toSet();
  for (var i = 0; i < recipes.length; i++) {
    _checkRecipe(issues, i, recipes[i], knownIngredients, knownTags);
  }
  return issues;
}

void _checkNames(
  List<ValidationIssue> issues,
  String key,
  String kind,
  List<String> names,
) {
  for (var i = 0; i < names.length; i++) {
    final problem = _nameProblem(kind, names[i]);
    if (problem != null) {
      issues.add(ValidationIssue([key, i], problem));
    }
  }
  for (final i in duplicateNameIndexes(names)) {
    issues.add(
      ValidationIssue([key, i], 'Duplicate $kind name: "${names[i]}"'),
    );
  }
}

String? _nameProblem(String kind, String name) {
  if (name.isEmpty) {
    return 'Empty $kind name';
  }
  if (name.trim() != name) {
    return 'Surrounding whitespace in $kind name: "$name"';
  }
  if (name.contains('\n') || name.contains('\r')) {
    return 'Line break in $kind name: "$name"';
  }
  return null;
}

void _checkRecipe(
  List<ValidationIssue> issues,
  int index,
  Recipe recipe,
  Set<String> knownIngredients,
  Set<String> knownTags,
) {
  for (var t = 0; t < recipe.tags.length; t++) {
    if (!knownTags.contains(recipe.tags[t])) {
      issues.add(
        ValidationIssue([
          'recipes',
          index,
          'tags',
          t,
        ], 'Unknown tag: "${recipe.tags[t]}"'),
      );
    }
  }
  for (final t in duplicateNameIndexes(recipe.tags)) {
    issues.add(
      ValidationIssue([
        'recipes',
        index,
        'tags',
        t,
      ], 'Duplicate tag on the recipe: "${recipe.tags[t]}"'),
    );
  }
  for (var l = 0; l < recipe.lines.length; l++) {
    final line = recipe.lines[l];
    final path = ['recipes', index, 'lines', l];
    if (!knownIngredients.contains(line.ingredient)) {
      issues.add(
        ValidationIssue(path, 'Unknown ingredient: "${line.ingredient}"'),
      );
    }
    if (line.amount.min <= 0) {
      issues.add(
        ValidationIssue(
          path,
          'Amount must be positive: ${formatAmount(line.amount)}',
        ),
      );
    }
    if (line.amount.min > line.amount.max) {
      issues.add(
        ValidationIssue(
          path,
          'Range ends out of order: ${formatAmount(line.amount)}',
        ),
      );
    }
  }
  final made = recipe.made;
  if (made != null && made.times < 1) {
    issues.add(
      ValidationIssue([
        'recipes',
        index,
        'made',
        'times',
      ], 'times must be at least 1: ${made.times}'),
    );
  }
}
