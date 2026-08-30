/// Which transport carries a bar, and what a bar picked off each is kept
/// under — the registry the sharing seam is resolved through (ADR 22).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// transports have one at all (ADR 22). Empty until the composition root has a
/// name to hand the LAN adapter to announce under; a transport absent here has
/// no adapter in this build, so an offer over it is kept on the record and
/// announced by nothing.
final offeringsProvider = Provider<Map<Transport, BarOfferings>>(
  (ref) => const {},
);
