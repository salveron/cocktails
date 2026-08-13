/// The one writable provider: the startup load, the bar on show, and the file
/// seam either way (docs/components.md#state-contracts).
library;

import 'package:cocktails/data/data.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bar_writer.dart';
import 'seams.dart';

/// The root, and the only thing that writes: `ui/` reads through the derived
/// providers and mutates through `barWriterProvider` (ADR 23).
final shelfProvider = AsyncNotifierProvider<ShelfController, Shelf>(
  ShelfController.new,
);

final class ShelfController extends AsyncNotifier<Shelf> {
  List<String> _startupIssues = const [];

  List<String> get startupIssues => _startupIssues;

  /// Reads the index and opens the bar it names, founding one where the device
  /// holds none and falling back to a backup where it will not decode
  /// (FR-DAT-4).
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
    // An index naming no bar, or naming one it does not hold, still opens on
    // whatever it does hold; only a shelf with nothing on it founds a bar.
    final bars = records?.bars ?? const <Bar>[];
    if (bars.isEmpty) return _foundFirstBar(store, issues);
    final open = bars.firstWhere(
      (bar) => bar.id == records!.openId,
      orElse: () => bars.first,
    );
    final loaded = await store.loadBar(open.id);
    if (loaded is Corrupt<BarPayload>) issues.addAll(_described(loaded.issues));
    _startupIssues = List.unmodifiable(issues);
    return Shelf(
      bars: bars,
      openId: open.id,
      collection: switch (loaded) {
        Loaded(:final value) => value.collection,
        Empty() => Collection(),
        Corrupt(:final recovered) => recovered?.collection ?? Collection(),
      },
    );
  }

  /// A device holding nothing gets one empty owned bar, written before it is
  /// published so a first edit has a file to land beside.
  Future<Shelf> _foundFirstBar(BarStore store, List<String> issues) async {
    final bar = Bar(id: newBarId(), name: 'Home bar', mode: BarMode.owner);
    _startupIssues = List.unmodifiable(issues);
    // The bar before the index, as the migration does: the index is what says
    // a bar exists, so it is written once the file it names is there.
    await store.saveBar(bar, Collection());
    await store.saveShelf((bars: [bar], openId: bar.id));
    return Shelf(bars: [bar], openId: bar.id);
  }

  /// The unit amounts read in: on the controller, not the writer, being the
  /// reader's on a guest bar too (FR-BAR-3, FR-SET-1, ADR 21).
  Future<void> setDisplay(FixedUnit display) async {
    final shelf = await future;
    final bar = shelf.open;
    if (bar == null || bar.display == display) return;
    await _publish(shelf.withBar(bar.copyWith(display: display)));
  }

  /// A shareable copy and where it went, opaque so the screen hands it on
  /// unread (FR-DAT-1). A guest bar exports like any other (FR-BAR-4).
  Future<String> export() async {
    final shelf = await future;
    return ref
        .read(barStoreProvider)
        .exportSnapshot(shelf.open!, shelf.collection);
  }

  /// What [text] holds, judged before anything is touched — the confirmation
  /// and the copy [replaceOpen] keeps both slot in between (FR-DAT-3/4).
  ImportReview review(String text) => switch (const YamlCodec().decode(text)) {
    Decoded(:final value) => (bar: value, issues: const <String>[]),
    Rejected(:final issues) => (bar: null, issues: _described(issues)),
  };

  /// Replaces the open bar with a picked file, copying what stood first
  /// (FR-DAT-3). Owned bars only, by that requirement's own wording — the same
  /// file is *added* as a guest bar instead (FR-BAR-7).
  Future<void> replaceOpen(BarPayload payload) async {
    // Awaited first: the bar is only known once the load has answered, and the
    // copy must be of what stood rather than of nothing.
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
          .withCollection(payload.collection),
    );
  }

  /// FR-DAT-4's issues as a reader meets them, whenever they arose.
  static List<String> _described(List<SourcedIssue> issues) =>
      List.unmodifiable([for (final issue in issues) issue.description]);

  /// Publish, then persist only what moved: a stock tap rewrites one bar's file
  /// and a unit pick only the index, neither rotating the other's backups.
  Future<void> _publish(Shelf edited) async {
    final standing = state.valueOrNull;
    if (edited == standing) return;
    state = AsyncData(edited);
    final store = ref.read(barStoreProvider);
    if (standing == null || edited.collection != standing.collection) {
      await store.saveBar(edited.open!, edited.collection);
    }
    if (standing == null ||
        edited.openId != standing.openId ||
        !listEquals(edited.bars, standing.bars)) {
      await store.saveShelf((bars: edited.bars, openId: edited.openId));
    }
  }

  /// The one route a collection edit takes, reached through [BarWriter].
  Future<void> editCollection(Collection Function(Collection) edit) async {
    final shelf = await future;
    final edited = edit(shelf.collection);
    if (edited == shelf.collection) return;
    // withCollection throws on a guest bar: ADR 23's last line of defence.
    await _publish(shelf.withCollection(edited));
  }
}
