/// Display transforms over a recipe's amounts (docs/components.md#computations):
/// the ×N of FR-REC-7 and the part→ml of FR-SET-1, neither ever stored.
library;

import 'line_format.dart';
import 'model.dart';

/// The factors a recipe view offers (FR-REC-7), the first as written.
const scaleFactors = [1, 2, 3, 4];

typedef DisplayedLine = ({String measure, String body});

/// [line] at [scale] under [settings] — at ×1 in parts, exactly what
/// [formatRecipeLine] writes, split where the transform stops.
DisplayedLine displayRecipeLine(
  RecipeLine line,
  Settings settings, {
  int scale = 1,
}) {
  final inMl = line.unit == Unit.part && settings.display == DisplayUnit.ml;
  final factor = inMl ? scale * settings.partMl : scale.toDouble();
  return (
    measure: formatMeasure(
      _scaled(line.amount, factor),
      inMl ? Unit.ml : line.unit,
    ),
    body: formatLineBody(line),
  );
}

/// Multiplying in binary lands a hair off — 0.1 part in ml would read
/// 3.0000000000000004 — so what is shown rounds where no drink can tell.
Amount _scaled(Amount amount, double factor) =>
    Amount.range(_round(amount.min * factor), _round(amount.max * factor));

double _round(double value) => (value * 100).roundToDouble() / 100;
