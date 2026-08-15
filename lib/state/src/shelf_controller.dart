/// The one writable provider (docs/components.md#state-contracts).
library;

import 'package:cocktails/data/data.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bar_writer.dart';
import 'seams.dart';

/// The root: `ui/` reads through the derived providers and mutates through
/// `barWriterProvider` (ADR 23).
final shelfProvider = AsyncNotifierProvider<ShelfController, Shelf>(
  ShelfController.new,
);

/// What the last load — startup or crossing — turned up (FR-DAT-4). Ordinary
/// state written by the load itself: a field read off the controller would only
/// be right while every write set it before the shelf moved, which is an
/// invariant nothing could enforce.
final loadIssuesProvider = NotifierProvider<LoadIssuesController, List<String>>(
  LoadIssuesController.new,
);

final class LoadIssuesController extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void report(List<String> issues) => state = List.unmodifiable(issues);
}

final class ShelfController extends AsyncNotifier<Shelf> {
  /// Reads the index and opens the bar it names (FR-DAT-4).
  @override
  Future<Shelf> build() async {
    final store = ref.watch(barStoreProvider);
    final issues = <String>[];
    final index = await store.loadShelf();
    if (index is Corrupt<Records>) issues.addAll(_described(index.issues));
    final records = switch (index) {
      Loaded(:final value) => value,
      Empty() => null,
      Corrupt(:final recovered) => recovered,
    };
    // No index at all is a first run and gets a bar; an index listing none is a
    // reader who deleted their last, whom the bar list meets instead (ADR 20).
    if (records == null) return _foundFirstBar(store, issues);
    // One naming no open bar, or naming one it lacks, opens on what it holds.
    final bars = records.bars;
    final open = bars.isEmpty
        ? null
        : bars.firstWhere(
            (bar) => bar.id == records.openId,
            orElse: () => bars.first,
          );
    final collection = open == null
        ? null
        : await _collectionOf(store, open.id, issues);
    _report(issues);
    return _summarising(
      store,
      Shelf(bars: bars, openId: open?.id, collection: collection),
    );
  }

  /// An index written before a bar was ever summarised carries no counts for
  /// it, and the bar list reads counts alone (ADR 20). Each such bar is read
  /// once here, under the startup spinner, and the index is written back
  /// holding what they turned out to be — so this runs once per bar, ever. A
  /// bar that cannot be read keeps its absent summary rather than gaining one
  /// saying it holds nothing.
  Future<Shelf> _summarising(BarStore store, Shelf shelf) async {
    final counted = <Bar>[];
    for (final bar in shelf.bars) {
      if (bar.holds != null) {
        counted.add(bar);
      } else if (bar.id == shelf.openId) {
        counted.add(bar.summarised(shelf.collection));
      } else {
        final collection = await _readableCollectionOf(store, bar.id);
        counted.add(collection == null ? bar : bar.summarised(collection));
      }
    }
    if (listEquals(counted, shelf.bars)) return shelf;
    final summarised = Shelf(
      bars: counted,
      openId: shelf.openId,
      collection: shelf.collection,
    );
    await store.saveShelf((bars: summarised.bars, openId: summarised.openId));
    return summarised;
  }

  /// A bar's contents where they could be read at all, null where the file is
  /// unreadable and no backup decoded. A file that never landed is the empty
  /// collection opening it would give, which is a real answer.
  Future<Collection?> _readableCollectionOf(BarStore store, String id) async =>
      switch (await store.loadBar(id)) {
        Loaded(:final value) => value.collection,
        Empty() => Collection(),
        Corrupt(:final recovered) => recovered?.collection,
      };

  /// A device holding nothing gets one empty owned bar, its file before the
  /// index as [addOwnedBar] and the migration both write one.
  Future<Shelf> _foundFirstBar(BarStore store, List<String> issues) async {
    final bar = _newBar('Home bar', Collection());
    _report(issues);
    await store.saveBar(bar, Collection());
    await store.saveShelf((bars: [bar], openId: bar.id));
    return Shelf(bars: [bar], openId: bar.id);
  }

  /// One bar's contents, or the best recovered from them, what failed reaching
  /// [issues] (FR-DAT-4). The one read of a bar's bytes, startup or crossing.
  Future<Collection> _collectionOf(
    BarStore store,
    String id,
    List<String> issues,
  ) async {
    final loaded = await store.loadBar(id);
    if (loaded is Corrupt<BarPayload>) issues.addAll(_described(loaded.issues));
    return switch (loaded) {
      Loaded(:final value) => value.collection,
      Empty() => Collection(),
      Corrupt(:final recovered) => recovered?.collection ?? Collection(),
    };
  }

  /// The unit amounts read in: on the controller rather than the writer, being
  /// the reader's on a guest bar too (FR-BAR-3, FR-SET-1, ADR 21).
  Future<void> setDisplay(FixedUnit display) async {
    final shelf = await future;
    final bar = shelf.open;
    if (bar == null || bar.display == display) return;
    await _publish(shelf.withBar(bar.copyWith(display: display)));
  }

  /// A shareable copy and where it went, opaque so the screen hands it on
  /// unread (FR-DAT-1, FR-BAR-4).
  Future<String> export() async {
    final shelf = await future;
    return ref
        .read(barStoreProvider)
        .exportSnapshot(shelf.open!, shelf.collection);
  }

  /// What [text] holds, judged before anything is touched (FR-DAT-3/4).
  ImportReview review(String text) => switch (const YamlCodec().decode(text)) {
    Decoded(:final value) => (bar: value, issues: const <String>[]),
    Rejected(:final issues) => (bar: null, issues: _described(issues)),
  };

  /// Replaces the open bar with a picked file, copying what stood first
  /// (FR-DAT-3). Owned bars only — the same file is *added* as a guest bar
  /// instead (FR-BAR-7).
  Future<void> replaceOpen(BarPayload payload) async {
    // Awaited first: the copy must be of what stood rather than of nothing.
    final shelf = await future;
    final bar = shelf.open;
    if (bar == null || !bar.isOwned) return;
    await ref
        .read(barStoreProvider)
        .exportSnapshot(
          bar,
          shelf.collection,
          purpose: ExportPurpose.beforeImport,
        );
    await _publish(
      shelf
          .withBar(bar.copyWith(name: payload.name, display: payload.display))
          .withCollection(payload.collection, _now()),
    );
  }

  /// The switch (FR-BAR-1): the record and the bytes at once (ADR 20).
  Future<void> openBar(String id) async {
    final shelf = await future;
    if (shelf.openId == id || shelf.barWithId(id) == null) return;
    final issues = <String>[];
    final collection = await _collectionOf(
      ref.read(barStoreProvider),
      id,
      issues,
    );
    // The banner reports the load last asked for, so a sound bar clears it.
    _report(issues);
    await _publish(shelf.opening(id, collection));
  }

  /// FR-BAR-2: a new bar, empty, owned and opened on the spot; its file lands
  /// before the index names it.
  Future<void> addOwnedBar(String name) async {
    final shelf = await future;
    final collection = Collection();
    final bar = _newBar(name, collection);
    await ref.read(barStoreProvider).saveBar(bar, collection);
    _report(const []);
    await _publish(shelf.withBar(bar).opening(bar.id, collection));
  }

  /// An owned bar, summarised and stamped from the moment it is founded, so no
  /// bar is ever listed without the counts the list reads it by.
  Bar _newBar(String name, Collection collection) => Bar(
    id: newBarId(),
    name: name,
    mode: BarMode.owner,
  ).summarised(collection, at: _now());

  DateTime _now() => ref.read(clockProvider)();

  /// FR-BAR-2. A guest bar's name is its owner's and arrives with every refresh
  /// (FR-BAR-5), so a rename there would be thrown away by the next one.
  Future<void> renameBar(String id, String name) async {
    final shelf = await future;
    final bar = shelf.barWithId(id);
    if (bar == null || !bar.isOwned || bar.name == name) return;
    await _publish(shelf.withBar(bar.copyWith(name: name)));
  }

  /// FR-BAR-2: the copy first, then the bar. The record goes before the file it
  /// names — storage to reclaim one way round, a bar opening onto nothing the
  /// other. Deleting the bar on show leaves none open.
  Future<void> removeBar(String id) async {
    final shelf = await future;
    final bar = shelf.barWithId(id);
    if (bar == null) return;
    final store = ref.read(barStoreProvider);
    // Only an owned bar is copied: a guest's contents are its owner's, and
    // FR-BAR-3 removes one touching nothing. Any bar but the one on show is
    // read back for it, no other collection being resident (ADR 20).
    if (bar.isOwned) {
      final collection = id == shelf.openId
          ? shelf.collection
          : await _collectionOf(store, id, <String>[]);
      await store.exportSnapshot(
        bar,
        collection,
        purpose: ExportPurpose.beforeDelete,
      );
    }
    await _publish(shelf.withoutBar(id));
    await store.removeBar(id);
  }

  /// FR-DAT-4's issues as a reader meets them, whenever they arose.
  static List<String> _described(List<SourcedIssue> issues) =>
      List.unmodifiable([for (final issue in issues) issue.description]);

  void _report(List<String> issues) =>
      ref.read(loadIssuesProvider.notifier).report(issues);

  /// Publish, then persist only what moved: a stock tap rewrites one bar's file
  /// and a unit pick only the index, neither rotating the other's backups. A
  /// collection is written only where the bar under it stayed put — that is what
  /// tells an edit from a crossing, which brings its collection up from disk and
  /// would rotate the backups of a bar nobody touched.
  Future<void> _publish(Shelf edited) async {
    final standing = state.requireValue;
    if (edited == standing) return;
    state = AsyncData(edited);
    final store = ref.read(barStoreProvider);
    final crossed = edited.openId != standing.openId;
    if (!crossed && edited.collection != standing.collection) {
      await store.saveBar(edited.open!, edited.collection);
    }
    if (crossed || !listEquals(edited.bars, standing.bars)) {
      await store.saveShelf((bars: edited.bars, openId: edited.openId));
    }
  }

  /// The one route a collection edit takes, reached through [BarWriter].
  Future<void> editCollection(Collection Function(Collection) edit) async {
    final shelf = await future;
    final edited = edit(shelf.collection);
    if (edited == shelf.collection) return;
    // withCollection throws on a guest bar: ADR 23's last line of defence.
    await _publish(shelf.withCollection(edited, _now()));
  }
}
