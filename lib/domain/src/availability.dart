/// What the bottles on hand make of a recipe (FR-DIS-1) — derived on read,
/// never stored (docs/components.md#state-contracts).
library;

import 'model.dart';

/// Over required lines only — an optional line shows, never counts (FR-REC-3).
enum Availability { makeable, makeableLow, missing }

/// One line out is enough to miss; a low line only downgrades.
Availability availabilityOf(Model model, Recipe recipe) {
  var low = false;
  for (final line in recipe.lines) {
    if (line.isOptional) continue;
    switch (stockOf(model, line.ingredient)) {
      case StockLevel.out:
        return Availability.missing;
      case StockLevel.low:
        low = true;
      case StockLevel.in_:
        break;
    }
  }
  return low ? Availability.makeableLow : Availability.makeable;
}

/// The one home for what a name outside the vocabulary reads as. Validation
/// keeps those out of a stored model, so it only ever answers a name mid-edit.
StockLevel stockOf(Model model, String ingredient) =>
    model.ingredientNamed(ingredient)?.stock ?? StockLevel.out;
