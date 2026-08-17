/// A bar arriving and arriving again (FR-BAR-3/5/7): adding a guest bar from
/// what an owner shared, and asking its source for it once more. Everything
/// here runs over a fake channel, the seam being what keeps the state layer
/// device-free (ADR 22, docs/components.md#work-in-flight).
library;

import 'dart:async';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_bar_store.dart';
import 'write_log.dart';

/// Answers nothing until a test says so, so the order two refreshes land in is
/// the test's to choose rather than the scheduler's.
final class _FakeChannel implements BarChannel {
  @override
  Transport get transport => Transport.file;

  /// Every source it was handed, in order.
  final asked = <BarSource>[];

  /// One per fetch still out, oldest first.
  final out = <Completer<FetchOutcome?>>[];

  @override
  Future<FetchOutcome?> fetch(BarSource source) {
    asked.add(source);
    final answering = Completer<FetchOutcome?>();
    out.add(answering);
    return answering.future;
  }
}

void main() {
  final now = DateTime.utc(2026, 8, 15, 9);
  const source = BarSource(via: Transport.file, at: '', from: '');

  final stored = Collection(
    ingredients: [Ingredient('gin', stock: StockLevel.in_)],
    recipes: [
      Recipe(
        'Martini',
        lines: const [
          RecipeLine(Amount(2), 'part', ['gin']),
        ],
      ),
    ],
  );
  final arrived = Collection(
    ingredients: [Ingredient('rye'), Ingredient('vermouth')],
    recipes: [
      Recipe(
        'Manhattan',
        lines: const [
          RecipeLine(Amount(2), 'part', ['rye']),
          RecipeLine(Amount(1), 'part', ['vermouth']),
        ],
      ),
    ],
  );

  BarPayload payloadOf(
    Collection collection, {
    String name = "Ada's bar",
    FixedUnit display = FixedUnit.ml,
  }) => (name: name, display: display, collection: collection);

  final owned = Bar(
    id: 'own1',
    name: 'Home bar',
    mode: BarMode.owner,
  ).summarised(Collection(), at: now);

  final guest = Bar(
    id: 'gst1',
    name: "Ada's bar",
    mode: BarMode.guest,
    display: FixedUnit.oz,
    source: source,
    refreshed: DateTime.utc(2026, 8, 1),
  ).summarised(stored);

  late _FakeChannel channel;
  late MemoryBarStore store;

  setUp(() {
    channel = _FakeChannel();
    store = MemoryBarStore.of(owned, Collection());
  });

  /// A store holding both bars, [openId] naming the one on show.
  MemoryBarStore holding(String openId) {
    final seeded = MemoryBarStore((bars: [owned, guest], openId: openId));
    seeded.barOutcomes[owned.id] = Loaded((
      name: owned.name,
      display: owned.display,
      collection: Collection(),
    ));
    seeded.barOutcomes[guest.id] = Loaded(payloadOf(stored));
    return seeded;
  }

  Future<ProviderContainer> started([MemoryBarStore? seeded]) async {
    final container = ProviderContainer(
      overrides: [
        barStoreProvider.overrideWithValue(seeded ?? store),
        clockProvider.overrideWithValue(() => now),
        channelsProvider.overrideWithValue({channel.transport: channel}),
      ],
    );
    addTearDown(container.dispose);
    await container.read(shelfProvider.future);
    return container;
  }

  ShelfController controllerOf(ProviderContainer container) =>
      container.read(shelfProvider.notifier);

  Bar barOf(ProviderContainer container, String id) =>
      container.read(shelfProvider).requireValue.barWithId(id)!;

  RefreshState? refreshOf(ProviderContainer container, String id) =>
      container.read(refreshesProvider)[id];

  /// Asks [id]'s source and hands it [outcome], returning once it has settled.
  /// The pump is what `refresh` reading the shelf first costs: the ask is out a
  /// microtask after the call rather than within it.
  Future<void> refreshed(
    ProviderContainer container,
    String id,
    FetchOutcome? outcome,
  ) async {
    final refreshing = controllerOf(container).refresh(id);
    await pumpEventQueue();
    channel.out.last.complete(outcome);
    await refreshing;
  }

  group('the channels a build offers', () {
    test('the file transport is wired to the picker beside it', () {
      final container = ProviderContainer(
        overrides: [filePickerProvider.overrideWithValue(() async => null)],
      );
      addTearDown(container.dispose);
      final channels = container.read(channelsProvider);
      expect(channels[Transport.file], isA<FileBarChannel>());
      // Declared ahead of its adapter, so the index's format need not move
      // when one lands (ADR 22).
      expect(channels[Transport.cloud], isNull);
    });
  });

  group('adding a guest bar', () {
    test('it lands read-only, opened, and keeping its source', () async {
      final container = await started();
      await controllerOf(
        container,
      ).addGuestBar("Bo's bar", source, payloadOf(arrived, name: "Ada's bar"));
      final shelf = container.read(shelfProvider).requireValue;
      expect(shelf.bars, hasLength(2));
      final added = shelf.open!;
      expect(added.mode, BarMode.guest);
      // What it is called here is the reader's, not the file's (FR-BAR-3).
      expect(added.name, "Bo's bar");
      expect(added.source, source);
      expect(added.refreshed, now);
      expect(container.read(collectionProvider), arrived);
      // Read-only from here on: nothing hands out a writer for it (ADR 23).
      expect(container.read(barWriterProvider), isNull);
    });

    /// Establishing is where a reader has no pick yet, so the file's own unit
    /// is what they start from; every refresh after keeps theirs (ADR 21).
    test('the file it came in names the unit it is first read in', () async {
      final container = await started();
      await controllerOf(
        container,
      ).addGuestBar('Ada', source, payloadOf(arrived, display: FixedUnit.ml));
      expect(
        container.read(shelfProvider).requireValue.open!.display,
        FixedUnit.ml,
      );
    });

    /// A crash between the two would otherwise leave the index naming a bar
    /// that opens onto nothing.
    test('its file lands before the index names it', () async {
      final logged = WriteLog((bars: [owned], openId: owned.id));
      logged.barOutcomes[owned.id] = Loaded((
        name: owned.name,
        display: owned.display,
        collection: Collection(),
      ));
      final container = await started(logged);
      logged.calls.clear();
      await controllerOf(
        container,
      ).addGuestBar('Ada', source, payloadOf(arrived));
      final added = container.read(shelfProvider).requireValue.open!;
      expect(logged.calls, ['bar:${added.id}', 'shelf']);
      expect(logged.savedBars[added.id]?.$2, arrived);
      expect(logged.savedShelf?.bars.map((bar) => bar.id), contains(added.id));
    });

    /// The bar list reads counts and nothing else (ADR 20), so a bar is never
    /// listed without them.
    test('it is counted from the moment it is added', () async {
      final container = await started();
      await controllerOf(
        container,
      ).addGuestBar('Ada', source, payloadOf(arrived));
      final added = container.read(shelfProvider).requireValue.open!;
      expect(added.holds, holdingsOf(arrived));
      // A guest's contents change only when its source answers.
      expect(added.updated, isNull);
    });
  });

  group('refreshing', () {
    test('what arrives replaces the collection, never the name', () async {
      final seeded = holding(guest.id);
      final container = await started(seeded);
      final refreshing = controllerOf(container).refresh(guest.id);
      await pumpEventQueue();
      expect(refreshOf(container, guest.id), isA<Reaching>());
      channel.out.single.complete(
        Fetched(payloadOf(arrived, name: 'The Ada Room')),
      );
      await refreshing;
      expect(container.read(collectionProvider), arrived);
      expect(barOf(container, guest.id).refreshed, now);
      // The reader named this bar; what the owner calls theirs is not news
      // enough to rename it (FR-BAR-3, ADR 21).
      expect(barOf(container, guest.id).name, guest.name);
      expect(refreshOf(container, guest.id), isNull);
      // What landed outlives the session: the bar on show is written as any
      // edit to it is, and the index restamped beside it.
      expect(seeded.savedBars[guest.id]?.$2, arrived);
      final listed = seeded.savedShelf!.bars.firstWhere(
        (bar) => bar.id == guest.id,
      );
      expect(listed.name, guest.name);
      expect(listed.refreshed, now);
    });

    /// The reader's picks outlive every refresh (FR-SET-1, ADR 21).
    test('the reading unit stays the reader\'s', () async {
      final container = await started(holding(guest.id));
      await refreshed(
        container,
        guest.id,
        Fetched(payloadOf(arrived, display: FixedUnit.ml)),
      );
      expect(barOf(container, guest.id).display, FixedUnit.oz);
    });

    test('it asks the source the bar was added from', () async {
      final container = await started(holding(guest.id));
      await refreshed(container, guest.id, Fetched(payloadOf(arrived)));
      expect(channel.asked, [source]);
    });

    /// Only the open bar's collection is resident (ADR 20), so a refresh
    /// landing behind the reader has to reach that bar's own file itself.
    test('one landing on a bar not on show writes that bar\'s file', () async {
      final seeded = holding(owned.id);
      final container = await started(seeded);
      await refreshed(container, guest.id, Fetched(payloadOf(arrived)));
      expect(seeded.savedBars[guest.id]?.$2, arrived);
      expect(barOf(container, guest.id).holds, holdingsOf(arrived));
      // The bar on show is untouched by another bar's refresh.
      expect(container.read(collectionProvider), Collection());
    });

    test('an owned bar carries no source and is never asked', () async {
      final container = await started(holding(owned.id));
      await controllerOf(container).refresh(owned.id);
      expect(channel.out, isEmpty);
      expect(refreshOf(container, owned.id), isNull);
    });

    test('a bar the shelf does not hold is never asked', () async {
      final container = await started(holding(guest.id));
      await controllerOf(container).refresh('nobody');
      expect(channel.out, isEmpty);
    });
  });

  group('a refresh that does not land', () {
    test('a refused file leaves the bar as it stood, and says why', () async {
      final container = await started(holding(guest.id));
      await refreshed(
        container,
        guest.id,
        Refused([
          SourcedIssue(
            ValidationIssue(
              const ['recipes', 0],
              ValidationIssueKind.unknownIngredient,
              'Unknown ingredient: "rye"',
            ),
            4,
          ),
        ]),
      );
      expect(container.read(collectionProvider), stored);
      expect(barOf(container, guest.id).refreshed, DateTime.utc(2026, 8, 1));
      final failure = refreshOf(container, guest.id);
      expect(failure, isA<RefreshRefused>());
      expect((failure! as RefreshRefused).issues, [
        'line 4: Unknown ingredient: "rye"',
      ]);
      expect((failure as RefreshRefused).at, now);
    });

    test(
      'a source that could not be reached says which way it failed',
      () async {
        final container = await started(holding(guest.id));
        await refreshed(
          container,
          guest.id,
          Unreachable(UnreachableReason.withdrawn),
        );
        expect(container.read(collectionProvider), stored);
        final failure = refreshOf(container, guest.id);
        expect(
          (failure! as RefreshUnreachable).why,
          UnreachableReason.withdrawn,
        );
      },
    );

    /// The file transport's fetch is the picker, and a reader who picked
    /// nothing has not failed at anything.
    test('a reader who stood down leaves nothing to be met', () async {
      final container = await started(holding(guest.id));
      await refreshed(container, guest.id, null);
      expect(container.read(collectionProvider), stored);
      expect(refreshOf(container, guest.id), isNull);
    });

    /// A source naming a transport this build has no adapter for — an index
    /// carrying `cloud` before its channel lands.
    test('a transport with no adapter cannot be reached', () async {
      final seeded = MemoryBarStore((
        bars: [
          Bar(
            id: 'cld1',
            name: "Ada's bar",
            mode: BarMode.guest,
            source: const BarSource(
              via: Transport.cloud,
              at: 'somewhere',
              from: 'Ada',
            ),
          ).summarised(stored),
        ],
        openId: 'cld1',
      ));
      seeded.barOutcomes['cld1'] = Loaded(payloadOf(stored));
      final container = await started(seeded);
      await controllerOf(container).refresh('cld1');
      expect(channel.out, isEmpty);
      final failure = refreshOf(container, 'cld1');
      expect((failure! as RefreshUnreachable).why, UnreachableReason.notFound);
    });

    test(
      'a bar deleted while the fetch was out takes its answer with it',
      () async {
        final seeded = holding(owned.id);
        final container = await started(seeded);
        final refreshing = controllerOf(container).refresh(guest.id);
        await pumpEventQueue();
        await controllerOf(container).removeBar(guest.id);
        channel.out.single.complete(Fetched(payloadOf(arrived)));
        await refreshing;
        expect(
          container.read(shelfProvider).requireValue.barWithId(guest.id),
          isNull,
        );
        expect(refreshOf(container, guest.id), isNull);
        expect(seeded.savedBars.containsKey(guest.id), isFalse);
      },
    );
  });

  group('two asks for one bar', () {
    test('the newer one stands and the late answer is dropped', () async {
      final container = await started(holding(guest.id));
      final controller = controllerOf(container);
      final first = controller.refresh(guest.id);
      final second = controller.refresh(guest.id);
      await pumpEventQueue();
      expect(channel.out, hasLength(2));
      channel.out[1].complete(Fetched(payloadOf(arrived)));
      await second;
      channel.out[0].complete(Fetched(payloadOf(stored)));
      await first;
      // The contents of the newer answer, and the counts that go with them.
      expect(container.read(collectionProvider), arrived);
      expect(barOf(container, guest.id).holds, holdingsOf(arrived));
    });

    test('a late failure never lands on top of one that succeeded', () async {
      final container = await started(holding(guest.id));
      final controller = controllerOf(container);
      final first = controller.refresh(guest.id);
      final second = controller.refresh(guest.id);
      await pumpEventQueue();
      channel.out[1].complete(Fetched(payloadOf(arrived)));
      await second;
      channel.out[0].complete(Unreachable(UnreachableReason.offline));
      await first;
      expect(refreshOf(container, guest.id), isNull);
    });

    /// A new ask clears what the last one came to: a reader watching a failure
    /// is told the app is trying again, not left reading the old refusal.
    test('asking again clears the failure standing', () async {
      final container = await started(holding(guest.id));
      await refreshed(
        container,
        guest.id,
        Unreachable(UnreachableReason.offline),
      );
      expect(refreshOf(container, guest.id), isA<RefreshUnreachable>());
      final again = controllerOf(container).refresh(guest.id);
      await pumpEventQueue();
      expect(refreshOf(container, guest.id), isA<Reaching>());
      channel.out[1].complete(null);
      await again;
    });
  });
}
