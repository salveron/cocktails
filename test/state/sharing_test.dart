/// The owner's side in flight (FR-BAR-6): an offer recorded, announced, and
/// withdrawn again, over a fake owner's half — the seam being what keeps the
/// state layer device-free (ADR 22, docs/components.md#work-in-flight).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/domain/src/shelf/bar.dart' show summaryOf;
import 'package:cocktails/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_bar_store.dart';
import '../support/state_test_support.dart';

void main() {
  setUpShelf();

  late MemoryOfferings offerings;

  Future<ProviderContainer> sharing({MemoryBarStore? seeded}) {
    offerings = MemoryOfferings();
    return startedOver(
      seeded ?? store,
      clock: () => now,
      overrides: [
        offeringsProvider.overrideWithValue({Transport.lan: offerings}),
      ],
    );
  }

  Bar barIn(ProviderContainer container, [String? id]) =>
      container.read(shelfProvider).requireValue.barWithId(id ?? bar.id)!;

  SharingState? sharingOf(ProviderContainer container, String id) =>
      container.read(sharingProvider)[id];

  /// The pump is what reading the shelf first costs: the announcement is out a
  /// microtask after the call rather than within it.
  Future<void> offered(ProviderContainer container, {bool lands = true}) async {
    final offering = controllerOf(container).offerBar(bar.id, Transport.lan);
    await pumpEventQueue();
    final answering = offerings.out.isEmpty ? null : offerings.out.last;
    if (lands && answering != null && !answering.isCompleted) {
      answering.complete();
    }
    await offering;
  }

  group('offering', () {
    test(
      'the way is kept on the record, and announced under the name',
      () async {
        final container = await sharing();
        await offered(container);
        expect(barIn(container).offers.map((o) => o.via), [Transport.lan]);
        expect(offerings.offered.single, (id: bar.id, name: bar.name));
      },
    );

    /// The index is where an offer outlives the run (ADR 22), so it is written
    /// rather than held.
    test('the offer reaches the index', () async {
      final container = await sharing();
      await offered(container);
      final saved = store.savedShelf!.bars.single;
      expect(saved.offers.map((o) => o.via), [Transport.lan]);
    });

    /// One offer per transport is what a bar's coherence asks, so offering the
    /// same way again is not a second entry and announces nothing further.
    test('offering a way already offered announces nothing more', () async {
      final container = await sharing();
      await offered(container);
      await offered(container);
      expect(barIn(container).offers, hasLength(1));
      expect(offerings.offered, hasLength(1));
    });

    test(
      'while the announcement is out, the bar reads as announcing',
      () async {
        final container = await sharing();
        final offering = controllerOf(
          container,
        ).offerBar(bar.id, Transport.lan);
        await pumpEventQueue();
        expect(sharingOf(container, bar.id), isA<Announcing>());
        offerings.out.last.complete();
        await offering;
        expect(sharingOf(container, bar.id), isNull);
      },
    );
  });

  group('withdrawing', () {
    test('the way is dropped, and the device told to silence it', () async {
      final container = await sharing();
      await offered(container);
      final withdrawing = controllerOf(
        container,
      ).withdrawBar(bar.id, Transport.lan);
      await pumpEventQueue();
      expect(sharingOf(container, bar.id), isA<Silencing>());
      offerings.out.last.complete();
      await withdrawing;
      expect(barIn(container).offers, isEmpty);
      expect(offerings.withdrawn.single, bar.id);
      expect(sharingOf(container, bar.id), isNull);
    });

    test('withdrawing a way never offered tells the device nothing', () async {
      final container = await sharing();
      await controllerOf(container).withdrawBar(bar.id, Transport.lan);
      expect(offerings.withdrawn, isEmpty);
    });
  });

  /// D4: the intent rides on the record and the announcement does not, so what
  /// failed is reported rather than quietly un-offering the bar (ADR 22).
  group('an announcement that does not happen', () {
    test('leaves the offer standing, and says what stopped it', () async {
      final container = await sharing();
      offerings.refusing = Exception('no network');
      await offered(container, lands: false);
      expect(barIn(container).offers.map((o) => o.via), [Transport.lan]);
      final failed = sharingOf(container, bar.id);
      expect(failed, isA<SharingFailed>());
      expect((failed! as SharingFailed).message, contains('no network'));
      expect((failed as SharingFailed).at, now);
    });

    /// A transport with no adapter in this build announced nothing, which is
    /// the same thing to report as an announcement that refused.
    test('a way with no adapter in this build reports the same', () async {
      final container = await startedOver(
        store,
        clock: () => now,
        overrides: [offeringsProvider.overrideWithValue(const {})],
      );
      await controllerOf(container).offerBar(bar.id, Transport.lan);
      expect(barIn(container).offers.map((o) => o.via), [Transport.lan]);
      expect(sharingOf(container, bar.id), isA<SharingFailed>());
    });

    test('the reader having heard it clears it', () async {
      final container = await sharing();
      offerings.refusing = Exception('no network');
      await offered(container, lands: false);
      container.read(sharingProvider.notifier).told(bar.id);
      expect(sharingOf(container, bar.id), isNull);
    });
  });

  final guest = Bar(
    id: 'b3e1d7',
    name: "Bo's bar",
    mode: BarMode.guest,
    source: const BarSource(via: Transport.file, at: '', from: ''),
    refreshed: now,
    summary: summaryOf(stored),
  );

  MemoryBarStore withGuest() =>
      MemoryBarStore((bars: [bar, guest], openId: bar.id, deviceName: null))
        ..barOutcomes[bar.id] = Ok(contentOf(stored))
        ..barOutcomes[guest.id] = Ok(contentOf(stored));

  /// A guest already hands the collection over as a file, so offering it over
  /// the LAN is the same act with the same refusals — what is not written is
  /// the collection (FR-BAR-6, ADR 23).
  test('a guest bar is shared from here like an owned one', () async {
    final container = await sharing(seeded: withGuest());

    final offering = controllerOf(container).offerBar(guest.id, Transport.lan);
    await pumpEventQueue();
    offerings.out.last.complete();
    await offering;

    expect(barIn(container, guest.id).offeredBy(Transport.lan), isTrue);
    expect(offerings.offered.single, (id: guest.id, name: guest.name));
    expect(barIn(container, guest.id).source, guest.source);
  });

  group('renaming a bar on offer', () {
    /// An offer is listed by name, so a rename the room makes has to reach the
    /// list: offering again is how a way is renamed (ADR 22).
    test('lists it again under the new name', () async {
      final container = await sharing();
      await offered(container);
      final renaming = controllerOf(container).renameBar(bar.id, 'Cellar');
      await pumpEventQueue();
      offerings.out.last.complete();
      await renaming;
      expect(offerings.offered.last, (id: bar.id, name: 'Cellar'));
      expect(barIn(container).name, 'Cellar');
      expect(barIn(container).offers.map((o) => o.via), [Transport.lan]);
    });

    test('a bar not on offer tells the network nothing', () async {
      final container = await sharing();
      await controllerOf(container).renameBar(bar.id, 'Cellar');
      expect(offerings.offered, isEmpty);
    });

    test('a guest bar on offer is listed under the reader\'s name', () async {
      final container = await sharing(seeded: withGuest());
      final offering = controllerOf(
        container,
      ).offerBar(guest.id, Transport.lan);
      await pumpEventQueue();
      offerings.out.last.complete();
      await offering;
      final renaming = controllerOf(container).renameBar(guest.id, 'Mine now');
      await pumpEventQueue();
      offerings.out.last.complete();
      await renaming;
      expect(offerings.offered.last, (id: guest.id, name: 'Mine now'));
    });

    /// The record is the truth and the list a report of it, so a list that
    /// would not take the new name leaves the rename standing.
    test('a list that refuses the name leaves the rename standing', () async {
      final container = await sharing();
      await offered(container);
      offerings.refusing = Exception('no network');
      await controllerOf(container).renameBar(bar.id, 'Cellar');
      expect(barIn(container).name, 'Cellar');
      expect(sharingOf(container, bar.id), isA<SharingFailed>());
    });
  });
}
