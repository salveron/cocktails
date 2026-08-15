/// The canonical emitter behind YamlCodec.encode: fixed key order, two-space
/// indents, defaults omitted, every section present, no comments — the form
/// docs/architecture.md#data-format specifies and the round-trip tests pin.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:yaml/yaml.dart';

import 'bar_store.dart' show Records;

/// The schema version the app reads and writes — the bar's file and the index
/// alike, one number for the whole on-disk layout (ADR 21).
const int storeFormatVersion = 2;

/// The oldest version still read. Written back as [storeFormatVersion], so
/// nothing but the reader below ever meets it.
const int oldestReadableFormat = 1;

/// Characters that end a plain scalar inside a flow collection.
final _flowUnsafe = RegExp(r'[,\[\]{}:]');

/// One bar's file: the owner's [name] for it, the [display] whoever establishes
/// a bar from this carries over, and the collection (ADR 21).
String encodeBar(BarPayload payload) {
  final collection = payload.collection;
  final settings = collection.settings;
  final sections = [
    'format: $storeFormatVersion\n'
        'name: ${_scalar(payload.name)}',
    'settings:\n'
        '  part_ml: ${formatNumber(settings.partMl)}\n'
        '  oz_ml: ${formatNumber(settings.ozMl)}\n'
        '  display: ${payload.display.token}',
    _section('units', collection.units.map(_unitEntry)),
    _section('ingredients', collection.ingredients.map(_ingredientEntry)),
    _section('ingredient_tags', collection.ingredientTags.map(_tagEntry)),
    _section('recipe_tags', collection.recipeTags.map(_tagEntry)),
    _section(
      'recipes',
      collection.recipes.map(
        (recipe) => _recipeEntry(recipe, collection.units),
      ),
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
  _flowMap(['name: ${_scalar(name, inFlow: true)}', ...fields]),
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

/// The index: every bar's record and which is open, in the same canonical form
/// a bar's file takes. Device state rather than an export — it travels nowhere
/// (docs/architecture.md#data-format).
String encodeShelf(Records records) {
  final open = records.openId;
  final sections = [
    'format: $storeFormatVersion\n'
        'open:${open == null ? '' : ' ${_scalar(open)}'}',
    _section('bars', records.bars.map(_barEntry)),
  ];
  return '${sections.join('\n\n')}\n';
}

/// One record, one line: the halves a mode rules out are left off as every
/// default is, so an owner carries no source and a guest no offers.
List<String> _barEntry(Bar bar) {
  final refreshed = bar.refreshed;
  final updated = bar.updated;
  final source = bar.source;
  final holds = bar.holds;
  return [
    _flowMap([
      'id: ${_scalar(bar.id, inFlow: true)}',
      'name: ${_scalar(bar.name, inFlow: true)}',
      'mode: ${bar.mode.token}',
      'display: ${bar.display.token}',
      if (bar.offers.isNotEmpty)
        'offers: [${bar.offers.map(_offer).join(', ')}]',
      // Quoted: a timestamp's colons would end the scalar in flow context.
      if (refreshed != null) 'refreshed: ${_stamp(refreshed)}',
      if (updated != null) 'updated: ${_stamp(updated)}',
      if (holds != null) 'holds: ${_holds(holds)}',
      if (source != null) 'source: ${_source(source)}',
    ]),
  ];
}

String _stamp(DateTime at) =>
    _scalar(at.toUtc().toIso8601String(), inFlow: true);

/// Every kind, in [Holding]'s own order and including the zeroes: a summary
/// left half-written is one a reader cannot tell from a bar that holds none.
String _holds(Map<Holding, int> holds) => _flowMap([
  for (final holding in Holding.values)
    '${holding.token}: ${holds[holding] ?? 0}',
]);

String _offer(Offer offer) => _flowMap([
  'via: ${offer.via.token}',
  if (offer.guests.isNotEmpty) 'guests: ${_flowList(offer.guests)}',
]);

String _source(BarSource source) => _flowMap([
  'via: ${source.via.token}',
  'at: ${_scalar(source.at, inFlow: true)}',
  'from: ${_scalar(source.from, inFlow: true)}',
]);

String _flowMap(List<String> fields) => '{${fields.join(', ')}}';

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
