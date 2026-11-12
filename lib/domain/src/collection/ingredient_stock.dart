library;

import 'collection.dart';
import 'ingredient.dart';
import 'recipe_line.dart';

/// Restocking widens short to anything under full stock (ADR 16).
bool isShortLine(
  Collection collection,
  RecipeLine line, {
  required bool restocking,
}) {
  final stock = stockOfLine(collection, line);
  return restocking ? stock != StockLevel.in_ : stock == StockLevel.out;
}

/// Best-stocked alternative (ADR-11); a line naming nothing reads out.
StockLevel stockOfLine(Collection collection, RecipeLine line) =>
    line.ingredients.fold(StockLevel.out, (best, ingredient) {
      final stock = stockOf(collection, ingredient);
      return stock.index < best.index ? stock : best;
    });

/// Out for a name outside the collection; used mid-edit only.
StockLevel stockOf(Collection collection, String ingredient) =>
    collection.ingredientNamed(ingredient)?.stock ?? StockLevel.out;
