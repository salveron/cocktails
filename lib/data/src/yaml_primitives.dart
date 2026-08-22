/// The generic YAML-reading primitives a bar's own file and the shelf index
/// are both built from: key checks, typed field reads, list walks, and the
/// issue-reporting shape they all report through.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:yaml/yaml.dart';

typedef EntryReader<T> =
    T? Function(YamlNode node, List<Object> path, List<ValidationIssue> issues);

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
void checkKeys(
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

/// A top-level section's entries; the same walk as any other string list,
/// rooted at the file itself.
List<T> readEntries<T>(
  YamlMap root,
  String key,
  List<ValidationIssue> issues,
  EntryReader<T> readEntry,
) {
  final entries = <T>[];
  forEachEntry(root, key, const [], issues, (node, path) {
    final entry = readEntry(node, path, issues);
    if (entry != null) entries.add(entry);
  });
  return entries;
}

/// The value [key] carries, put through [parse]; null where the key is absent
/// or carries something [parse] refuses, which is reported as failing
/// [requirement]. A [required] key reports its absence; an optional one leaves
/// that to the caller's default.
T? readValue<T>(
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
  if (parsed == null) report(issues, [...path, key], requirement, node);
  return parsed;
}

String? asString(Object? value) => value is String ? value : null;

/// A string field under [key]; every one asks for the same thing.
String? readText(
  YamlMap map,
  String key,
  List<Object> path,
  List<ValidationIssue> issues, {
  bool required = false,
}) => readValue<String>(
  map,
  key,
  path,
  issues,
  parse: asString,
  requirement: '$key must be a string',
  required: required,
);

/// A true/false field under [key]; every one asks for the same thing.
bool? readBool(
  YamlMap map,
  String key,
  List<Object> path,
  List<ValidationIssue> issues,
) => readValue<bool>(
  map,
  key,
  path,
  issues,
  parse: (value) => value is bool ? value : null,
  requirement: '$key must be true or false',
);

/// A whole number under [key]; [atLeast] is Holds' alone, a count never
/// negative, and narrows the requirement's wording along with the value.
int? readInt(
  YamlMap map,
  String key,
  List<Object> path,
  List<ValidationIssue> issues, {
  int? atLeast,
}) => readValue<int>(
  map,
  key,
  path,
  issues,
  parse: (value) =>
      value is int && (atLeast == null || value >= atLeast) ? value : null,
  requirement: atLeast == null
      ? '$key must be a number'
      : '$key must be a count',
);

/// A finite decimal under [key]; the format writes size ratios as plain
/// numbers, never quoted.
double? readDouble(
  YamlMap map,
  String key,
  List<Object> path,
  List<ValidationIssue> issues,
) => readValue<double>(
  map,
  key,
  path,
  issues,
  parse: (value) => value is num && value.isFinite ? value.toDouble() : null,
  requirement: '$key must be a number',
);

/// Enum-token value or null; one bad token doesn't cost other entry fields.
/// The tokens on offer are the message, so no call site spells them out.
/// [fromToken] rather than `enumFromToken` itself: the domain's own lookup is
/// unexported (ADR-04), each enum's static the reader is meant to lean on.
T? readToken<T extends Tokened>(
  YamlMap map,
  String key,
  List<Object> path,
  List<ValidationIssue> issues, {
  required T? Function(String) fromToken,
  required List<T> values,
  bool required = false,
}) => readValue<T>(
  map,
  key,
  path,
  issues,
  parse: (value) => fromToken(asString(value) ?? ''),
  requirement:
      '$key must be one of '
      '${[for (final value in values) value.token].join(', ')}',
  required: required,
);

/// List of bare names under [key]: tags worn, aliases answered to.
List<String> readNames(
  YamlMap node,
  String key,
  List<Object> path,
  List<ValidationIssue> issues,
  String what,
) {
  final names = <String>[];
  forEachEntry(node, key, path, issues, (entryNode, entryPath) {
    final name = stringValue(entryNode, entryPath, issues, what);
    if (name != null) names.add(name);
  });
  return names;
}

/// Walks string-list under [key]; shared shape for tags and lines.
void forEachEntry(
  YamlMap map,
  String key,
  List<Object> path,
  List<ValidationIssue> issues,
  void Function(YamlNode node, List<Object> path) readEntry,
) {
  final node = map.nodes[key];
  if (node == null) return;
  if (node is! YamlList) {
    report(issues, [...path, key], '$key must be a list', node);
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

/// `display:` into a [FixedUnit], defaulting to [FixedUnit.part] — the
/// reading every settings block and every bar record hold under the one key
/// (ADR 21). [node] is the enclosing mapping, not yet confirmed one: its
/// shape is the caller's own block to report on, so a non-mapping is passed
/// over here rather than raising a second issue for it.
FixedUnit readDisplay(
  YamlNode? node,
  List<Object> path,
  List<ValidationIssue> issues,
) => node is! YamlMap
    ? FixedUnit.part
    : readValue<FixedUnit>(
            node,
            'display',
            path,
            issues,
            parse: (value) => FixedUnit.fromToken(asString(value) ?? ''),
            requirement: 'display must be part, ml or oz',
          ) ??
          FixedUnit.part;

String? stringValue(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
  String what,
) {
  final value = node.value;
  if (value is String) return value;
  report(issues, path, '$what must be a string', node);
  return null;
}

void report(
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
