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
  noRequiredLine,
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
  List<Tag> ingredientTags = const [],
  List<Tag> recipeTags = const [],
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
  final ingredientTagNames = ingredientTags.map((t) => t.name).toList();
  final recipeTagNames = recipeTags.map((t) => t.name).toList();
  final knownIngredientTags = nameKeys(ingredientTagNames);
  _checkNames(
    issues,
    'ingredients',
    'ingredient',
    ingredientNames,
    extraRule: _reservedSuffixProblem,
    entryIssues: (i) => _checkTagReferences(
      ingredients[i].tags,
      ['ingredients', i],
      known: knownIngredientTags,
      entity: 'ingredient',
    ),
  );
  _checkNames(issues, 'ingredient_tags', 'ingredient tag', ingredientTagNames);
  _checkNames(issues, 'recipe_tags', 'recipe tag', recipeTagNames);
  final knownIngredients = nameKeys(ingredientNames);
  final knownRecipeTags = nameKeys(recipeTagNames);
  _checkNames(
    issues,
    'recipes',
    'recipe',
    recipes.map((r) => r.name).toList(),
    entryIssues: (i) => _checkRecipe(recipes[i], knownIngredients, [
      'recipes',
      i,
    ], knownTags: knownRecipeTags),
  );
  return issues;
}

/// [names] without [except], which is what every `validate…` call wants: the
/// names an entry must not collide with, its own left out so a rename never
/// collides with the name it is leaving — a change of case included, that
/// being the same name (ADR 08).
Set<String> otherNames(Set<String> names, String? except) => {
  for (final name in names)
    if (except == null || !name.sameName(except)) name,
};

/// Checks one ingredient — its name and its tag references — before it enters
/// the vocabulary (M11); an empty result means valid. [otherIngredientNames]
/// holds every *other* entry's name, so renaming an entry never collides with
/// itself.
///
/// Paths are relative to the entry, so a name issue carries an empty path —
/// the same convention as [validateRecipe].
List<ValidationIssue> validateIngredient(
  Ingredient ingredient, {
  required Set<String> knownIngredientTags,
  Set<String> otherIngredientNames = const {},
}) => [
  ..._checkName(
    'ingredient',
    ingredient.name,
    isDuplicate: _holdsName(otherIngredientNames, ingredient.name),
    extraRule: _reservedSuffixProblem,
  ),
  ..._checkTagReferences(
    ingredient.tags,
    const [],
    known: nameKeys(knownIngredientTags),
    entity: 'ingredient',
  ),
];

/// Checks one tag before it enters a vocabulary (M12); an empty result means
/// valid. Serves either vocabulary — [otherTagNames] is what says which, and
/// the colour needs no checking, being an enum. Argument and path conventions
/// as in [validateIngredient].
List<ValidationIssue> validateTag(
  Tag tag, {
  Set<String> otherTagNames = const {},
}) => _checkName(
  'tag',
  tag.name,
  isDuplicate: _holdsName(otherTagNames, tag.name),
);

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
    isDuplicate: _holdsName(otherRecipeNames, recipe.name),
  ),
  ..._checkRecipe(
    recipe,
    nameKeys(knownIngredients),
    const [],
    knownTags: nameKeys(knownTags),
  ),
];

/// Whether [names] already holds [name], the two compared as one name is
/// (ADR 08). The `known…` sets below are folded once on the way in instead,
/// being asked the same question line after line.
bool _holdsName(Set<String> names, String name) =>
    names.any((other) => other.sameName(name));

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

_Problem? _reservedSuffixProblem(String name) {
  for (final suffix in reservedSuffixes) {
    if (name.endsWith(suffix)) {
      return (
        kind: ValidationIssueKind.reservedSuffix,
        message:
            'Ingredient name ends with the reserved "$suffix" suffix: "$name"',
      );
    }
  }
  return null;
}

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

/// Every rule on one entry's tag references — the name resolves, and no name
/// twice — applied wherever a list of tag names hangs off an entry. [known]
/// holds the folded names of the vocabulary that list draws from; [entity]
/// only words the message.
List<ValidationIssue> _checkTagReferences(
  List<String> tags,
  List<Object> basePath, {
  required Set<String> known,
  required String entity,
}) {
  final issues = <ValidationIssue>[];
  final duplicates = duplicateNameIndexes(tags).toSet();
  for (var t = 0; t < tags.length; t++) {
    final tag = tags[t];
    _addProblems(
      issues,
      [...basePath, 'tags', t],
      [
        known.contains(nameKey(tag))
            ? null
            : (
                kind: ValidationIssueKind.unknownTag,
                message: 'Unknown tag: "$tag"',
              ),
        duplicates.contains(t)
            ? (
                kind: ValidationIssueKind.duplicateTag,
                message: 'Duplicate tag on the $entity: "$tag"',
              )
            : null,
      ],
    );
  }
  return issues;
}

List<ValidationIssue> _checkRecipe(
  Recipe recipe,
  Set<String> knownIngredients,
  List<Object> basePath, {
  required Set<String> knownTags,
}) {
  final issues = _checkTagReferences(
    recipe.tags,
    basePath,
    known: knownTags,
    entity: 'recipe',
  );
  // Availability judges required lines, so a recipe with none would be
  // makeable out of nothing (FR-REC-2).
  if (recipe.lines.every((line) => line.isOptional)) {
    issues.add(
      ValidationIssue(
        [...basePath, 'lines'],
        ValidationIssueKind.noRequiredLine,
        'Recipe needs at least one ingredient line that is not optional',
      ),
    );
  }
  for (var l = 0; l < recipe.lines.length; l++) {
    final line = recipe.lines[l];
    final amount = formatAmount(line.amount);
    _addProblems(
      issues,
      [...basePath, 'lines', l],
      [
        knownIngredients.contains(nameKey(line.ingredient))
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
