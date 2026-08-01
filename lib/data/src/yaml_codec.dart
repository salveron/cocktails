/// Decode/encode between store text and [Model], with the format-version
/// gate — the pipeline of docs/components.md#data-contracts. Shape issues
/// reject before value validation runs, so a broken section never cascades
/// into spurious reference errors.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:yaml/yaml.dart';

import 'sourced_issue.dart';
import 'yaml_reader.dart';
import 'yaml_writer.dart';

sealed class DecodeResult {}

final class Decoded extends DecodeResult {
  final Model model;

  Decoded(this.model);
}

final class Rejected extends DecodeResult {
  final List<SourcedIssue> issues;

  Rejected(List<SourcedIssue> issues) : issues = List.unmodifiable(issues);
}

final class YamlCodec {
  static const int formatVersion = storeFormatVersion;

  const YamlCodec();

  /// Canonical text: fixed key order, fixed indent, no comments.
  String encode(Model model) => encodeModel(model);

  /// Never throws — every failure is a [Rejected] carrying sourced issues.
  DecodeResult decode(String yaml) {
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
            'The top level must be a mapping with format, settings, units, '
            'ingredients, ingredient_tags, recipe_tags, recipes',
          ),
        ),
      ]);
    }
    final gateIssue = _formatGateIssue(root);
    if (gateIssue != null) {
      return Rejected([_sourced(root, gateIssue)]);
    }
    final parts = readModelParts(root);
    final issues = parts.issues.isNotEmpty
        ? parts.issues
        : validateModel(
            settings: parts.settings,
            units: parts.units,
            ingredients: parts.ingredients,
            ingredientTags: parts.ingredientTags,
            recipeTags: parts.recipeTags,
            recipes: parts.recipes,
          );
    if (issues.isNotEmpty) {
      return Rejected([for (final issue in issues) _sourced(root, issue)]);
    }
    return Decoded(
      Model(
        settings: parts.settings,
        units: parts.units,
        ingredients: parts.ingredients,
        ingredientTags: parts.ingredientTags,
        recipeTags: parts.recipeTags,
        recipes: parts.recipes,
      ),
    );
  }

  static SourcedIssue _sourced(YamlNode root, ValidationIssue issue) =>
      SourcedIssue(issue, lineOfPath(root, issue.path));

  /// The step-2 gate: on any [gateIssue] nothing else runs (FR-DAT-4).
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
    if (value != formatVersion) {
      return _gateIssue(
        'Unsupported format version $value; this app reads format '
        '$formatVersion',
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
