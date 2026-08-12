/// The writable provider: startup load, mutations, and saves.
library;

import 'dart:convert';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Store seam: file in prod, memory in tests.
final barStoreProvider = Provider<BarStore>(
  (ref) => throw UnimplementedError('barStoreProvider must be overridden'),
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

/// What a picked file turned out to be: the bar it holds, or what stopped it
/// being read (FR-DAT-4). Never both.
typedef ImportReview = ({BarPayload? bar, List<String> issues});

final collectionProvider = AsyncNotifierProvider<ModelController, Collection>(
  ModelController.new,
);

/// The record of the bar on show — its name and the unit it reads amounts in
/// (ADR 21). Null only before the first load answers.
final openBarProvider = Provider<Bar?>((ref) {
  ref.watch(collectionProvider);
  return ref.watch(collectionProvider.notifier).openBar;
});

/// Startup load errors; empty when successful (FR-DAT-4).
final startupIssuesProvider = Provider<List<String>>((ref) {
  ref.watch(collectionProvider);
  return ref.watch(collectionProvider.notifier).startupIssues;
});

final class ModelController extends AsyncNotifier<Collection> {
  List<String> _startupIssues = const [];

  List<String> get startupIssues => _startupIssues;

  Bar? _openBar;

  /// The bar this controller's collection belongs to; the shelf around it is
  /// M32's, so what stands here is the one record the screens need.
  Bar? get openBar => _openBar;

  /// The index as it was read, kept so a write of one record carries the rest:
  /// an index rewritten from the open bar alone would drop every other bar.
  Records _records = (bars: const [], openId: null);

  /// Reads the index, opens the bar it names, and seeds an empty owned bar
  /// where the device holds none. A bar that fails to decode opens on its
  /// newest backup and says why (FR-DAT-4).
  @override
  Future<Collection> build() async {
    final store = ref.watch(barStoreProvider);
    final issues = <String>[];
    final shelf = await store.loadShelf();
    if (shelf is Corrupt<Records>) issues.addAll(_described(shelf.issues));
    final records = switch (shelf) {
      Loaded(:final value) => value,
      Empty() => null,
      Corrupt(:final recovered) => recovered,
    };
    // An index naming no bar, or naming one it does not hold, still opens on
    // whatever it does hold; only a shelf with nothing on it founds a bar.
    final bars = records?.bars ?? const <Bar>[];
    if (bars.isEmpty) return _foundFirstBar(store, issues);
    final bar = bars.firstWhere(
      (bar) => bar.id == records!.openId,
      orElse: () => bars.first,
    );
    _openBar = bar;
    _records = (bars: bars, openId: bar.id);
    final loaded = await store.loadBar(bar.id);
    if (loaded is Corrupt<BarPayload>) issues.addAll(_described(loaded.issues));
    _startupIssues = List.unmodifiable(issues);
    return switch (loaded) {
      Loaded(:final value) => value.collection,
      Empty() => Collection(),
      Corrupt(:final recovered) => recovered?.collection ?? Collection(),
    };
  }

  /// A device holding nothing gets one empty owned bar, written before it is
  /// published so a first edit has a file to land beside.
  Future<Collection> _foundFirstBar(BarStore store, List<String> issues) async {
    final bar = Bar(id: newBarId(), name: 'Home bar', mode: BarMode.owner);
    _openBar = bar;
    _records = (bars: [bar], openId: bar.id);
    _startupIssues = List.unmodifiable(issues);
    // The bar before the index, as the migration does: the index is what says
    // a bar exists, so it is written once the file it names is there.
    await store.saveBar(bar, Collection());
    await store.saveShelf(_records);
    return Collection();
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

  /// The unit amounts read in — the reader's, so it lives on the bar's record
  /// and never in the collection a refresh replaces (FR-SET-1, ADR 21).
  Future<void> setDisplay(FixedUnit display) async {
    final bar = _openBar;
    if (bar == null || bar.display == display) return;
    final edited = bar.copyWith(display: display);
    _openBar = edited;
    _records = (
      bars: [
        for (final standing in _records.bars)
          standing.id == edited.id ? edited : standing,
      ],
      openId: _records.openId,
    );
    await ref.read(barStoreProvider).saveShelf(_records);
    ref.notifyListeners();
  }

  /// A shareable copy of the bar on screen, and where it went — opaque, so the
  /// screen hands it on rather than reading it (FR-DAT-1).
  Future<String> export() async {
    final collection = await future;
    return ref.read(barStoreProvider).exportSnapshot(_openBar!, collection);
  }

  /// What [text] holds, judged before anything is touched: the confirmation and
  /// the copy [replaceAll] keeps both slot in between (FR-DAT-3/4).
  ImportReview review(String text) => switch (const YamlCodec().decode(text)) {
    Decoded(:final value) => (bar: value, issues: const <String>[]),
    Rejected(:final issues) => (bar: null, issues: _described(issues)),
  };

  /// Replaces the open bar's collection with [collection], keeping a copy of
  /// what it replaces first (FR-DAT-3).
  Future<void> replaceAll(Collection collection) async {
    // Awaited first: the bar is only known once the startup load has answered,
    // and the copy must be of what stood rather than of nothing.
    final replaced = await future;
    await ref
        .read(barStoreProvider)
        .exportSnapshot(
          _openBar!,
          replaced,
          purpose: ExportPurpose.beforeImport,
        );
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
    await ref.read(barStoreProvider).saveBar(_openBar!, edited);
  }
}
