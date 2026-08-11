/// The writable provider: startup load, mutations, and saves.
library;

import 'dart:convert';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Store seam: file in prod, memory in tests.
final modelStoreProvider = Provider<ModelStore>(
  (ref) => throw UnimplementedError('modelStoreProvider must be overridden'),
);

/// Share seam (ADR 18): hands an exported copy to the system's sheet. The one
/// file naming the package, and what a widget test overrides to read the
/// location [ModelController.export] answered with.
final sharerProvider = Provider<Future<void> Function(String)>(
  (ref) =>
      (location) => SharePlus.instance.share(
        ShareParams(files: [XFile(location, mimeType: _exportMimeType)]),
      ),
);

/// Plain text, not RFC 9512's `application/yaml`: almost nothing on Android
/// declares that type, so the chooser would stand near empty — and the file is
/// text by FR-DAT-2 anyway. Stated, no `.yaml` mapping existing to look up.
const _exportMimeType = 'text/plain';

/// Pick seam (ADR 18), the share's other half: the document the picker answered
/// with, as text — null where the reader picked nothing. No type filter, YAML
/// having no MIME type Android knows: it would grey out the very file the reader
/// came for, so the decode judges what arrives (FR-DAT-4).
final filePickerProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final picked = await openFile();
    return picked == null ? null : pickedText(picked);
  },
);

/// Bytes decoded here, never `XFile.readAsString`, which drops its own
/// `encoding` for the bytes-backed file Android hands over and reads byte per
/// character — turning `Curaçao` into `CuraÃ§ao`. Malformed input throws over
/// substituting U+FFFD, that being the same loss made quieter.
Future<String> pickedText(XFile picked) async =>
    utf8.decode(await picked.readAsBytes());

/// What a picked file turned out to be: the collection it holds, or what
/// stopped it being read (FR-DAT-4). Never both.
typedef ImportReview = ({Collection? collection, List<String> issues});

final collectionProvider = AsyncNotifierProvider<ModelController, Collection>(
  ModelController.new,
);

/// Startup load errors; empty when successful (FR-DAT-4).
final startupIssuesProvider = Provider<List<String>>((ref) {
  ref.watch(collectionProvider);
  return ref.watch(collectionProvider.notifier).startupIssues;
});

final class ModelController extends AsyncNotifier<Collection> {
  List<String> _startupIssues = const [];

  List<String> get startupIssues => _startupIssues;

  /// Corrupt store recovers from newest backup or defaults to empty (FR-DAT-4).
  @override
  Future<Collection> build() async {
    final outcome = await ref.watch(modelStoreProvider).load();
    final (collection, issues) = switch (outcome) {
      Loaded(:final collection) => (collection, const <String>[]),
      Empty() => (Collection(), const <String>[]),
      Corrupt(:final issues, :final recoveredFromBackup) => (
        recoveredFromBackup ?? Collection(),
        _described(issues),
      ),
    };
    _startupIssues = issues;
    return collection;
  }

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

  /// A shareable copy of the collection on screen, and where it went — opaque,
  /// so the screen hands it on rather than reading it (FR-DAT-1).
  Future<String> export() async =>
      ref.read(modelStoreProvider).exportSnapshot(await future);

  /// What [text] holds, judged before anything is touched: the confirmation and
  /// the copy [replaceAll] keeps both slot in between (FR-DAT-3/4).
  ImportReview review(String text) => switch (const YamlCodec().decode(text)) {
    Decoded(:final collection) => (
      collection: collection,
      issues: const <String>[],
    ),
    Rejected(:final issues) => (collection: null, issues: _described(issues)),
  };

  /// Replaces the collection with [collection], keeping a copy of the one it
  /// replaces first (FR-DAT-3).
  Future<void> replaceAll(Collection collection) async {
    await ref
        .read(modelStoreProvider)
        .exportSnapshot(await future, purpose: ExportPurpose.beforeImport);
    await _edit((_) => collection);
  }

  /// FR-DAT-4's issues as a reader meets them — one reading, whether the file
  /// failed at startup or was just picked.
  static List<String> _described(List<SourcedIssue> issues) =>
      List.unmodifiable([for (final issue in issues) issue.description]);

  /// Edit route: derive, publish, persist; waits for startup; no-op if unchanged (FR-DAT-4).
  Future<void> _edit(Collection Function(Collection) edit) async {
    final collection = await future;
    final edited = edit(collection);
    if (edited == collection) return;
    state = AsyncData(edited);
    await ref.read(modelStoreProvider).save(edited);
  }
}
