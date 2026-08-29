/// YAML tree → the parts of a bar's own file; shape errors become issues at
/// data-format paths.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:yaml/yaml.dart';

import 'yaml_primitives.dart';
import 'yaml_writer.dart' show oldestReadableFormat;

final class BarParts {
  /// What the file calls the bar, empty where it did not say — a format-1 file
  /// carries no `name:` and is named by whoever establishes a bar from it
  /// (ADR 21).
  final String name;

  /// The unit the file reads amounts in, taken only where a bar is established
  /// and never on a refresh (ADR 21).
  final FixedUnit display;
  final Settings settings;
  final List<Unit> units;
  final List<Ingredient> ingredients;
  final List<Tag> ingredientTags;
  final List<Tag> recipeTags;
  final List<Recipe> recipes;
  final List<ValidationIssue> issues;

  BarParts({
    required this.name,
    required this.display,
    required this.settings,
    required this.units,
    required this.ingredients,
    required this.ingredientTags,
    required this.recipeTags,
    required this.recipes,
    required this.issues,
  });
}

const _barSections = {
  'format',
  'name',
  'settings',
  'units',
  'ingredients',
  'ingredient_tags',
  'recipe_tags',
  'recipes',
};

BarParts readBarParts(YamlMap root) {
  final issues = <ValidationIssue>[];
  checkKeys(root, _barSections, const [], issues);
  // File with no units uses shipped defaults; parsed against them (ADR-09).
  final units = root.nodes['units'] == null
      ? defaultUnits
      : readEntries(root, 'units', issues, _readUnit);
  final settingsNode = root.nodes['settings'];
  return BarParts(
    name: _readBarName(root, issues),
    // Settings first, so the block's issues read in the file's own order.
    settings: _readSettings(settingsNode, issues),
    display: readDisplay(settingsNode, const ['settings'], issues),
    units: units,
    ingredients: readEntries(root, 'ingredients', issues, _readIngredient),
    ingredientTags: readEntries(root, 'ingredient_tags', issues, _readTag),
    recipeTags: readEntries(root, 'recipe_tags', issues, _readTag),
    recipes: readEntries(
      root,
      'recipes',
      issues,
      (node, path, issues) => _readRecipe(node, path, issues, units),
    ),
    issues: issues,
  );
}

/// Required from format 2 on, absent by definition in a format-1 file.
String _readBarName(YamlMap root, List<ValidationIssue> issues) =>
    readText(
      root,
      'name',
      const [],
      issues,
      required: root.nodes['format']?.value != oldestReadableFormat,
    ) ??
    '';

/// The two sizes, which are the owner's. `display` sits in the same block but
/// belongs to the reader, so [readDisplay] takes it out separately (ADR 21).
Settings _readSettings(YamlNode? node, List<ValidationIssue> issues) {
  const defaults = Settings();
  const path = ['settings'];
  final map = readMapping(node, path, issues, 'settings', const {
    'part_ml',
    'oz_ml',
    'display',
  });
  if (map == null) return defaults;
  double? size(String key) => readDouble(map, key, path, issues);
  return Settings(
    partMl: size('part_ml') ?? defaults.partMl,
    ozMl: size('oz_ml') ?? defaults.ozMl,
  );
}

/// Omitted `plural` means it reads like the name.
Unit? _readUnit(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  final map = readMapping(node, path, issues, 'Unit entry', const {
    'name',
    'plural',
  });
  if (map == null) return null;
  final name = readText(map, 'name', path, issues, required: true);
  final plural = readText(map, 'plural', path, issues) ?? '';
  return name == null ? null : Unit(name, plural: plural);
}

Ingredient? _readIngredient(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  final map = readMapping(node, path, issues, 'Ingredient entry', const {
    'name',
    'stock',
    'tags',
    'aliases',
  });
  if (map == null) return null;
  final name = readText(map, 'name', path, issues, required: true);
  final stock =
      readToken(
        map,
        'stock',
        path,
        issues,
        fromToken: StockLevel.fromToken,
        values: StockLevel.values,
      ) ??
      StockLevel.out;
  final aliases = readNames(map, 'aliases', path, issues, 'Alias');
  final tags = readNames(map, 'tags', path, issues, 'Tag');
  return name == null
      ? null
      : Ingredient(name, stock: stock, aliases: aliases, tags: tags);
}

/// Unlike `stock`, `color` is required; every tag carries one (ADR-07).
Tag? _readTag(YamlNode node, List<Object> path, List<ValidationIssue> issues) {
  final map = readMapping(node, path, issues, 'Tag entry', const {
    'name',
    'color',
  });
  if (map == null) return null;
  final name = readText(map, 'name', path, issues, required: true);
  final color = readToken(
    map,
    'color',
    path,
    issues,
    fromToken: TagColor.fromToken,
    values: TagColor.values,
    required: true,
  );
  return name == null || color == null ? null : Tag(name, color: color);
}

Recipe? _readRecipe(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
  List<Unit> units,
) {
  // `made` is accepted and ignored, whatever it holds: the key left the product
  // with FR-REC-6, and a file already on a device keeps opening (ADR 21).
  const keys = {'name', 'tags', 'lines', 'notes', 'made'};
  final map = readMapping(node, path, issues, 'Recipe entry', keys);
  if (map == null) return null;
  final name = readText(map, 'name', path, issues, required: true);
  final tags = readNames(map, 'tags', path, issues, 'Tag');
  final lines = <RecipeLine>[];
  forEachEntry(map, 'lines', path, issues, (entryNode, entryPath) {
    final text = stringValue(entryNode, entryPath, issues, 'Recipe line');
    if (text == null) return;
    final parsed = tryParseRecipeLine(text, units);
    final line = parsed.line;
    if (line == null) {
      issues.add(
        ValidationIssue(
          entryPath,
          ValidationIssueKind.malformedLine,
          parsed.problem!,
        ),
      );
    } else {
      lines.add(line);
    }
  });
  final notes = readText(map, 'notes', path, issues) ?? '';
  if (name == null) return null;
  return Recipe(name, tags: tags, lines: lines, notes: notes);
}
