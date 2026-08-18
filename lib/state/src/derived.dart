/// Read-only over the shelf (docs/components.md#state-contracts).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shelf_controller.dart';

/// The open bar's collection: derived, not owned, and plainly a collection.
final collectionProvider = Provider<Collection>(
  (ref) => ref.watch(shelfProvider).requireValue.collection,
);

/// Each vocabulary, sorted (ADR-08) — every screen reading it shares the one
/// sort, computed once per collection change rather than once per build.
final recipeTagsProvider = Provider<List<Tag>>(
  (ref) => _sortedByName(ref.watch(collectionProvider).recipeTags),
);

final ingredientTagsProvider = Provider<List<Tag>>(
  (ref) => _sortedByName(ref.watch(collectionProvider).ingredientTags),
);

List<Tag> _sortedByName(List<Tag> tags) =>
    [...tags]..sort((a, b) => compareNames(a.name, b.name));

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

/// How the open bar's optimizer is asked (FR-SET-2), and the defaults where
/// none is open.
final shoppingProvider = Provider<Shopping>(
  (ref) => ref.watch(openBarProvider)?.shopping ?? const Shopping(),
);

/// What a screen asks beyond the collection and its settings: the reading of
/// short (ADR 16), and the tags the search is aimed at (ADR 24) — empty while
/// the chips sift, so a pick re-keys nothing there and the one costly search
/// stands. A value rather than a record, which holding a list would compare by
/// identity: two equal asks would be two searches. Sorted for the same reason.
final class ShoppingAsk {
  final bool restocking;
  final List<String> aimedAt;

  ShoppingAsk({required this.restocking, Iterable<String> aimedAt = const []})
    : aimedAt = List.unmodifiable([...aimedAt]..sort());

  @override
  bool operator ==(Object other) =>
      other is ShoppingAsk &&
      other.restocking == restocking &&
      listEquals(other.aimedAt, aimedAt);

  @override
  int get hashCode => Object.hash(restocking, Object.hashAll(aimedAt));
}

/// What to buy next, searched once at the largest budget (FR-DIS-6, ADR 15);
/// autoDispose, so the one costly computation stops with the screen that asked
/// for it.
final purchasesProvider = Provider.autoDispose
    .family<List<Purchase>, ShoppingAsk>((ref, ask) {
      final collection = ref.watch(collectionProvider);
      final shopping = ref.watch(shoppingProvider);
      return purchasesWithin(
        collection,
        budgets.last,
        most: shopping.most,
        restocking: ask.restocking,
        buyingOptional: shopping.buyingOptional,
        scoring: ask.aimedAt.isEmpty
            ? null
            : recipesWearing(collection, ask.aimedAt),
      );
    });
