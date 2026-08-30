/// Which transport carries a bar, and what a bar picked off each is kept
/// under — the registry the sharing seam is resolved through (ADR 22).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'derived.dart';
import 'seams.dart';

/// The ways a bar travels, by transport — composed from the seams beside it and
/// replaced wholesale by fakes, so nothing above learns what a network is. One
/// absent here has no adapter in this build, which is how `Transport.cloud`
/// waits (ADR 22).
final channelsProvider = Provider<Map<Transport, BarChannel>>(
  (ref) => Map.unmodifiable({
    Transport.file: FileBarChannel(ref.watch(filePickerProvider)),
  }),
);

/// What a file-picked bar is kept under: no screen builds an address (ADR 22).
const fileSource = FileBarChannel.source;

/// The owner's half of each way a bar travels, by transport — only some
/// transports have one at all (ADR 22). A transport absent here has no adapter
/// in this build, so an offer over it is kept on the record and announced by
/// nothing; a file is handed over rather than offered, so it has none.
///
/// The name the LAN announces under is read per announcement rather than held,
/// which is what lets a rename take without rebuilding a live adapter (ADR 28).
final offeringsProvider = Provider<Map<Transport, BarOfferings>>((ref) {
  final store = ref.watch(barStoreProvider);
  final lan = LanBarChannel(
    bytesOf: (id) => exportOf(store, id),
    deviceName: () => ref.read(deviceNameProvider),
  );
  ref.onDispose(lan.stop);
  return Map.unmodifiable({Transport.lan: lan});
});

/// What a stranger is served for the bar [id]: its own export, read through
/// [store] and put back out by the canonical emitter, so a copy taken over the
/// wire and one sent as a file are the same document (ADR 22). Null where the
/// store cannot answer for it — on the wire that reads as a bar not offered,
/// which is one of the three readings and none of them is *broken*.
Future<String?> exportOf(BarStore store, String id) async =>
    switch (await store.loadBar(id)) {
      Ok(:final value) => const YamlCodec().encode(value),
      _ => null,
    };
