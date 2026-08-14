/// Read-only over the shelf (docs/components.md#state-contracts).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shelf_controller.dart';

/// The open bar's collection: derived, not owned, and plainly a collection.
final collectionProvider = Provider<Collection>(
  (ref) => ref.watch(shelfProvider).requireValue.collection,
);

/// The record beside it: name, mode, reading unit, source, last refresh.
final openBarProvider = Provider<Bar?>(
  (ref) => ref.watch(shelfProvider).valueOrNull?.open,
);

/// Every bar the device holds, records only (ADR 20).
final barsProvider = Provider<List<Bar>>(
  (ref) => ref.watch(shelfProvider).valueOrNull?.bars ?? const [],
);

/// By recipe name, recomputed whole per change (under a millisecond at NFR-2).
final availabilityProvider = Provider<Map<String, Availability>>((ref) {
  final collection = ref.watch(collectionProvider);
  return {
    for (final recipe in collection.recipes)
      recipe.name: availabilityOf(collection, recipe),
  };
});

/// What to buy next, searched once at the largest budget (FR-DIS-6, ADR 15),
/// keyed on what counts as short (ADR 16); autoDispose, so the one costly
/// computation stops with the screen that asked for it.
final purchasesProvider = Provider.autoDispose.family<List<Purchase>, bool>(
  (ref, restocking) => purchasesWithin(
    ref.watch(collectionProvider),
    budgets.last,
    restocking: restocking,
  ),
);
