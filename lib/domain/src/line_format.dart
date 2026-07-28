/// Parser and canonical formatter for the compact recipe-line grammar in
/// docs/architecture.md: `<amount> <unit> <ingredient name>`, optionally
/// suffixed with one mark. Enforces syntax only — value rules (positive
/// amounts, ordered range ends) live in validation.dart.
library;

import 'model.dart';

/// The mark suffixes — ` (base)`, ` (optional)` — reserved so that ingredient
/// names cannot end with one.
final reservedSuffixes = List<String>.unmodifiable([
  for (final mark in LineMark.values) _suffix(mark),
]);

String _suffix(LineMark mark) => ' (${mark.token})';

final _linePattern = RegExp(r'^(\S+)\s+(\S+)\s+(\S.*)$');
final _amountPattern = RegExp(r'^(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?$');

/// A parsed line, or the problem preventing one — never throws.
typedef ParsedLine = ({RecipeLine? line, String? problem});

/// The single grammar implementation; [parseRecipeLine] is built on it.
ParsedLine tryParseRecipeLine(String text) {
  final trimmed = text.trim();
  final mark = _markOf(trimmed);
  final body = mark == null
      ? trimmed
      : trimmed.substring(0, trimmed.length - _suffix(mark).length).trimRight();
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
  return (line: RecipeLine(amount, unit, match[3]!, mark: mark), problem: null);
}

/// The mark [trimmed] ends with, if any. Only the last suffix counts: a second
/// one is part of the ingredient name, where the reserved-suffix rule sees it.
LineMark? _markOf(String trimmed) {
  for (final mark in LineMark.values) {
    if (trimmed.endsWith(_suffix(mark))) return mark;
  }
  return null;
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
  final mark = line.mark;
  return '${formatAmount(line.amount)} ${line.unit.token} '
      '${line.ingredient}${mark == null ? '' : _suffix(mark)}';
}

/// Canonical amount text: whole numbers without a trailing `.0`, ranges as
/// `a-b` with equal ends collapsed to the single value.
String formatAmount(Amount amount) => amount.isRange
    ? '${formatNumber(amount.min)}-${formatNumber(amount.max)}'
    : formatNumber(amount.min);

/// Canonical number text of the data format — whole values without `.0` —
/// shared with the YAML emitter (`part_ml`).
String formatNumber(double value) => value == value.truncateToDouble()
    ? value.truncate().toString()
    : value.toString();

Amount? _tryParseAmount(String text) {
  final match = _amountPattern.firstMatch(text);
  if (match == null) {
    return null;
  }
  final min = double.parse(match[1]!);
  final max = match[2];
  return max == null ? Amount(min) : Amount.range(min, double.parse(max));
}
