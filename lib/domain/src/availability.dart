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
    switch (stockOfLine(model, line)) {
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

/// Can make it now (FR-DIS-5): low still counts, and unjudged reads as missing.
bool canMake(Availability? availability) =>
    availability != null && availability != Availability.missing;

/// What a line stands at: its best-stocked alternative, any one of them making
/// it (ADR-11). Order runs best to worst, and folding from the worst leaves a
/// line naming nothing out rather than crashing the pass over every recipe.
StockLevel stockOfLine(Model model, RecipeLine line) =>
    line.ingredients.fold(StockLevel.out, (best, ingredient) {
      final stock = stockOf(model, ingredient);
      return stock.index < best.index ? stock : best;
    });

/// Stock of name outside vocabulary; used mid-edit only.
StockLevel stockOf(Model model, String ingredient) =>
    model.ingredientNamed(ingredient)?.stock ?? StockLevel.out;
