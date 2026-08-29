/// A recipe line: its shape, its grammar, and its canonical text. Both parser
/// and formatter use unit vocabulary to determine the unit/name boundary
/// (ADR-09); value rules live in collection_validation.dart, not here.
library;

import '../names.dart';
import '../tokens.dart';
import 'amount.dart';
import 'unit.dart';

/// A recipe line's mark: base spirit or optional (ADR-06).
/// One field ensures a line cannot be both.
enum LineMark implements Tokened {
  base('base'),
  optional('optional');

  @override
  final String token;
  const LineMark(this.token);

  static LineMark? fromToken(String text) => enumFromToken(values, text);
}

/// What separates a line's alternatives, in the grammar and in the file
/// (ADR-11); barred from ingredient spellings so the split stays unambiguous.
const alternativeSeparator = '/';

/// A line names unit and ingredients by name, resolved against vocabularies
/// (ADR-09). More than one name is a substitution group: any one of them on
/// hand makes the line (ADR-11). Never empty — the grammar is the only maker
/// of lines and it refuses one naming nothing; no assert, since a const
/// constructor cannot evaluate one.
final class RecipeLine {
  final Amount amount;
  final String unit;
  final List<String> ingredients;
  final LineMark? mark;

  const RecipeLine(this.amount, this.unit, this.ingredients, {this.mark});

  bool get isBase => mark == LineMark.base;

  bool get isOptional => mark == LineMark.optional;

  RecipeLine copyWith({
    Amount? amount,
    String? unit,
    List<String>? ingredients,
  }) => RecipeLine(
    amount ?? this.amount,
    unit ?? this.unit,
    ingredients ?? this.ingredients,
    mark: mark,
  );

  /// Only way to change/clear the mark (copyWith uses null for "keep").
  RecipeLine marked(LineMark? mark) =>
      RecipeLine(amount, unit, ingredients, mark: mark);

  @override
  bool operator ==(Object other) =>
      other is RecipeLine &&
      other.amount == amount &&
      other.unit == unit &&
      listEquals(other.ingredients, ingredients) &&
      other.mark == mark;

  @override
  int get hashCode =>
      Object.hash(amount, unit, Object.hashAll(ingredients), mark);

  @override
  String toString() {
    final mark = this.mark;
    return 'RecipeLine($amount $unit ${ingredients.join(' $alternativeSeparator ')}'
        '${mark == null ? '' : ', ${mark.token}'})';
  }
}

/// Reserved mark suffixes; ingredient names cannot end with them.
final reservedSuffixes = List<String>.unmodifiable([
  for (final mark in LineMark.values) lineMarkSuffix(mark),
]);

/// How a mark reads at the end of a line; nothing for an unmarked one. Shared
/// with the cards, which write the body themselves (docs/ui-design.md).
String lineMarkSuffix(LineMark? mark) => mark == null ? '' : ' (${mark.token})';

final _linePattern = RegExp(r'^(\S+)\s+(\S.*)$');
final _amountPattern = RegExp(r'^(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?$');
final _space = RegExp(r'\s');

/// Splits alternatives, spaced or not: "cognac / vodka", "cognac/vodka".
final _separator = RegExp('\\s*${RegExp.escape(alternativeSeparator)}\\s*');

/// Parsed line or error; never throws.
typedef ParsedLine = ({RecipeLine? line, String? problem});

/// The single grammar implementation; [parseRecipeLine] is built on it.
ParsedLine tryParseRecipeLine(String text, List<Unit> units) {
  final trimmed = text.trim();
  final mark = _markOf(trimmed);
  final body = mark == null
      ? trimmed
      : trimmed
            .substring(0, trimmed.length - lineMarkSuffix(mark).length)
            .trimRight();
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
  // The mark came off first, so it governs the group, not one ingredient of it.
  final ingredients = measured.ingredient.split(_separator);
  if (ingredients.any((name) => name.isEmpty)) {
    return (
      line: null,
      problem:
          'Expected an ingredient either side of '
          '"$alternativeSeparator": "$trimmed"',
    );
  }
  return (
    line: RecipeLine(amount, measured.unit, ingredients, mark: mark),
    problem: null,
  );
}

String _shapeProblem(String text) =>
    'Expected "<amount> [unit] <ingredient>": "$text"';

/// [rest]'s unit and ingredient under vocabulary's spelling. Omitted unit is a part (FR-REC-2).
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

/// The mark [trimmed] ends with, if any; only the last one counts.
LineMark? _markOf(String trimmed) {
  for (final mark in LineMark.values) {
    if (trimmed.endsWith(lineMarkSuffix(mark))) return mark;
  }
  return null;
}

/// Throws [FormatException] if [line] doesn't match the grammar.
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
    '${amountText(line.amount, line.unit, units)} ${_formatLineBody(line)}';

/// Line halves split where display transform stops (amount_scaling.dart).
String amountText(Amount amount, String unit, List<Unit> units) =>
    '${formatAmount(amount)} ${units.unitNamed(unit)?.spelling(amount) ?? unit}';

/// Canonical body: alternatives joined by the separator, then the mark. A card
/// writes its own, one alternative at a time, from [lineMarkSuffix] and these
/// same names — the file's separator is not what it reads (ADR-11).
String _formatLineBody(RecipeLine line) =>
    line.ingredients.join(' $alternativeSeparator ') +
    lineMarkSuffix(line.mark);

/// Canonical amount text: integers without `.0`, ranges as `a-b`.
String formatAmount(Amount amount) => amount.isRange
    ? '${formatNumber(amount.min)}-${formatNumber(amount.max)}'
    : formatNumber(amount.min);

/// Canonical number: integers without `.0`, shared with YAML emitter.
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
