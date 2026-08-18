/// Recipe availability from on-hand ingredients; derived on read (FR-DIS-1).
library;

import 'collection.dart';

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

/// Whether [line] counts as short: out always does, restocking widening that
/// to anything under full stock (ADR 16) — [availabilityOf]'s reading too.
bool isShortLine(
  Collection collection,
  RecipeLine line, {
  required bool restocking,
}) {
  final stock = stockOfLine(collection, line);
  return restocking ? stock != StockLevel.in_ : stock == StockLevel.out;
}

/// Can make it now (FR-DIS-5): low still counts, and unjudged reads as missing.
bool canMake(Availability? availability) =>
    availability != null && availability != Availability.missing;

/// What a line stands at: its best-stocked alternative (ADR-11), folded from
/// the worst so a line naming nothing reads out rather than crashing.
StockLevel stockOfLine(Collection collection, RecipeLine line) =>
    line.ingredients.fold(StockLevel.out, (best, ingredient) {
      final stock = stockOf(collection, ingredient);
      return stock.index < best.index ? stock : best;
    });

/// Stock of name outside vocabulary; used mid-edit only.
StockLevel stockOf(Collection collection, String ingredient) =>
    collection.ingredientNamed(ingredient)?.stock ?? StockLevel.out;
