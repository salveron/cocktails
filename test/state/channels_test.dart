/// The registry the sharing seam resolves through (ADR 22): which transport
/// has an adapter in this build, and which is only declared.
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/data_test_support.dart';
import '../support/domain_test_support.dart';
import '../support/memory_bar_store.dart';

void main() {
  /// A container over [store] alone — what every provider here needs and the
  /// only thing most of them do.
  ProviderContainer over(BarStore store) {
    final container = ProviderContainer(
      overrides: [barStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the channels a build offers', () {
    test('a file is picked and the LAN is asked (FR-BAR-7/8)', () {
      final container = ProviderContainer(
        overrides: [
          filePickerProvider.overrideWithValue(() async => null),
          barStoreProvider.overrideWithValue(MemoryBarStore()),
        ],
      );
      addTearDown(container.dispose);
      final channels = container.read(channelsProvider);
      expect(channels[Transport.file], isA<FileBarChannel>());
      expect(channels[Transport.lan], isA<LanBarChannel>());
      // Declared ahead of its adapter, so the index's format need not move
      // when one lands (ADR 22).
      expect(channels[Transport.cloud], isNull);
    });

    /// One device is one server and one announcement (ADR 22), so the two
    /// registries name the same adapter rather than one each.
    test('the LAN fetches and offers through one adapter', () {
      final container = over(MemoryBarStore());
      expect(
        container.read(channelsProvider)[Transport.lan],
        same(container.read(offeringsProvider)[Transport.lan]),
      );
    });

    test('a file-picked bar is kept under the file transport', () {
      expect(fileSource.via, Transport.file);
    });
  });

  group('the ways a build offers', () {
    test('the LAN offers and a file does not (FR-BAR-7)', () {
      final offerings = over(MemoryBarStore()).read(offeringsProvider);
      expect(offerings[Transport.lan], isA<LanBarChannel>());
      // A file is handed over rather than offered, so nothing follows it to
      // withdraw; the cloud waits on an adapter of any kind (ADR 22).
      expect(offerings[Transport.file], isNull);
      expect(offerings[Transport.cloud], isNull);
    });

    test('what is served is the bar\'s own export (ADR 22)', () async {
      final bar = ownedBar();
      final store = MemoryBarStore.of(bar, docCollection());
      expect(await exportOf(store, bar), canonicalText);
    });

    /// A rename and a unit pick move the index and no bar file, so the file's
    /// own header is what a guest would otherwise be handed (FR-BAR-6).
    test(
      'the name and unit served are the record\'s, not the file\'s',
      () async {
        final stale = ownedBar();
        final store = MemoryBarStore.of(stale, docCollection());
        final moved = stale.copyWith(name: 'Cellar', display: FixedUnit.ml);
        final served = await exportOf(store, moved);
        expect(const YamlCodec().decode(served!), isA<Ok<BarContent>>());
        final content =
            (const YamlCodec().decode(served) as Ok<BarContent>).value;
        expect(content.name, 'Cellar');
        expect(content.display, FixedUnit.ml);
      },
    );

    test('a guest bar is served as it was last refreshed', () async {
      final guest = guestBar();
      final store = MemoryBarStore.of(guest, docCollection());
      final served = await exportOf(store, guest);
      final content =
          (const YamlCodec().decode(served!) as Ok<BarContent>).value;
      expect(content.name, guest.name);
      expect(content.collection, docCollection());
    });

    test('a bar the store cannot answer for is served nothing', () async {
      expect(await exportOf(MemoryBarStore(), ownedBar()), isNull);
    });

    test('a bar the shelf does not hold is served nothing', () async {
      expect(await exportOf(MemoryBarStore(), null), isNull);
    });
  });
}
