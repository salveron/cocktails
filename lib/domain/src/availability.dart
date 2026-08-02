/// Recipe availability from on-hand bottles; derived on read (FR-DIS-1).
library;

import 'model.dart';

/// Required lines only; optional never counts (FR-REC-3).
enum Availability { makeable, makeableLow, missing }

/// One missing line is enough; low only downgrades.
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

/// Stock of name outside vocabulary; used mid-edit only.
StockLevel stockOf(Model model, String ingredient) =>
    model.ingredientNamed(ingredient)?.stock ?? StockLevel.out;
