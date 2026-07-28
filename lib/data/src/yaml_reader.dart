/// YAML tree → model parts (decode steps 3 and 5 of
/// docs/components.md#data-contracts): shape errors — wrong types, missing or
/// unknown keys, bad tokens, malformed lines — become issues at data-format
/// paths, and [lineOfPath] is the one place those paths bind to source lines.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:yaml/yaml.dart';

final class ModelParts {
  final Settings settings;
  final List<Ingredient> ingredients;
  final List<Tag> tags;
  final List<Recipe> recipes;
  final List<ValidationIssue> issues;

  ModelParts({
    required this.settings,
    required this.ingredients,
    required this.tags,
    required this.recipes,
    required this.issues,
  });
}

typedef _EntryReader<T> =
    T? Function(YamlNode node, List<Object> path, List<ValidationIssue> issues);

ModelParts readModelParts(YamlMap root) {
  final issues = <ValidationIssue>[];
  const sections = {'format', 'settings', 'ingredients', 'tags', 'recipes'};
  _checkKeys(root, sections, const [], issues);
  return ModelParts(
    settings: _readSettings(root.nodes['settings'], issues),
    ingredients: _readEntries(root, 'ingredients', issues, _readIngredient),
    tags: _readEntries(root, 'tags', issues, _readTag),
    recipes: _readEntries(root, 'recipes', issues, _readRecipe),
    issues: issues,
  );
}

/// The 1-based source line [path] leads to — of the deepest resolvable node
/// when the full path does not exist. A map segment answers with the key's
/// own line, which reads better for keys whose value starts further down.
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

/// A value's display form for issue messages, kept short.
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

/// Unknown keys are structural errors — a misspelled key would otherwise
/// silently drop content on an import that replaces the whole database.
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

Settings _readSettings(YamlNode? node, List<ValidationIssue> issues) {
  const defaults = Settings();
  if (node == null) return defaults;
  if (node is! YamlMap) {
    _report(issues, const ['settings'], 'settings must be a mapping', node);
    return defaults;
  }
  _checkKeys(node, const {'part_ml', 'display'}, const ['settings'], issues);
  var partMl = defaults.partMl;
  final partMlNode = node.nodes['part_ml'];
  if (partMlNode != null) {
    final value = partMlNode.value;
    if (value is num && value.isFinite) {
      partMl = value.toDouble();
    } else {
      _report(
        issues,
        const ['settings', 'part_ml'],
        'part_ml must be a number',
        partMlNode,
      );
    }
  }
  var display = defaults.display;
  final displayNode = node.nodes['display'];
  if (displayNode != null) {
    final value = displayNode.value;
    final parsed = value is String ? DisplayUnit.fromToken(value) : null;
    if (parsed == null) {
      _report(
        issues,
        const ['settings', 'display'],
        'display must be part or ml',
        displayNode,
      );
    } else {
      display = parsed;
    }
  }
  return Settings(partMl: partMl, display: display);
}

List<T> _readEntries<T>(
  YamlMap root,
  String key,
  List<ValidationIssue> issues,
  _EntryReader<T> readEntry,
) {
  final node = root.nodes[key];
  if (node == null) return [];
  if (node is! YamlList) {
    _report(issues, [key], '$key must be a list', node);
    return [];
  }
  final entries = <T>[];
  for (var i = 0; i < node.nodes.length; i++) {
    final entry = readEntry(node.nodes[i], [key, i], issues);
    if (entry != null) entries.add(entry);
  }
  return entries;
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
  _checkKeys(node, const {'name', 'stock'}, path, issues);
  final name = _readName(node, path, issues);
  var stock = StockLevel.out;
  final stockNode = node.nodes['stock'];
  if (stockNode != null) {
    final value = stockNode.value;
    final parsed = value is String ? StockLevel.fromToken(value) : null;
    if (parsed == null) {
      _report(
        issues,
        [...path, 'stock'],
        'stock must be one of in, low, out',
        stockNode,
      );
    } else {
      stock = parsed;
    }
  }
  return name == null ? null : Ingredient(name, stock: stock);
}

Tag? _readTag(YamlNode node, List<Object> path, List<ValidationIssue> issues) {
  final name = _stringValue(node, path, issues, 'Tag');
  return name == null ? null : Tag(name);
}

Recipe? _readRecipe(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  if (node is! YamlMap) {
    _report(issues, path, 'Recipe entry must be a mapping', node);
    return null;
  }
  const keys = {'name', 'tags', 'lines', 'notes', 'made'};
  _checkKeys(node, keys, path, issues);
  final name = _readName(node, path, issues);
  final tags = <String>[];
  _forEachEntry(node, 'tags', path, issues, (entryNode, entryPath) {
    final tag = _stringValue(entryNode, entryPath, issues, 'Tag');
    if (tag != null) tags.add(tag);
  });
  final lines = <RecipeLine>[];
  _forEachEntry(node, 'lines', path, issues, (entryNode, entryPath) {
    final text = _stringValue(entryNode, entryPath, issues, 'Recipe line');
    if (text == null) return;
    final parsed = tryParseRecipeLine(text);
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
  var notes = '';
  final notesNode = node.nodes['notes'];
  if (notesNode != null) {
    notes = _stringValue(notesNode, [...path, 'notes'], issues, 'notes') ?? '';
  }
  MadeHistory? made;
  final madeNode = node.nodes['made'];
  if (madeNode != null) {
    made = _readMade(madeNode, [...path, 'made'], issues);
  }
  if (name == null) return null;
  return Recipe(name, tags: tags, lines: lines, notes: notes, made: made);
}

/// Walks the string-list value under [key], handing each element node and its
/// path to [readEntry] — the shared shape handling of recipe tags and lines.
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

MadeHistory? _readMade(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  if (node is! YamlMap) {
    _report(issues, path, 'made must be a mapping', node);
    return null;
  }
  _checkKeys(node, const {'last', 'times'}, path, issues);
  DateTime? last;
  final lastNode = node.nodes['last'];
  if (lastNode == null) {
    issues.add(
      ValidationIssue(path, ValidationIssueKind.malformedValue, 'Missing last'),
    );
  } else {
    final text = _stringValue(lastNode, [...path, 'last'], issues, 'last');
    if (text != null) {
      last = _tryParseDate(text);
      if (last == null) {
        _report(
          issues,
          [...path, 'last'],
          'last must be a date (YYYY-MM-DD)',
          lastNode,
        );
      }
    }
  }
  int? times;
  final timesNode = node.nodes['times'];
  if (timesNode == null) {
    issues.add(
      ValidationIssue(
        path,
        ValidationIssueKind.malformedValue,
        'Missing times',
      ),
    );
  } else {
    final value = timesNode.value;
    if (value is int) {
      times = value;
    } else {
      _report(
        issues,
        [...path, 'times'],
        'times must be a whole number',
        timesNode,
      );
    }
  }
  if (last == null || times == null) return null;
  return MadeHistory(last, times);
}

String? _readName(
  YamlMap map,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  final node = map.nodes['name'];
  if (node == null) {
    issues.add(
      ValidationIssue(path, ValidationIssueKind.malformedValue, 'Missing name'),
    );
    return null;
  }
  return _stringValue(node, [...path, 'name'], issues, 'name');
}

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

final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Strict `YYYY-MM-DD`, rejecting calendar overflow (a `02-31` must not roll
/// into March) — the emitter writes dates back in exactly this form.
DateTime? _tryParseDate(String text) {
  final match = _datePattern.firstMatch(text);
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  final overflows = date.year != year || date.month != month || date.day != day;
  return overflows ? null : date;
}
