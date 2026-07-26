/// Parser and canonical formatter for the compact recipe-line grammar in
/// docs/architecture.md: `<amount> <unit> <ingredient name>`, optionally
/// suffixed ` (optional)`. Enforces syntax only — value rules (positive
/// amounts, ordered range ends) live in validation.dart.
library;

import 'model.dart';

/// Reserved suffix marking a line optional; ingredient names cannot end
/// with it.
const optionalSuffix = ' (optional)';

final _linePattern = RegExp(r'^(\S+)\s+(\S+)\s+(\S.*)$');
final _amountPattern = RegExp(r'^(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?$');

/// Throws a [FormatException] naming the offending part when [line] does
/// not match the grammar.
RecipeLine parseRecipeLine(String line) {
  final trimmed = line.trim();
  final isOptional = trimmed.endsWith(optionalSuffix);
  final text = isOptional
      ? trimmed.substring(0, trimmed.length - optionalSuffix.length).trimRight()
      : trimmed;
  final match = _linePattern.firstMatch(text);
  if (match == null) {
    throw FormatException(
      'Expected "<amount> <unit> <ingredient>": "$trimmed"',
    );
  }
  return RecipeLine(
    _parseAmount(match[1]!),
    _parseUnit(match[2]!),
    match[3]!,
    isOptional: isOptional,
  );
}

/// Canonical form: single spaces, the [formatAmount] amount text.
String formatRecipeLine(RecipeLine line) {
  final suffix = line.isOptional ? optionalSuffix : '';
  return '${formatAmount(line.amount)} ${line.unit.name} '
      '${line.ingredient}$suffix';
}

/// Canonical amount text: whole numbers without a trailing `.0`, ranges as
/// `a-b` with equal ends collapsed to the single value.
String formatAmount(Amount amount) => amount.isRange
    ? '${_formatNumber(amount.min)}-${_formatNumber(amount.max)}'
    : _formatNumber(amount.min);

Amount _parseAmount(String text) {
  final match = _amountPattern.firstMatch(text);
  if (match == null) {
    throw FormatException('Invalid amount: "$text"');
  }
  final min = double.parse(match[1]!);
  final max = match[2];
  return max == null ? Amount(min) : Amount.range(min, double.parse(max));
}

Unit _parseUnit(String text) {
  for (final unit in Unit.values) {
    if (unit.name == text) {
      return unit;
    }
  }
  throw FormatException('Unknown unit: "$text"');
}

String _formatNumber(double value) => value == value.truncateToDouble()
    ? value.truncate().toString()
    : value.toString();
