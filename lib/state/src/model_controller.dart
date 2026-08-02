/// The writable provider: startup load, mutations, and saves.
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Store seam: file in prod, memory in tests.
final modelStoreProvider = Provider<ModelStore>(
  (ref) => throw UnimplementedError('modelStoreProvider must be overridden'),
);

/// Clock provider for FR-REC-6; testable for fixed dates.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final modelProvider = AsyncNotifierProvider<ModelController, Model>(
  ModelController.new,
);

/// Startup load errors; empty when successful (FR-DAT-4).
final startupIssuesProvider = Provider<List<String>>((ref) {
  ref.watch(modelProvider);
  return ref.watch(modelProvider.notifier).startupIssues;
});

final class ModelController extends AsyncNotifier<Model> {
  List<String> _startupIssues = const [];

  List<String> get startupIssues => _startupIssues;

  /// Corrupt store recovers from newest backup or defaults to empty (FR-DAT-4).
  @override
  Future<Model> build() async {
    final outcome = await ref.watch(modelStoreProvider).load();
    final (model, issues) = switch (outcome) {
      Loaded(:final model) => (model, const <String>[]),
      Empty() => (Model(), const <String>[]),
      Corrupt(:final issues, :final recoveredFromBackup) => (
        recoveredFromBackup ?? Model(),
        List<String>.unmodifiable([
          for (final issue in issues) issue.description,
        ]),
      ),
    };
    _startupIssues = issues;
    return model;
  }

  Future<void> setSettings(Settings settings) =>
      _edit((model) => model.withSettings(settings));

  /// Units vocabulary whole; renames reach measured lines in one edit (FR-VOC-5).
  Future<void> setUnits(List<UnitEdit> units) =>
      _edit((model) => model.withUnits(units));

  /// Adds/replaces ingredient; every line that named it follows (FR-VOC-1).
  Future<void> upsertIngredient(Ingredient ingredient, {String? replacing}) =>
      _edit((model) => model.withIngredient(ingredient, replacing: replacing));

  Future<void> removeIngredient(String name) =>
      _edit((model) => model.withoutIngredient(name));

  Future<void> setStock(String ingredient, StockLevel stock) =>
      _edit((model) => model.withStock(ingredient, stock));

  /// Upserts tag; [replacing] renames first so all wearers follow.
  Future<void> upsertTag(TagKind kind, Tag tag, {String? replacing}) =>
      _edit((model) {
        final renamed = replacing == null || replacing == tag.name
            ? model
            : model.withTagRenamed(kind, replacing, tag.name);
        return renamed.withTag(kind, tag);
      });

  Future<void> removeTag(TagKind kind, String name) =>
      _edit((model) => model.withoutTag(kind, name));

  /// Adds/replaces recipe; auto-creates missing ingredients; lines canonicalize (ADR-08, ADR-10).
  Future<void> upsertRecipe(
    Recipe recipe, {
    List<Ingredient> addingIngredients = const [],
    String? replacing,
  }) => _edit((model) {
    var edited = model;
    for (final ingredient in addingIngredients) {
      edited = edited.withIngredient(ingredient);
    }
    if (replacing != null && replacing != recipe.name) {
      edited = edited.withoutRecipe(replacing);
    }
    return edited.withRecipe(recipe).withCanonicalIngredientNames();
  });

  Future<void> removeRecipe(String name) =>
      _edit((model) => model.withoutRecipe(name));

  Future<void> markMade(String name) =>
      _edit((model) => model.withRecipeMade(name, ref.read(clockProvider)()));

  /// Restores or clears recipe history.
  Future<void> setMade(String name, MadeHistory? made) =>
      _edit((model) => model.withRecipeHistory(name, made));

  /// Edit route: derive, publish, persist; waits for startup; no-op if unchanged (FR-DAT-4).
  Future<void> _edit(Model Function(Model) edit) async {
    final model = await future;
    final edited = edit(model);
    if (edited == model) return;
    state = AsyncData(edited);
    await ref.read(modelStoreProvider).save(edited);
  }
}
