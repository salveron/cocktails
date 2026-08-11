/// Narrowing the recipe list by what a recipe is built on (FR-DIS-4, ADR 12),
/// and drawing one of what is left of it (FR-DIS-5).
library;

import 'dart:math';

import 'availability.dart';
import 'names.dart';
import 'collection.dart';

/// Every bottle a base line of [recipe] names — several, base being a mark on
/// the line (ADR 06) and a line naming more than one (ADR 11); or none at all.
Set<String> basesOf(Recipe recipe) => {
  for (final line in recipe.lines)
    if (line.isBase) ...line.ingredients,
};

/// The spirits the collection narrows by, A→Z: one per bottle, named before it
/// is weighed for repetition, so two spellings of one bottle are one spirit.
List<String> baseSpirits(Collection collection) {
  final seen = <String>{};
  final named = [
    for (final recipe in collection.recipes)
      for (final spirit in basesOf(recipe)) collection.bottleNamed(spirit),
  ];
  return [
    for (final spirit in named)
      if (!repeatsName(seen, spirit)) spirit,
  ]..sort(compareNames);
}

/// What a roll lands on (FR-DIS-5): one of [candidates] the bar can make, drawn
/// from [random]. Never [besides] — the one already standing — while another is
/// there, so a second roll always moves. Null where none can be made.
Recipe? randomCanMake(
  Iterable<Recipe> candidates,
  Map<String, Availability> availability,
  Random random, {
  String? besides,
}) {
  final can = [
    for (final recipe in candidates)
      if (canMake(availability[recipe.name])) recipe,
  ];
  final moved = [
    for (final recipe in can)
      if (besides == null || !recipe.name.sameName(besides)) recipe,
  ];
  final drawn = moved.isEmpty ? can : moved;
  return drawn.isEmpty ? null : drawn[random.nextInt(drawn.length)];
}

/// Whether [recipe] answers to a pick: [spirit], or — where null — no base.
bool marksBase(Recipe recipe, String? spirit) => spirit == null
    ? basesOf(recipe).isEmpty
    : basesOf(recipe).any((base) => base.sameName(spirit));
