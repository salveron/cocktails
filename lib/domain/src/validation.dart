/// Collection validation: referential integrity, names, value rules (FR-DAT-4).
/// Issues' paths mirror data-format keys for YAML/form mapping.
library;

import 'names.dart';
import 'line_format.dart';
import 'collection.dart';
import 'shelf.dart';

/// Issue rules; switch on this instead of the message.
enum ValidationIssueKind {
  emptyName,
  whitespaceInName,
  lineBreakInName,
  commaInAlias,
  duplicateName,
  reservedSuffix,
  separatorInName,
  unitSizeNotPositive,
  missingUnit,
  unknownUnit,
  unknownIngredient,
  unknownTag,
  duplicateTag,
  duplicateAlternative,
  amountNotPositive,
  rangeOutOfOrder,
  noRequiredLine,
  unsupportedFormat,
  malformedLine,
  malformedValue,
}

/// One violation: path, rule, and offending value.
final class ValidationIssue {
  final List<Object> path;
  final ValidationIssueKind kind;
  final String message;

  ValidationIssue(List<Object> path, this.kind, this.message)
    : path = List.unmodifiable(path);

  /// [path] as dotted-indexed form, e.g. `recipes[0].lines[2]`.
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

/// Checks the parts of a would-be [Collection]; an empty result means valid.
List<ValidationIssue> validateCollection({
  Settings settings = const Settings(),
  List<Unit> units = defaultUnits,
  List<Ingredient> ingredients = const [],
  List<Tag> ingredientTags = const [],
  List<Tag> recipeTags = const [],
  List<Recipe> recipes = const [],
}) {
  final issues = <ValidationIssue>[];
  // A size of zero or less would leave a conversion meaningless in both
  // directions, ml being what the other two are measured against (ADR 17).
  for (final (key, size) in [
    ('part_ml', settings.partMl),
    ('oz_ml', settings.ozMl),
  ]) {
    if (size <= 0) {
      issues.add(
        ValidationIssue(
          ['settings', key],
          ValidationIssueKind.unitSizeNotPositive,
          '$key must be positive: $size',
        ),
      );
    }
  }
  _checkUnits(issues, units);
  final ingredientTagNames = ingredientTags.map((t) => t.name).toList();
  final recipeTagNames = recipeTags.map((t) => t.name).toList();
  final knownIngredientTags = nameKeys(ingredientTagNames);
  // Names and aliases share one namespace (ADR-10).
  final knownIngredients = <String>{};
  _checkNames(
    issues,
    'ingredients',
    'ingredient',
    ingredients.map((i) => i.name).toList(),
    namespace: knownIngredients,
    extraRule: (name) => _reservedTextProblem('name', name),
    entryIssues: (i) => [
      ..._checkAliases(ingredients[i].aliases, [
        'ingredients',
        i,
      ], taken: knownIngredients),
      ..._checkTagReferences(
        ingredients[i].tags,
        ['ingredients', i],
        known: knownIngredientTags,
        entity: 'ingredient',
      ),
    ],
  );
  _checkNames(issues, 'ingredient_tags', 'ingredient tag', ingredientTagNames);
  _checkNames(issues, 'recipe_tags', 'recipe tag', recipeTagNames);
  final knownRecipeTags = nameKeys(recipeTagNames);
  _checkNames(
    issues,
    'recipes',
    'recipe',
    recipes.map((r) => r.name).toList(),
    entryIssues: (i) => _checkRecipe(
      recipes[i],
      knownIngredients,
      ['recipes', i],
      knownTags: knownRecipeTags,
      knownUnits: nameKeys(units.spellings),
    ),
  );
  return issues;
}

/// Checks the parts of a would-be [Shelf] — the index's own record, never a
/// bar's contents (ADR-21) — against the rules its constructor keeps, reported
/// rather than thrown. Names go unchecked for uniqueness: two bars may carry
/// one (FR-BAR-1). Paths follow the index's keys, `open` before `bars` as the
/// file writes them.
List<ValidationIssue> validateShelf({required List<Bar> bars, String? openId}) {
  final issues = <ValidationIssue>[];
  final ids = {for (final bar in bars) bar.id};
  if (openId != null && !ids.contains(openId)) {
    issues.add(
      ValidationIssue(
        const ['open'],
        ValidationIssueKind.malformedValue,
        'open names no bar on the shelf: "$openId"',
      ),
    );
  }
  final seen = <String>{};
  for (var i = 0; i < bars.length; i++) {
    final bar = bars[i];
    _addProblems(
      issues,
      ['bars', i, 'id'],
      [
        // Ids are minted rather than written, so they compare exactly: ADR-08's
        // fold is a rule for names, and two ids differing in case are two bars.
        bar.id.isEmpty
            ? (kind: ValidationIssueKind.emptyName, message: 'Empty bar id')
            : null,
        seen.add(bar.id)
            ? null
            : (
                kind: ValidationIssueKind.duplicateName,
                message: 'Duplicate bar id: "${bar.id}"',
              ),
      ],
    );
    issues.addAll(
      _checkName(
        'bar',
        bar.name,
        isDuplicate: false,
        basePath: ['bars', i, 'name'],
      ),
    );
    issues.addAll(_checkRecord(bar, ['bars', i]));
  }
  return issues;
}

/// The half of a record its mode allows it: a guest refreshes from a source and
/// has nothing of its own to give away, an owner shares and refreshes from
/// nothing (FR-BAR-3/6).
List<ValidationIssue> _checkRecord(Bar bar, List<Object> basePath) {
  final issues = <ValidationIssue>[];
  final hasSource = bar.source != null;
  _addProblems(
    issues,
    [...basePath, 'source'],
    [
      if (bar.isOwned && hasSource)
        (
          kind: ValidationIssueKind.malformedValue,
          message: 'An owned bar refreshes from no source: "${bar.name}"',
        ),
      if (!bar.isOwned && !hasSource)
        (
          kind: ValidationIssueKind.malformedValue,
          message:
              'A guest bar needs the source it refreshes from: "${bar.name}"',
        ),
    ],
  );
  if (bar.isOwned && bar.refreshed != null) {
    issues.add(
      ValidationIssue(
        [...basePath, 'refreshed'],
        ValidationIssueKind.malformedValue,
        'An owned bar has nothing to refresh: "${bar.name}"',
      ),
    );
  }
  if (!bar.isOwned && bar.updated != null) {
    issues.add(
      ValidationIssue(
        [...basePath, 'updated'],
        ValidationIssueKind.malformedValue,
        'A guest bar changes only when it refreshes: "${bar.name}"',
      ),
    );
  }
  final vias = <Transport>{};
  for (var o = 0; o < bar.offers.length; o++) {
    final via = bar.offers[o].via;
    _addProblems(
      issues,
      [...basePath, 'offers', o],
      [
        bar.isOwned
            ? null
            : (
                kind: ValidationIssueKind.malformedValue,
                message:
                    'A guest bar is not this device\'s to share: "${bar.name}"',
              ),
        vias.add(via)
            ? null
            : (
                kind: ValidationIssueKind.duplicateName,
                message: 'Bar offered twice by ${via.token}: "${bar.name}"',
              ),
      ],
    );
  }
  return issues;
}

/// Every rule on the unit vocabulary (ADR-09).
void _checkUnits(List<ValidationIssue> issues, List<Unit> units) {
  final seen = <String>{};
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    _addProblems(
      issues,
      ['units', i],
      [
        _nameProblem('unit', unit.name),
        seen.add(nameKey(unit.name))
            ? null
            : _duplicateProblem('unit', unit.name),
      ],
    );
    if (unit.plural.isEmpty) continue;
    _addProblems(
      issues,
      ['units', i, 'plural'],
      [
        _nameProblem('unit plural', unit.plural),
        unit.plural.sameName(unit.name) || seen.add(nameKey(unit.plural))
            ? null
            : _duplicateProblem('unit', unit.plural),
      ],
    );
  }
  for (final fixed in FixedUnit.values) {
    if (!units.any((unit) => unit.name.sameName(fixed.token))) {
      issues.add(
        ValidationIssue(
          const ['units'],
          ValidationIssueKind.missingUnit,
          'units must include "${fixed.token}"',
        ),
      );
    }
  }
}

/// [names] minus [except]; omit the original so renames don't self-collide (ADR-08).
Set<String> otherNames(Set<String> names, String? except) => {
  for (final name in names)
    if (except == null || !name.sameName(except)) name,
};

/// Checks one ingredient before entering vocabulary; paths relative to entry.
List<ValidationIssue> validateIngredient(
  Ingredient ingredient, {
  required Set<String> knownIngredientTags,
  Set<String> otherIngredientNames = const {},
}) {
  final taken = nameKeys(otherIngredientNames);
  return [
    ..._checkName(
      'ingredient',
      ingredient.name,
      isDuplicate: repeatsName(taken, ingredient.name),
      extraRule: (name) => _reservedTextProblem('name', name),
    ),
    ..._checkAliases(ingredient.aliases, const [], taken: taken),
    ..._checkTagReferences(
      ingredient.tags,
      const [],
      known: nameKeys(knownIngredientTags),
      entity: 'ingredient',
    ),
  ];
}

/// Checks one tag before entering a vocabulary.
List<ValidationIssue> validateTag(
  Tag tag, {
  Set<String> otherTagNames = const {},
}) => _checkName(
  'tag',
  tag.name,
  isDuplicate: _holdsName(otherTagNames, tag.name),
);

/// Checks one recipe against vocabularies; paths relative to recipe.
List<ValidationIssue> validateRecipe(
  Recipe recipe, {
  required Set<String> knownIngredients,
  required Set<String> knownTags,
  required Set<String> knownUnits,
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
    knownUnits: nameKeys(knownUnits),
  ),
];

/// Whether [names] already holds [name] as one name (ADR-08).
bool _holdsName(Set<String> names, String name) =>
    names.any((other) => other.sameName(name));

/// Every rule for one list of named entries, applied per entry.
void _checkNames(
  List<ValidationIssue> issues,
  String key,
  String entity,
  List<String> names, {
  Set<String>? namespace,
  _Problem? Function(String name)? extraRule,
  List<ValidationIssue> Function(int index)? entryIssues,
}) {
  final taken = namespace ?? <String>{};
  for (var i = 0; i < names.length; i++) {
    issues.addAll(
      _checkName(
        entity,
        names[i],
        isDuplicate: repeatsName(taken, names[i]),
        extraRule: extraRule,
        basePath: [key, i],
      ),
    );
    if (entryIssues != null) {
      issues.addAll(entryIssues(i));
    }
  }
}

/// Every rule on ingredient aliases; comma barred (FR-VOC-6, ADR-10).
List<ValidationIssue> _checkAliases(
  List<String> aliases,
  List<Object> basePath, {
  required Set<String> taken,
}) {
  final issues = <ValidationIssue>[];
  for (var a = 0; a < aliases.length; a++) {
    final alias = aliases[a];
    _addProblems(
      issues,
      [...basePath, 'aliases', a],
      [
        _nameProblem('ingredient alias', alias),
        alias.contains(',')
            ? (
                kind: ValidationIssueKind.commaInAlias,
                message: 'Comma in ingredient alias: "$alias"',
              )
            : null,
        repeatsName(taken, alias)
            ? _duplicateProblem('ingredient', alias)
            : null,
        _reservedTextProblem('alias', alias),
      ],
    );
  }
  return issues;
}

/// Single home of name rules, whether from list or form.
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
    isDuplicate ? _duplicateProblem(entity, name) : null,
    extraRule?.call(name),
  ]);
  return issues;
}

_Problem _duplicateProblem(String entity, String name) => (
  kind: ValidationIssueKind.duplicateName,
  message: 'Duplicate $entity name: "$name"',
);

/// All non-null problems as issues sharing one [path].
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

/// The grammar's own text is reserved: no ingredient spelling may end with a
/// mark suffix, nor hold the separator that would split it in two (ADR-11).
_Problem? _reservedTextProblem(String what, String name) {
  for (final suffix in reservedSuffixes) {
    if (name.endsWith(suffix)) {
      return (
        kind: ValidationIssueKind.reservedSuffix,
        message:
            'Ingredient $what ends with the reserved "$suffix" suffix: "$name"',
      );
    }
  }
  return name.contains(alternativeSeparator)
      ? (
          kind: ValidationIssueKind.separatorInName,
          message:
              'Ingredient $what holds the reserved '
              '"$alternativeSeparator" separator: "$name"',
        )
      : null;
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

/// Every rule on tag references: must resolve, no duplicates.
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
  required Set<String> knownUnits,
}) {
  final issues = _checkTagReferences(
    recipe.tags,
    basePath,
    known: knownTags,
    entity: 'recipe',
  );
  // At least one required line needed; optional only can't be made (FR-REC-2).
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
    // Any one alternative makes the line, but each must name an ingredient, and
    // naming one twice is a slip rather than a choice (ADR-11).
    final repeated = duplicateNameIndexes(line.ingredients).toSet();
    _addProblems(
      issues,
      [...basePath, 'lines', l],
      [
        for (var a = 0; a < line.ingredients.length; a++) ...[
          knownIngredients.contains(nameKey(line.ingredients[a]))
              ? null
              : (
                  kind: ValidationIssueKind.unknownIngredient,
                  message: 'Unknown ingredient: "${line.ingredients[a]}"',
                ),
          repeated.contains(a)
              ? (
                  kind: ValidationIssueKind.duplicateAlternative,
                  message:
                      'Duplicate alternative on the line: '
                      '"${line.ingredients[a]}"',
                )
              : null,
        ],
        knownUnits.contains(nameKey(line.unit))
            ? null
            : (
                kind: ValidationIssueKind.unknownUnit,
                message: 'Unknown unit: "${line.unit}"',
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
  return issues;
}
