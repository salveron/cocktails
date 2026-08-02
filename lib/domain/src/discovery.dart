/// Narrowing the recipe list by what a recipe is built on (FR-DIS-4, ADR 12).
library;

import 'helpers.dart';
import 'model.dart';

/// Every bottle a base line of [recipe] names — several, base being a mark on
/// the line (ADR 06) and a line naming more than one (ADR 11); or none at all.
Set<String> basesOf(Recipe recipe) => {
  for (final line in recipe.lines)
    if (line.isBase) ...line.ingredients,
};

/// The spirits the collection narrows by, A→Z: one per bottle, named before it
/// is weighed for repetition, so two spellings of one bottle are one spirit.
List<String> baseSpirits(Model model) {
  final seen = <String>{};
  final named = [
    for (final recipe in model.recipes)
      for (final spirit in basesOf(recipe)) baseSpiritNamed(model, spirit),
  ];
  return [
    for (final spirit in named)
      if (!repeatsName(seen, spirit)) spirit,
  ]..sort((a, b) => nameKey(a).compareTo(nameKey(b)));
}

/// [spirit] under the bottle's own name (ADR 10) — what [baseSpirits] offers.
String baseSpiritNamed(Model model, String spirit) =>
    model.ingredientNamed(spirit)?.name ?? spirit;

/// Whether [recipe] answers to a pick: [spirit], or — where null — no base.
bool marksBase(Recipe recipe, String? spirit) => spirit == null
    ? basesOf(recipe).isEmpty
    : basesOf(recipe).any((base) => base.sameName(spirit));
