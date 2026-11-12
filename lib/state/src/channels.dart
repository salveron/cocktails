library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'derived.dart';
import 'seams.dart';

/// Both LAN halves in one adapter, since one device is one server (ADR 22).
/// The announced name is a supplier, so a rename needs no rebuild (ADR 28).
final _lanProvider = Provider<LanBarChannel>((ref) {
  final store = ref.watch(barStoreProvider);
  final lan = LanBarChannel(
    bytesOf: (id) => exportOf(
      store,
      ref.read(barsProvider).where((bar) => bar.id == id).firstOrNull,
    ),
    deviceName: () => ref.read(deviceNameProvider),
  );
  ref.onDispose(lan.stop);
  return lan;
});

/// Replaced wholesale by fakes, so nothing above learns what a network is.
/// `Transport.cloud` has no adapter yet; refreshes meet [Unreachable] (ADR 22).
final channelsProvider = Provider<Map<Transport, BarChannel>>(
  (ref) => Map.unmodifiable({
    Transport.file: FileBarChannel(ref.watch(filePickerProvider)),
    Transport.lan: ref.watch(_lanProvider),
  }),
);

/// Where a file-picked bar is kept: no screen builds an address (ADR 22).
const fileSource = FileBarChannel.source;

/// Offers nearby (FR-BAR-8); with no finder, none found (ADR 22, ADR 04).
final nearbyProvider = Provider<Stream<List<Found>> Function()>(
  (ref) => () {
    final finder = ref.read(findersProvider)[Transport.lan];
    if (finder == null) return const Stream<List<Found>>.empty();
    return finder.nearby();
  },
);

final findersProvider = Provider<Map<Transport, BarFinder>>(
  (ref) => Map.unmodifiable({Transport.lan: ref.watch(_lanProvider)}),
);

/// An offer over an absent transport is recorded but never announced.
final offeringsProvider = Provider<Map<Transport, BarOfferings>>(
  (ref) => Map.unmodifiable({Transport.lan: ref.watch(_lanProvider)}),
);

/// Name and unit come from the record, since renames move the index alone.
/// Canonical emit, so wire and file copies match (ADR 22); null: not offered.
Future<String?> exportOf(BarStore store, Bar? bar) async {
  if (bar == null) return null;
  return switch (await store.loadBar(bar.id)) {
    Ok(:final value) => const YamlCodec().encode(
      bar.contentWith(value.collection),
    ),
    _ => null,
  };
}
