/// The read-only providers over the collection (docs/components.md).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model_controller.dart';

/// Availability by recipe name, recomputed whole on every collection change —
/// the pass is under a millisecond at NFR-2 scale. Empty until the load lands.
final availabilityProvider = Provider<Map<String, Availability>>((ref) {
  final collection = ref.watch(collectionProvider).valueOrNull;
  return {
    if (collection != null)
      for (final recipe in collection.recipes)
        recipe.name: availabilityOf(collection, recipe),
  };
});

/// What to buy next, searched once at the largest budget (FR-DIS-6, ADR 15) —
/// keyed on what counts as short (ADR 16), and autoDispose, so the one costly
/// computation stops with the screen that asked for it (docs/components.md).
final purchasesProvider = Provider.autoDispose.family<List<Purchase>, bool>((
  ref,
  restocking,
) {
  final collection = ref.watch(collectionProvider).valueOrNull;
  return collection == null
      ? const []
      : purchasesWithin(collection, budgets.last, restocking: restocking);
});
