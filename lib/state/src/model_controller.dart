/// The one writable provider — startup load, every mutation, and the save
/// that follows it (docs/components.md#state-contracts).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden with the file store at the composition root and with the memory
/// store in tests — the seam that keeps state and widget tests device-free.
final modelStoreProvider = Provider<ModelStore>(
  (ref) => throw UnimplementedError('modelStoreProvider must be overridden'),
);

/// The clock behind FR-REC-6, a provider so a test can stamp a fixed date.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final modelProvider = AsyncNotifierProvider<ModelController, Model>(
  ModelController.new,
);

/// What the startup load could not read, ready to display; empty when the
/// store was healthy (FR-DAT-4).
final startupIssuesProvider = Provider<List<String>>((ref) {
  ref.watch(modelProvider);
  return ref.watch(modelProvider.notifier).startupIssues;
});

final class ModelController extends AsyncNotifier<Model> {
  List<String> _startupIssues = const [];

  List<String> get startupIssues => _startupIssues;

  /// A corrupt store starts on the newest backup that decoded, or on an empty
  /// model when none did — with its issues readable either way (FR-DAT-4).
  @override
  Future<Model> build() async {
    final outcome = await ref.watch(modelStoreProvider).load();
    final (model, issues) = switch (outcome) {
      Loaded(:final model) => (model, const <String>[]),
      Empty() => (Model(), const <String>[]),
      Corrupt(:final issues, :final recoveredFromBackup) => (
        recoveredFromBackup ?? Model(),
        List<String>.unmodifiable(issues.map(_describe)),
      ),
    };
    _startupIssues = issues;
    return model;
  }

  Future<void> setSettings(Settings settings) =>
      _edit((model) => model.withSettings(settings));

  Future<void> upsertIngredient(Ingredient ingredient) =>
      _edit((model) => model.withIngredient(ingredient));

  Future<void> renameIngredient(String from, String to) =>
      _edit((model) => model.withIngredientRenamed(from, to));

  Future<void> removeIngredient(String name) =>
      _edit((model) => model.withoutIngredient(name));

  Future<void> setStock(String ingredient, StockLevel stock) =>
      _edit((model) => model.withStock(ingredient, stock));

  Future<void> upsertTag(Tag tag) => _edit((model) => model.withTag(tag));

  Future<void> renameTag(String from, String to) =>
      _edit((model) => model.withTagRenamed(from, to));

  Future<void> removeTag(String name) =>
      _edit((model) => model.withoutTag(name));

  Future<void> upsertRecipe(Recipe recipe) =>
      _edit((model) => model.withRecipe(recipe));

  Future<void> removeRecipe(String name) =>
      _edit((model) => model.withoutRecipe(name));

  Future<void> markMade(String name) =>
      _edit((model) => model.withRecipeMade(name, ref.read(clockProvider)()));

  /// The one route from an edit to the disk: derive, publish, persist. It
  /// waits for the startup load, so an edit made while the app is still
  /// starting lands on the loaded model instead of replacing it. An edit that
  /// changes nothing is not saved — that write would only push a good backup
  /// out of the rotation.
  Future<void> _edit(Model Function(Model) edit) async {
    final model = await future;
    final edited = edit(model);
    if (edited == model) return;
    state = AsyncData(edited);
    await ref.read(modelStoreProvider).save(edited);
  }
}

/// "what is wrong and where" (FR-DAT-4), worded as the import report words it.
String _describe(SourcedIssue sourced) => sourced.line == null
    ? sourced.issue.message
    : 'line ${sourced.line}: ${sourced.issue.message}';
