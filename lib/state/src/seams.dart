/// Where the platform crosses in, one provider each so a test swaps in a
/// function (ADR 18, docs/architecture.md#platform-facts).
library;

import 'dart:convert';
import 'dart:math';

import 'package:cocktails/data/data.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

final barStoreProvider = Provider<BarStore>(
  (ref) => throw UnimplementedError('barStoreProvider must be overridden'),
);

/// The clock a bar's stamps are read off — a seam so a test names the time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// A recipe draw's randomness — a seam so a test names the sequence (FR-DIS-5).
final randomProvider = Provider<Random>((ref) => Random());

/// Takes an export's opaque location; `text/plain`, Android knowing no YAML.
final sharerProvider = Provider<Future<void> Function(String)>(
  (ref) =>
      (location) => SharePlus.instance.share(
        ShareParams(files: [XFile(location, mimeType: 'text/plain')]),
      ),
);

/// What the phone calls itself, overridden at the composition root with what
/// [platformDeviceName] answered — so everything downstream reads a plain
/// string, and a test that overrides nothing reads the fallback (ADR 28).
final platformNameProvider = Provider<String>((ref) => fallbackDeviceName);

const fallbackDeviceName = 'Cocktails';

const _deviceChannel = MethodChannel('dev.salveron.cocktails/device');

/// The name the reader gave this phone, or [fallbackDeviceName] where there is
/// none to give and where there is no Android host to ask.
Future<String> platformDeviceName() async {
  try {
    final name = await _deviceChannel.invokeMethod<String>('name');
    return name == null || name.trim().isEmpty ? fallbackDeviceName : name;
  } on PlatformException {
    return fallbackDeviceName;
  } on MissingPluginException {
    return fallbackDeviceName;
  }
}

/// The picked text, null where nothing was picked; no filter would match.
final filePickerProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final picked = await openFile();
    return picked == null ? null : pickedText(picked);
  },
);

/// Named, not inlined, so overriding the provider with a plain string never
/// reaches it; throws over `readAsString`'s silent U+FFFD substitution.
Future<String> pickedText(XFile picked) async =>
    utf8.decode(await picked.readAsBytes());
