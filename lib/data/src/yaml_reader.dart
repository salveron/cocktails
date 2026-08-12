/// YAML tree → the parts of a bar's file and of the index; shape errors become
/// issues at data-format paths.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:yaml/yaml.dart';

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

typedef _EntryReader<T> =
    T? Function(YamlNode node, List<Object> path, List<ValidationIssue> issues);

BarParts readBarParts(YamlMap root) {
  final issues = <ValidationIssue>[];
  const sections = {
    'format',
    'name',
    'settings',
    'units',
    'ingredients',
    'ingredient_tags',
    'recipe_tags',
    'recipes',
  };
  _checkKeys(root, sections, const [], issues);
  // File with no units uses shipped defaults; parsed against them (ADR-09).
  final units = root.nodes['units'] == null
      ? defaultUnits
      : _readEntries(root, 'units', issues, _readUnit);
  final settingsNode = root.nodes['settings'];
  return BarParts(
    // Required from format 2 on, absent by definition in a format-1 file.
    name:
        _readText(
          root,
          'name',
          const [],
          issues,
          required: root.nodes['format']?.value != oldestReadableFormat,
        ) ??
        '',
    // Settings first, so the block's issues read in the file's own order.
    settings: _readSettings(settingsNode, issues),
    display: _readDisplay(settingsNode, issues),
    units: units,
    ingredients: _readEntries(root, 'ingredients', issues, _readIngredient),
    ingredientTags: _readEntries(root, 'ingredient_tags', issues, _readTag),
    recipeTags: _readEntries(root, 'recipe_tags', issues, _readTag),
    recipes: _readEntries(
      root,
      'recipes',
      issues,
      (node, path, issues) => _readRecipe(node, path, issues, units),
    ),
    issues: issues,
  );
}

final class ShelfParts {
  final List<Bar> bars;
  final String? openId;
  final List<ValidationIssue> issues;

  ShelfParts({required this.bars, this.openId, required this.issues});
}

/// The index's records, built whatever they say: coherence between a record's
/// parts is `validateShelf`'s to report, and a `Bar` that refused to exist
/// could only be crashed on rather than told about (ADR 20).
ShelfParts readShelfParts(YamlMap root) {
  final issues = <ValidationIssue>[];
  _checkKeys(root, const {'format', 'open', 'bars'}, const [], issues);
  // The key is written whether or not a bar is open, so a bare `open:` — a
  // YAML null — is a shelf with none on show rather than a malformed value.
  final open = root.nodes['open'];
  return ShelfParts(
    openId: open == null || open.value == null
        ? null
        : _readText(root, 'open', const [], issues),
    bars: _readEntries(root, 'bars', issues, _readBar),
    issues: issues,
  );
}

Bar? _readBar(YamlNode node, List<Object> path, List<ValidationIssue> issues) {
  if (node is! YamlMap) {
    _report(issues, path, 'Bar entry must be a mapping', node);
    return null;
  }
  const keys = {
    'id',
    'name',
    'mode',
    'display',
    'offers',
    'refreshed',
    'source',
  };
  _checkKeys(node, keys, path, issues);
  final id = _readText(node, 'id', path, issues, required: true);
  final name = _readText(node, 'name', path, issues, required: true);
  final mode = _readToken(
    node,
    'mode',
    path,
    issues,
    fromToken: BarMode.fromToken,
    values: BarMode.values,
    token: (value) => value.token,
    required: true,
  );
  final display =
      _readToken(
        node,
        'display',
        path,
        issues,
        fromToken: FixedUnit.fromToken,
        values: FixedUnit.values,
        token: (value) => value.token,
      ) ??
      FixedUnit.part;
  final offers = <Offer>[];
  _forEachEntry(node, 'offers', path, issues, (entryNode, entryPath) {
    final offer = _readOffer(entryNode, entryPath, issues);
    if (offer != null) offers.add(offer);
  });
  final refreshed = _readValue<DateTime>(
    node,
    'refreshed',
    path,
    issues,
    parse: (value) => DateTime.tryParse(_asString(value) ?? '')?.toUtc(),
    requirement: 'refreshed must be a UTC timestamp',
  );
  final source = _readSource(node.nodes['source'], [...path, 'source'], issues);
  if (id == null || name == null || mode == null) return null;
  return Bar(
    id: id,
    name: name,
    mode: mode,
    display: display,
    offers: offers,
    source: source,
    refreshed: refreshed,
  );
}

Offer? _readOffer(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  if (node is! YamlMap) {
    _report(issues, path, 'Offer entry must be a mapping', node);
    return null;
  }
  _checkKeys(node, const {'via', 'guests'}, path, issues);
  final via = _readTransport(node, path, issues);
  return via == null
      ? null
      : (via: via, guests: _readNames(node, 'guests', path, issues, 'Guest'));
}

BarSource? _readSource(
  YamlNode? node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  if (node == null) return null;
  if (node is! YamlMap) {
    _report(issues, path, 'source must be a mapping', node);
    return null;
  }
  _checkKeys(node, const {'via', 'at', 'from'}, path, issues);
  final via = _readTransport(node, path, issues);
  final at = _readText(node, 'at', path, issues, required: true);
  final from = _readText(node, 'from', path, issues, required: true);
  return via == null || at == null || from == null
      ? null
      : BarSource(via: via, at: at, from: from);
}

Transport? _readTransport(
  YamlMap node,
  List<Object> path,
  List<ValidationIssue> issues,
) => _readToken(
  node,
  'via',
  path,
  issues,
  fromToken: Transport.fromToken,
  values: Transport.values,
  token: (value) => value.token,
  required: true,
);

/// 1-based source line [path] leads to; deepest resolvable node if not found.
int lineOfPath(YamlNode root, List<Object> path) {
  var node = root;
  var span = node.span;
  for (final segment in path) {
    if (node is YamlMap && segment is String) {
      final entry = _entryNamed(node, segment);
      if (entry == null) break;
      span = entry.key.span;
      node = entry.value;
    } else if (node is YamlList &&
        segment is int &&
        segment >= 0 &&
        segment < node.nodes.length) {
      node = node.nodes[segment];
      span = node.span;
    } else {
      break;
    }
  }
  return span.start.line + 1;
}

/// Value display for issue messages, compact.
String briefValue(Object? value) {
  final text = switch (value) {
    String() => '"$value"',
    YamlList() => 'a list',
    YamlMap() => 'a mapping',
    _ => '$value',
  };
  return text.length <= 40 ? text : '${text.substring(0, 39)}…';
}

MapEntry<YamlNode, YamlNode>? _entryNamed(YamlMap map, String key) {
  for (final entry in map.nodes.entries) {
    final keyNode = entry.key;
    if (keyNode is YamlNode && keyNode.value == key) {
      return MapEntry(keyNode, entry.value);
    }
  }
  return null;
}

/// Unknown keys are structural errors; misspelled keys silently lose data.
void _checkKeys(
  YamlMap map,
  Set<String> known,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  for (final keyNode in map.nodes.keys) {
    final key = (keyNode as YamlNode).value;
    if (key is String && known.contains(key)) continue;
    issues.add(
      ValidationIssue(
        [...path, if (key is String) key],
        ValidationIssueKind.malformedValue,
        'Unknown key: ${briefValue(key)}',
      ),
    );
  }
}

/// The two sizes, which are the owner's. `display` sits in the same block but
/// belongs to the reader, so [_readDisplay] takes it out separately (ADR 21).
Settings _readSettings(YamlNode? node, List<ValidationIssue> issues) {
  const defaults = Settings();
  if (node is! YamlMap) {
    if (node != null) {
      _report(issues, const ['settings'], 'settings must be a mapping', node);
    }
    return defaults;
  }
  const path = ['settings'];
  _checkKeys(node, const {'part_ml', 'oz_ml', 'display'}, path, issues);
  double? size(String key) => _readValue<double>(
    node,
    key,
    path,
    issues,
    parse: (value) => value is num && value.isFinite ? value.toDouble() : null,
    requirement: '$key must be a number',
  );
  return Settings(
    partMl: size('part_ml') ?? defaults.partMl,
    ozMl: size('oz_ml') ?? defaults.ozMl,
  );
}

/// Its own wording rather than the token list: the readings, named. The block's
/// shape is [_readSettings]' to report on, so a non-mapping is passed over here.
FixedUnit _readDisplay(YamlNode? node, List<ValidationIssue> issues) =>
    node is! YamlMap
    ? FixedUnit.part
    : _readValue<FixedUnit>(
            node,
            'display',
            const ['settings'],
            issues,
            parse: (value) => FixedUnit.fromToken(_asString(value) ?? ''),
            requirement: 'display must be part, ml or oz',
          ) ??
          FixedUnit.part;

/// A top-level section's entries; the same walk as any other string list,
/// rooted at the file itself.
List<T> _readEntries<T>(
  YamlMap root,
  String key,
  List<ValidationIssue> issues,
  _EntryReader<T> readEntry,
) {
  final entries = <T>[];
  _forEachEntry(root, key, const [], issues, (node, path) {
    final entry = readEntry(node, path, issues);
    if (entry != null) entries.add(entry);
  });
  return entries;
}

/// The value [key] carries, put through [parse]; null where the key is absent
/// or carries something [parse] refuses, which is reported as failing
/// [requirement]. A [required] key reports its absence; an optional one leaves
/// that to the caller's default.
T? _readValue<T>(
  YamlMap map,
  String key,
  List<Object> path,
  List<ValidationIssue> issues, {
  required T? Function(Object? value) parse,
  required String requirement,
  bool required = false,
}) {
  final node = map.nodes[key];
  if (node == null) {
    if (required) _reportMissing(issues, path, key);
    return null;
  }
  final parsed = parse(node.value);
  if (parsed == null) _report(issues, [...path, key], requirement, node);
  return parsed;
}

String? _asString(Object? value) => value is String ? value : null;

/// A string field under [key]; every one asks for the same thing.
String? _readText(
  YamlMap map,
  String key,
  List<Object> path,
  List<ValidationIssue> issues, {
  bool required = false,
}) => _readValue<String>(
  map,
  key,
  path,
  issues,
  parse: _asString,
  requirement: '$key must be a string',
  required: required,
);

/// Omitted `plural` means it reads like the name.
Unit? _readUnit(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  if (node is! YamlMap) {
    _report(issues, path, 'Unit entry must be a mapping', node);
    return null;
  }
  _checkKeys(node, const {'name', 'plural'}, path, issues);
  final name = _readText(node, 'name', path, issues, required: true);
  final plural = _readText(node, 'plural', path, issues) ?? '';
  return name == null ? null : Unit(name, plural: plural);
}

Ingredient? _readIngredient(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  if (node is! YamlMap) {
    _report(issues, path, 'Ingredient entry must be a mapping', node);
    return null;
  }
  _checkKeys(node, const {'name', 'stock', 'tags', 'aliases'}, path, issues);
  final name = _readText(node, 'name', path, issues, required: true);
  final stock =
      _readToken(
        node,
        'stock',
        path,
        issues,
        fromToken: StockLevel.fromToken,
        values: StockLevel.values,
        token: (value) => value.token,
      ) ??
      StockLevel.out;
  final aliases = _readNames(node, 'aliases', path, issues, 'Alias');
  final tags = _readNames(node, 'tags', path, issues, 'Tag');
  return name == null
      ? null
      : Ingredient(name, stock: stock, aliases: aliases, tags: tags);
}

/// Unlike `stock`, `color` is required; every tag carries one (ADR-07).
Tag? _readTag(YamlNode node, List<Object> path, List<ValidationIssue> issues) {
  if (node is! YamlMap) {
    _report(issues, path, 'Tag entry must be a mapping', node);
    return null;
  }
  _checkKeys(node, const {'name', 'color'}, path, issues);
  final name = _readText(node, 'name', path, issues, required: true);
  final color = _readToken(
    node,
    'color',
    path,
    issues,
    fromToken: TagColor.fromToken,
    values: TagColor.values,
    token: (value) => value.token,
    required: true,
  );
  return name == null || color == null ? null : Tag(name, color: color);
}

/// Enum-token value or null; one bad token doesn't cost other entry fields.
/// The tokens on offer are the message, so no call site spells them out.
T? _readToken<T extends Enum>(
  YamlMap map,
  String key,
  List<Object> path,
  List<ValidationIssue> issues, {
  required T? Function(String) fromToken,
  required List<T> values,
  required String Function(T value) token,
  bool required = false,
}) => _readValue<T>(
  map,
  key,
  path,
  issues,
  parse: (value) => fromToken(_asString(value) ?? ''),
  requirement:
      '$key must be one of '
      '${[for (final value in values) token(value)].join(', ')}',
  required: required,
);

/// List of bare names under [key]: tags worn, aliases answered to.
List<String> _readNames(
  YamlMap node,
  String key,
  List<Object> path,
  List<ValidationIssue> issues,
  String what,
) {
  final names = <String>[];
  _forEachEntry(node, key, path, issues, (entryNode, entryPath) {
    final name = _stringValue(entryNode, entryPath, issues, what);
    if (name != null) names.add(name);
  });
  return names;
}

Recipe? _readRecipe(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
  List<Unit> units,
) {
  if (node is! YamlMap) {
    _report(issues, path, 'Recipe entry must be a mapping', node);
    return null;
  }
  // `made` is accepted and ignored, whatever it holds: the key left the product
  // with FR-REC-6, and a file already on a device keeps opening (ADR 21).
  const keys = {'name', 'tags', 'lines', 'notes', 'made'};
  _checkKeys(node, keys, path, issues);
  final name = _readText(node, 'name', path, issues, required: true);
  final tags = _readNames(node, 'tags', path, issues, 'Tag');
  final lines = <RecipeLine>[];
  _forEachEntry(node, 'lines', path, issues, (entryNode, entryPath) {
    final text = _stringValue(entryNode, entryPath, issues, 'Recipe line');
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
  final notes = _readText(node, 'notes', path, issues) ?? '';
  if (name == null) return null;
  return Recipe(name, tags: tags, lines: lines, notes: notes);
}

/// Walks string-list under [key]; shared shape for tags and lines.
void _forEachEntry(
  YamlMap map,
  String key,
  List<Object> path,
  List<ValidationIssue> issues,
  void Function(YamlNode node, List<Object> path) readEntry,
) {
  final node = map.nodes[key];
  if (node == null) return;
  if (node is! YamlList) {
    _report(issues, [...path, key], '$key must be a list', node);
    return;
  }
  for (var i = 0; i < node.nodes.length; i++) {
    readEntry(node.nodes[i], [...path, key, i]);
  }
}

/// Required key missing; path is the entry itself, no inner node.
void _reportMissing(
  List<ValidationIssue> issues,
  List<Object> path,
  String key,
) => issues.add(
  ValidationIssue(path, ValidationIssueKind.malformedValue, 'Missing $key'),
);

String? _stringValue(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
  String what,
) {
  final value = node.value;
  if (value is String) return value;
  _report(issues, path, '$what must be a string', node);
  return null;
}

void _report(
  List<ValidationIssue> issues,
  List<Object> path,
  String requirement,
  YamlNode node,
) {
  issues.add(
    ValidationIssue(
      path,
      ValidationIssueKind.malformedValue,
      '$requirement: ${briefValue(node.value)}',
    ),
  );
}
