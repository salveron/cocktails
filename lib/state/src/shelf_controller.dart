/// The one writable provider (docs/components.md#state-contracts).
library;

import 'dart:async';

import 'package:cocktails/data/data.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bar_writer.dart';
import 'channels.dart';
import 'refreshes.dart';
import 'seams.dart';
import 'sharing.dart';

/// The root; `ui/` mutates only through `barWriterProvider` (ADR 23).
final shelfProvider = AsyncNotifierProvider<ShelfController, Shelf>(
  ShelfController.new,
);

/// What the last load turned up (FR-DAT-4). Not a controller field: that would
/// need every write to set it before the shelf moved, which nothing enforces.
final loadIssuesProvider = NotifierProvider<LoadIssuesController, List<String>>(
  LoadIssuesController.new,
);

final class LoadIssuesController extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void report(List<String> issues) => state = List.unmodifiable(issues);
}

/// A picked file's outcome (FR-DAT-4): a bar or its issues, never both.
typedef ImportReview = ({BarContent? bar, List<String> issues});

/// What reaching a source turned up (FR-BAR-5/8): a bar to agree to or refuse,
/// or an [UnreachableReason] (never both), its wording left to `ui/` (ADR 22).
typedef Arrival = ({ImportReview? review, UnreachableReason? why});

final class ShelfController extends AsyncNotifier<Shelf> {
  /// Opens the bar the index names (FR-DAT-4).
  @override
  Future<Shelf> build() async {
    final store = ref.watch(barStoreProvider);
    final issues = <String>[];
    final index = await store.loadShelf();
    if (index is Rejected<ShelfIndex>) issues.addAll(_described(index.issues));
    final records = switch (index) {
      Ok(:final value) => value,
      Empty() => null,
      Rejected(:final recovered) => recovered,
      Unreachable() => null,
    };
    // No index: a first run. No bars listed: the last was deleted (ADR 20).
    if (records == null) return _foundFirstBar(store, issues);
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
    final shelf = await _summarising(
      store,
      Shelf(
        bars: [for (final bar in bars) _unshared(bar)],
        openId: open?.id,
        deviceName: records.deviceName,
        collection: collection,
      ),
    );
    return shelf;
  }

  /// Backfills counts missing from older index entries, once per bar (ADR 20).
  /// An unreadable bar keeps no summary, rather than one saying it is empty.
  Future<Shelf> _summarising(BarStore store, Shelf shelf) async {
    final counted = <Bar>[];
    for (final bar in shelf.bars) {
      if (bar.summary != null) {
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
      deviceName: shelf.deviceName,
      collection: shelf.collection,
    );
    await store.saveShelf(_indexOf(summarised));
    return summarised;
  }

  /// FR-BAR-6: offers do not outlive the process, so load clears them.
  static Bar _unshared(Bar bar) =>
      bar.offers.isEmpty ? bar : bar.copyWith(offers: const []);

  static ShelfIndex _indexOf(Shelf shelf) =>
      (bars: shelf.bars, openId: shelf.openId, deviceName: shelf.deviceName);

  /// Null only when unreadable with no backup; a missing file reads as empty.
  Future<Collection?> _readableCollectionOf(BarStore store, String id) async =>
      _collectionFrom(await store.loadBar(id));

  static Collection? _collectionFrom(Outcome<BarContent> outcome) =>
      switch (outcome) {
        Ok(:final value) => value.collection,
        Empty() => Collection(),
        Rejected(:final recovered) => recovered?.collection,
        Unreachable() => null,
      };

  Future<Shelf> _foundFirstBar(BarStore store, List<String> issues) async {
    final bar = _newBar('Home bar', Collection());
    _report(issues);
    await store.saveBar(bar, Collection());
    await store.saveShelf((bars: [bar], openId: bar.id, deviceName: null));
    return Shelf(bars: [bar], openId: bar.id);
  }

  /// Contents, or the best recovered; failures go to issues (FR-DAT-4).
  Future<Collection> _collectionOf(
    BarStore store,
    String id,
    List<String> issues,
  ) async {
    final loaded = await store.loadBar(id);
    if (loaded is Rejected<BarContent>) {
      issues.addAll(_described(loaded.issues));
    }
    return _collectionFrom(loaded) ?? Collection();
  }

  /// The reader's unit, even on guest bars, so it stays off the writer
  /// (FR-BAR-3, FR-SET-1, ADR 21).
  Future<void> setDisplay(FixedUnit display) async {
    final shelf = await future;
    final bar = shelf.open;
    if (bar == null || bar.display == display) return;
    await _publish(shelf.withBar(bar.copyWith(display: display)));
  }

  /// Optimizer settings, kept beside the unit (ADR 24).
  Future<void> setShopping(ShoppingSettings shopping) async {
    final shelf = await future;
    final bar = shelf.open;
    if (bar == null || bar.shopping == shopping) return;
    await _publish(shelf.withBar(bar.copyWith(shopping: shopping)));
  }

  /// An opaque copy, so the screen hands it on unread (FR-DAT-1, FR-BAR-4).
  Future<String> export(String id) async {
    final shelf = await future;
    return ref
        .read(barStoreProvider)
        .exportSnapshot(shelf.barWithId(id)!, await _residentOrRead(shelf, id));
  }

  /// Only the bar on show is resident; others are read from file (ADR 20).
  Future<Collection> _residentOrRead(Shelf shelf, String id) async =>
      id == shelf.openId
      ? shelf.collection
      : await _collectionOf(ref.read(barStoreProvider), id, <String>[]);

  /// What [text] holds, judged before anything is touched (FR-DAT-3/4).
  ImportReview review(String text) => switch (const YamlCodec().decode(text)) {
    Ok(:final value) => (bar: value, issues: const <String>[]),
    Rejected(:final issues) => (bar: null, issues: _described(issues)),
    Empty() || Unreachable() => (bar: null, issues: const <String>[]),
  };

  /// FR-BAR-8: asks [source] once; what comes back is agreed on the form first.
  Future<Arrival> reach(BarSource source) async {
    final channel = ref.read(channelsProvider)[source.via];
    final outcome = channel == null
        ? Unreachable<BarContent>(UnreachableReason.notFound)
        : await channel.fetch(source);
    return switch (outcome) {
      Ok(:final value) => (
        review: (bar: value, issues: const <String>[]),
        why: null,
      ),
      Rejected(:final issues) => (
        review: (bar: null, issues: _described(issues)),
        why: null,
      ),
      Unreachable(:final why) => (review: null, why: why),
      // Null (dismissed picker) or Empty: nothing asked, nothing reported.
      null || Empty() => (review: null, why: null),
    };
  }

  /// Replaces the open bar's contents, copying what stood first (FR-DAT-3).
  /// Owned bars only; a guest's file is added as a new bar instead (FR-BAR-7).
  Future<void> replaceOpen(String name, BarContent payload) async {
    // Awaited first, so the copy is of what stood, not of nothing.
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
          .withBar(bar.copyWith(name: name, display: payload.display))
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
    // Reported even when empty, so a sound bar clears the banner.
    _report(issues);
    await _publish(shelf.opening(id, collection));
  }

  /// FR-BAR-2: a new owned bar, opened at once, empty or seeded from a picked
  /// file (FR-BAR-7).
  Future<void> addOwnedBar(String name, {BarContent? from}) {
    final collection = from?.collection ?? Collection();
    return _found(
      _newBar(name, collection, display: from?.display),
      collection,
    );
  }

  /// FR-BAR-3/7: another owner's shared bar, read-only (ADR 23), refreshable.
  Future<void> addGuestBar(String name, BarSource source, BarContent payload) =>
      _found(
        Bar(
          id: newBarId(),
          name: name,
          mode: BarMode.guest,
          display: payload.display,
          source: source,
          refreshed: _now(),
        ).summarised(payload.collection),
        payload.collection,
      );

  /// The file is written before the index, so a crash cannot strand a bar.
  Future<void> _found(Bar bar, Collection collection) async {
    final shelf = await future;
    await ref.read(barStoreProvider).saveBar(bar, collection);
    _report(const []);
    await _publish(shelf.withBar(bar).opening(bar.id, collection));
  }

  /// FR-BAR-5: re-asks a guest's source; progress shows in refreshesProvider.
  Future<void> refresh(String id) async {
    final shelf = await future;
    final source = shelf.barWithId(id)?.source;
    if (source == null) return;
    final refreshes = ref.read(refreshesProvider.notifier);
    final token = refreshes.ask(id);
    // A transport with no adapter yet (cloud) cannot be reached at all.
    final channel = ref.read(channelsProvider)[source.via];
    final outcome = channel == null
        ? Unreachable<BarContent>(UnreachableReason.notFound)
        : await channel.fetch(source);
    switch (outcome) {
      // Null (dismissed picker) or Empty: nothing asked, nothing failed.
      case null || Empty():
        refreshes.settled(id, token);
      case Rejected(:final issues):
        refreshes.settled(
          id,
          token,
          RefreshRefused(_described(issues), _now()),
        );
      case Unreachable(:final why):
        refreshes.settled(id, token, RefreshUnreachable(why, _now()));
      case Ok(:final value):
        await _applyRefresh(id, token, value);
    }
  }

  /// Applies only an answered refresh (FR-BAR-5).
  Future<void> _applyRefresh(String id, int token, BarContent payload) async {
    final shelf = await future;
    if (!ref.read(refreshesProvider.notifier).settled(id, token)) return;
    final refreshed = shelf.refreshedWith(id, payload, _now());
    // Null where the bar was deleted while the fetch was out.
    final bar = refreshed.barWithId(id);
    if (bar == null) return;
    // `_publish` saves only the bar on show: a bar behind the reader needs
    // saving here (ADR 20).
    if (id != refreshed.openId) {
      await ref.read(barStoreProvider).saveBar(bar, payload.collection);
    }
    await _publish(refreshed);
  }

  /// FR-BAR-8: the reader names this device (ADR 28); a blank name is ignored.
  /// A rename while announced is for the screen to refuse.
  Future<void> renameDevice(String name) async {
    final shelf = await future;
    if (name.isEmpty || name == shelf.deviceName) return;
    await _publish(shelf.namingDevice(name));
  }

  /// FR-BAR-6: intent is saved first; a failed announce is reported (ADR 22).
  Future<void> offerBar(String id, Transport via) async {
    final shelf = await future;
    final bar = shelf.barWithId(id);
    if (bar == null || bar.offeredBy(via)) return;
    await _publish(shelf.offering(id, via));
    ref.read(sharingProvider.notifier).announcing(id);
    await _telling(id, via, (offerings) => offerings.offer(id, bar.name));
  }

  /// FR-BAR-6: ends refreshes over this offer only; guests keep what they hold.
  Future<void> withdrawBar(String id, Transport via) async {
    final shelf = await future;
    final bar = shelf.barWithId(id);
    if (bar == null || !bar.offeredBy(via)) return;
    await _publish(shelf.withdrawing(id, via));
    ref.read(sharingProvider.notifier).silencing(id);
    await _telling(id, via, (offerings) => offerings.withdraw(id));
  }

  /// With no adapter in this build, the announcement is reported as refused.
  Future<void> _telling(
    String id,
    Transport via,
    Future<void> Function(BarOfferings) tell,
  ) async {
    final sharing = ref.read(sharingProvider.notifier);
    final offerings = ref.read(offeringsProvider)[via];
    if (offerings == null) {
      sharing.settled(
        id,
        SharingFailed('nothing shares over ${via.token}', _now()),
      );
      return;
    }
    try {
      await tell(offerings);
      sharing.settled(id);
    } on Exception catch (error) {
      sharing.settled(id, SharingFailed('$error', _now()));
    }
  }

  /// Counted from founding, so the list never meets one uncounted.
  /// A file that founds it brings its reading unit (ADR 21).
  Bar _newBar(String name, Collection collection, {FixedUnit? display}) => Bar(
    id: newBarId(),
    name: name,
    mode: BarMode.owner,
  ).copyWith(display: display).summarised(collection, at: _now());

  DateTime _now() => ref.read(clockProvider)();

  /// FR-BAR-2/3: the reader names any bar, a guest's included (ADR 21).
  /// A bar on offer is re-announced by name to each way offering it.
  Future<void> renameBar(String id, String name) async {
    final shelf = await future;
    final bar = shelf.barWithId(id);
    if (bar == null || bar.name == name) return;
    await _publish(shelf.withBar(bar.copyWith(name: name)));
    for (final offer in bar.offers) {
      await _telling(id, offer.via, (offerings) => offerings.offer(id, name));
    }
  }

  /// FR-BAR-2: the record goes before its file, so none opens onto nothing.
  Future<void> removeBar(String id) async {
    final shelf = await future;
    final bar = shelf.barWithId(id);
    if (bar == null) return;
    final store = ref.read(barStoreProvider);
    // A guest's contents are its owner's, so only an owned bar is copied.
    if (bar.isOwned) {
      await store.exportSnapshot(
        bar,
        await _residentOrRead(shelf, id),
        purpose: ExportPurpose.beforeDelete,
      );
    }
    await _publish(shelf.withoutBar(id));
    await store.removeBar(id);
  }

  /// The issues as a reader meets them (FR-DAT-4).
  static List<String> _described(List<SourcedIssue> issues) =>
      List.unmodifiable([for (final issue in issues) issue.description]);

  void _report(List<String> issues) =>
      ref.read(loadIssuesProvider.notifier).report(issues);

  /// Persists only what moved: a stock tap rewrites one bar's file, a unit pick
  /// only the index, and a crossing neither, so no backup rotates needlessly.
  Future<void> _publish(Shelf edited) async {
    final standing = state.requireValue;
    if (edited == standing) return;
    state = AsyncData(edited);
    final store = ref.read(barStoreProvider);
    final crossed = edited.openId != standing.openId;
    if (!crossed && edited.collection != standing.collection) {
      await store.saveBar(edited.open!, edited.collection);
    }
    if (crossed ||
        edited.deviceName != standing.deviceName ||
        !listEquals(edited.bars, standing.bars)) {
      await store.saveShelf(_indexOf(edited));
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
