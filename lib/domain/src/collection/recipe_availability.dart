/// Recipe availability from on-hand ingredients; derived on read (FR-DIS-1).
library;

import 'collection.dart';
import 'ingredient.dart';
import 'ingredient_stock.dart';
import 'recipe.dart';

/// Required lines only; optional never counts (FR-REC-3).
enum Availability { makeable, makeableLow, missing }

/// One missing line is enough; low only downgrades.
Availability availabilityOf(Collection collection, Recipe recipe) {
  var low = false;
  for (final line in recipe.lines) {
    if (line.isOptional) continue;
    if (isShortLine(collection, line, restocking: false)) {
      return Availability.missing;
    }
    if (stockOfLine(collection, line) == StockLevel.low) low = true;
  }
  return low ? Availability.makeableLow : Availability.makeable;
}

/// Can make it now (FR-DIS-5): low still counts, and unjudged reads as missing.
bool canMake(Availability? availability) =>
    availability != null && availability != Availability.missing;
