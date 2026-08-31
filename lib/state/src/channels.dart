/// Which transport carries a bar, and what a bar picked off each is kept
/// under — the registry the sharing seam is resolved through (ADR 22).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'derived.dart';
import 'seams.dart';

/// Both halves of the LAN in one adapter, since one device is one server and
/// one announcement (ADR 22); the announced name a supplier, so a rename needs
/// no rebuild (ADR 28).
final _lanProvider = Provider<LanBarChannel>((ref) {
  final store = ref.watch(barStoreProvider);
  final lan = LanBarChannel(
    bytesOf: (id) => exportOf(store, id),
    deviceName: () => ref.read(deviceNameProvider),
  );
  ref.onDispose(lan.stop);
  return lan;
});

/// The ways a bar travels, by transport — replaced wholesale by fakes, so
/// nothing above learns what a network is. One absent here has no adapter in
/// this build: how `Transport.cloud` waits, and what a refresh meets as
/// [Unreachable] (ADR 22).
final channelsProvider = Provider<Map<Transport, BarChannel>>(
  (ref) => Map.unmodifiable({
    Transport.file: FileBarChannel(ref.watch(filePickerProvider)),
    Transport.lan: ref.watch(_lanProvider),
  }),
);

/// What a file-picked bar is kept under: no screen builds an address (ADR 22).
const fileSource = FileBarChannel.source;

/// The owner's half, which only some ways have: a file is handed over rather
/// than offered. An offer over a way absent here stands on the record and is
/// announced by nothing.
final offeringsProvider = Provider<Map<Transport, BarOfferings>>(
  (ref) => Map.unmodifiable({Transport.lan: ref.watch(_lanProvider)}),
);

/// What a stranger is served for the bar [id]: a load and the canonical
/// emitter, so a copy taken over the wire and one sent as a file are the same
/// document. Null reads on the wire as a bar not offered (ADR 22).
Future<String?> exportOf(BarStore store, String id) async =>
    switch (await store.loadBar(id)) {
      Ok(:final value) => const YamlCodec().encode(value),
      _ => null,
    };
