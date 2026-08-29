/// What a recipe line stands at, read off the ingredients on hand.
library;

import 'collection.dart';
import 'ingredient.dart';
import 'recipe_line.dart';

/// Whether [line] counts as short: out always does, restocking widening that
/// to anything under full stock (ADR 16) — availabilityOf's reading too.
bool isShortLine(
  Collection collection,
  RecipeLine line, {
  required bool restocking,
}) {
  final stock = stockOfLine(collection, line);
  return restocking ? stock != StockLevel.in_ : stock == StockLevel.out;
}

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
