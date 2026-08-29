/// The registry the sharing seam resolves through (ADR 22): which transport
/// has an adapter in this build, and which is only declared.
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
