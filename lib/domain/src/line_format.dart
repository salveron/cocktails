/// Parser and canonical formatter for the compact recipe-line grammar in
/// docs/architecture.md: `<amount> [unit] <ingredient name>`, optionally
/// suffixed with one mark. Enforces syntax only — value rules (positive
/// amounts, ordered range ends) live in validation.dart. The formatter writes
/// the fullest form, so what the app stores never leans on what it accepts.
library;

import 'model.dart';

/// The mark suffixes — ` (base)`, ` (optional)` — reserved so that ingredient
/// names cannot end with one.
final reservedSuffixes = List<String>.unmodifiable([
  for (final mark in LineMark.values) _suffix(mark),
]);

String _suffix(LineMark mark) => ' (${mark.token})';

final _linePattern = RegExp(r'^(\S+)\s+(\S.*)$');
final _amountPattern = RegExp(r'^(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?$');
final _space = RegExp(r'\s');

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
    return (line: null, problem: _shapeProblem(trimmed));
  }
  final amount = _tryParseAmount(match[1]!);
  if (amount == null) {
    return (line: null, problem: 'Invalid amount: "${match[1]}"');
  }
  final measured = _measure(match[2]!);
  if (measured == null) {
    return (line: null, problem: _shapeProblem(trimmed));
  }
  return (
    line: RecipeLine(amount, measured.unit, measured.ingredient, mark: mark),
    problem: null,
  );
}

String _shapeProblem(String text) =>
    'Expected "<amount> [unit] <ingredient>": "$text"';

/// What [rest] measures and of what. An omitted unit reads as [Unit.part]
/// (FR-REC-2), so "1 gin" is one part of gin — which is also why a word that
/// is no unit joins the name, and a mistyped one surfaces as an unknown
/// ingredient. Null when a unit is all that was written.
({Unit unit, String ingredient})? _measure(String rest) {
  final space = rest.indexOf(_space);
  if (space < 0) {
    return _unitOf(rest) == null ? (unit: Unit.part, ingredient: rest) : null;
  }
  final unit = _unitOf(rest.substring(0, space));
  return unit == null
      ? (unit: Unit.part, ingredient: rest)
      : (unit: unit, ingredient: rest.substring(space).trimLeft());
}

/// The unit [token] names, plural accepted — "2 dashes" is 2 dash. Only the
/// singular is a wire token; the formatter writes nothing else.
Unit? _unitOf(String token) {
  for (final singular in [
    token,
    if (token.endsWith('s')) token.substring(0, token.length - 1),
    if (token.endsWith('es')) token.substring(0, token.length - 2),
  ]) {
    final unit = Unit.fromToken(singular);
    if (unit != null) return unit;
  }
  return null;
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
String formatRecipeLine(RecipeLine line) =>
    '${formatMeasure(line.amount, line.unit)} ${formatLineBody(line)}';

/// The halves a line reads in, split where a display transform stops
/// (scaling.dart): how much of it, and of what.
String formatMeasure(Amount amount, Unit unit) =>
    '${formatAmount(amount)} ${unit.token}';

String formatLineBody(RecipeLine line) {
  final mark = line.mark;
  return '${line.ingredient}${mark == null ? '' : _suffix(mark)}';
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
