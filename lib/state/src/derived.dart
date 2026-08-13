/// The read-only providers over the collection (docs/components.md).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shelf_controller.dart';

/// The open bar's collection: derived, not owned, which is what keeps every
/// screen reading the shape it always did.
final collectionProvider = Provider<AsyncValue<Collection>>(
  (ref) => ref.watch(shelfProvider).whenData((shelf) => shelf.collection),
);

/// The record beside it: name, mode, reading unit, source, last refresh.
final openBarProvider = Provider<Bar?>(
  (ref) => ref.watch(shelfProvider).valueOrNull?.open,
);

/// Every bar the device holds, records only (ADR 20).
final barsProvider = Provider<List<Bar>>(
  (ref) => ref.watch(shelfProvider).valueOrNull?.bars ?? const [],
);

/// What the last load — startup or crossing — turned up (FR-DAT-4).
final loadIssuesProvider = Provider<List<String>>((ref) {
  ref.watch(shelfProvider);
  return ref.watch(shelfProvider.notifier).loadIssues;
});

/// By recipe name, recomputed whole per change (under a millisecond at NFR-2).
final availabilityProvider = Provider<Map<String, Availability>>((ref) {
  final collection = ref.watch(collectionProvider).valueOrNull;
  return {
    if (collection != null)
      for (final recipe in collection.recipes)
        recipe.name: availabilityOf(collection, recipe),
  };
});

/// What to buy next, searched once at the largest budget (FR-DIS-6, ADR 15),
/// keyed on what counts as short (ADR 16); autoDispose, so the one costly
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
