/// Display transforms: scaling (FR-REC-7) and part→ml conversion (FR-SET-1).
library;

import 'line_format.dart';
import 'collection.dart';

/// The factors a recipe view offers (FR-REC-7), the first as written.
const scaleFactors = [1, 2, 3, 4];

/// [line]'s measure at [scale]. A line measured in one of the fixed units reads
/// in the one the settings name; everything else reads as entered (ADR 17). The
/// measure is all that transforms — a card writes the body itself, one
/// alternative at a time (docs/ui-design.md#recipes-screen).
String displayMeasure(
  RecipeLine line,
  Settings settings,
  List<Unit> units, {
  int scale = 1,
}) {
  final from = FixedUnit.named(line.unit);
  final converts = from != null && from != settings.display;
  final factor = converts
      ? scale * settings.ratio(from, settings.display)
      : scale.toDouble();
  return formatMeasure(
    _scaled(line.amount, factor),
    converts ? settings.display.token : line.unit,
    units,
  );
}

/// Rounds to 2 decimals to avoid binary float artifacts in display.
Amount _scaled(Amount amount, double factor) =>
    Amount.range(_round(amount.min * factor), _round(amount.max * factor));

double _round(double value) => (value * 100).roundToDouble() / 100;
