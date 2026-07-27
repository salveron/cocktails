/// Model validation behind FR-DAT-4 and the recipe form: referential
/// integrity, duplicate names, and the value rules of the data format in
/// docs/architecture.md. Takes model parts instead of a [Model] so duplicate
/// names are reported rather than thrown; issue paths mirror the data-format
/// keys, ready for mapping to YAML positions (codec) or form fields.
library;

import 'helpers.dart';
import 'line_format.dart';
import 'model.dart';

/// The rule an issue reports, so consumers switch on the rule instead of
/// matching [ValidationIssue.message]. The last three are raised by the codec
/// (M6), which reports its own findings as issues rather than as a second
/// diagnostic type.
enum ValidationIssueKind {
  emptyName,
  whitespaceInName,
  lineBreakInName,
  duplicateName,
  reservedSuffix,
  partMlNotPositive,
  unknownIngredient,
  unknownTag,
  duplicateTag,
  amountNotPositive,
  rangeOutOfOrder,
  timesBelowOne,
  unsupportedFormat,
  malformedLine,
  malformedValue,
}

/// One violation: [path] locates it in data-format keys and indexes, [kind]
/// names the rule that failed, [message] names the offending value.
final class ValidationIssue {
  final List<Object> path;
  final ValidationIssueKind kind;
  final String message;

  ValidationIssue(List<Object> path, this.kind, this.message)
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
  bool operator ==(Object other) =>
      other is ValidationIssue &&
      listEquals(other.path, path) &&
      other.kind == kind &&
      other.message == message;

  @override
  int get hashCode => Object.hash(Object.hashAll(path), kind, message);

  @override
  String toString() => '$location: $message';
}

/// A violation before it gains a path.
typedef _Problem = ({ValidationIssueKind kind, String message});

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
      ValidationIssue(
        ['settings', 'part_ml'],
        ValidationIssueKind.partMlNotPositive,
        'part_ml must be positive: ${settings.partMl}',
      ),
    );
  }
  final ingredientNames = ingredients.map((i) => i.name).toList();
  final tagNames = tags.map((t) => t.name).toList();
  _checkNames(
    issues,
    'ingredients',
    'ingredient',
    ingredientNames,
    extraRule: _reservedSuffixProblem,
  );
  _checkNames(issues, 'tags', 'tag', tagNames);
  final knownIngredients = ingredientNames.toSet();
  final knownTags = tagNames.toSet();
  _checkNames(
    issues,
    'recipes',
    'recipe',
    recipes.map((r) => r.name).toList(),
    entryIssues: (i) =>
        _checkRecipe(recipes[i], knownIngredients, knownTags, ['recipes', i]),
  );
  return issues;
}

/// Checks one ingredient before it enters the vocabulary (M11); an empty
/// result means valid. [otherIngredientNames] holds every *other* entry's
/// name, so renaming an entry never collides with itself.
///
/// Paths are relative to the entry, so a name issue carries an empty path —
/// the same convention as [validateRecipe].
List<ValidationIssue> validateIngredient(
  Ingredient ingredient, {
  Set<String> otherIngredientNames = const {},
}) => _checkName(
  'ingredient',
  ingredient.name,
  isDuplicate: otherIngredientNames.contains(ingredient.name),
  extraRule: _reservedSuffixProblem,
);

/// Checks one tag before it enters the vocabulary (M12); an empty result
/// means valid. Argument and path conventions as in [validateIngredient].
List<ValidationIssue> validateTag(
  Tag tag, {
  Set<String> otherTagNames = const {},
}) =>
    _checkName('tag', tag.name, isDuplicate: otherTagNames.contains(tag.name));

/// Checks one recipe — its name and its contents — against the current
/// vocabularies; an empty result means valid. The entry point the recipe form
/// uses (M14); [validateModel] is the whole-file entry point, sharing this
/// same rule set per recipe.
///
/// Paths are relative to the recipe itself (`['lines', 2]`, `['made',
/// 'times']`) and empty for a name issue — there is no list index to anchor to
/// outside a recipe list. [otherRecipeNames] as in [validateIngredient].
List<ValidationIssue> validateRecipe(
  Recipe recipe, {
  required Set<String> knownIngredients,
  required Set<String> knownTags,
  Set<String> otherRecipeNames = const {},
}) => [
  ..._checkName(
    'recipe',
    recipe.name,
    isDuplicate: otherRecipeNames.contains(recipe.name),
  ),
  ..._checkRecipe(recipe, knownIngredients, knownTags, const []),
];

/// Every rule for one list of named entries, applied entry by entry so issues
/// come out in index order. [extraRule] adds a rule only one vocabulary has;
/// [entryIssues] appends an entry's own issues behind its name issues, which
/// is what keeps a recipe's lines from trailing the next recipe's name.
void _checkNames(
  List<ValidationIssue> issues,
  String key,
  String entity,
  List<String> names, {
  _Problem? Function(String name)? extraRule,
  List<ValidationIssue> Function(int index)? entryIssues,
}) {
  final duplicates = duplicateNameIndexes(names).toSet();
  for (var i = 0; i < names.length; i++) {
    issues.addAll(
      _checkName(
        entity,
        names[i],
        isDuplicate: duplicates.contains(i),
        extraRule: extraRule,
        basePath: [key, i],
      ),
    );
    if (entryIssues != null) {
      issues.addAll(entryIssues(i));
    }
  }
}

/// The single home of the name rules, whether the name arrives inside a list
/// or alone from a form.
List<ValidationIssue> _checkName(
  String entity,
  String name, {
  required bool isDuplicate,
  _Problem? Function(String name)? extraRule,
  List<Object> basePath = const [],
}) {
  final issues = <ValidationIssue>[];
  _addProblems(issues, basePath, [
    _nameProblem(entity, name),
    isDuplicate
        ? (
            kind: ValidationIssueKind.duplicateName,
            message: 'Duplicate $entity name: "$name"',
          )
        : null,
    extraRule?.call(name),
  ]);
  return issues;
}

/// Every non-null problem in [problems], as issues sharing one [path].
void _addProblems(
  List<ValidationIssue> issues,
  List<Object> path,
  List<_Problem?> problems,
) {
  for (final problem in problems) {
    if (problem != null) {
      issues.add(ValidationIssue(path, problem.kind, problem.message));
    }
  }
}

_Problem? _reservedSuffixProblem(String name) => name.endsWith(optionalSuffix)
    ? (
        kind: ValidationIssueKind.reservedSuffix,
        message:
            'Ingredient name ends with the reserved "$optionalSuffix" '
            'suffix: "$name"',
      )
    : null;

_Problem? _nameProblem(String entity, String name) {
  if (name.isEmpty) {
    return (kind: ValidationIssueKind.emptyName, message: 'Empty $entity name');
  }
  if (name.trim() != name) {
    return (
      kind: ValidationIssueKind.whitespaceInName,
      message: 'Surrounding whitespace in $entity name: "$name"',
    );
  }
  if (name.contains('\n') || name.contains('\r')) {
    return (
      kind: ValidationIssueKind.lineBreakInName,
      message: 'Line break in $entity name: "$name"',
    );
  }
  return null;
}

List<ValidationIssue> _checkRecipe(
  Recipe recipe,
  Set<String> knownIngredients,
  Set<String> knownTags,
  List<Object> basePath,
) {
  final issues = <ValidationIssue>[];
  final duplicateTags = duplicateNameIndexes(recipe.tags).toSet();
  for (var t = 0; t < recipe.tags.length; t++) {
    final tag = recipe.tags[t];
    _addProblems(
      issues,
      [...basePath, 'tags', t],
      [
        knownTags.contains(tag)
            ? null
            : (
                kind: ValidationIssueKind.unknownTag,
                message: 'Unknown tag: "$tag"',
              ),
        duplicateTags.contains(t)
            ? (
                kind: ValidationIssueKind.duplicateTag,
                message: 'Duplicate tag on the recipe: "$tag"',
              )
            : null,
      ],
    );
  }
  for (var l = 0; l < recipe.lines.length; l++) {
    final line = recipe.lines[l];
    final amount = formatAmount(line.amount);
    _addProblems(
      issues,
      [...basePath, 'lines', l],
      [
        knownIngredients.contains(line.ingredient)
            ? null
            : (
                kind: ValidationIssueKind.unknownIngredient,
                message: 'Unknown ingredient: "${line.ingredient}"',
              ),
        line.amount.min <= 0
            ? (
                kind: ValidationIssueKind.amountNotPositive,
                message: 'Amount must be positive: $amount',
              )
            : null,
        line.amount.min > line.amount.max
            ? (
                kind: ValidationIssueKind.rangeOutOfOrder,
                message: 'Range ends out of order: $amount',
              )
            : null,
      ],
    );
  }
  final made = recipe.made;
  if (made != null && made.times < 1) {
    issues.add(
      ValidationIssue(
        [...basePath, 'made', 'times'],
        ValidationIssueKind.timesBelowOne,
        'times must be at least 1: ${made.times}',
      ),
    );
  }
  return issues;
}
