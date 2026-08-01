/// Parser and canonical formatter for the compact recipe-line grammar in
/// docs/architecture.md: `<amount> [unit] <ingredient name>`, optionally
/// suffixed with one mark. Enforces syntax only — value rules live in
/// validation.dart. Both halves take the unit vocabulary (ADR 09), which is
/// what says where a unit ends and a name begins, and how an amount is spelled.
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
ParsedLine tryParseRecipeLine(String text, List<Unit> units) {
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
  final measured = _measure(match[2]!, units);
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

/// What [rest] measures and of what, under the vocabulary's own spelling. An
/// omitted unit is a part (FR-REC-2), which is also why a word that is no unit
/// joins the name and a mistyped one surfaces as an unknown ingredient. Null
/// when a unit is all that was written.
({String unit, String ingredient})? _measure(String rest, List<Unit> units) {
  final space = rest.indexOf(_space);
  if (space < 0) {
    return units.unitNamed(rest) == null
        ? (unit: partUnit, ingredient: rest)
        : null;
  }
  final unit = units.unitNamed(rest.substring(0, space));
  return unit == null
      ? (unit: partUnit, ingredient: rest)
      : (unit: unit.name, ingredient: rest.substring(space).trimLeft());
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
RecipeLine parseRecipeLine(String line, List<Unit> units) {
  final parsed = tryParseRecipeLine(line, units);
  final result = parsed.line;
  if (result == null) {
    throw FormatException(parsed.problem!);
  }
  return result;
}

/// Canonical form: single spaces, the [formatAmount] amount text.
String formatRecipeLine(RecipeLine line, List<Unit> units) =>
    '${formatMeasure(line.amount, line.unit, units)} ${formatLineBody(line)}';

/// The halves a line reads in, split where a display transform stops
/// (scaling.dart). The measure takes the spelling that amount calls for, or the
/// name as written where the vocabulary has lost the unit.
String formatMeasure(Amount amount, String unit, List<Unit> units) =>
    '${formatAmount(amount)} ${units.unitNamed(unit)?.spelling(amount) ?? unit}';

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
