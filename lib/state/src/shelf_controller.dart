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

/// The root: `ui/` reads through the derived providers and mutates through
/// `barWriterProvider` (ADR 23).
final shelfProvider = AsyncNotifierProvider<ShelfController, Shelf>(
  ShelfController.new,
);

/// What the last load — startup or crossing — turned up (FR-DAT-4). Ordinary
/// state: a field on the controller would only be right while every write set
/// it before the shelf moved, an invariant nothing could enforce.
final loadIssuesProvider = NotifierProvider<LoadIssuesController, List<String>>(
  LoadIssuesController.new,
);

final class LoadIssuesController extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void report(List<String> issues) => state = List.unmodifiable(issues);
}

/// What a picked file turned out to be (FR-DAT-4). Never both.
typedef ImportReview = ({BarContent? bar, List<String> issues});

/// What reaching a source turned up (FR-BAR-5/8): a bar to be agreed to or
/// refused, or the reason nothing arrived at all — never both. The reason is
/// [UnreachableReason] rather than words, the wording staying `ui/`'s (ADR 22).
typedef Arrival = ({ImportReview? review, UnreachableReason? why});

final class ShelfController extends AsyncNotifier<Shelf> {
  /// Reads the index and opens the bar it names (FR-DAT-4).
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
    final shelf = await _summarising(
      store,
      Shelf(
        bars: bars,
        openId: open?.id,
        deviceName: records.deviceName,
        collection: collection,
      ),
    );
    _announceStanding(shelf);
    return shelf;
  }

  /// An index written before a bar was ever summarised carries no counts for
  /// it, and the bar list reads counts alone (ADR 20). Each such bar is read
  /// once here, under the startup spinner, and written back holding the count
  /// — so this runs once per bar, ever. One that cannot be read keeps its
  /// absent summary rather than gaining one saying it holds nothing.
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

  /// What the store keeps of a shelf: the records and the two device-wide
  /// facts beside them.
  static ShelfIndex _indexOf(Shelf shelf) =>
      (bars: shelf.bars, openId: shelf.openId, deviceName: shelf.deviceName);

  /// A bar's contents where they could be read at all, null where the file is
  /// unreadable and no backup decoded. A file that never landed is the empty
  /// collection opening it would give, which is a real answer.
  Future<Collection?> _readableCollectionOf(BarStore store, String id) async =>
      _collectionFrom(await store.loadBar(id));

  /// The one outcome reading: as is here, coalesced in [_collectionOf].
  static Collection? _collectionFrom(Outcome<BarContent> outcome) =>
      switch (outcome) {
        Ok(:final value) => value.collection,
        Empty() => Collection(),
        Rejected(:final recovered) => recovered?.collection,
        Unreachable() => null,
      };

  /// A device holding nothing gets one empty owned bar, founded as any is.
  Future<Shelf> _foundFirstBar(BarStore store, List<String> issues) async {
    final bar = _newBar('Home bar', Collection());
    _report(issues);
    await store.saveBar(bar, Collection());
    await store.saveShelf((bars: [bar], openId: bar.id, deviceName: null));
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
    if (loaded is Rejected<BarContent>) {
      issues.addAll(_described(loaded.issues));
    }
    return _collectionFrom(loaded) ?? Collection();
  }

  /// The unit amounts read in: on the controller rather than the writer, being
  /// the reader's on a guest bar too (FR-BAR-3, FR-SET-1, ADR 21).
  Future<void> setDisplay(FixedUnit display) async {
    final shelf = await future;
    final bar = shelf.open;
    if (bar == null || bar.display == display) return;
    await _publish(shelf.withBar(bar.copyWith(display: display)));
  }

  /// What the optimizer is asked — beside the unit, for its reason (ADR 24).
  Future<void> setShopping(ShoppingSettings shopping) async {
    final shelf = await future;
    final bar = shelf.open;
    if (bar == null || bar.shopping == shopping) return;
    await _publish(shelf.withBar(bar.copyWith(shopping: shopping)));
  }

  /// A shareable copy and where it went, opaque so the screen hands it on
  /// unread (FR-DAT-1, FR-BAR-4).
  Future<String> export() async {
    final shelf = await future;
    return ref
        .read(barStoreProvider)
        .exportSnapshot(shelf.open!, shelf.collection);
  }

  /// What [text] holds, judged before anything is touched (FR-DAT-3/4). A
  /// decode never answers [Empty] or [Unreachable]; only here for [Outcome]'s
  /// sake.
  ImportReview review(String text) => switch (const YamlCodec().decode(text)) {
    Ok(:final value) => (bar: value, issues: const <String>[]),
    Rejected(:final issues) => (bar: null, issues: _described(issues)),
    Empty() || Unreachable() => (bar: null, issues: const <String>[]),
  };

  /// FR-BAR-8: [source] asked once, for a bar that does not exist here yet —
  /// the add's own fetch, where [refresh] is the same ask for one that does.
  /// Nothing is touched: what came back is agreed to on the form, as a picked
  /// file is.
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
      // A fetch answers neither, and a picker dismissed is not a road this
      // reaches: nothing was asked, so nothing is reported.
      null || Empty() => (review: null, why: null),
    };
  }

  /// Replaces the open bar's contents with a picked file's, copying what stood
  /// first (FR-DAT-3). Owned bars only — the same file is *added* as a guest bar
  /// instead (FR-BAR-7). [name] is the reader's, as a bar's name always is.
  Future<void> replaceOpen(String name, BarContent payload) async {
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
    // The banner reports the load last asked for, so a sound bar clears it.
    _report(issues);
    await _publish(shelf.opening(id, collection));
  }

  /// FR-BAR-2: a new bar, owned and opened on the spot — empty, or holding a
  /// picked file (FR-BAR-7), named by the reader where the contents are not.
  Future<void> addOwnedBar(String name, {BarContent? from}) {
    final collection = from?.collection ?? Collection();
    return _found(
      _newBar(name, collection, display: from?.display),
      collection,
    );
  }

  /// FR-BAR-3/7: another owner's bar, added from what they shared rather than
  /// imported into this device's own — the same file's other road, named by the
  /// reader as any is. Read-only (ADR 23), the source kept for a refresh.
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

  /// The founding both roads take: the bar's file before the index naming it,
  /// a crash between the two otherwise leaving a bar that opens onto nothing.
  Future<void> _found(Bar bar, Collection collection) async {
    final shelf = await future;
    await ref.read(barStoreProvider).saveBar(bar, collection);
    _report(const []);
    await _publish(shelf.withBar(bar).opening(bar.id, collection));
  }

  /// FR-BAR-5: asks a guest bar's source again, whatever way it came. Off the
  /// gesture — no screen awaits this, and what the ask is doing is met in
  /// `refreshesProvider`. An owned bar carries no source and is left alone.
  Future<void> refresh(String id) async {
    final shelf = await future;
    final source = shelf.barWithId(id)?.source;
    if (source == null) return;
    final refreshes = ref.read(refreshesProvider.notifier);
    final token = refreshes.ask(id);
    // A source naming a transport this build has no adapter for cannot be
    // reached at all — an index carrying `cloud` before its channel lands.
    final channel = ref.read(channelsProvider)[source.via];
    final outcome = channel == null
        ? Unreachable<BarContent>(UnreachableReason.notFound)
        : await channel.fetch(source);
    switch (outcome) {
      // The reader dismissed the picker: nothing was asked, so nothing
      // failed. A fetch never answers Empty; grouped here for the same reason.
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

  /// What a refresh that answered comes to, the bar left exactly as it stood
  /// where it did not (FR-BAR-5).
  Future<void> _applyRefresh(String id, int token, BarContent payload) async {
    final shelf = await future;
    if (!ref.read(refreshesProvider.notifier).settled(id, token)) return;
    final refreshed = shelf.refreshedWith(id, payload, _now());
    // Null where the bar was deleted while the fetch was out.
    final bar = refreshed.barWithId(id);
    if (bar == null) return;
    // `_publish` writes the bar on show and no other, so a refresh landing
    // behind the reader reaches its own file here (ADR 20).
    if (id != refreshed.openId) {
      await ref.read(barStoreProvider).saveBar(bar, payload.collection);
    }
    await _publish(refreshed);
  }

  /// FR-BAR-8: what this device announces itself as, the reader's to choose
  /// (ADR 28). A blank name is no name at all and is left alone; a rename while
  /// something is announced is the screen's to refuse, the announcement having
  /// gone up under the old one.
  Future<void> renameDevice(String name) async {
    final shelf = await future;
    if (name.isEmpty || name == shelf.deviceName) return;
    await _publish(shelf.namingDevice(name));
  }

  /// FR-BAR-6: an owned bar offered by [via]. The intent is recorded before the
  /// network hears anything, so an announcement that fails is reported rather
  /// than quietly un-offering the bar (ADR 22). A guest bar is its owner's to
  /// share, and one already offered this way is left alone.
  Future<void> offerBar(String id, Transport via) async {
    final shelf = await future;
    final bar = shelf.barWithId(id);
    if (bar == null || !bar.isOwned) return;
    if (bar.offeredBy(via)) return;
    await _publish(shelf.offering(id, via));
    ref.read(sharingProvider.notifier).announcing(id);
    await _telling(id, via, (offerings) => offerings.offer(id, bar.name));
  }

  /// FR-BAR-6: the offer by [via] withdrawn, which ends refreshes over it and
  /// nothing else — what a guest already holds stays theirs.
  Future<void> withdrawBar(String id, Transport via) async {
    final shelf = await future;
    final bar = shelf.barWithId(id);
    if (bar == null || !bar.isOwned) return;
    if (!bar.offeredBy(via)) return;
    await _publish(shelf.withdrawing(id, via));
    ref.read(sharingProvider.notifier).silencing(id);
    await _telling(id, via, (offerings) => offerings.withdraw(id));
  }

  /// FR-BAR-6: what the index says is offered, announced again — an offer
  /// outlives the run and an announcement does not (ADR 22). The record already
  /// says so, so this reaches the seam and nothing else, and nothing about the
  /// first frame waits on a socket. Past the build that calls it, the seam
  /// resolving the announced name off this very provider, and not at all where
  /// the container went first.
  void _announceStanding(Shelf shelf) {
    var live = true;
    ref.onDispose(() => live = false);
    scheduleMicrotask(() {
      if (!live) return;
      final sharing = ref.read(sharingProvider.notifier);
      for (final bar in shelf.bars) {
        for (final offer in bar.offers) {
          sharing.announcing(bar.id);
          unawaited(
            _telling(bar.id, offer.via, (o) => o.offer(bar.id, bar.name)),
          );
        }
      }
    });
  }

  /// The half that reaches the network, whichever way it is going. A transport
  /// with no adapter in this build announced nothing, which is the same thing
  /// to report as an announcement that refused.
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

  /// An owned bar, counted and stamped from the moment it is founded, so none
  /// is ever listed without the counts the list reads it by. A file that founded
  /// it brings its reading unit (ADR 21); `copyWith` keeps the default.
  Bar _newBar(String name, Collection collection, {FixedUnit? display}) => Bar(
    id: newBarId(),
    name: name,
    mode: BarMode.owner,
  ).copyWith(display: display).summarised(collection, at: _now());

  DateTime _now() => ref.read(clockProvider)();

  /// FR-BAR-2/3: what the bar is called here — the reader's on a guest bar as
  /// on their own, a label on someone else's collection rather than an edit to
  /// it, and kept across every refresh as the reading unit is (ADR 21).
  Future<void> renameBar(String id, String name) async {
    final shelf = await future;
    final bar = shelf.barWithId(id);
    if (bar == null || bar.name == name) return;
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

  /// Publish, then persist only what moved: a stock tap rewrites one bar's
  /// file, a unit pick only the index, and a crossing — its collection
  /// already up from disk — neither, so no backup rotates needlessly.
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
