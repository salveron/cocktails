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

    test('a file-picked bar is kept under the file transport', () {
      expect(fileSource.via, Transport.file);
    });
  });

  group('the ways a build offers', () {
    ProviderContainer over(BarStore store) {
      final container = ProviderContainer(
        overrides: [barStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

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
      expect(await exportOf(store, bar.id), canonicalText);
    });

    test('a bar the store cannot answer for is served nothing', () async {
      expect(await exportOf(MemoryBarStore(), 'nothing'), isNull);
    });
  });
}
