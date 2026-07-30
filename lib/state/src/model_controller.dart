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

  /// Adds [ingredient] or replaces the one of its name, [replacing] renamed
  /// first so every recipe line that named it follows (FR-VOC-1).
  Future<void> upsertIngredient(Ingredient ingredient, {String? replacing}) =>
      _edit((model) {
        final renamed = replacing == null || replacing == ingredient.name
            ? model
            : model.withIngredientRenamed(replacing, ingredient.name);
        return renamed.withIngredient(ingredient);
      });

  Future<void> removeIngredient(String name) =>
      _edit((model) => model.withoutIngredient(name));

  Future<void> setStock(String ingredient, StockLevel stock) =>
      _edit((model) => model.withStock(ingredient, stock));

  /// [upsertIngredient] for a tag, in [kind]'s vocabulary: [replacing] renamed
  /// first, so everything wearing it follows.
  Future<void> upsertTag(TagKind kind, Tag tag, {String? replacing}) =>
      _edit((model) {
        final renamed = replacing == null || replacing == tag.name
            ? model
            : model.withTagRenamed(kind, replacing, tag.name);
        return renamed.withTag(kind, tag);
      });

  Future<void> removeTag(TagKind kind, String name) =>
      _edit((model) => model.withoutTag(kind, name));

  /// Adds [recipe] or replaces the one of its name, with whatever the same
  /// action introduced: the [addingIngredients] it named and did not find, and
  /// the [replacing] name a rename leaves behind.
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
    return edited.withRecipe(recipe);
  });

  Future<void> removeRecipe(String name) =>
      _edit((model) => model.withoutRecipe(name));

  Future<void> markMade(String name) =>
      _edit((model) => model.withRecipeMade(name, ref.read(clockProvider)()));

  /// The one route from an edit to the disk: derive, publish, persist. It
  /// waits for the startup load, so an edit made while the app is still
  /// starting lands on the loaded model instead of replacing it. An edit that
  /// changes nothing is not saved — that write would only push a good backup
  /// out of the rotation. Whatever one form or dialog settles arrives here as
  /// one edit, so it spends one save and one backup rotation, never several: a
  /// recipe naming three new bottles must not save itself over its own
  /// history (FR-DAT-4).
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
