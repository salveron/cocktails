/// The canonical emitter behind YamlCodec.encode: fixed key order, two-space
/// indents, defaults omitted, every section present, no comments — the form
/// docs/architecture.md#data-format specifies and the round-trip tests pin.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:yaml/yaml.dart';

/// The schema version the app reads and writes.
const int storeFormatVersion = 1;

/// Characters that end a plain scalar inside a flow collection.
final _flowUnsafe = RegExp(r'[,\[\]{}:]');

String encodeModel(Model model) {
  final settings = model.settings;
  final sections = [
    'format: $storeFormatVersion',
    'settings:\n'
        '  part_ml: ${formatNumber(settings.partMl)}\n'
        '  oz_ml: ${formatNumber(settings.ozMl)}\n'
        '  display: ${settings.display.token}',
    _section('units', model.units.map(_unitEntry)),
    _section('ingredients', model.ingredients.map(_ingredientEntry)),
    _section('ingredient_tags', model.ingredientTags.map(_tagEntry)),
    _section('recipe_tags', model.recipeTags.map(_tagEntry)),
    _section(
      'recipes',
      model.recipes.map((recipe) => _recipeEntry(recipe, model.units)),
    ),
  ];
  return '${sections.join('\n\n')}\n';
}

/// A top-level list section; entries are line lists, first line after `- `,
/// the rest indented to match.
String _section(String key, Iterable<List<String>> entries) {
  if (entries.isEmpty) return '$key: []';
  final buffer = StringBuffer('$key:');
  for (final entry in entries) {
    buffer.write('\n  - ${entry.first}');
    for (final line in entry.skip(1)) {
      buffer.write('\n    $line');
    }
  }
  return buffer.toString();
}

/// The one-line `{name: …}` entry every vocabulary writes, [fields] carrying
/// whatever else the entry has to say once its defaults are left out.
List<String> _vocabularyEntry(String name, List<String> fields) => [
  '{${['name: ${_scalar(name, inFlow: true)}', ...fields].join(', ')}}',
];

/// A plural reading like the name is left out, as every default is.
List<String> _unitEntry(Unit unit) => _vocabularyEntry(unit.name, [
  if (unit.plural.isNotEmpty) 'plural: ${_scalar(unit.plural, inFlow: true)}',
]);

List<String> _ingredientEntry(Ingredient ingredient) =>
    _vocabularyEntry(ingredient.name, [
      if (ingredient.stock != StockLevel.out)
        'stock: ${ingredient.stock.token}',
      if (ingredient.tags.isNotEmpty) 'tags: ${_flowList(ingredient.tags)}',
      if (ingredient.aliases.isNotEmpty)
        'aliases: ${_flowList(ingredient.aliases)}',
    ]);

/// A tag's colour is never omitted — there is no default to omit it against.
List<String> _tagEntry(Tag tag) =>
    _vocabularyEntry(tag.name, ['color: ${tag.color.token}']);

List<String> _recipeEntry(Recipe recipe, List<Unit> units) => [
  'name: ${_scalar(recipe.name)}',
  if (recipe.tags.isNotEmpty) 'tags: ${_flowList(recipe.tags)}',
  if (recipe.lines.isNotEmpty) 'lines:',
  for (final line in recipe.lines)
    '  - ${_scalar(formatRecipeLine(line, units))}',
  if (recipe.notes.isNotEmpty) 'notes: ${_scalar(recipe.notes)}',
];

String _flowList(Iterable<String> values) =>
    '[${values.map((value) => _scalar(value, inFlow: true)).join(', ')}]';

String _scalar(String value, {bool inFlow = false}) =>
    _isPlainSafe(value, inFlow: inFlow) ? value : _quoted(value);

/// Plain only when YAML reads the bare text back as the same string — the
/// parser itself decides, so `1976`, `true`, `a: b`, or `x #y` get quoted.
bool _isPlainSafe(String value, {required bool inFlow}) {
  if (inFlow && value.contains(_flowUnsafe)) return false;
  try {
    return loadYaml(value) == value;
  } on Exception {
    return false;
  }
}

String _quoted(String value) {
  final buffer = StringBuffer('"');
  for (final code in value.codeUnits) {
    buffer.write(switch (code) {
      0x22 => r'\"',
      0x5C => r'\\',
      0x0A => r'\n',
      0x0D => r'\r',
      0x09 => r'\t',
      < 0x20 => '\\x${code.toRadixString(16).padLeft(2, '0')}',
      _ => String.fromCharCode(code),
    });
  }
  buffer.write('"');
  return buffer.toString();
}
