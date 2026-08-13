/// The write surface, held apart from the controller so a guest bar can be
/// given none at all ([ADR 23](../../../docs/adr/23-nothing-writes-a-guest-bar.md)).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shelf_controller.dart';

/// Every collection mutation, or null where the bar on show is not the
/// reader's to write (FR-BAR-3/4). A screen must hold a non-null writer before
/// it can call anything, and the null it may get back is the same fact that
/// hides the control — so "read-only" and "not offered rather than refused"
/// are one check rather than two.
/// Null says "the bar on show is not the reader's to write", never "the load
/// has not answered yet": an edit made during startup lands on the loaded bar
/// as it always has, the writer awaiting the load like every other edit, and
/// the shell draws no control to press until the load answers anyway.
final barWriterProvider = Provider<BarWriter?>((ref) {
  final shelf = ref.watch(shelfProvider);
  if (shelf case AsyncData(:final value)) {
    final open = value.open;
    if (open == null || !open.isOwned) return null;
  }
  return BarWriter(ref.read(shelfProvider.notifier));
});

/// Each mutation is one line over a `CollectionEdits` derivation; the shared
/// path behind them publishes and saves (docs/components.md#state-contracts).
final class BarWriter {
  final ShelfController _controller;

  const BarWriter(this._controller);

  Future<void> setSettings(Settings settings) =>
      _edit((collection) => collection.withSettings(settings));

  /// Units vocabulary whole; renames reach measured lines in one edit (FR-VOC-5).
  Future<void> setUnits(List<UnitEdit> units) =>
      _edit((collection) => collection.withUnits(units));

  /// Adds/replaces ingredient; every line that named it follows (FR-VOC-1).
  Future<void> upsertIngredient(Ingredient ingredient, {String? replacing}) =>
      _edit(
        (collection) =>
            collection.withIngredient(ingredient, replacing: replacing),
      );

  Future<void> removeIngredient(String name) =>
      _edit((collection) => collection.withoutIngredient(name));

  Future<void> setStock(String ingredient, StockLevel stock) =>
      _edit((collection) => collection.withStock(ingredient, stock));

  /// Upserts tag; [replacing] renames first so all wearers follow.
  Future<void> upsertTag(TagKind kind, Tag tag, {String? replacing}) =>
      _edit((collection) {
        final renamed = replacing == null || replacing == tag.name
            ? collection
            : collection.withTagRenamed(kind, replacing, tag.name);
        return renamed.withTag(kind, tag);
      });

  Future<void> removeTag(TagKind kind, String name) =>
      _edit((collection) => collection.withoutTag(kind, name));

  /// Adds/replaces recipe; auto-creates missing ingredients; lines canonicalize (ADR-08, ADR-10).
  Future<void> upsertRecipe(
    Recipe recipe, {
    List<Ingredient> addingIngredients = const [],
    String? replacing,
  }) => _edit((collection) {
    var edited = collection;
    for (final ingredient in addingIngredients) {
      edited = edited.withIngredient(ingredient);
    }
    if (replacing != null && replacing != recipe.name) {
      edited = edited.withoutRecipe(replacing);
    }
    return edited.withRecipe(recipe).withCanonicalIngredientNames();
  });

  Future<void> removeRecipe(String name) =>
      _edit((collection) => collection.withoutRecipe(name));

  Future<void> _edit(Collection Function(Collection) edit) =>
      _controller.editCollection(edit);
}
