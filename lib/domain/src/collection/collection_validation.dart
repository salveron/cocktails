/// Collection validation: referential integrity, names, value rules (FR-DAT-4).
library;

import '../issues.dart';
import '../names.dart';
import 'collection.dart';
import 'ingredient.dart';
import 'recipe.dart';
import 'recipe_line.dart';
import 'tag.dart';
import 'unit.dart';
import 'unit_sizes.dart';

/// Checks the parts of a would-be [Collection]; an empty result means valid.
List<ValidationIssue> validateCollection({
  UnitSizes unitSizes = const UnitSizes(),
  List<Unit> units = defaultUnits,
  List<Ingredient> ingredients = const [],
  List<Tag> ingredientTags = const [],
  List<Tag> recipeTags = const [],
  List<Recipe> recipes = const [],
}) {
  final issues = <ValidationIssue>[];
  _checkUnitSizes(issues, unitSizes);
  _checkUnits(issues, units);
  final ingredientTagNames = ingredientTags.map((t) => t.name).toList();
  final recipeTagNames = recipeTags.map((t) => t.name).toList();
  final knownIngredientTags = nameKeys(ingredientTagNames);
  // Names and aliases share one namespace (ADR-10).
  final knownIngredients = <String>{};
  _checkIngredients(issues, ingredients, knownIngredients, knownIngredientTags);
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

/// A size of zero or less would leave a conversion meaningless in both
/// directions, ml being what the other two are measured against (ADR 17).
void _checkUnitSizes(List<ValidationIssue> issues, UnitSizes unitSizes) {
  for (final (key, size) in [
    ('part_ml', unitSizes.partMl),
    ('oz_ml', unitSizes.ozMl),
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
}

void _checkIngredients(
  List<ValidationIssue> issues,
  List<Ingredient> ingredients,
  Set<String> knownIngredients,
  Set<String> knownIngredientTags,
) {
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
}

/// Every rule on the unit vocabulary (ADR-09).
void _checkUnits(List<ValidationIssue> issues, List<Unit> units) {
  final seen = <String>{};
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    addProblems(
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
    addProblems(
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
    if (isOtherName(name, except)) name,
};

/// Checks one ingredient before entering vocabulary; paths relative to entry.
List<ValidationIssue> validateIngredient(
  Ingredient ingredient, {
  required Set<String> knownIngredientTags,
  Set<String> otherIngredientNames = const {},
}) {
  final taken = nameKeys(otherIngredientNames);
  return [
    ...checkName(
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
}) => checkName(
  'tag',
  tag.name,
  isDuplicate: repeatsName(nameKeys(otherTagNames), tag.name),
);

/// Checks one recipe against vocabularies; paths relative to recipe.
List<ValidationIssue> validateRecipe(
  Recipe recipe, {
  required Set<String> knownIngredients,
  required Set<String> knownTags,
  required Set<String> knownUnits,
  Set<String> otherRecipeNames = const {},
}) => [
  ...checkName(
    'recipe',
    recipe.name,
    isDuplicate: repeatsName(nameKeys(otherRecipeNames), recipe.name),
  ),
  ..._checkRecipe(
    recipe,
    nameKeys(knownIngredients),
    const [],
    knownTags: nameKeys(knownTags),
    knownUnits: nameKeys(knownUnits),
  ),
];

/// Every rule for one list of named entries, applied per entry.
void _checkNames(
  List<ValidationIssue> issues,
  String key,
  String entity,
  List<String> names, {
  Set<String>? namespace,
  Problem? Function(String name)? extraRule,
  List<ValidationIssue> Function(int index)? entryIssues,
}) {
  final taken = namespace ?? <String>{};
  for (var i = 0; i < names.length; i++) {
    issues.addAll(
      checkName(
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
    addProblems(
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

Problem _duplicateProblem(String entity, String name) => (
  kind: ValidationIssueKind.duplicateName,
  message: duplicateNameMessage(entity, name),
);

/// The grammar's own text is reserved: no ingredient spelling may end with a
/// mark suffix, nor hold the separator that would split it in two (ADR-11).
Problem? _reservedTextProblem(String what, String name) {
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

Problem? _nameProblem(String entity, String name) {
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
    addProblems(
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
    _checkLine(
      issues,
      recipe.lines[l],
      l,
      basePath,
      knownIngredients,
      knownUnits,
    );
  }
  return issues;
}

/// Every rule on one recipe line: each alternative must name a known
/// ingredient, and naming one twice is a slip rather than a choice (ADR-11);
/// the unit must be known; the amount must be positive and its range in order.
void _checkLine(
  List<ValidationIssue> issues,
  RecipeLine line,
  int index,
  List<Object> basePath,
  Set<String> knownIngredients,
  Set<String> knownUnits,
) {
  final amount = formatAmount(line.amount);
  final repeated = duplicateNameIndexes(line.ingredients).toSet();
  addProblems(
    issues,
    [...basePath, 'lines', index],
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
