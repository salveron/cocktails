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

/// A parsed line, or the problem preventing one — never throws.
typedef ParsedLine = ({RecipeLine? line, String? problem});

/// The single grammar implementation; [parseRecipeLine] is built on it.
ParsedLine tryParseRecipeLine(String text) {
  final trimmed = text.trim();
  final isOptional = trimmed.endsWith(optionalSuffix);
  final body = isOptional
      ? trimmed.substring(0, trimmed.length - optionalSuffix.length).trimRight()
      : trimmed;
  final match = _linePattern.firstMatch(body);
  if (match == null) {
    return (
      line: null,
      problem: 'Expected "<amount> <unit> <ingredient>": "$trimmed"',
    );
  }
  final amount = _tryParseAmount(match[1]!);
  if (amount == null) {
    return (line: null, problem: 'Invalid amount: "${match[1]}"');
  }
  final unit = Unit.fromToken(match[2]!);
  if (unit == null) {
    return (line: null, problem: 'Unknown unit: "${match[2]}"');
  }
  return (
    line: RecipeLine(amount, unit, match[3]!, isOptional: isOptional),
    problem: null,
  );
}

/// Throws a [FormatException] naming the offending part when [line] does
/// not match the grammar.
RecipeLine parseRecipeLine(String line) {
  final parsed = tryParseRecipeLine(line);
  final result = parsed.line;
  if (result == null) {
    throw FormatException(parsed.problem!);
  }
  return result;
}

/// Canonical form: single spaces, the [formatAmount] amount text.
String formatRecipeLine(RecipeLine line) {
  final suffix = line.isOptional ? optionalSuffix : '';
  return '${formatAmount(line.amount)} ${line.unit.token} '
      '${line.ingredient}$suffix';
}

/// Canonical amount text: whole numbers without a trailing `.0`, ranges as
/// `a-b` with equal ends collapsed to the single value.
String formatAmount(Amount amount) => amount.isRange
    ? '${_formatNumber(amount.min)}-${_formatNumber(amount.max)}'
    : _formatNumber(amount.min);

Amount? _tryParseAmount(String text) {
  final match = _amountPattern.firstMatch(text);
  if (match == null) {
    return null;
  }
  final min = double.parse(match[1]!);
  final max = match[2];
  return max == null ? Amount(min) : Amount.range(min, double.parse(max));
}

String _formatNumber(double value) => value == value.truncateToDouble()
    ? value.truncate().toString()
    : value.toString();
