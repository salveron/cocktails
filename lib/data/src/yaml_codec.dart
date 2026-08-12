/// Decode/encode between store text and what it holds — a bar (ADR 21) or the
/// index over them all; format-version gate.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:yaml/yaml.dart';

import 'bar_store.dart';
import 'sourced_issue.dart';
import 'yaml_reader.dart';
import 'yaml_writer.dart';

sealed class DecodeResult<T> {}

final class Decoded<T> extends DecodeResult<T> {
  final T value;

  Decoded(this.value);
}

final class Rejected<T> extends DecodeResult<T> {
  final List<SourcedIssue> issues;

  Rejected(List<SourcedIssue> issues) : issues = List.unmodifiable(issues);
}

final class YamlCodec {
  static const int formatVersion = storeFormatVersion;

  const YamlCodec();

  /// Canonical text: fixed key order, fixed indent, no comments.
  String encode(BarPayload payload) => encodeBar(payload);

  String encodeIndex(Records records) => encodeShelf(records);

  /// Never throws — every failure is a [Rejected] carrying sourced issues.
  /// Answers all three of a bar's parts and leaves who keeps which to the
  /// caller, which is where an import and a refresh differ (ADR 21).
  DecodeResult<BarPayload> decode(String yaml) => _decode(
    yaml,
    'format, name, settings, units, ingredients, ingredient_tags, '
    'recipe_tags, recipes',
    _readPayload,
  );

  /// The index, judged by `validateShelf` as a bar's file is by
  /// `validateCollection` — one canonical form, two documents.
  DecodeResult<Records> decodeIndex(String yaml) =>
      _decode(yaml, 'format, open, bars', _readRecords);

  DecodeResult<T> _decode<T>(
    String yaml,
    String shape,
    T? Function(YamlMap root, List<ValidationIssue> issues) read,
  ) {
    final YamlNode root;
    try {
      root = loadYamlNode(yaml);
    } on Exception catch (error) {
      final line = error is YamlException ? error.span?.start.line : null;
      final message = error is YamlException ? error.message : '$error';
      return Rejected([
        SourcedIssue(
          ValidationIssue(
            const [],
            ValidationIssueKind.malformedValue,
            'Not valid YAML: $message',
          ),
          line == null ? null : line + 1,
        ),
      ]);
    }
    if (root is! YamlMap) {
      return Rejected([
        _sourced(
          root,
          ValidationIssue(
            const [],
            ValidationIssueKind.malformedValue,
            'The top level must be a mapping with $shape',
          ),
        ),
      ]);
    }
    final gateIssue = _formatGateIssue(root);
    if (gateIssue != null) return Rejected([_sourced(root, gateIssue)]);

    final issues = <ValidationIssue>[];
    final value = read(root, issues);
    if (value == null || issues.isNotEmpty) {
      return Rejected([for (final issue in issues) _sourced(root, issue)]);
    }
    return Decoded(value);
  }

  /// A format-1 file carries no `name:` and its `made:` was dropped by the
  /// reader; the caller names the bar it establishes from one (ADR 21).
  static BarPayload? _readPayload(YamlMap root, List<ValidationIssue> issues) {
    final parts = readBarParts(root);
    issues.addAll(parts.issues);
    if (issues.isNotEmpty) return null;
    issues.addAll(
      validateCollection(
        settings: parts.settings,
        units: parts.units,
        ingredients: parts.ingredients,
        ingredientTags: parts.ingredientTags,
        recipeTags: parts.recipeTags,
        recipes: parts.recipes,
      ),
    );
    if (issues.isNotEmpty) return null;
    // A hand-edited file may name a bottle by an alias; the collection holds
    // the canonical name, so the next save writes it back that way (ADR 10).
    return (
      name: parts.name,
      display: parts.display,
      collection: Collection(
        settings: parts.settings,
        units: parts.units,
        ingredients: parts.ingredients,
        ingredientTags: parts.ingredientTags,
        recipeTags: parts.recipeTags,
        recipes: parts.recipes,
      ).withCanonicalIngredientNames(),
    );
  }

  static Records? _readRecords(YamlMap root, List<ValidationIssue> issues) {
    final parts = readShelfParts(root);
    issues.addAll(parts.issues);
    if (issues.isNotEmpty) return null;
    issues.addAll(validateShelf(bars: parts.bars, openId: parts.openId));
    return issues.isEmpty ? (bars: parts.bars, openId: parts.openId) : null;
  }

  static SourcedIssue _sourced(YamlNode root, ValidationIssue issue) =>
      SourcedIssue(issue, lineOfPath(root, issue.path));

  /// The step-2 gate: on any [gateIssue] nothing else runs (FR-DAT-4). Format 1
  /// passes and is written back as 2, so there is one reader of the old form
  /// rather than two (ADR 21).
  static ValidationIssue? _formatGateIssue(YamlMap root) {
    final node = root.nodes['format'];
    if (node == null) {
      return _gateIssue(
        'Missing format version; this app reads "format: $formatVersion"',
      );
    }
    final value = node.value;
    if (value is! int) {
      return _gateIssue('format must be an integer: ${briefValue(value)}');
    }
    if (value < oldestReadableFormat || value > formatVersion) {
      return _gateIssue(
        'Unsupported format version $value; this app reads format '
        '$oldestReadableFormat to $formatVersion',
      );
    }
    return null;
  }

  static ValidationIssue _gateIssue(String message) => ValidationIssue(
    const ['format'],
    ValidationIssueKind.unsupportedFormat,
    message,
  );
}
