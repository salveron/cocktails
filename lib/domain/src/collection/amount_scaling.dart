/// Display transforms: scaling (FR-REC-7) and part→ml conversion (FR-SET-1).
library;

import 'amount.dart';
import 'recipe_line.dart';
import 'unit.dart';
import 'unit_sizes.dart';

/// The factors a recipe view offers (FR-REC-7), the first as written.
const scaleFactors = [1, 2, 3, 4];

/// [line]'s measure at [scale], read in [display] — the reader's pick, standing
/// beside the sizes because the two are the owner's (ADR 21). A fixed
/// unit converts, everything else reads as entered (ADR 17), and the measure is
/// all that transforms (docs/ui-design.md#recipes-screen).
String scaledAmountText(
  RecipeLine line,
  UnitSizes unitSizes,
  FixedUnit display,
  List<Unit> units, {
  int scale = 1,
}) {
  final from = FixedUnit.named(line.unit);
  final converts = from != null && from != display;
  final factor = converts
      ? scale * unitSizes.ratio(from, display)
      : scale.toDouble();
  return amountText(
    _scaled(line.amount, factor),
    converts ? display.token : line.unit,
    units,
  );
}

/// Rounds to 2 decimals to avoid binary float artifacts in display.
Amount _scaled(Amount amount, double factor) =>
    Amount.range(_round(amount.min * factor), _round(amount.max * factor));

double _round(double value) => (value * 100).roundToDouble() / 100;
