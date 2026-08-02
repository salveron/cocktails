/// Display transforms: scaling (FR-REC-7) and part→ml conversion (FR-SET-1).
library;

import 'helpers.dart';
import 'line_format.dart';
import 'model.dart';

/// The factors a recipe view offers (FR-REC-7), the first as written.
const scaleFactors = [1, 2, 3, 4];

typedef DisplayedLine = ({String measure, String body});

/// [line] at [scale]; anchored to reserved units (ADR-09).
DisplayedLine displayRecipeLine(
  RecipeLine line,
  Settings settings,
  List<Unit> units, {
  int scale = 1,
}) {
  final inMl =
      line.unit.sameName(partUnit) && settings.display == DisplayUnit.ml;
  final factor = inMl ? scale * settings.partMl : scale.toDouble();
  return (
    measure: formatMeasure(
      _scaled(line.amount, factor),
      inMl ? mlUnit : line.unit,
      units,
    ),
    body: formatLineBody(line),
  );
}

/// Rounds to 2 decimals to avoid binary float artifacts in display.
Amount _scaled(Amount amount, double factor) =>
    Amount.range(_round(amount.min * factor), _round(amount.max * factor));

double _round(double value) => (value * 100).roundToDouble() / 100;
